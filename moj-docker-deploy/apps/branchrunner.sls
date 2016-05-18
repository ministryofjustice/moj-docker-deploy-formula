# Only enable if this pillar key exists
{% if salt['pillar.get']('branch_runner', False) %}
include:
  - .containers
  - .branchremover

# Here we loop through branch names set in a grain by jenkins
{% for branch_name in salt['grains.get']('branch_names', []) %}

# Here we get the settings for the container the branch runner will run
# This is the path to the dictionary with the vhost config
{% set branch_pillar_path = salt['pillar.get']('branch_runner:pillar_path') %}
# This is the container to select from the vhost
{% set branch_container_name = salt['pillar.get']('branch_runner:container_to_run') %}
# This is the vhost we will use to configure nginx
{% set branch_vhost = salt['pillar.get'](branch_pillar_path) %}
# This is the container config we will use to run the branch container
{% set branch_container = branch_vhost['containers'][branch_container_name] %}

# Here we construct the string to send to docker pull
{% set default_registry = salt['pillar.get']('default_registry', '') %}
{% set docker_registry = branch_container.get('registry', default_registry) %}
{% set branch_container_long_name = branch_container['name'] %}
{% set branch_container_full = '%s/%s' % (docker_registry, branch_container_long_name) %}

{%- if salt['pillar.get']('rds:db-engine', False) %}
# If there is a database we need to override it with a fresh dbname
{% set db_password = pillar['rds']['db-master-password'] | urlencode %}
{% set DATABASE_URL= '%s://%s:%s@%s:%s/%s' | format(
                        pillar['rds']['db-engine'],
                        pillar['rds']['db-master-username'],
                        db_password,
                        grains['dbhost'],
                        grains['dbport'],
                        branch_name ) %}
{% else %}
{% set DATABASE_URL= "" %}
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
    - source: salt://moj-docker-deploy/apps/templates/upstart_branch_container.conf
    - template: jinja
    - context: 
      branch_container_full: {{ branch_container_full }}
      container_full_name: {{ branch_container_full }}
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
    - source: salt://moj-docker-deploy/apps/templates/nginx_container.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
      server_name: '{{branch_name | replace(".", "-") }}.{{
        salt['pillar.get'](
          'branch_runner:container_base_hostname',
          default=salt['pillar.get']('master_zone')
        )
      }}'
      appdata:
# This ensures that we send the correct vhost config to nginx
# We have to override the containers dictionary so that we can
# set the container name to the branch name
# The 3 dots are a yaml end of document marker that gets added
# by yaml.dump on single values (latest version of salt would 
# remove automatically)
{% for k, v in branch_vhost.items() if k != "containers" %}
        {{k}}: {{v|yaml|replace('...','')}}
{% endfor %}
        branchbuilder: True
        assets_host_path: '/{{branch_name}}'
        containers:
          '{{branch_name}}': {{branch_container | yaml}}
    - watch_in:
      - service: nginx

{% endfor %}
{% endif %}
