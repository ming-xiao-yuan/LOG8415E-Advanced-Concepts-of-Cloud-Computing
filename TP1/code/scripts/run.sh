#!/bin/bash

# Access the env variables
source env_vars.sh

# Getting AWS credentials from the terminal
echo "Please provide your AWS Access Key: "
read AWS_ACCESS_KEY
echo

echo "Please provide your AWS Secret Access Key: "
read AWS_SECRET_ACCESS_KEY
echo

echo "Please provide your AWS Session Token: "
read AWS_SESSION_TOKEN
echo

# Exporting the credentials to be accessible in all the scripts
echo "export AWS_ACCESS_KEY='$AWS_ACCESS_KEY'" > env_vars.sh
echo "export AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY'" >> env_vars.sh
echo "export AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN'" >> env_vars.sh

echo -e "Starting Assignment 1...\n"
echo -e "-----------\n"

## Deploying the infrastructure
echo -e "Deploying the infrastructure...\n"
./create_instances.sh

## Sending the requests to the load balancer
./send_requests.sh

# Running the benchmark
echo -e "Running the benchmarks...\n"
./run_benchmark.sh

# Terminating the infrastructure
echo -e "Terminating infrastructure...\n"
./kill_instances.sh

# Clears the content of env_vars.sh
> env_vars.sh

echo -e "You successfully ended Assignment 1 :)"
