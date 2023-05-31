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