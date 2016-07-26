#!/bin/bash
# Derived from https://aws.amazon.com/blogs/compute/using-amazon-efs-to-persist-data-from-amazon-ecs-containers/

# $targetEFSId is set in the EB configuration parameters.

# Get region of EC2 from instance metadata
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

echo target efs  id: $targetEFSId
echo availability zone: $EC2_AVAIL_ZONE
echo region: $EC2_REGION

ENDPOINT=$EC2_AVAIL_ZONE.$targetEFSId.efs.$EC2_REGION.amazonaws.com:/

echo mounting: $ENDPOINT
mount -t nfs4 -o nfsvers=4.1 $ENDPOINT /mnt/efs

# Restart docker to ensure it is aware of the mounted file system.
service docker restart
