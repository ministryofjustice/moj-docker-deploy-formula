# Setup envvironment variables for containers. 
#
# Pillar envvars settings will be collected into a file that can
# be injected into containers as environment variables on startup
#
include:
  - docker

{% import 'moj-docker-deploy/apps/libs.sls' as macros with context %}

{% if salt['pillar.get']('registry_logins') %}
/root/.dockercfg:
  file.managed:
    - source: salt://moj-docker-deploy/apps/templates/docker_logins.py
    - template: py
    - user: root
    - group: root
    - mode: 600
    - require_in:
      - docker.pulled
{% endif %}

/etc/docker_env.d:
  file.directory:
    - user: root
    - group: docker
    - mode: 750

# Systemd services
/etc/systemd/system:
  file.directory:
    - mode: 755
    - makedirs: True

/usr/share/moj-docker-deploy:
  file.directory:
    - mode: 755
    - makedirs: True

{% for appname,appdata in pillar.get('docker_envs', {}).items() %}
{% for cname,cdata in appdata.get('containers',{}).items() %}
{{   macros.setup_container_environment_variables(cname, cdata) }}
{% endfor %}
{% endfor %}

# Set up environment variabes for non proxied containers
{% for cname,cdata in pillar.get('containers',{}).items() %}
{{ macros.setup_container_environment_variables(cname, cdata) }}
{% endfor %}

