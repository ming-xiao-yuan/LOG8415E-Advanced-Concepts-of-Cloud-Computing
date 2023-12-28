#!/bin/bash

# Access the env variables
source env_vars.sh

# Pulling requests_app's image
docker pull ikrash3d/requests_app:latest

echo -e "\nSending requests...\n"

# Running the requests_app's container
docker run -e load_balancer_url="$load_balancer_url" -d --name requests_app_latest ikrash3d/requests_app:latest

## Showing the requests_app's prints
docker logs -f requests_app_latest

# Removing the requests_app's container
echo -e "Removing the docker container...\n"
docker rm requests_app_latest