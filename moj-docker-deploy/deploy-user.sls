include:
  - bootstrap.groups

/etc/sudoers.d/deploy:
  file.managed:
    - mode: 0440
    - source: salt://files/deploy.sudoers

deploy-user:
  user.present:
    - name: deploy
    - home: /home/deploy
    - shell: /bin/bash
    - groups:
      - ssh_user
    - require:
      - group: ssh_user
  ssh_auth.present:
    - name: AAAAB3NzaC1yc2EAAAADAQABAAABAQDKOeduPuIr9RQB6mGltcCDY0GEBFfBjOSBg9lAZYU/ezvsZrNRPx0NbOyCNOlPtr4ET3+HS1VoonN/yHV0zRq5HQJGtgJNN3H3RulavfxMOl7FchQwsXm1LYkp9xofqwfOq+PUlD8Bvt5zC5uDzxAwuwI1jTTnSB4XZ1eDQIBIZ3/pb9mWSMe/vp+OzuLLoLRiHE/vJtGhGVJPkpYIVBTeQb5WOpqPnN1uZC0bwsxa3wq2mFSowk+nyLArE0D2R4EN/qnkuEuVd59FE3uzvQq2cD6O2vZLUmgvt4iGcovMuCkPdZvZPPNXD0yTHPai/ri8VUmZd9B0Q9+Bne5q0owz
    - comment: 'deploy-key'
    - user: deploy
    - enc: 'ssh-rsa'
    - config: .ssh/authorized_keys2
    - require:
      - user: deploy-user
