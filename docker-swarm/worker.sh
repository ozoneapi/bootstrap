#!/bin/bash

source /tmp/bootstrap/bootstrap-functions.sh
if [[ $? != 0 ]]; then
  >&2 echo "Error while loading bootstrap functions."
  exit 1
fi

# install docker
echo "Installing and starting docker - start"

dnf install -y docker
if [[ $? != 0 ]]; then
  >&2 echo "Error while installing docker."
  exit 1
fi

systemctl start docker
if [[ $? != 0 ]]; then
  >&2 echo "Error while starting docker."
  exit 1
fi
echo "Installing and starting docker - done"

# get the swarm name as an instance tag
SWARM_NAME=$(getTag "SwarmName")
if [[ -z ${SWARM_NAME} ]]; then
  >&2 echo "SwarmName tag not found. Cannot proceed."
  exit 1
fi


# Get the SwarmJoinToken. Sleep 5 seconds to allow the manager to initialise. Repeat until found
SWARM_JOIN_TOKEN=$(getSsmParameter "${SWARM_NAME}.JoinToken")
while [[ -z ${SWARM_JOIN_TOKEN} ]]; do
  echo "Swarm join token not found. Sleeping 5 seconds."
  sleep 5
  SWARM_JOIN_TOKEN=$(getSsmParameter "${SWARM_NAME}.JoinToken")
done

SWARM_IP=$(getSsmParameter "${SWARM_NAME}.SwarmIpAddress")
echo "Swarm IP address is ${SWARM_IP}. Joining swarm."

echo "Joining swarm with token ${SWARM_JOIN_TOKEN}"
docker swarm join \
  --token ${SWARM_JOIN_TOKEN} \
  ${SWARM_IP}

if [[ $? != 0 ]]; then
  >&2 echo "Error while joining swarm."
  exit 1
fi



