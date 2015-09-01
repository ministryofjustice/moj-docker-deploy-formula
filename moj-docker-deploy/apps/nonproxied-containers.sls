# Setup template for non-proxied containers. 
#
# Containers will be configured to be created and service
# jobs setup for them.
#

{% import 'moj-docker-deploy/apps/libs.sls' as macros with context %}

include:
  - docker
  
# Create container configs for all the non-proxied containers
{% for container, cdata in  salt['pillar.get']('containers', {}).items() %} # Start container loop
{{ macros.create_container_config(container, cdata) }}
{% endfor %} # End container loop
