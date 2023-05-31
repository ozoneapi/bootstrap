#!/bin/bash

source /tmp/bootstrap/bootstrap-functions.sh
if [[ $? != 0 ]]; then
  >&2 echo "Error while loading bootstrap functions."
  exit 1
fi

# install docker
echo "Installing and starting docker - start"

yumInstall -y docker
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

# login to docker repository
echo "Logging in to docker repository - start"
DOCKER_LOGIN_USERNAME=$(getSsmParameter "docker-login-username")
if [[ -z ${DOCKER_LOGIN_USERNAME} ]]; then
  echo "docker-login-username parameter not found in SSM. Cannot proceed."
  exit -1
fi

DOCKER_LOGIN_PASSWORD=$(getSsmParameter "docker-login-password")
if [[ -z ${DOCKER_LOGIN_PASSWORD} ]]; then
  echo "docker-login-password parameter not found in SSM. Cannot proceed."
  exit -1
fi

DOCKER_LOGIN_REGISTRY=$(getSsmParameter "docker-login-registry")
if [[ -z ${DOCKER_LOGIN_REGISTRY} ]]; then
  echo "docker-login-registry parameter not found in SSM. Cannot proceed."
  exit -1
fi

docker login ${DOCKER_LOGIN_REGISTRY} -u ${DOCKER_LOGIN_USERNAME} -p ${DOCKER_LOGIN_PASSWORD}
if [[ $? != 0 ]]; then
  >&2 echo "Error while logging in to docker repository."
  exit 1
fi
echo "Logging in to docker repository - done"

# all set to run
STACK_NAME=$(getTag "StackName")
echo "getting stack name ${STACK_NAME}"

B64_DOCKER_RUN_COMMAND=$(getSsmParameter "${STACK_NAME}.docker-run-command")

DOCKER_RUN_COMMAND=$(echo ${B64_DOCKER_RUN_COMMAND} | base64 -d)

echo "Running ${DOCKER_RUN_COMMAND} - start"

docker run ${DOCKER_RUN_COMMAND}
if [[ $? != 0 ]]; then
  >&2 echo "Error while running docker container."
  exit 1
fi






