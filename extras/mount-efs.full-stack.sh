#!/bin/bash

# Determine the EB environment ID that launched this instance, and then
# find the EFS with the same environment ID and mount it.

# derived from https://aws.amazon.com/blogs/compute/using-amazon-efs-to-persist-data-from-amazon-ecs-containers/

# need the latest version to do EFS calls
pip install --upgrade awscli

#Get region of EC2 from instance metadata
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

EC2_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

EB_ENV_ID=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$EC2_INSTANCE_ID" --region $EC2_REGION --query 'Tags[?Key==`elasticbeanstalk:environment-id`].Value' --output text)

EFS_LIST=$(aws efs describe-file-systems --region us-east-1 --query 'FileSystems[*].FileSystemId' --output text)

echo availability-zone: $EC2_AVAIL_ZONE
echo region: $EC2_REGION
echo instance-id: $EC2_INSTANCE_ID
echo environment-id: $EB_ENV_ID
echo efs list: $EFS_LIST

EB_EFS_ID=""

for THIS_EFS_ID in $EFS_LIST;
do
  echo "Checking $THIS_EFS_ID"
  THIS_EB_ENV_ID=$(aws efs describe-tags --file-system-id $THIS_EFS_ID --region us-east-1 --query 'Tags[?Key==`elasticbeanstalk:environment-id`].Value' --output text)
  echo compare to $THIS_EB_ENV_ID
  if [ "$THIS_EB_ENV_ID" == "$EB_ENV_ID" ];
  then
    echo Matched: $THIS_EB_ENV_ID, $EB_ENV_ID
    EB_EFS_ID=$THIS_EFS_ID
    break
  fi
done
echo "Target EFS is: $EB_EFS_ID"

ENDPOINT=$EC2_AVAIL_ZONE.$EB_EFS_ID.efs.$EC2_REGION.amazonaws.com:/

echo endpoint: $ENDPOINT

if [ ! -z "$EB_EFS_ID" ];
then
  if [ "grep -qs '/efs ' /proc/mounts" ];
  then
    echo mounting: $ENDPOINT
    mount -t nfs4 -o nfsvers=4.1 $ENDPOINT /efs
  fi
fi
