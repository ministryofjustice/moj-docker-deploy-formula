include:
  - nginx
  - docker
  - .environment

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
      appdata: {{appdata}}
    - watch_in:
      - service: nginx

{% for container, cdata in appdata.get('containers',{}).items() %} # Start container loop
/etc/init/{{container}}_container.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://apps/templates/upstart_container.conf
    - template: jinja
    - context:
      cdata: {{cdata}}
      cname: {{container}}
      default_registry: {{ salt['pillar.get']('default_registry', '') }}
      tag: {{ salt['grains.get']('%s_tag' % container , 'latest') }}
      task: {{ salt['grains.get']('%s_task' % container , 'none') }}

{{container}}_service:
  service.running:
    - name: {{container}}_container
    - enable: true
    - watch:
      - file: /etc/init/{{container}}_container.conf
      - file: /etc/docker_env.d/{{container}}
     
{% endfor %} # End container loop
{% endfor %} # End app loop
