#
# Instance related
#
function getTag() {
  local TAG_NAME=${1}

  aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$(getEc2InstanceId)" "Name=key,Values=${TAG_NAME}" \
    --query "Tags[0].Value" \
    --output text \
    --region $(getEc2Region)
}

function getImdsvToken() {
  curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 10"
}

function getEc2InstanceId() {
  local TOKEN=$(getImdsvToken)
  curl -s http://169.254.169.254/latest/meta-data/instance-id \
    -H "X-aws-ec2-metadata-token: ${TOKEN}"
}

function getEc2Region() {
  local TOKEN=$(getImdsvToken)
  curl -s http://169.254.169.254/latest/meta-data/placement/region \
  -H "X-aws-ec2-metadata-token: ${TOKEN}"
}

function getPrivateIpAddress() {
  aws ec2 describe-instances --instance-id $(getEc2InstanceId) \
     --query "Reservations[0].Instances[0].PrivateIpAddress" --output text
}


#
# SSM Parameters
#
function getSsmParameter() {
  local PARAMETER_NAME=${1}
  local REGION=$(getEc2Region)

  aws ssm get-parameter \
    --name ${PARAMETER_NAME} \
    --region ${REGION} \
    --with-decryption \
    --query Parameter.Value \
    --output text
}

function setSsmParameter() {
  local PARAMETER_NAME=${1}
  local PARAMETER_VALUE=${2}
  local REGION=$(getEc2Region)

  aws ssm put-parameter \
    --name ${PARAMETER_NAME} \
    --value "${PARAMETER_VALUE}" \
    --type SecureString \
    --region ${REGION} \
    --overwrite
}

function yumInstall() {
  local PACKAGE_NAMES=${*}


  # try 3 times to install the packages
  for i in {1..3}; do
    # sleep while yum lock is active
    while [[ -f /var/run/yum.pid ]]; do
      echo "`date` - yum lock file exists. Waiting for yum to finish"
      sleep 5
    done

    yum install -y ${PACKAGE_NAMES}
    if [[ $? == 0 ]]; then
      echo "`date` - yum install succeeded"
      break
    fi

    echo "Installation failed on attempt ${i}. Sleeping for 5 seconds"
    sleep 5
  done
}


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

  # make sure ozone folder exist
  mkdir -p /usr/o3
  chown ssm-user: /usr/o3


}

function configure_git {

  echo "configuring git credential helper - start"
  git config --global credential.helper '!f() {
    sleep 1
    if [[ -z ${GITHUB_HTTPS_CREDS} ]]; then
      export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
      export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
      export GITHUB_HTTPS_CREDS=$(aws ssm get-parameter --name github.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
    fi
    if [[ -n $GITHUB_HTTPS_CREDS ]]; then
      local GIT_USERNAME=$(echo ${GITHUB_HTTPS_CREDS} | cut -d ':' -f1)
      local GIT_ACCESS_CRED=$(echo ${GITHUB_HTTPS_CREDS} | cut -d ':' -f2)
      echo "username=${GIT_USERNAME}"
      echo "password=${GIT_ACCESS_CRED}"
    fi
  }; f'
  echo "configuring git credential helper - done"

  echo "Configuring credential.https://github.com/ozoneapi.helper - start"
  git config --global credential.https://github.com.useHttpPath true
  git config --global credential.https://github.com/ozoneapi.helper '!f() {
    sleep 1
    if [[ -z ${GITHUB_HTTPS_CREDS} ]]; then
      export TOKEN=$(curl --max-time 0.5 -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 2")
      export REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region -H "X-aws-ec2-metadata-token: $TOKEN")
      export GITHUB_HTTPS_CREDS=$(aws ssm get-parameter --name github.https.creds --region ${REGION} --with-decryption --query Parameter.Value --output text)
    fi
    if [[ -n $GITHUB_HTTPS_CREDS ]]; then
      local GIT_USERNAME=$(echo ${GITHUB_HTTPS_CREDS} | cut -d ':' -f1)
      local GIT_ACCESS_CRED=$(echo ${GITHUB_HTTPS_CREDS} | cut -d ':' -f2)
      echo "username=${GIT_USERNAME}"
      echo "password=${GIT_ACCESS_CRED}"
    fi
  }; f'
  echo "Configuring credential.https://github.com/ozoneapi.helper - done"

}

function ensure_ssm_user {
  USER=$(whoami)

  if [[ $USER != 'ssm-user' ]]; then
    >&2 echo "Not running as ssm-user. Cannot proceed."
    exit 1
  fi
}

function clone_repo {

  # ensure we have two params
  if [[ $# != 2 ]]; then
    >&2 echo "Usage: clone_repo <repo_url> <repo_branch>"
    exit 1
  fi

  local REPO_URL=${1}
  local REPO_BRANCH=${2}

  echo "Cloning repo ${REPO_URL} branch ${REPO_BRANCH}"

  OZONE_HOME="/usr/o3"

  # ensure OZONE_HOME exists
  if [[ ! -d ${OZONE_HOME} ]]; then
    >&2 echo "${OZONE_HOME} does not exist"
    exit 1
  fi


  BRANCH_OPTS="--branch=${GEPPETTO_BRANCH}"

  cd ${OZONE_HOME}

  git clone --quiet \
    --quiet \
    --branch ${REPO_BRANCH} \
    ${REPO_URL}

  if [[ $? != 0 ]]; then
    >&2 echo "Error while cloning repo."
    exit 1
  fi

}
