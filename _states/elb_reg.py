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
    '''
    Checks state of instance in a loadbalancer returns True
    if the instance is InService, False otherwise.
    '''
    # NOQA
    current_state = __salt__['boto_elb.get_instance_health'](
        name, region, instances=[instance])
    if current_state:
        if current_state[0]['state'] == 'InService':
            return True


def _instance_out_of_service(name, region, instance):
    '''
    Checks state of instance in a loadbalancer returns True
    if the instance is OutOfService, False otherwise.
    '''
    # NOQA
    current_state = __salt__['boto_elb.get_instance_health'](
        name, region, instances=[instance])
    if current_state:
        if current_state[0]['state'] == 'OutOfService':
            return True


def instance_registered(name, instance, timeout=310, region=None):
    '''
    Salt state that ensures that an instance is registered and
    InService on a given ELB.
    The timeout should be sufficient for the healthcheck on the ELB to pass.
    '''
    if region is None:
        region = get_region()
    ret = {
        'name': name,
        'changes': {},
        'result': False,
        'comment': ''
    }

    # NOQA
    current_state = __salt__['boto_elb.get_instance_health'](
        name, region, instances=[instance])
    log = logging.getLogger(__name__)
    log.info(current_state)
    if current_state:
        if current_state[0]['state'] == 'InService':
            ret['comment'] = 'Instance already in service.'
            ret['result'] = True
            return ret
    # NOQA
    if __salt__['boto_elb.register_instances'](
            name, instances=[instance], region=region):
        ret['comment'] = 'Instance registered. '
        ret['changes'] = {name: {'new': instance, 'old': None}}
    if do_timeout(timeout, interval=10)(_instance_in_service)(
            name, region, instance):
        ret['comment'] += 'Instance InService'
        ret['result'] = True
    else:
        ret['comment'] += 'Instance not InService'
    return ret


def instance_deregistered(name, instance, timeout=310, region=None):
    '''
    Salt state that ensures that an instance is deregistered and
    OutOfService on a given ELB.
    The timeout should be sufficient for the connections to drain from an
    instance once it is deregistered. i.e. you should set the timeout here
    to be slightly greater than the connection draining time on the ELB.
    '''
    if region is None:
        region = get_region()
    ret = {
        'name': name,
        'changes': {},
        'result': False,
        'comment': ''
    }

    # NOQA
    current_state = __salt__['boto_elb.get_instance_health'](
        name, region, instances=[instance])
    if current_state:
        if current_state[0]['state'] == 'OutOfService':
            ret['comment'] = 'Instance already out of service'
            ret['result'] = True
            return ret
    # NOQA
    if __salt__['boto_elb.deregister_instances'](
            name, instances=[instance], region=region):
        ret['comment'] = 'Instance deregistered. '
        ret['changes'] = {name: {'old': instance, 'new': None}}
    if do_timeout(timeout, interval=10)(_instance_out_of_service)(
            name, region, instance):
        ret['comment'] += 'Instance Out of Service'
        ret['result'] = True
    else:
        ret['comment'] += 'Instance not OutOfService'
    return ret


def get_region():
  instance_identity = boto.utils.get_instance_identity(timeout=5, num_retries=2)
  instance_region = instance_identity['document']['region']
  return instance_region
