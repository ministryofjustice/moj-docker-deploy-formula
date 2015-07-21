include:
  - .proxied-containers
  - .nonproxied-containers
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