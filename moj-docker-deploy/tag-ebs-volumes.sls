tag-ebs-volumes:
  file.managed:
    - source: salt://moj-docker-deploy/files/ebs-tag.py
    - name: /usr/local/bin/ebs-tag.py
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - pip: requests
      - pip: boto
  cmd.run:
    - unless: /usr/local/bin/ebs-tag.py query Env:{{grains['Env']}} Apps:{{grains['Apps']}}
    - name: /usr/local/bin/ebs-tag.py ensure Env:{{grains['Env']}} Apps:{{grains['Apps']}}
    - cwd: /
    - require:
      - file: /usr/local/bin/ebs-tag.py

python-pip:
  pkg.installed

requests:
  pip.installed:
    - require:
      - pkg: python-pip

boto:
  pip.installed:
    - require:
      - pkg: python-pip
