## v1.2.0

Features:
* updated nginx-formula to 3.3.0, for the new log file/format customisation
* allowed customization of nginx log format
* Add ability to cluster containers with other hosts containers

Fixes:
* Strip dots from branch name subdomain host name
* Updated README
* Add a fallback check to the pillar for a containers host port
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
