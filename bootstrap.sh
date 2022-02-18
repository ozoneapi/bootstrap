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
      exit -1
    fi
    usermod -a -G wheel ssm-user
    if [[ $? != 0 ]]; then
      >&2 echo "Error while updating user permissions."
      exit -1
    fi
    echo "ssm-user ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/dont-prompt-ssm-user-for-sudo-password
    if [[ $? != 0 ]]; then
      >&2 echo "Error while updating user sudo password policy."
      exit -1
    fi
  fi
}

#/usr/bin/env bash
echo "Bootstrapping Geppetto"

# ensure git is installed
if [[ ! -f /usr/bin/git ]]; then
  echo "- git is not installed on this system. Installing git..."
  yum install -y git sudo
  # check for status again
  if [[ -f /usr/bin/git ]]; then
    echo "- git install check successful."
  else
    echo "- git install check failed. Ensure it is installed correctly."
    exit -1
  fi
fi

# create the ssm user
create_ssm_user

OZONE_HOME="/usr/o3"
GEPPETTO_HOME=${OZONE_HOME}/geppetto

if [[ -d ${GEPPETTO_HOME} ]]; then
  echo "- Cleaning old ${GEPPETTO_HOME}"
  sudo rm -rf ${GEPPETTO_HOME}
fi

echo "- Creating ${GEPPETTO_HOME}"
sudo mkdir -p ${GEPPETTO_HOME}

# assign right permissions
echo "- Assign user permissions to ${OZONE_HOME}"
sudo chown -R ssm-user:ssm-user ${OZONE_HOME}

CWD=$(dirname $0)

echo "- run the ssm-user bootstrap script"
sudo -iu ssm-user GIT_HTTPS_CREDS=${GIT_HTTPS_CREDS} BRANCH=${BRANCH} AUTODEPLOY=${AUTODEPLOY:-"false"} ${CWD}/ssm-bootstrap.sh

if [[ $? != 0 ]]; then
  >&2 echo "Bootstrap initialization failed."
  exit -1
fi
