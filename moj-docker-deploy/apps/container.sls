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
      tag: '{{ salt['grains.get']('%s_tag' % container , 'latest') | replace("'", "''") }}'

{{container}}_service:
  service.running:
    - name: {{container}}_container
    - enable: true
    - watch:
      - file: /etc/init/{{container}}_container.conf
      - file: /etc/docker_env.d/{{container}}

{% if salt['grains.get']('zero_downtime_deploy', False) %}
{% for elb in salt['pillar.get']('elb',[]) %}
{{ container }}_{{ elb['name'] }}_down:
  elb_reg.instance_deregistered:
    - name: ELB-{{ elb['name'] | replace(".", "") }}
    - instance: {{ salt['grains.get']('aws_instance_id', []) }}
    - timeout: 130
    - prereq:
      # This prereq means that this state will trigger before the
      # following files change (and only if they do change).
      # As changes to these files also mean a restart of the container
      - file: /etc/init/{{container}}_container.conf
      - file: /etc/docker_env.d/{{container}}

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
