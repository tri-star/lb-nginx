#!/bin/bash

set -ex

test -d /data/log/nginx || mkdir -p /data/log/nginx || { exit; }
test -d /data/letsencrypt/certs || mkdir -p /data/letsencrypt/certs || { exit; }
test -d /data/letsencrypt/accounts || mkdir -p /data/letsencrypt/accounts || { exit; }

chown -R www-data:www-data /data/log/nginx

if [ "${GCP_IP_NAME}" != "" ]; then
  /bin/bash ./gce_fix_ip.sh $GCP_IP_NAME
fi
if [ "${AWS_EIP_ID}" != "" ]; then
  /bin/bash ./aws_set_eip.sh $AWS_EIP_ID
fi

/usr/local/bin/supervisord
