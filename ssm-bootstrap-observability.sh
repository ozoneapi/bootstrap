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

# for legacy reasons, there is code, in geppetto, to check the existance of
# git config credential.helper
# at some point, this should be removed, from code, as well as config
# so that we do not send Zone git credentials to other Git Repos,
# that the user may try to access
# #Security
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



# ensure git credential helper, for bitbucker/ozone, that reads creds from AWS
# prefer this usage, because this will not leak creds to other
# git servers, than the one we intended
echo "Configuring credential.https://bitbucket.org/ozoneapi.helper"
git config --global core.askPass false
git config --global credential.https://bitbucket.org.useHttpPath true
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

echo "Make sure OZONE_HOME($OZONE_HOME) exists"
mkdir -p $OZONE_HOME

OBS_HOME=${OZONE_HOME}/observability-ctrl-plane

if [[ -z ${OBS_BRANCH} ]]; then
  >&2 echo "No OBS_BRANCH specified. Cannot proceed."
  exit 1
fi

BRANCH_OPTS="--branch=${OBS_BRANCH}"

# TODO: Need a "proper" clean, before deleting the OZONE_HOME
# if [[ $(which pm2) != 0 ]]; then
#   pm2 delete-all
# fi
# if [[ -d ${OZONE_HOME} ]]; then
#   echo "Cleaning up existing Ozone install from ${OZONE_HOME}."
#   rm -rf ${OZONE_HOME}
#   mkdir -p ${OZONE_HOME}
# fi

if [[ -d ${OBS_HOME} ]]; then
  echo "Cleaning up existing observability control plane."
  rm -rf ${OBS_HOME}
fi

echo "- Clone observability into ${OBS_HOME} ${BRANCH_OPTS}"
git clone --quiet ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/observability-ctrl-plane.git ${OBS_HOME}

if [[ $? != 0 && $OBS_BRANCH != 'develop' ]]; then
  echo "- Clone failed on branch ${OBS_BRANCH}. Trying 'develop'."
  BRANCH_OPTS="--branch=develop"
  git clone --quiet ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/observability-ctrl-plane.git ${OBS_HOME}
fi

echo "- Running node initialisation on observability control plane"
/usr/o3/observability-ctrl-plane/node-init/scripts/install-observers.sh