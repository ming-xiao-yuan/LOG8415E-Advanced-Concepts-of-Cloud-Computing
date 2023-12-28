#!/bin/bash

# Access the env variables
source env_vars.sh

# cd ../infrastructure

# echo "Please provide your email for the SSH Key"
# read EMAIL

# ssh-keygen -t rsa -b 4096 -C $EMAIL -f my_terraform_key

cd ../scripts

#Getting AWS credentials from the terminal
echo "Please provide your AWS Access Key: "
read AWS_ACCESS_KEY

echo "Please provide your AWS Secret Access Key: "
read AWS_SECRET_ACCESS_KEY

echo "Please provide your AWS Session Token: "
read AWS_SESSION_TOKEN

# Exporting the credentials to be accessible in all the scripts
echo "export AWS_ACCESS_KEY='$AWS_ACCESS_KEY'" > env_vars.sh
echo "export AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY'" >> env_vars.sh
echo "export AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN'" >> env_vars.sh

echo -e "Starting final assignment ...\n"
echo -e "-----------\n"

# Deploying the infrastructure
echo -e "Deploying the infrastructure...\n"
./create_instances.sh

# Wait for 2 minutes
echo "Waiting for 2 minutes before testing the proxy..."
sleep 120

# Deploying the infrastructure
echo -e "Testing the proxy...\n"
./test_proxy.sh

echo -e "You successfully ended your final assignment."