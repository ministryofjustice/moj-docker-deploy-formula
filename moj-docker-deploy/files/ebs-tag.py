#!/usr/bin/python

import boto
import sys
import boto.ec2
import requests

conn = boto.ec2.connect_to_region('eu-west-1')
my_instance_id = requests.get('http://169.254.169.254/latest/meta-data/instance-id').text
my_volumes = [v for v in conn.get_all_volumes() if v.attach_data.instance_id == my_instance_id]

def query(expected_tags):
  for v in my_volumes:
    for k in expected_tags.keys():
      if not v.tags.has_key(k):
        return False
      if v.tags[k] != expected_tags[k]:
        return False
  return True

def ensure(desired_tags):
  try:
    for v in my_volumes:
      v.add_tags(desired_tags)
  except boto.exception.EC2ResponseError:
    print "Failed to set tags {}. Perhaps the permisson ec2:CreateTags is missing from the IAM user".format(desired_tags)
    # Ideally we'd want to return a 1 here but this aborts the salt run. We don't want to
    # do that to products which might still be on an old stack without that permission.
    sys.exit(0)
  if not query(desired_tags):
    print "Failed to set tags {}".format(desired_tags)
    sys.exit(1)

if len(sys.argv) < 3:
  sys.stderr.write("Usage: {} <query|ensure> <tag:value>...\n".format(sys.argv[0]))
  sys.exit(99)

tags = dict(map( lambda x: x.split(':'), sys.argv[2:]))

if sys.argv[1] == 'query':
  if query(tags):
    sys.exit(0)
  else:
    sys.exit(1)

elif sys.argv[1] == 'ensure':
  ensure(tags)
else:
  sys.stderr.write("Usage: {} <query|ensure> <tag:value>...\n".format(sys.argv[0]))
  sys.exit(99)
