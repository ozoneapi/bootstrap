#/usr/bin/env bash
echo "Bootstrapping Geppetto"
USER=`whoami`
if [[ ${USER} != "root" ]]; then
  echo "This script needs to be run as a \"root\". Ensure correct setup."
  exit -1
fi

echo " - running as user ${USER}. Check successful."
echo " - Assuming user has \"sudo\" permissions with no need for password"

if [[ -f /root/.git-credentials ]]; then
  HAVE_CREDS=$(cat /root/.git-credentials | grep -v bitbucket.org/ozoneapi | wc -l)
fi

if [[ ! -z $HAVE_CREDS && $HAVE_CREDS != 0 ]]; then
  echo "git https creds configured."
elif [[ -v GIT_HTTPS_CREDS ]]; then
  echo "persisting git https creds"
  echo "https://$GIT_HTTPS_CREDS@bitbucket.org/ozoneapi" >> /root/.git-credentials
else
  echo "Export the git https credentials before running this script. Run:"
  echo "export GIT_HTTPS_CREDS=<username:app-password>"
  exit -1
fi

# ensure git is installed
if [[ ! -f /usr/bin/git ]]; then
  echo "- git is not installed on this system. Installing git..."
  yum install -y git-core
fi

# check for status again
if [[ -f /usr/bin/git ]]; then
  echo "- git install check successful."
else
  echo "- git install check failed. Ensure it is installed correctly."
  exit -1
fi

if [[ ! -f /root/.gitconfig ]]; then
  git config --global credential.helper store
fi

OZONE_HOME="/usr/o3"
GEPPETTO_HOME=${OZONE_HOME}/geppetto

if [[ -d ${GEPPETTO_HOME} ]]; then
  echo "- Cleaning old ${GEPPETTO_HOME}"
  rm -rf /usr/o3/geppetto
fi

echo "- Creating ${GEPPETTO_HOME}"
mkdir -p ${GEPPETTO_HOME}

if [[ -v BRANCH ]]; then
  BRANCH_OPTS="--branch=${BRANCH}"
fi

echo "- Clone geppetto into ${GEPPETTO_HOME} ${BRANCH_OPTS}"
git clone ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto ${GEPPETTO_HOME}

echo "- Move git config and credentials to ssm-user"
if [[ ! -d /home/ssm-user ]]; then
  mkdir -p /home/ssm-user
fi  

mv /root/.gitconfig /home/ssm-user
mv /root/.git-credentials /home/ssm-user
chown -R ssm-user:ssm-user /home/ssm-user
chown -R ssm-user:ssm-user /usr/o3 /home/ssm-user