/etc/docker_env.d:
  file.directory:
    - user: root
    - group: docker
    - mode: 750
    

{% for appname,appdata in pillar.get('docker_envs', {}).items() %}
{% for cname,cdata in appdata.get('containers',{}).items() %}
/etc/docker_env.d/{{ cname }}:
  file:
    - managed
    - source: salt://apps/templates/docker_env
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
    - source: salt://apps/templates/docker_env_bash
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
{% endfor %}
{% endfor %}
