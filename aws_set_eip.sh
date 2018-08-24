#!/bin/bash

set -x

ALLOCATION_ID="$1"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
INSTANCE_REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//g')"
aws ec2 associate-address \
  --region $INSTANCE_REGION \
  --instance-id $INSTANCE_ID \
 --allocation-id $ALLOCATION_ID \
 --allow-reassociation
