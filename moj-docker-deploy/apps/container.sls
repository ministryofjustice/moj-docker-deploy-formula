include:
  - nginx

# get rid of legacy config
/etc/nginx/conf.d/demo.conf:
  file.absent

{% for app, appdata in salt['pillar.get']('docker_envs', {}).items() %}
/etc/nginx/conf.d/{{app}}.conf:
  file.managed:
    - source: salt://apps/templates/nginx_container.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - context:
      app: {{app}}
      appdata: {{appdata | yaml}}
    - watch_in:
      - service: nginx

{% if 'type' in appdata.keys() and appdata['type']=='standalone' %}
  {% set container_types = ['standalone'] %}
{% else %}
  {% set container_types = ['rails', 'assets'] %}
{% endif %}

{% for container_type in container_types %} # Start container type loop
/etc/init/{{app}}_{{container_type}}_container.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://apps/templates/upstart_container.conf
    - template: jinja
    - context:
      app: {{app}}
      container_type: {{container_type}}
      docker_registry: {{ salt['pillar.get']('docker_registry', '') }}
      tag: {{ salt['grains.get']('%s_tag' % app , 'latest') }}

{{app}}_{{container_type}}_service:
  service.running:
    - name: {{app}}_{{container_type}}_container
    - enable: true
    - require:
      - file: /etc/init/{{app}}_{{container_type}}_container.conf
{% endfor %} # End container type loop
{% endfor %} # End app loop
