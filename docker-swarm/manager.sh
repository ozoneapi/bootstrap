#!/bin/bash

source /tmp/bootstrap/bootstrap-functions.sh
if [[ $? != 0 ]]; then
  >&2 echo "Error while loading bootstrap functions."
  exit 1
fi

# install docker
echo "Installing and starting docker - start"

yum install -y docker
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

# get the swarm ip address if its already been initialised
echo "Retrieving swarm ip address for swarm ${SWARM_NAME}"
SWARM_IP=$(getSsmParameter "${SWARM_NAME}.SwarmIpAddress")

# if not initialised, initialise it
if [[ -z ${SWARM_IP} ]]; then
  echo "Swarm IP address not found. Initialising swarm."
  SWARM_IP=$(getPrivateIpAddress)
  echo "Setting Swarm IP address to ${SWARM_IP}"

  setSSMParameter "${SWARM_NAME}.SwarmIpAddress" "${SWARM_IP}"
  if [[ $? != 0 ]]; then
    >&2 echo "Error while setting swarm ip address."
    exit 1
  fi

  docker swarm init --advertise-addr ${SWARM_IP}
  if [[ $? != 0 ]]; then
    >&2 echo "Error while initialising swarm."
    exit 1
  fi

else
  # swarm initialised, join it as a manager node
  echo "Swarm IP address is ${SWARM_IP}. Joining swarm."

  SWARM_TOKEN=$(getSsmParameter "${SWARM_NAME}.SwarmJoinToken")
  if [[ -z ${SWARM_TOKEN} ]]; then
    >&2 echo "Swarm join token not found. Cannot proceed."
    exit 1
  fi

  echo "Joining swarm with token ${SWARM_TOKEN}"
  docker swarm join \
    --token ${SWARM_TOKEN} \
    ${SWARM_IP}

  if [[ $? != 0 ]]; then
    >&2 echo "Error while joining swarm."
    exit 1
  fi
fi



