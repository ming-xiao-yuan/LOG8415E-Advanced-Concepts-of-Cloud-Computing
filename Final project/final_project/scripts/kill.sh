#!/bin/bash

# Access the env variables
source env_vars.sh

echo -e "Destroying all instances...\n"

cd ../infrastructure

# Kills the infrastructure
terraform.exe destroy -auto-approve -var="AWS_ACCESS_KEY=$AWS_ACCESS_KEY" -var="AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" -var="AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN"

# Clears the content of ip_addresses.sh
> ip_addresses.sh

cd ../scripts

# Clears the content of env_vars.sh
> env_vars.sh

echo -e "Everything was deleted successfully\n"
echo -e "-----------\n"
