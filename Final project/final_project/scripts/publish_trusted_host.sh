#!/bin/bash
# Build the Docker image
docker build -f ../trusted_host/Dockerfile -t trusted_host ../trusted_host

# Tag the Docker image
docker tag trusted_host mingxiaoyuan/trusted_host:latest

# Push the Docker image to the repository
docker push mingxiaoyuan/trusted_host:latest