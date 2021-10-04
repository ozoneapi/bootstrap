#/usr/bin/env bash
echo "Bootstrapping Geppetto"
USER=`whoami`
if [[ -v SKIP_SSM_USER ]]; then
  if [[ ${USER} = "root" ]]; then
    echo "This script needs to be run as a non-\"root\". Ensure correct setup."
    exit -1
  fi
else 
  if [[ ${USER} != "ssm-user" ]]; then
    echo "This script needs to be run as \"ssm-user\". Ensure correct setup."
    exit -1
  fi
fi

echo " - running as user ${USER}. Check successful."
echo " - Assuming user has \"sudo\" permissions with no need for password"

# ensure git is installed
if [[ ! -f /usr/bin/git ]]; then
  echo "- git is not installed on this system. Installing git..."
  sudo yum install -y git-core
  # check for status again
  if [[ -f /usr/bin/git ]]; then
    echo "- git install check successful."
  else
    echo "- git install check failed. Ensure it is installed correctly."
    exit -1
  fi
fi

# ensure git credential helper is configured to be the "store"
if [[ `git config --global credential.helper | wc -l` = 0 ]]; then
  echo "Credential Helper not configured. Configuring 'store'"
  git config --global credential.helper store

  # cross check the store has been configured, otherwise fail
  if [[ `git config --global credential.helper | wc -l` = 0 ]]; then
    >&2 echo "git store configuration failed. Cannot proceed."
    exit -1
  fi
fi

if [[ `git config --global credential.helper` != 'store' ]]; then 
  echo "Credential helper is not 'store'. Skip git-credential configuration and check."
else
  echo 'Credential helper is "store". Validating ~/.git-credentials file.'

  # Configure the credentials if they are not already done
  unset -v HAVE_CREDS
  if [[ -f ~/.git-credentials ]]; then
    HAVE_CREDS=$(cat ~/.git-credentials | grep -v bitbucket.org/ozoneapi | wc -l)
  fi

  if [[ ! -z ${HAVE_CREDS} && ${HAVE_CREDS} != 0 ]]; then
    echo "git https creds configured."
  else 
    # if credentials not configured, use defaults
    if [[ ! -v GIT_HTTPS_CREDS ]]; then
      echo "Export the git https credentials before running this script. Run:"
      echo "export GIT_HTTPS_CREDS=<username:app-password>"
      exit -1
    fi
    echo "persisting git https creds"
    echo "https://$GIT_HTTPS_CREDS@bitbucket.org/ozoneapi" >> ~/.git-credentials
  fi
fi

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
sudo chown -R ${USER}:${USER} ${OZONE_HOME}

if [[ -v BRANCH ]]; then
  BRANCH_OPTS="--branch=${BRANCH}"
fi

echo "- Clone geppetto into ${GEPPETTO_HOME} ${BRANCH_OPTS}"
git clone ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto ${GEPPETTO_HOME}