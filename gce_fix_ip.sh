#!/bin/bash

set -x

GCP_PROJECT=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/project/project-id")
GCP_ZONE=$(basename $(curl -s -H "Authorization":"Bearer ${GCP_TOKEN}" -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone))
GCP_REGION=${GCP_ZONE:0:-2}
GCP_INSTANCE=$(hostname)
GCP_IP_NAME=$1

test "${GCP_PROJECT}" = "" && { echo "GCP_PROJECT not set."; exit 1; }
test "${GCP_REGION}" = "" && { echo "GCP_REGION not set."; exit 1; }
test "${GCP_ZONE}" = "" && { echo "GCP_ZONE not set."; exit 1; }
test "${GCP_INSTANCE}" = "" && { echo "GCP_INSTANCE not set."; exit 1; }
test "${GCP_IP_NAME}" = "" && { echo "GCP_IP_NAME not set."; exit 1; }

GCP_API_BASE_URL="https://www.googleapis.com/compute/v1/projects/${GCP_PROJECT}"
GCP_TOKEN=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" -H "Metadata-Flavor: Google" | jq -r .access_token)

test "${GCP_TOKEN}" = "null" && { echo "Failed to get token."; exit 1; }

ADDRESS_JSON=$(curl -s -H "Authorization":"Bearer ${GCP_TOKEN}" ${GCP_API_BASE_URL}/regions/${GCP_REGION}/addresses/$GCP_IP_NAME)
IP_STATUS=$(echo "${ADDRESS_JSON}" | jq -r .status)
GLOBAL_IP=$(echo "${ADDRESS_JSON}" | jq -r .address)

test "${IP_STATUS}" = "null" && { echo "Failed to get IP status."; exit 1; }
test "${GLOBAL_IP}" = "null" && { echo "Failed to get Global IP."; exit 1; }

RESOURCE_HOLDER=""
HOLDER_EXTERNAL_NAT_NAME=""
if [ "${IP_STATUS}" = "IN_USE" ]; then
  RESOURCE_HOLDER=$(basename $(echo "${ADDRESS_JSON}" | jq -r .users[0]) )
  if [ "${RESOURCE_HOLDER}" != "${GCP_INSTANCE}" ]; then
    RESOURCE_HOLDER_DETAIL_JSON=$(curl -s -H "Authorization":"Bearer ${GCP_TOKEN}" "${GCP_API_BASE_URL}/zones/${GCP_ZONE}/instances/${RESOURCE_HOLDER}")
    HOLDER_EXTERNAL_NAT_NAME=$(echo "${RESOURCE_HOLDER_DETAIL_JSON}" | jq -r .networkInterfaces[0].accessConfigs[0].name)
    curl -s -XPOST -H "Authorization":"Bearer ${GCP_TOKEN}" "${GCP_API_BASE_URL}/zones/${GCP_ZONE}/instances/${RESOURCE_HOLDER}/deleteAccessConfig?networkInterface=nic0&accessConfig=${HOLDER_EXTERNAL_NAT_NAME/ /%20}" -d ""
    sleep 10
  else
    echo "Address already used."
    exit 0
  fi
fi

INSTANCE_DETAIL_JSON=$(curl -s -H "Authorization":"Bearer ${GCP_TOKEN}" "${GCP_API_BASE_URL}/zones/${GCP_ZONE}/instances/${GCP_INSTANCE}")
CURRENT_IP=$(echo "${INSTANCE_DETAIL_JSON}" | jq -r .networkInterfaces[0].accessConfigs[0].natIP)
EXTERNAL_NAT_NAME=$(echo "${INSTANCE_DETAIL_JSON}" | jq -r .networkInterfaces[0].accessConfigs[0].name)

if [ "${CURRENT_IP}" != "null" ]; then
  curl -s -XPOST -H "Authorization":"Bearer ${GCP_TOKEN}" "${GCP_API_BASE_URL}/zones/${GCP_ZONE}/instances/${GCP_INSTANCE}/deleteAccessConfig?networkInterface=nic0&accessConfig=${EXTERNAL_NAT_NAME/ /%20}" -d ""
  sleep 10
  if [ "${RESOURCE_HOLDER}" != "" -a "${RESOURCE_HOLDER}" != "${GCP_INSTANCE}" ]; then
    REQUEST_BODY="{ \"kind\": \"compute#accessConfig\", \"type\": \"ONE_TO_ONE_NAT\", \"name\": \"${HOLDER_EXTERNAL_NAT_NAME}\"} "
    curl -s -XPOST -H "Content-type: application/json" -H "Authorization":"Bearer ${GCP_TOKEN}" "${GCP_API_BASE_URL}/zones/${GCP_ZONE}/instances/${RESOURCE_HOLDER}/addAccessConfig?networkInterface=nic0" \
      -d "${REQUEST_BODY}"
    sleep 10
  fi
fi


REQUEST_BODY="
{
  \"kind\": \"compute#accessConfig\",
  \"type\": \"ONE_TO_ONE_NAT\",
  \"name\": \"${EXTERNAL_NAT_NAME}\",
  \"natIP\": \"${GLOBAL_IP}\"
}
"
curl -s -XPOST -H "Content-type: application/json" -H "Authorization":"Bearer ${GCP_TOKEN}" "${GCP_API_BASE_URL}/zones/${GCP_ZONE}/instances/${GCP_INSTANCE}/addAccessConfig?networkInterface=nic0" \
-d "${REQUEST_BODY}"
