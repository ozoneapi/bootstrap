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

# login to docker repository
echo "Logging in to docker repository - start"
DOCKER_LOGIN_USERNAME=$(aws ssm get-parameter --name "docker-login-username" --region ${REGION} --query "Parameter.Value" --output text)
if [[ -z ${DOCKER_LOGIN_USERNAME} ]]; then
  echo "docker-login-username parameter not found in SSM. Cannot proceed."
  exit -1
fi

DOCKER_LOGIN_PASSWORD=$(aws ssm get-parameter --name "docker-login-password" --region ${REGION} --query "Parameter.Value" --output text)
if [[ -z ${DOCKER_LOGIN_PASSWORD} ]]; then
  echo "docker-login-password parameter not found in SSM. Cannot proceed."
  exit -1
fi

DOCKER_LOGIN_REGISTRY=$(aws ssm get-parameter --name "docker-login-registry" --region ${REGION} --query "Parameter.Value" --output text)
if [[ -z ${DOCKER_LOGIN_REGISTRY} ]]; then
  echo "docker-login-registry parameter not found in SSM. Cannot proceed."
  exit -1
fi

docker login ${DOCKER_LOGIN_REGISTRY} -u ${DOCKER_LOGIN_USERNAME} -p ${DOCKER_LOGIN_PASSWORD}
if [[ $? != 0 ]]; then
  >&2 echo "Error while logging in to docker repository."
  exit 1
fi

# all set to run
B64_DOCKER_RUN_COMMAND=$(getTag "DockerRunCommand")

DOCKER_RUN_COMMAND=$(echo ${B64_DOCKER_RUN_COMMAND} | base64 -d)

echo "Running ${DOCKER_RUN_COMMAND} - start"
docker run ${DOCKER_RUN_COMMAND}
if [[ $? != 0 ]]; then
  >&2 echo "Error while running docker container."
  exit 1
fi






