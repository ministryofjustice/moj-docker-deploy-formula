#Branchrunner

## Contents
---------------------------------------------------
###[1. Introduction](#introduction)

###[2. Setup](#setup)

* [2.1 Pillar Configuration](#pillar-configuration)
* [2.2 Build and deploy](#build-and-deploy)

### [3. Known Issues](#known-issues)

* [3.1 Subdomains and SSL](#subdomains-and-ssl)

--------------------------------------------------
### Introduction

Branchrunner is a way of simultaneously running different code branch containers on the same stack.
It provides separate vhost addresses for each deployed branch container.

--------------------------------------------------
### Setup

##### Pillar Configuration

The pillar is configured by adding a branch_runner key that defines,

* `pillar_path`: The key string that points to the pillar vhost/container options to apply to the branch runner container. Usually this will point directly to the main configuration section for the application container.
* `container_base_hostname`: The hostname to use as the base for the creation of branchrunner vhosts. For example, if the base vhost is `my-app.example.com` then branchrunner will create vhosts pointing to the new containers in the form `my-feature-branch.my-app.example.com`.
* `container_to_run`: The name of the container that will be run.

For example, the pillar will usually be in the form below

	branch_runner:
	  pillar_path: docker_envs:my-app.example.com # Note, this is a string keyed to the config section below
	  container_base_hostname: my-app.example.com
	  container_to_run: my-app

	docker_envs:
	  my-app.example.com: # This is the section referenced by 'pillar_path' above
	    nginx_port: 80
	    containers:
	      my-app:
	        name: my-app
	        location: /
	        ports:
	          app:
	            host: 9080
	            container: 8080


##### Build and deploy

The build and deploy process is very similar to a standard deployment. The main differences are that we need to upload the assets to a separate directory than the main one, and then we can deploy the branch using the `add_branch` fab command. Note that we usually add a stage before this to clean up now deprecated branchrunner installed branches.

For example, if we're deploying a branch 'my-feature-branch' for our application 'my-application',

* First we upload branchrunner assets to a subdirectory: my-feature-branch"

		fab application:my-application upload_assets:/assets,/my-feature-branch
  

* Then we setup the previously deployed branchrunner application we want to remove, highstating to actually do the removal
		
		fab application:my-application remove_deleted_branches:my-application
		fab application:my-application highstate
		
* Finally , we actually deploy the new branchrunner application

		fab application:my-application add_branch:my-feature-branch

* We should now be able to navigate to the new vhost endpoint

	http://my-feature-branch.my-app.example.com
	

----------------------------------------------------

### Known Issues

##### Subdomains and SSL

Branchrunner automatically generates vhosts as subdomains of the main application address. This means that any wildcards SSL certificates will not be applicable to the branchrunner applications. This is usually workaroundable by simply allowing the insecure connection when connecting to the branchrunner application address

