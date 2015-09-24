include:
  - .environment
  - .proxied-containers
  - .nonproxied-containers
  - .container-cleanup

HOME:
  environ.setenv:
    - value: /root
