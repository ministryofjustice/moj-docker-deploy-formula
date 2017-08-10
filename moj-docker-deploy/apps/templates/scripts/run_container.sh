#!/bin/bash
{# Set up variables for normal container or branchrunning #}
{% if appdata is defined and appdata.get('branchbuilder', False) %}
{% set target_container_name = branch_name %}
{% set docker_branchrunner_args = " -e DB_NAME='{{branch_name}}' -e DOCKER_STATE=create " %}
{% else %}
{% set target_container_name = cname %}
{% set docker_branchrunner_args = " " %}
{% endif %}

function container_pre_start( )
{
	echo  "{{cname}}_container: pulling container {{ container_full_name }} with {{ tag }}"
	docker pull {{ container_full_name }}:{{ tag }}
	{% if 'links' in cdata %}
    max_retry=10
{% for link_config in cdata.get('links') %}
    for i in $(seq 1 ${max_retry})
    do
        echo INFO: pre-start: Introspecting a the target link running container named {{ link_config.get('link') }}...
        found_container=$(docker inspect --format='{% raw %}{{.State.Running}}{% endraw %}' {{ link_config.get('link') }} 2>/dev/null || true)
        if [ "${found_container}" = "true" ]; then
            echo INFO: pre-start: Found container required for linking ${found_container}...
            break
        elif [ "${i}" = "${max_retry}" ]; then
            echo CRITICAL: pre-start: Retry timed out on container required for linking, {{ link_config.get('link') }}, exiting pre-start with exit code 1...
            exit 1
        else
            echo WARNING: pre-start: Could not find container required for linking, {{ link_config.get('link') }}, retry ${i}/${max_retry}...
            sleep 3
        fi
    done
    echo INFO: pre-start: All target link running containers found, exiting pre-start
    exit 0
{% endfor %}
{% endif%}
}

function container_start( )
{
	status=$(container_status)
	if [ "x${status}" == "xrunning" ]; then
		 echo  "{{cname}}_container: service already running"
		 exit 0
	fi
	echo  "{{cname}}_container: starting service"
	docker rm -f {{cname}} > /dev/null 2>&1

	PILLAR_TAG='{{ tag | replace("'", "'\\''") }}'
	if [ -z $TAG ]; then
	    TAG=$PILLAR_TAG
	fi

	{%  if 'volumes' in cdata %}
	VOL_OPTS="{% for descr, vol_set in cdata['volumes'].items() %} -v {{vol_set['host']}}:{{vol_set['container']}} {% endfor %}"
	{% endif %}

	{% if 'ulimits' in cdata %}
	ULIMIT_OPTS="{% for opt, limits in cdata['ulimits'].items() %} --ulimit {{ opt }}={{ limits }} {% endfor %}"
	{% endif %}

	{% if 'ports' in cdata %}
	{% if appdata is defined and appdata.get('branchbuilder', False) %}
	PORT_OPTS="{% for descr, port_set in cdata['ports'].items() %} -p {{port_set['container']}} {% endfor %}"
	{% else %}
	PORT_OPTS="{% for descr, port_set in cdata['ports'].items() %} -p {{port_set['host']}}:{{port_set['container']}} {% endfor %}"
	{% endif %}
	{% endif %}

	if [ -f /etc/docker_env.d/{{target_container_name}} ]; then
	        ENV_OPTS="--env-file /etc/docker_env.d/{{target_container_name}}"
	fi

	# If clustering is enabled for this container, and we have neighbour hosts details are available
	# then add the neighbour and container alias <container_name>.<remote_instance_dns_name> to
	# the hosts file in the container
	{% set ec2_neighbours = salt['grains.get']('ec2_neighbours', {}) %}
	{% set ec2_local_private_dns_name = salt['grains.get']('ec2_local:private_dns_name', '') %}
	{% set ec2_local_private_dns_name_safe = salt['grains.get']('ec2_local:private_dns_name_safe', '') %}

	{% if 'enable_clustering' in cdata and cdata['enable_clustering'] == True %}
	HOSTS_OPTS="{% for ip, neighbours in ec2_neighbours.items() %} --add-host={{neighbours['private_dns_name']}}:{{ip}} --add-host={{target_container_name}}.{{neighbours['private_dns_name']}}:{{ip}}{% endfor %}"
	HOSTS_OPTS_SAFE="{% for ip, neighbours in ec2_neighbours.items() %} --add-host={{neighbours['private_dns_name_safe']}}:{{ip}} --add-host={{target_container_name}}-{{neighbours['private_dns_name_safe']}}:{{ip}}{% endfor %}"
	CLUSTER_NODES="[ {% for ip, neighbours in ec2_neighbours.items() %} '{{target_container_name}}.{{neighbours['private_dns_name']}}'{% if not loop.last %},{% endif %} {% endfor %}]"
	CLUSTER_NODES_SAFE="[{% for ip, neighbours in ec2_neighbours.items() %} '{{target_container_name}}-{{neighbours['private_dns_name_safe']}}'{% if not loop.last %},{% endif %} {% endfor %}]"
	HOSTNAME_OPTS=" -h {{target_container_name}}-{{ec2_local_private_dns_name_safe}} "
	{% endif %}

	{% if 'links' in cdata %}
	LINK_CONTAINERS="{% for link_config in cdata.get('links') %} --link {{ link_config.get('link') }}:{{ link_config.get('alias', link_config.get('link')) }} {% endfor %} "
	{% endif %}

	docker run --name="{{ target_container_name }}" {{cdata.get('docker_args', '')}} \
	    ${LINK_CONTAINERS} \
	    -e "CLUSTER_NODES=${CLUSTER_NODES}" \
	    -e "CLUSTER_NODES_SAFE=${CLUSTER_NODES_SAFE}" \
	                    {{ docker_branchrunner_args }} \
	    ${HOSTNAME_OPTS} ${HOSTS_OPTS} ${HOSTS_OPTS_SAFE} ${ULIMIT_OPTS} ${ENV_OPTS} ${VOL_OPTS} ${PORT_OPTS} {{container_full_name}}:"$TAG" {{cdata.get('startup_args', '')}}
}

function container_post_start()
{
	echo INFO: post-start: Checking if container {{target_container_name}} is running
    # Test for success
    max_retry=10
    for i in $(seq 1 ${max_retry})
    do
        echo INFO: post-start: Introspecting for a running container named {{target_container_name}}
        found_container=$(docker inspect --format='{% raw %}{{ .State.Running }}{% endraw %}' {{ target_container_name }} 2>/dev/null || true)
        if [ "${found_container}" != "true" ]; then
            echo WARNING: post-start: Docker container {{target_container_name}} not started yet, retry ${i}/${max_retry}...
            sleep 3
        else
            echo INFO: post-start: Docker container {{target_container_name}} running, exiting...
            exit 0
        fi
    done
    echo ERROR: Docker failed to start instance
    exit 1
}

function container_stop( )
{
	echo  "{{cname}}_container: stopping service"
	docker stop {{cname}} > /dev/null 2>&1
	docker rm -f {{cname}} > /dev/null 2>&1
}

function container_status( )
{
	# If the container is non existent
	exists=$(docker ps -q --filter="name={{cname}}")
	if [ "x${exists}" == "x" ]; then
		echo "not running"
	else
		# Get the status of the actual container
		status=$(docker inspect --format={% raw %}'{{.State.Status}}'{% endraw %} {{cname}})
		echo  "${status}"
	fi
}

# Management instructions of the service
case "$1" in
	pre_start)
		echo  "{{cname}}_container: service pre_start"
		container_pre_start
		;;
	start)
		echo  "{{cname}}_container: service start"
		container_start
		;;
	post_start)
		echo  "{{cname}}_container: service post_start"
		container_post_start
		;;
	stop)
		echo  "{{cname}}_container: service stop"
				container_stop
		;;
	reload)
		echo  "{{cname}}_container: service reload"
				container_stop
		sleep  1
		container_start
		;;
	status)
		echo  "{{cname}}_container: service status"
		container_status
		;;
	*)
		echo ERROR: main: called with unrecognised argument \'$*\', exiting
		echo  "Usage: $ 0 {start | stop | reload | status}"
		exit  1
		;;
esac

exit  0
