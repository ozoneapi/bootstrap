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

git config --global core.askPass false
git config --global credential.https://github.com.useHttpPath true

git config --global credential.helper '!f() {
  sleep 1
  if [[ -z ${GITHUB_HTTPS_CREDS} ]]; then
    export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
    export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
    export GITHUB_HTTPS_CREDS=$(aws ssm get-parameter --name github.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
  fi
  if [[ -n $GITHUB_HTTPS_CREDS ]]; then
    echo "username=${GITHUB_HTTPS_CREDS}"
    echo "password="
  fi
}; f'

# if failed, error out
if [[ $? != 0 ]]; then
  >&2 echo "Could not set credential.helper Cannot proceed."
  exit 1
else
  echo "credential.helper set successfully"
fi

git config --global credential.https://github.com/ozoneapi.helper '!f() {
  sleep 1
  if [[ -z ${GITHUB_HTTPS_CREDS} ]]; then
    export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
    export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
    export GITHUB_HTTPS_CREDS=$(aws ssm get-parameter --name github.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
  fi
  if [[ -n $GITHUB_HTTPS_CREDS ]]; then
    echo "username=${GITHUB_HTTPS_CREDS}"
    echo "password="
  fi
}; f'
if [[ $? != 0 ]]; then
  >&2 echo "Could not set credential.https://github.com/ozoneapi.helper  Cannot proceed."
  exit 1
else
  echo "credential.https://github.com/ozoneapi.helper  set successfully"
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
git clone --quiet ${BRANCH_OPTS} https://github.com/ozoneapi/observability-ctrl-plane.git ${OBS_HOME}

if [[ $? != 0 ]]; then
  echo "- Clone failed on branch ${OBS_BRANCH}."
  exit 1
fi

echo "- Running node initialisation on observability control plane"
/usr/o3/observability-ctrl-plane/node-init/scripts/node-init.sh
