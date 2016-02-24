## moj-docker-deploy formula

A formula to deploy apps using docker containers.

This is formula is driven almost entirely from the pillar and the most common
settings are described below

------------------------------------------------------
### The Pillars Settings Explained

Files under the 'pillar' directory are where template deploy stores the settings used to configure the deployed AWS instances and infrastructure. There are a number of standard settings used to create application containers and setup up the environment to work with them. In addition, this is the place to put configuration settings for the various salt formula used by the project, such as sensu settings, etc

Any settings that should be kept secret are marked **SECRET** and should be moved into a separate *-secrets.yaml file and encrypted by git-crypt.

Key sections are the 'docker_envs' section, used to define the setup of nginx proxied containers. There is also a main 'containers' key at the root level, used to define non-proxied containers.

For more help in resolving problems and errors, see the [Template Deploy Troubleshooting Guide](docs/troubleshooting.md)

------------------------------------------------------
### Contents

####[Registry Settings](#registry-settings)

- [default_registry](#default-registry)
- [registry_logins](#registry-logins)

####[System Settings](#system-settings)

- [nginx](#nginx)

####[Docker Environment Settings](#docker-environment-settings)

- [docker_envs](#docker_envs)
- [nginx_port](#nginx_port)
- [nginx_logs](#nginx_logs)
- [basic_auth](#basic_auth)
- [assets_location](#assets_location)
- [ssl](#ssl)
- [proxies](#proxies)
- [server_names](#server_names)

####[Proxied Containers Settings Subsection](#proxied-containers-settings-subsection)
- [containers](#containers)
- [name](#name)
- [initial_version](#initial_version)
- [registry](#registry)
- [http_locations](#http_locations)
- [location](#location)
- [ports](#ports)
- [volumes](#volumes)
- [envvars](#envvars)
- [enable_clustering](#enable_clustering)
- [cluster_nodes_prefix](#cluster_nodes_prefix)

####[Non-Proxied Containers Settings](#non-proxied-containers-settings-subsection)

####[Setting up branchrunner](docs/branchrunner.md)

####[Overriding the formula files in your own repo](#overriding-the-formula-files-in-your-own-repo)

------------------------------------------------------
###Registry Settings
###default-registry
This registry will be used if no registry is set in the containers section.

```yaml
default_registry: registry.service.dsd.io
```
	
###registry-logins
(**SECRET** - Must be kept in a *-secrets.sls file)

If your registries require a login then specify them here. The user and password should be plain text.

```yaml
registry_logins:
  'https://registry.service.dsd.io':
    email: hi@digital.justice.gov.uk
    user: <in keychain>
    password: <in keychain>
```
    
------------------------------------------------------
###System Settings
###nginx
Settings specific to nginx

```yaml
nginx:
  version: 1.4.6-1ubuntu3.3
```
	  
------------------------------------------------------
###Docker Environment Settings
###docker_envs

```yaml
docker_envs:
```

This is a dictionary of docker environments keyed by the server name for your vhost.

```yaml
	dev.blah.dsd.io:
```
  
###nginx_port
This is the port you should direct your ELB to. If not specified, the default setting is as shown below.

```yaml    
    nginx_port: 80
```

You can specify multiple vhosts with the same port, but in that case you have to make sure that all the vhosts that will not be the default server also explicitly say so as below. If not, nginx will refuse to load the config due to multiple default servers being set.

```yaml
    default_server: False
```

    
###nginx_logs
This key allows you to customise the format & path of nginx logs. If not specified, the default logging configuration will be used, resulting in these lines in the nginx config file:
```
    access_log  /var/log/nginx/{{server_name}}.access.json logstash_json;
    error_log   /var/log/nginx/{{server_name}}.error.log error;
```
If you want to customize this, you can specify additional (or replacement) formats and log file paths like this:
```
    nginx_logs:
      formats:
        # NOTE: logstash_json format is always present,
        # you only need to define alternative formats
        my_custom_format: 'my custom format definition'
      access_logs:
        - path: '/var/log/nginx/logstash_access.log'
          format: logstash_json
        - path: '/var/log/nginx/my_custom_access.log'
          format: my_custom_format
      error_logs:
        - path: '/var/log/nginx/error.log'
          format: error
```


###basic_auth
This key specifies whether basic authentication will be used. If enabled and set to True the required nginx directives are added in the default (location)(#location) specified (or on the default / otherwise)
```yaml
	basic_auth: True
```

In order to provide credentials, one has to specify them in the basic_auth_creds pillar on the same level. Supplied passwords be in hash form as supplied by the htpasswd utility. For more information please visit (ngx_http_auth_basic_module)[http://nginx.org/en/docs/http/ngx_http_auth_basic_module.html]

```yaml
        docker_envs:
          example.service.me:
              basic_auth_creds:
                  username1: 'HASH'
                  username2: 'HASH'
```


###assets_location
This key specifies the location in nginx to proxy to the S3 bucket. If not specified, the default setting is as shown below.
   
```yaml 
    	assets_location: /assets
```

###ssl
This is the section to specify ssl settings. Below we set 'redirect' to True, if you enable this and have a custom health check on your ELB you will also want to add the health-check location to [http_locations](#http_locations) to allow pass-through of non-https connections to those locations. If not specified, the default setting is as shown below.

```yaml    
	    ssl:
	      redirect: True
```

###proxies
You can use the following to specify arbitrary proxies to other hosts or upstreams.

```yaml
	    proxies:
	      - location: /some-random-bucket
	        upstream: https://mmb-test.s3-eu-west-1.amazonaws.com
	        host_header: mmb-test.s3.amazonaws.com
```
	        
###server_names
If you need your vhost to respond to other cnames include them here

```yaml
	    server_names: 
	      - cname.blah.dsd.io
```

------------------------------------------------------
###Proxied Containers Settings Subsection
###containers
The containers subsection is used to define containers which respond to HTTP and should be put behind an nginx reverse proxy. Each container must define at least one exposed port labeled app. Each entry is a dictionary of container name keys mapped to the containers specific settings. The key is a custom name for the container, it can be anything and is used by salt to name upstart jobs and for the deploy task. 

```yaml    
	    containers:
	      another_app:
```
      
####name
This is the name of the container as it is tagged in docker

```yaml        
            name: tutum/hello-world
```

####initial_version
This is the initial version tag of the container to install if there is no other version
already installed on the intance.

```yaml        
            initial_version: master.kj2312km
```

####registry
You can use this key to override the default_registry.

```yaml
            registry: myprivateregistry.com
```

Note, to use the default docker hub registry you need to set the registry to be empty as shown below

```yaml
            registry:
```

####http_locations
Paths listed here will not be redirected to https, this is can be useful for example, for custom ELB checks when you have the SSL redirect enabled. (see [ssl](#ssl))

```
	        http_locations:
	          - /ping.json
```
  
####location
This is the nginx location that is mapped to the container
        
```yaml        
            location: /
```

####ports      
Here we can set the 'host' port, the port which docker forwards into the container. It can be anything as long as it's not in use on the host and is automatically set as an nginx upstream. The 'container' port is the port that the process in the container is listening on.

```yaml
	        ports:
	          app:
	            host: 9080
	            container: 80
```
            
####volumes
This allows you to mount host volumes in the container.

```yaml        
	        volumes:
	          es_vol:
	            host: /mnt/es_data
	            container: /data
```

####envvars
(**SECRET** - Some settings should be kept in a *-secrets.yaml file)

These environment variables will be set in the container, these will often be a place where usernames and passwords are stored so make sure sensitive information goes into a corresponding secrets file.

```yaml
	        envvars:
	          ENV_VAR1: value
	          ENV_VAR2: value2
```
		          
Note you get some free variables for database details etc, the following will be set in the container automatically.
The automatic values below cannot be overridden

- *ENV*: The environment you specify in the fab command
- *PROJECT*: The application name you specify in the fab command
- *DATABASE_URL*: The RDS database url, in the form DB_ENGINE://DB_USERNAME:DB_PASSWORD@DB_HOST:DB_PORT/DB_NAME

The following automatic values can be overriden in the pillar 

- *DB_ENGINE*: The RDS engine
- *DB_HOST*: The RDS hostname
- *DB_PORT*: The RDS port
- *DB_USERNAME*: The RDS username set in the cloudformation yaml
- *DB_PASSWORD*: The RDS password set in the cloudformation yaml


#### enable\_clustering

When set to True, clustering of containers with ports exposed on their hosts will be enabled. In practice, this means that other EC2 hosts and containers DNS resolvable inside a container, and a list of nodes will be exposed via environmental variables. See https://github.com/ministryofjustice/template-deploy#clustering_containers for more details.

```yaml
	enable_clustering: True
```

#### cluster\_nodes\_prefix

To add a prefix to cluster nodes lists.

```yaml
	cluster_nodes_prefix: 'someprefix-'
```

------------------------------------------------------
###Non-proxied Containers Settings Subsection

Outside of the 'docker_envs' section used to add proxied containers, we can also define an additional 'containers' section, here we list the containers we want to define that we don't want proxied by nginx. The format is the same as the [previous container definitions](#proxied-containers-settings-subsection) with the main difference being that nginx specific entries such as 'locations' are no longer used.


------------------------------------------------------
###Overriding the formula files in your own repo

In case you need to use a self-customized version of certain files from your repo instead of the corresponding formula files, you can do the following:

- under `salt` create a directory structure replicating the formula one

- place the file in the location corresponding to the formula one.

Example:
You want to use your own `upstart_container.conf` file because of customizations you have made.
Within your `deploy` repo, under `salt` create the following subdirectories: 


      moj-docker-deploy/apps/templates

and place your `upstart_container.conf` file there.
Execute an `update`:


      fab application:<app_name> environment:<env>  aws:<your aws credentials> config:./cloudformation/<your app>.yaml passwords:./cloudformation/<your app>-secrets.yaml  update -u <your username>

On your target AWS nodes, check for a file:

    /etc/init/<your application>_container.conf

and verify that it has been updated as desired.
