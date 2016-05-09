## v2.1.0
* Make unattended upgrades the default setting

## v2.0.0
* Add alias option to links
* Use docker introspect running state for checking containers
* Fix broken error handling on containers missing on introspect
* Increase retry count to 10
* Trigger on any parent service started event
* Add alias to docker link command
* Change container linking pillar structure

## v1.4.3

Added support for container linking

## v1.4.2

Added support for setting arbitrary nginx Headers and Values directly from the Pillar.

## v1.4.1
Features:

Add support for basic http auth in nginx proxy on a per container basis.


## v1.4.0

Features:
* Allow overriding database settings in the pillar
* Allow disabling the default server setting on a vhost
Fixes:
* Add documentation for setting up branchrunner

## v1.3.6

Features:
* Updated nginx-formula dependency to v3.3.4

Fixes:
* custom nginx json log formats resulting in unparseable double-quoted json

## v1.3.5
Fixes:
* docker pulling the wrong tag 

## v1.3.4

* Add elasticache docker envs if available
* Enable clustering of containers with containers in other EC2 instances
Features:
* Update nginx-formula version to 3.3.3

## v1.3.3

Fixes:
  * Revert Remove require on requests

Features:
* Update nginx version to 3.3.2

## v1.3.1

Fixes:
* Remove require on requests

## v1.3.0

* Add an initial_version option to the container pillar
* Update nginx version to 3.3.1

## v1.2.0

Features:
* updated nginx-formula to 3.3.0, for the new log file/format customisation
* allowed customization of nginx log format
* Add ability to cluster containers with other hosts containers

Fixes:
* Strip dots from branch name subdomain host name
* Updated README
* Add a fallback check to the pillar for a containers host port
>>>>>>> master
* Fix macro calls introduced for nginx logs

## v1.0.6

* Fix macro import for cleanup containers

## v1.0.5

* Set a default nginx host to avoid branch confusion

## v1.0.4

* Bump aws-formula version to 0.4.3

## v1.0.3

* use grains from aws formula for elb name

## v1.0.2

* Move _states to root directory

## v1.0.0

* Initial release as split out from ministryofjustice/template-deploy
