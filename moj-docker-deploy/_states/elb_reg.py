import time
import logging

def do_timeout(timeout, interval):
    def decorate(func):
        def wrapper(*args, **kwargs):
            attempts = 0
            while True:
                result = func(*args, **kwargs)
                if result:
                    return result
                if attempts >= timeout / interval:
                    return False
                attempts += 1
                time.sleep(interval)
        return wrapper
    return decorate

def _instance_in_service(name, region, instance):
    current_state = __salt__['boto_elb.get_instance_health'](name, region, instances=[instance])
    if current_state:
        if current_state[0]['state'] == 'InService':
            return True

def _instance_out_of_service(name, region, instance):
    current_state = __salt__['boto_elb.get_instance_health'](name, region, instances=[instance])
    if current_state:
        if current_state[0]['state'] == 'OutOfService':
            return True

def instance_up(name, instance, timeout=310, region='eu-west-1'):
    '''
     
    '''

    ret = {
        'name': name,
        'changes': {},
        'result': False,
        'comment': ''
    }

    current_state = __salt__['boto_elb.get_instance_health'](name, region, instances=[instance])
    log = logging.getLogger(__name__)
    log.info(current_state)
    if current_state:
        if current_state[0]['state'] == 'InService':
            ret['comment'] = 'Instance already in service.'
            ret['result'] = True
            return ret
    if __salt__['boto_elb.register_instances'](name, instances=[instance], region=region):
        ret['comment'] = 'Instance registered. '
        ret['changes'] = {name: {'new':instance, 'old': None}}
    if do_timeout(timeout, interval=10)(_instance_in_service)(name, region, instance):
        ret['comment'] += 'Instance InService'
        ret['result'] = True
    return ret

def instance_down(name, instance, timeout=310, region='eu-west-1'):
    '''
     
    '''

    ret = {
        'name': name,
        'changes': {},
        'result': False,
        'comment': ''
    }

    current_state = __salt__['boto_elb.get_instance_health'](name, region, instances=[instance])
    if current_state:
        if current_state[0]['state'] == 'OutOfService':
            ret['comment'] = 'Instance already out of service'
            ret['result'] = True
            return ret
    if __salt__['boto_elb.deregister_instances'](name, instances=[instance], region=region):
        ret['comment'] = 'Instance deregistered. '
        ret['changes'] = {name: {'old':instance, 'new': None}}
    if do_timeout(timeout, interval=10)(_instance_out_of_service)(name, region, instance):
        ret['comment'] += 'Instance Out of Service'
        ret['result'] = True
    return ret
