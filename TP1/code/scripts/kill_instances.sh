#!/bin/bash

# Access the env variables
source env_vars.sh

echo -e "Destroying all instances...\n"

cd ../infrastructure

# Kills the infrastructure
terraform.exe destroy -auto-approve -var="aws_access_key_id=$AWS_ACCESS_KEY" -var="aws_secret_access_key=$AWS_SECRET_ACCESS_KEY" -var="aws_session_token=$AWS_SESSION_TOKEN"

echo -e "Everything was deleted successfully\n"
echo -e "-----------\n"
