#!/bin/bash
# Build the Docker image
docker build -f ../gatekeeper/Dockerfile -t gatekeeper ../gatekeeper

# Tag the Docker image
docker tag gatekeeper mingxiaoyuan/gatekeeper:latest

# Push the Docker image to the repository
docker push mingxiaoyuan/gatekeeper:latest