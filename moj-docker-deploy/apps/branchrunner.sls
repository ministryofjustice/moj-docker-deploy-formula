# Only enable if this pillar key exists
{% if salt['pillar.get']('branch_containers', False) %}
include:
  - apps.containers
  - apps.branchremover

{% for branch_name in salt['grains.get']('branch_names', []) %}
{% set branch_name = branch_name | replace("'", "''") %}
{% set default_registry = salt['pillar.get']('default_registry', '') %}
{% set branch_container_key = salt['pillar.get']('branch_containers') %}
{% set branch_container_name = salt['pillar.get']('branch_container_name') %}
{% set branch_container = salt['pillar.get']('{0}:{1}'.format(branch_container_key, branch_container_name)) %}
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

/etc/init/{{branch_name}}_container.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://apps/templates/upstart_branch_container.conf
    - template: jinja
    - context: 
      branch_container_full: {{ branch_container_full }}
      branch_name: {{branch_name}}
      cdata: {{ branch_container | yaml}}
      cname: {{ branch_container_name}}
      tag: '{{ branch_name }}'
      DATABASE_URL: {{DATABASE_URL}}

{{branch_name}}_service:
  service.running:
    - name: {{branch_name}}_container
    - enable: true
    - watch:
      - file: /etc/init/{{branch_name}}_container.conf
      - file: /etc/docker_env.d/{{branch_container_name}}
      - docker: {{ branch_name }}_pull
    - require_in:
      - file: /etc/nginx/conf.d/{{ branch_name }}.conf

'/etc/nginx/conf.d/{{branch_name}}.conf':
  file.managed:
    - source: salt://apps/templates/nginx_container.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
      server_name: '{{branch_name}}.{{
        salt['pillar.get'](
          'branch_runner:container_base_hostname',
          default=salt['pillar.get']('master_zone')
        )
      }}'
      branch_name: '{{branch_name}}'
      appdata:
        branchbuilder: True
        assets_host_path: '/{{branch_name}}/'
        containers:
          '{{branch_name}}': {{branch_container | yaml}}
    - watch_in:
      - service: nginx

{% endfor %}
{% endif %}
