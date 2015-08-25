include:
  - docker

{% import 'apps/libs.sls' as macros with context %}

{{ macros.create_container_config('tutum_cleanup', {
  'name': 'tutum/cleanup',
  'tag': 'v0.16.21',
  'registry': None,
  'docker_args': '--privileged',
  'volumes': {
    '/var/run': {
      'host': '/var/run',
      'container': '/var/run',
    },
    '/var/lib/docker': {
      'host': '/var/lib/docker',
      'container': '/var/lib/docker',
    },
  },
}) }}
{{ macros.setup_container_environment_variables('tutum_cleanup', {}) }}
