#!/bin/bash

source /tmp/bootstrap/bootstrap-functions.sh
if [[ $? != 0 ]]; then
  >&2 echo "Error while loading bootstrap functions."
  exit 1
fi

# create SSM user
echo "Creating SSM user..."
create_ssm_user
echo "SSM user created."

# install and run
sudo -iu ssm-user /tmp/bootstrap/install-and-run/install-and-run-as-ssm-user.sh


