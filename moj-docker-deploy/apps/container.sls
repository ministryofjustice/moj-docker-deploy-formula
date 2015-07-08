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
      appdata: {{appdata | yaml}}
    - watch_in:
      - service: nginx

{% for container, cdata in appdata.get('containers',{}).items() %} # Start container loop
{# Set up variables from pillar #}
{% set container_name = cdata.get('name', container) %}
{% set default_registry = salt['pillar.get']('default_registry', '') %}
{% set docker_registry =  cdata.get('registry', default_registry) %}
{% set container_full_name = (docker_registry, container_name) | select | join("/") %}

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
      container_full_name: {{ container_full_name }}
      cdata: {{cdata | yaml}}
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
