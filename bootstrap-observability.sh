#!/bin/bash

function create_ssm_user {
  # check if user already exists
  getent passwd ssm-user > /dev/null
  if [[ $? = 0 ]]; then
    echo "ssm-user user already exists. Don't need to do anything more."
  else
    # ssm-user creation
    useradd --comment "mirror AWS System Manager ssm-user" --create-home --shell /bin/bash ssm-user
    if [[ $? != 0 ]]; then
      >&2 echo "Error while creating user."
      exit 1
    fi
    usermod -a -G wheel ssm-user
    if [[ $? != 0 ]]; then
      >&2 echo "Error while updating user permissions."
      exit 1
    fi
    echo "ssm-user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/dont-prompt-ssm-user-for-sudo-password
    if [[ $? != 0 ]]; then
      >&2 echo "Error while updating user sudo password policy."
      exit 1
    fi
  fi
}

#/usr/bin/env bash
echo "Bootstrapping Observability Control Plane"

# ensure git is installed
echo "- Installing bootstrapping and observability tools"
dnf install -y less jq git-core tar unzip which sudo procps openssl shadow-utils ca-certificates findutils logrotate

# create the ssm user
create_ssm_user

OZONE_HOME="/usr/o3"
OBS_HOME=${OZONE_HOME}/observability-ctrl-plane
if [[ -d ${OBS_HOME} ]]; then
  echo "- Cleaning old ${OBS_HOME}"
  sudo rm -rf ${OBS_HOME}
fi

echo "- Creating ${OBS_HOME}"
sudo mkdir -p ${OBS_HOME}

# assign right permissions
echo "- Assign user permissions to ${OZONE_HOME}"
sudo chown -R ssm-user:ssm-user ${OZONE_HOME}

CWD=$(dirname $0)
REAL_DIR=$(realpath ${CWD})

echo "- run the ssm-bootstrap-observability bootstrap script in ${REAL_DIR}"
sudo -iu ssm-user GITHUB_HTTPS_CREDS=${GITHUB_HTTPS_CREDS} OBS_BRANCH=${OBS_BRANCH:-${BRANCH}} AUTODEPLOY=${AUTODEPLOY:-"false"} ${REAL_DIR}/ssm-bootstrap-observability.sh

if [[ $? != 0 ]]; then
  >&2 echo "Bootstrap initialization failed."
  exit 1
fi
