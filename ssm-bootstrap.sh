USER=`whoami`

if [[ $USER != 'ssm-user' ]]; then
  >&2 echo "Not running as ssm-user. Cannot proceed."
  exit -1
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
  echo "Credential helper is 'store'. Validating ${HOME}/.git-credentials file."

  # Configure the credentials if they are not already done
  unset -v HAVE_CREDS
  GIT_CRED_FILE="${HOME}/.git-credentials"
  if [[ -f ${GIT_CRED_FILE} ]]; then
    HAVE_CREDS=$(cat ${GIT_CRED_FILE} | grep -v bitbucket.org/ozoneapi | wc -l)
  fi

  if [[ ! -z ${HAVE_CREDS} && ${HAVE_CREDS} != 0 ]]; then
    echo "git https creds configured."
  else 
    echo "git https creds not already configured. Fetch from 'GIT_HTTPS_CREDS'"
    # if credentials not configured, use defaults
    if [[ -z ${GIT_HTTPS_CREDS} ]]; then
      >&2 echo "Export the git https credentials before running this script. Run:"
      >&2 echo "export GIT_HTTPS_CREDS=<username:app-password>"
      exit -1
    fi
    echo "persisting git https creds"
    echo "https://${GIT_HTTPS_CREDS}@bitbucket.org/ozoneapi" >> ${GIT_CRED_FILE}
  fi
fi

OZONE_HOME="/usr/o3"
GEPPETTO_HOME=${OZONE_HOME}/geppetto

if [[ -v BRANCH ]]; then
  BRANCH_OPTS="--branch=${BRANCH}"
fi

echo "- Clone geppetto into ${GEPPETTO_HOME} ${BRANCH_OPTS}"
git clone ${BRANCH_OPTS} https://bitbucket.org/ozoneapi/geppetto ${GEPPETTO_HOME}