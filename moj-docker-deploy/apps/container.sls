include:
  - nginx
  - docker
  - .environment

{% if salt['pillar.get']('registry_logins') %}
/root/.dockercfg:
  file.managed:
    - source: salt://apps/templates/docker_logins.py
    - template: py
    - user: root
    - group: root
    - mode: 600
{% endif %}

HOME:
  environ.setenv:
    - value: /root

{% if salt['grains.get']('dead_branch_name', False) %}
{% set branch_name = salt['grains.get']('dead_branch_name') | replace('/', '-') %}
{% set branch_name = branch_name | replace("'", "''") %}

{%- if salt['pillar.get']('rds:db-engine', False) == 'postgres' %}
postgresql-client:
  pkg.installed

'{{ branch_name }}_dropdb':
  cmd.run:
    - name: dropdb '{{ branch_name}}'
    - env:
      - PGPASSWORD: '{{salt['pillar.get']('rds:db-master-password')}}'
      - PGHOST: '{{salt['grains.get']('dbhost')}}'
      - PGPORT: '{{salt['grains.get']('dbport')}}'
      - PGUSER: '{{salt['pillar.get']('rds:db-master-username')}}'
    - require:
      - docker: '{{ branch_name }}'
      - pkg: postgresql-client
{% endif %}

'/etc/nginx/conf.d/{{branch_name}}.conf':
  file.absent:
    - watch_in:
      - service: nginx


'{{ branch_name }}':
  docker.absent
{% endif %}

{% for branch_name in salt['grains.get']('branch_names', []) %}
{% set branch_name = branch_name | replace('/', '-') %}
{% set branch_name = branch_name | replace("'", "''") %}
{% set container_port = salt['pillar.get']('branch_port') %}
{% set branch_environment = salt['pillar.get']('branch_environment') %}
{% set default_registry = salt['pillar.get']('default_registry', '') %}
{% set branch_container = salt['pillar.get']('branch_container') %}
{% set branch_container_name = branch_container.keys()[0] %}
{% set docker_registry = branch_container.get('registry', default_registry) %}
{% set branch_container_full = '%s/%s' % (docker_registry, branch_container_name) %}

{%- if salt['pillar.get']('rds:db-engine', False) %}
{% set db_password = pillar['rds']['db-master-password'] | urlencode %}
{% set DATABASE_URL= '%s://%s:%s@%s:%s/%s' | format(
                        pillar['rds']['db-engine'],
                        pillar['rds']['db-master-username'],
                        db_password,
                        grains['dbhost'],
                        grains['dbport'],
                        branch_name ) %}
{% endif %}

'{{ branch_name }}_pull':
  docker.pulled:
    - name: {{ branch_container_full }}
    - tag: '{{ branch_name }}'
    - force: True
    - require:
      # We need this for docker-py to find the dockercfg and login
      - environ: HOME

'{{ branch_name }}':
  cmd.run:
    - name: docker run -d --name='{{branch_name}}' --env-file /etc/docker_env.d/{{ branch_container_name }} -e DB_NAME='{{branch_name}}' -e DOCKER_STATE=vagrant -e DATABASE_URL="{{DATABASE_URL}}" -p {{container_port}} {{ branch_container_full }}:'{{ branch_name }}'
    - unless: docker ps | grep '{{branch_name}}'
    - require:
      - docker: '{{ branch_name }}_pull'

'/etc/nginx/conf.d/{{branch_name}}.conf':
  file.managed:
    - source: salt://apps/templates/nginx_container.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
      server_name: '{{branch_name}}.{{ salt['pillar.get']('master_zone') }}'
      branch_name: '{{branch_name}}'
      appdata:
        branchbuilder: True
        containers:
          '{{branch_name}}':
            http_locations:
              - /ping.json

      container_port: {{container_port}}
    - require:
      - cmd: '{{ branch_name }}'
    - watch_in:
      - service: nginx

{% endfor %}

{% for server_name, appdata in salt['pillar.get']('docker_envs', {}).items() %}
/etc/nginx/conf.d/{{server_name}}.conf:
  file.managed:
    - source: salt://apps/templates/nginx_container.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
      server_name: {{server_name}}
      appdata: {{appdata}}
    - watch_in:
      - service: nginx

{% for container, cdata in appdata.get('containers',{}).items() %} # Start container loop
{# Set up variables from pillar #}
{% set container_name = cdata.get('name', container) %}
{% set default_registry = salt['pillar.get']('default_registry', '') %}
{% set docker_registry = cdata.get('registry', default_registry) %}
{% set container_full_name = '%s/%s' % (docker_registry, container_name) %}

{{ container }}_pull:
  docker.pulled:
    - name: {{ container_full_name }}
    - tag: '{{ salt['grains.get']('%s_tag' % container , 'latest') | replace("'", "''") }}'
    - force: True
    - require:
      # We need this for docker-py to find the dockercfg and login
      - environ: HOME

/etc/init/{{container}}_container.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://apps/templates/upstart_container.conf
    - template: jinja
    - context:
      cdata: {{cdata}}
      cname: {{container}}
      default_registry: {{ salt['pillar.get']('default_registry', '') }}
      tag: '{{ salt['grains.get']('%s_tag' % container , 'latest') | replace("'", "''") }}'

{{container}}_service:
  service.running:
    - name: {{container}}_container
    - enable: true
    - watch:
      - file: /etc/init/{{container}}_container.conf
      - file: /etc/docker_env.d/{{container}}
      - docker: {{ container }}_pull

{% if salt['grains.get']('zero_downtime_deploy', False) %}
{% for elb in salt['pillar.get']('elb',[]) %}
{{ container }}_{{ elb['name'] }}_down:
  elb_reg.instance_deregistered:
    - name: ELB-{{ elb['name'] | replace(".", "") }}
    - instance: {{ salt['grains.get']('aws_instance_id', []) }}
    - timeout: 130
    # This must always happen before we touch the service:
    - require_in:
      - service: {{container}}_service
    # This should be onchanges but salt currently ANDs these changes
    # Because it is a watch if you do a zero downtime deploy and nothing's
    # Changed salt will still de/re-register you in the ELB. We can change
    # this to onchanges once this is released:
    # https://github.com/saltstack/salt/pull/24703
    - watch:
      - file: /etc/init/{{container}}_container.conf
      - file: /etc/docker_env.d/{{container}}
      - docker: {{container}}_pull

{{ container }}_{{ elb['name'] }}_up:
  elb_reg.instance_registered:
    - name: ELB-{{ elb['name'] | replace(".", "") }}
    - instance: {{ salt['grains.get']('aws_instance_id', []) }}
    - timeout: 120
    - watch:
      # Once the container service has restarted, make sure we
      # are registered in the ELB.
      - service: {{ container }}_service
{% endfor %}
{% endif %}
     
{% endfor %} # End container loop
{% endfor %} # End app loop
