# Macro to pull and setup a service job for a container
#  
# Args:
#   container(string) - The name of the container
#   cdata(dictionary) - The keyed setup data for the container
#    

{% macro create_container_config(container, cdata, server_name=None) %}

{% set container_name = cdata.get('name', container) %}
{% set default_registry = salt['pillar.get']('default_registry', '') %}
{% set docker_registry =  cdata.get('registry', default_registry) %}
{% set container_full_name = (docker_registry, container_name) | select | join("/") %}
{% set default_version = cdata.get('initial_version', 'latest') %}

{{ container }}_pull:
  dockerng.image_present:
    - name: {{ container_full_name }}:{{ salt['grains.get']('%s_tag' % container , default_version) | replace("'", "''") }}
    - force: True
    - require:
      # We need this for docker-py to find the dockercfg and login
      - environ: HOME

/etc/init/{{container}}_container.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://moj-docker-deploy/apps/templates/upstart_container.conf
    - template: jinja
    - context: 
      container_full_name: {{ container_full_name }}
      cdata: {{cdata | yaml}}
      cname: {{container}}
      default_registry: {{ salt['pillar.get']('default_registry', '') }}
      tag: '{{ salt['grains.get']('%s_tag' % container , default_version) | replace("'", "''") }}'

{{container}}_service:
  service.running:
    - name: {{container}}_container
    - enable: true
    - watch:
      - file: /etc/init/{{container}}_container.conf
      - file: /etc/docker_env.d/{{container}}
      - dockerng: {{ container }}_pull
{% if server_name %}
    - require_in:
      - file: /etc/nginx/conf.d/{{ server_name }}.conf
{% endif %}
    - check_cmd:
        - sleep {{ cdata.get('initial_delay', 1)}} && docker inspect {{ container }}

{% endmacro %}

# Macro to register and de-register a container with elbs
#  
# Args:
#   container(string) - The name of the container
# 
{% macro setup_elb_registering(container) %}

{% if salt['grains.get']('zero_downtime_deploy', False) %}
{% for lb in salt['grains.get']('lbs',{}).keys() %}
{{ container }}_{{ lb }}_down:
  elb_reg.instance_deregistered:
    - name: {{ lb }}
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
      - dockerng: {{container}}_pull

{{ container }}_{{ lb }}_up:
  elb_reg.instance_registered:
    - name: {{ lb }}
    - instance: {{ salt['grains.get']('aws_instance_id', []) }}
    - timeout: 120
    - watch:
      # Once the container service has restarted, make sure we
      # are registered in the ELB.
      - service: {{ container }}_service
{% endfor %}
{% endif %}
{% endmacro %}



# Macro to set up containers environment variables
#
# Args:
#   cname(string) - The name of the container
#   cdata(dictionary) - The keyed setup data for the container
{% macro setup_container_environment_variables(cname, cdata) %}
/etc/docker_env.d/{{ cname }}:
  file:
    - managed
    - source: salt://moj-docker-deploy/apps/templates/docker_env
    - user: root
    - group: docker
    - mode: 640
    - template: jinja
    - context: 
      appenv: {{ cdata | yaml }}
      appname: {{ cname }}
      task: '{{ salt['grains.get']('%s_task' % cname , 'none') | replace("'","''")  }}'
    - require:
      - file: /etc/docker_env.d

/etc/docker_env.d/{{ cname }}_bash:
  file:
    - managed
    - source: salt://moj-docker-deploy/apps/templates/docker_env_bash
    - user: root
    - group: docker
    - mode: 640
    - template: jinja
    - context: 
      appenv: {{ cdata | yaml }}
      appname: {{ cname }}
      task: '{{ salt['grains.get']('%s_task' % cname , 'none') | replace("'", "''") }}'
    - require:
      - file: /etc/docker_env.d
{% endmacro %}

