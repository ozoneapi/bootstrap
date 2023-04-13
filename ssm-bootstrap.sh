USER=$(whoami)

if [[ $USER != 'ssm-user' ]]; then
  >&2 echo "Not running as ssm-user. Cannot proceed."
  exit 1
fi

if [[ $(git config --global --get credential.helper) == 'store' ]]; then
  echo "Found credential store to be 'store'. Remove that, use custom store instead"
  git config --global --unset credential.helper
fi

# ensure git credential helper is configured to be the "store"
if [[ -z $(git config --get credential.https://bitbucket.org/ozoneapi.helper) ]]; then
  echo "Credential Helper not configured. Configuring custom helper for 'https://bitbucket.org/ozoneapi'"
  git config --global core.askPass false
  git config --global credential.https://bitbucket.org.useHttpPath true
  # use single quotes to stop variable expansion on the shell
  # shellcheck disable=SC2016
  git config --global credential.https://bitbucket.org/ozoneapi.helper '!f() { sleep 1; local GIT_USERNAME=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f1); local GIT_ACCESS_CRED=$(echo ${GIT_HTTPS_CREDS} | cut -d ':' -f2); echo "username=${GIT_USERNAME}"; echo "password=${GIT_ACCESS_CRED}"; }; f'

  # cross check the store has been configured, otherwise fail
  if [[ -z $(git config --global --get credential.https://bitbucket.org/ozoneapi.helper) ]]; then
    >&2 echo "git store configuration failed. Cannot proceed."
    exit 1
  fi
fi

OZONE_HOME="/usr/o3"
GEPPETTO_HOME=${OZONE_HOME}/geppetto

if [[ -v BRANCH ]]; then
  BRANCH_OPTS="--branch=${BRANCH}"
fi

if [[ -d ${GEPPETTO_HOME} ]]; then
  echo "Cleaning up existing geppetto."
  rm -rf ${GEPPETTO_HOME}
fi

echo "- ensure git credentials"
if [[ -z ${GIT_HTTPS_CREDS} ]]; then
  >&2 echo "GIT_HTTPS_CREDS not available. Cannot proceed."
  exit 1
fi

echo "- Clone geppetto into ${GEPPETTO_HOME} ${BRANCH_OPTS}"
git clone ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto.git ${GEPPETTO_HOME}

if [[ $? != 0 && $BRANCH != 'develop' ]]; then
  echo "- Clone failed on branch ${BRANCH}. Trying 'develop'."
  BRANCH_OPTS="--branch=develop"
  git clone ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto.git ${GEPPETTO_HOME}
fi

if [[ "${AUTODEPLOY,,}" == "true" ]]; then
  echo "Autodeploy requested."
  sudo ${GEPPETTO_HOME}/scripts/install-ozone-stage1.sh
  ${GEPPETTO_HOME}/scripts/install-ozone-stage3.sh
else
  echo "Not running autodeploy."
fi