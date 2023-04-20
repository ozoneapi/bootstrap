#!/bin/bash

USER=$(whoami)

if [[ $USER != 'ssm-user' ]]; then
  >&2 echo "Not running as ssm-user. Cannot proceed."
  exit 1
fi

if [[ $(git config --global --get credential.helper) == 'store' ]]; then
  echo "Found credential store to be 'store'. This is legacy. Will be changed to use the SSM Parameter store"
  git config --global --unset credential.helper
fi

echo "Configuring credential.helper"
# ensure git credential helper that reads creds from AWS
# use single quotes to stop variable expansion on the shell
# shellcheck disable=SC2016
git config --global credential.helper '!f() {
  sleep 1
  if [[ -z ${GIT_HTTPS_CREDS} && $BASE_RUNTIME == "EC2" ]]; then
    export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
    export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
    export GIT_HTTPS_CREDS=$(aws ssm get-parameter --name git.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
  fi
  if [[ -n $GIT_HTTPS_CREDS ]]; then
    local GIT_USERNAME=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f1)
    local GIT_ACCESS_CRED=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f2)
    echo "username=${GIT_USERNAME}"
    echo "password=${GIT_ACCESS_CRED}"
  fi
}; f'

echo "Configuring credential.https://bitbucket.org/ozoneapi.helper"
git config --global core.askPass false
git config --global credential.https://bitbucket.org.useHttpPath true
# ensure git credential helper, for bitbucker/ozone, that reads creds from AWS
# use single quotes to stop variable expansion on the shell
# shellcheck disable=SC2016
git config --global credential.https://bitbucket.org/ozoneapi.helper '!f() {
  sleep 1
  if [[ -z ${GIT_HTTPS_CREDS} && $BASE_RUNTIME == "EC2" ]]; then
    export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
    export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
    export GIT_HTTPS_CREDS=$(aws ssm get-parameter --name git.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
  fi
  if [[ -n $GIT_HTTPS_CREDS ]]; then
    local GIT_USERNAME=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f1)
    local GIT_ACCESS_CRED=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f2)
    echo "username=${GIT_USERNAME}"
    echo "password=${GIT_ACCESS_CRED}"
  fi
}; f'

OZONE_HOME="/usr/o3"
GEPPETTO_HOME=${OZONE_HOME}/geppetto

if [[ -z ${GEPPETTO_BRANCH} ]]; then
  >&2 echo "No GEPPETTO_BRANCH specified. Cannot proceed."
  exit 1
fi

BRANCH_OPTS="--branch=${GEPPETTO_BRANCH}"

# TODO: Need a "proper" clean, before deleting the OZONE_HOME
# if [[ $(which pm2) != 0 ]]; then
#   pm2 delete-all
# fi
# if [[ -d ${OZONE_HOME} ]]; then
#   echo "Cleaning up existing Ozone install from ${OZONE_HOME}."
#   rm -rf ${OZONE_HOME}
#   mkdir -p ${OZONE_HOME}
# fi

if [[ -d ${GEPPETTO_HOME} ]]; then
  echo "Cleaning up existing geppetto."
  rm -rf ${GEPPETTO_HOME}
fi

echo "- Clone geppetto into ${GEPPETTO_HOME} ${BRANCH_OPTS}"
git clone --quiet ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto.git ${GEPPETTO_HOME}

if [[ $? != 0 && $GEPPETTO_BRANCH != 'develop' ]]; then
  echo "- Clone failed on branch ${GEPPETTO_BRANCH}. Trying 'develop'."
  BRANCH_OPTS="--branch=develop"
  git clone --quiet ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto.git ${GEPPETTO_HOME}
fi
