#!/bin/bash

source /tmp/bootstrap/bootstrap-functions.sh
if [[ $? != 0 ]]; then
  >&2 echo "Error while loading bootstrap functions."
  exit 1
fi

# ensure ssm user
echo "Ensuring ssm user..."
ensure_ssm_user
echo "Ssm user ensured."

INSTALL_REPO_URL=$(getTag "InstallRepoUrl")
if [[ -z ${INSTALL_REPO_URL} ]]; then
  echo "InstallRepoUrl tag not found. Cannot proceed."
  exit -1
fi

INSTALL_REPO_BRANCH=$(getTag "InstallRepoBranch")
if [[ -z ${INSTALL_REPO_BRANCH} ]]; then
  echo "InstallRepo tag not found. Cannot proceed."
  exit -1
fi

INSTALL_SCRIPT=$(getTag "InstallScript")
if [[ -z ${INSTALL_SCRIPT} ]]; then
  echo "InstallScript tag not found. Cannot proceed."
  exit -1
fi

# configure git
echo "Configuring git..."
configure_git
echo "Git configured."

# clone install repo
echo "Cloning install repo..."
clone_repo ${INSTALL_REPO_URL} ${INSTALL_REPO_BRANCH}
echo "Install repo cloned."

# run install script
echo "Running install script..."
${INSTALL_SCRIPT}
echo "Install script finished."