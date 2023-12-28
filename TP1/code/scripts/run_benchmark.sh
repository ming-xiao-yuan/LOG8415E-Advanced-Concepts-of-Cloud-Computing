#!/bin/bash

# Access the env variables
source env_vars.sh

# Extract the image of the benchmark app
docker pull ikrash3d/benchmark_app_tp1:latest

# Runs the benchmark app image
docker run -e AWS_ACCESS_KEY=$AWS_ACCESS_KEY -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN -d --name benchmark_app_tp1 ikrash3d/benchmark_app_tp1:latest

container_id_or_name="benchmark_app_tp1"

# Waits for the container to finish executing
while [ "$(docker inspect -f '{{.State.Running}}' $container_id_or_name)" == "true" ]; do
    sleep 1
done

# Copies the file from the container to ./benchmark/metrics
docker cp benchmark_app_tp1:/benchmark/metrics/ '../benchmark/'

# Deletes the container
docker rm benchmark_app_tp1

