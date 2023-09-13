#!/bin/bash

function create_ssm_user {
  # check if user already exists
  getent passwd ssm-user > /dev/null
  if [[ $? = 0 ]]; then
    echo "ssm-user user already exists. Don't need to do anything more."
  else
    # ssm-user creation
    useradd --comment "mirror AWS System Manager ozone-user" --create-home --shell /bin/bash ssm-user
    if [[ $? != 0 ]]; then
      >&2 echo "Error while creating user."
      exit 1
    fi
    usermod -a -G wheel ssm-user
    if [[ $? != 0 ]]; then
      >&2 echo "Error while updating user permissions."
      exit 1
    fi
    echo "ssm-user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/dont-prompt-ozone-user-for-sudo-password
    if [[ $? != 0 ]]; then
      >&2 echo "Error while updating user sudo password policy."
      exit 1
    fi
  fi
}

#/usr/bin/env bash
echo "Bootstrapping OzDeploy"
apt-get update
# ensure git is installed
echo "- Installing bootstrapping tools"
apt-get install -y git-core sudo shadow-utils unzip wget
# cd /tmp
# curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip"
# unzip awscliv2.zip
# ./aws/install
# if [[ $? != 0 ]]; then
#   >&2 echo "Issue in installing AWS CLI. Exiting....."
#   exit -1
# fi
# echo "aws-cli is installed"

# rm -rf awscliv2.zip
# create the ssm user
create_ssm_user

OZONE_HOME="/usr/o3"
OZ_DEPLOY_HOME=${OZONE_HOME}/oz-deploy
if [[ -d ${OZ_DEPLOY_HOME} ]]; then
  echo "- Cleaning old ${OZ_DEPLOY_HOME}"
  sudo rm -rf ${OZ_DEPLOY_HOME}
fi


echo "- Creating ${OZ_DEPLOY_HOME}"

sudo mkdir -p ${OZ_DEPLOY_HOME}
# assign right permissions
echo "- Assign user permissions to ${OZONE_HOME}"
sudo chown -R ssm-user:ssm-user ${OZONE_HOME}

CWD=$(dirname $0)
REAL_DIR=$(realpath ${CWD})

echo "- run the ssm-user bootstrap script in ${REAL_DIR}"
sudo -iu ssm-user GIT_HTTPS_CREDS=${GIT_HTTPS_CREDS} OZ_DEPLOY_BRANCH=${OZ_DEPLOY_BRANCH:-${BRANCH}} AUTODEPLOY=${AUTODEPLOY:-"false"} ${REAL_DIR}/ssm-bootstrap.sh

if [[ $? != 0 ]]; then
  >&2 echo "Bootstrap initialization failed."
  exit 1
fi
