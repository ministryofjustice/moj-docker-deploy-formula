include:
  - apps.container

{% if salt['pillar.get']('rds:db-engine', False) == 'postgres' %}
postgresql-client:
  pkg.installed
{% endif %}

{% for branch_name in salt['grains.get']('dead_branch_names', []) %}
{% set branch_name = branch_name | replace("'", "''") %}

{% if salt['pillar.get']('rds:db-engine', False) == 'postgres' %}
'{{ branch_name }}_dropdb':
  cmd.run:
    - name: dropdb --if-exists '{{branch_name}}'
    - env:
      - PGPASSWORD: '{{salt['pillar.get']('rds:db-master-password')}}'
      - PGHOST: '{{salt['grains.get']('dbhost')}}'
      - PGPORT: '{{salt['grains.get']('dbport')}}'
      - PGUSER: '{{salt['pillar.get']('rds:db-master-username')}}'
    - require:
      - docker: '{{ branch_name }}'
      - pkg: postgresql-client
      - cmd: '{{ branch_name }}_dropconnections'

'/tmp/dc-{{branch_name}}.sql':
  file.managed:
    - source: salt://templates/disconnect_postgres.sql
    - template: jinja
    - context:
      branch_name: '{{branch_name}}'

'{{ branch_name }}_dropconnections':
  cmd.run:
    - name: 'psql -d {{salt['pillar.get']('rds:db-name')}} -f /tmp/dc-{{branch_name}}.sql'
    - require:
      - file: '/tmp/dc-{{branch_name}}.sql'
    - env:
      - PGPASSWORD: '{{salt['pillar.get']('rds:db-master-password')}}'
      - PGHOST: '{{salt['grains.get']('dbhost')}}'
      - PGPORT: '{{salt['grains.get']('dbport')}}'
      - PGUSER: '{{salt['pillar.get']('rds:db-master-username')}}'
{% endif %}

'/etc/nginx/conf.d/{{branch_name}}.conf':
  file.absent:
    - watch_in:
      - service: nginx

'{{ branch_name }}':
  docker.absent

'dead_branch_names_{{branch_name}}':
  grains.list_absent:
    - name: dead_branch_names
    - value: '{{ branch_name }}'

{% endfor %}

{% for branch_name in salt['grains.get']('branch_names', []) %}
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
