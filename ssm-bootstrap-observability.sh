#!/bin/bash

#
# Ensure we are running as ssm-user
#
USER=$(whoami)

if [[ $USER != 'ssm-user' ]]; then
  >&2 echo "Not running as ssm-user. Cannot proceed."
  exit 1
fi

#
# Get the right git configuration and credentials in place
#
if [[ $(git config --global --get credential.helper) == 'store' ]]; then
  echo "Found credential store to be 'store'. This is legacy. Will be changed to use the SSM Parameter store"
  git config --global --unset credential.helper
fi

echo "Configuring credential.helper"
if [[ -z ${GIT_HTTPS_CREDS} && $BASE_RUNTIME == "EC2" ]]; then
  echo "GIT_HTTPS_CREDS already set or BASE_RUNTIME is not EC2. Will not read SSM Parameter"
  echo "BASE_RUNTIME is ${BASE_RUNTIME}"
else
  echo "Attempting to read git.https.creds from SSM Parameter Store"

  echo "Reading TOKEN from EC2 Metadata"
  export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
  # if no TOKEN, error out
  if [[ -z ${TOKEN} ]]; then
    >&2 echo "Could not get TOKEN from EC2 Metadata. Cannot proceed."
    exit 1
  else
    echo "imdsv2 token retrieved successfully"
  fi

  echo "Reading TOKEN from EC2 Metadata"
  export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
  # if no REGION, error out
  if [[ -z ${REGION} ]]; then
    >&2 echo "Could not get REGION from EC2 Metadata. Cannot proceed."
    exit 1
  else
    echo "REGION is set to ${REGION}"
  fi

  export GIT_HTTPS_CREDS=$(aws ssm get-parameter --name git.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
  # if no GIT_HTTPS_CREDS, error out
  if [[ -z ${GIT_HTTPS_CREDS} ]]; then
    >&2 echo "Could not get GIT_HTTPS_CREDS from SSM Parameter Store. Cannot proceed."
    exit 1
  else
    echo "GIT_HTTPS_CREDS retrieved successfully"
  fi

  export GIT_USERNAME=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f1)
  # if no GIT_USERNAME, error out
  if [[ -z ${GIT_USERNAME} ]]; then
    >&2 echo "Could not get GIT_USERNAME from GIT_HTTPS_CREDS. Cannot proceed."
    exit 1
  else
    echo "GIT_USERNAME extracted from GIT_HTTPS_CREDS"
  fi

  export GIT_ACCESS_CRED=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f2)
  # if no GIT_ACCESS_CRED, error out
  if [[ -z ${GIT_ACCESS_CRED} ]]; then
    >&2 echo "Could not get GIT_ACCESS_CRED from GIT_HTTPS_CREDS. Cannot proceed."
    exit 1
  else
    echo "GIT_ACCESS_CRED extracted from GIT_HTTPS_CREDS"
  fi
fi

git config --global credential.helper 'username=${GIT_USERNAME} password=${GIT_ACCESS_CRED}'
# if failed, error out
if [[ $? != 0 ]]; then
  >&2 echo "Could not set credential.helper Cannot proceed."
  exit 1
else
  echo "credential.helper set successfully"
fi

git config --global core.askPass false
git config --global credential.https://bitbucket.org.useHttpPath true
git config --global credential.https://bitbucket.org/ozoneapi.helper 'username=${GIT_USERNAME} password=${GIT_ACCESS_CRED}'
if [[ $? != 0 ]]; then
  >&2 echo "Could not set credential.https://bitbucket.org/ozoneapi.helper  Cannot proceed."
  exit 1
else
  echo "credential.https://bitbucket.org/ozoneapi.helper  set successfully"
fi

#
# Clone the control plane
#
echo "Cloning Observability Control Plane"
OZONE_HOME="/usr/o3"

echo "Make sure OZONE_HOME ${OZONE_HOME} exists"
mkdir -p ${OZONE_HOME}

OBS_HOME=${OZONE_HOME}/observability-ctrl-plane

if [[ -z ${OBS_BRANCH} ]]; then
  >&2 echo "No OBS_BRANCH specified. Cannot proceed."
  exit 1
fi

BRANCH_OPTS="--branch=${OBS_BRANCH}"

if [[ -d ${OBS_HOME} ]]; then
  echo "Cleaning up existing observability control plane."
  rm -rf ${OBS_HOME}
fi

echo "- Clone observability into ${OBS_HOME} ${BRANCH_OPTS}"
git clone --quiet ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/observability-ctrl-plane.git ${OBS_HOME}

if [[ $? != 0 ]]; then
  echo "- Clone failed on branch ${OBS_BRANCH}."
  exit 1
fi

# clone geppetto if required
GEPPETTO_HOME=${OZONE_HOME}/geppetto

# check if geppetto exists
if [[ ! -d ${GEPPETTO_HOME} ]]; then
  echo "Clone geppetto into ${GEPPETTO_HOME} ${BRANCH_OPTS}"
  git clone --branch=develop https://bitbucket.org/ozoneapi/geppetto.git ${GEPPETTO_HOME}

  if [[ $? != 0 ]]; then
    echo "Failed to clone geppetto"
    exit 1
  fi
else
  echo "Geppetto already exists. Skipping cloning."
fi

echo "- Running node initialisation on observability control plane"
/usr/o3/observability-ctrl-plane/node-init/scripts/node-init.sh