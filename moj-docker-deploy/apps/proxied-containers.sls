# Setup template for proxied containers. 
#
# Containers will be configured to be created and service
# jobs setup for them. Nginx will then be set up to proxy
# connections to these containers.
#

{% import 'moj-docker-deploy/apps/libs.sls' as macros with context %}

include:
  - nginx
  - docker

# Set up proxying for the containers
{% for server_name, appdata in salt['pillar.get']('docker_envs', {}).items() %}
/etc/nginx/conf.d/{{server_name}}.conf:
  file.managed:
    - source: salt://moj-docker-deploy/apps/templates/nginx_container.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
      server_name: {{server_name}}
      appdata: {{appdata | yaml}}
    - watch_in:
      - service: nginx

# Create container configs for all the proxied containers
{% for container, cdata in appdata.get('containers',{}).items() %} # Start container loop
{{ macros.create_container_config(container, cdata, server_name) }}
{{ macros.setup_elb_registering(container) }}
{% endfor %} # End container loop
{% endfor %} # End app loop
