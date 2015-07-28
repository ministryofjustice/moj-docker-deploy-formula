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
{% set container_port = branch_container.get('ports')['app']['container'] %}
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
    - name: docker run -d --name='{{branch_name}}' --env-file /etc/docker_env.d/{{ branch_container_name }} -e DB_NAME='{{branch_name}}' -e DOCKER_STATE=create -e DATABASE_URL="{{DATABASE_URL}}" -p {{container_port}} {{ branch_container_full }}:'{{ branch_name }}'
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
        assets_host_path: '/{{branch_name}}/'
        containers:
          '{{branch_name}}': {{branch_container | yaml}}
    - require:
      - cmd: '{{ branch_name }}'
    - watch_in:
      - service: nginx

{% endfor %}
{% endif %}
