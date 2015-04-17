#!py
# This is a template that uses salt's python renderer:
# See http://docs.saltstack.com/en/latest/ref/states/all/salt.states.file.html
# in this case it returns json which is the intended contents of the file.
import base64
import json
from copy import deepcopy

def run():
    docker_logins = deepcopy(salt['pillar.get']('registry_logins',{}))
    for reg, login in docker_logins.items():
        user = login.pop('user')
        password = login.pop('password')
        auth = base64.b64encode("{0}:{1}".format(user,password))
        docker_logins[reg]['auth'] = auth
    return json.dumps(docker_logins)
