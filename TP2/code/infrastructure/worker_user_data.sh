#!/bin/bash

# Install necessary dependencies
sudo yum update -y
sudo yum install -y docker

# Add ec2-user to the docker group so you can execute Docker commands without using sudo
sudo usermod -a -G docker ec2-user

# Start Docker
sudo service docker start

# Pull the latest worker image from Docker Hub
{
    echo "Starting Docker image pull at $(date)"
    sudo docker pull mingxiaoyuan/worker:latest
    echo "Docker image pull completed at $(date)"
} >> /var/log/docker_pull.log 2>&1

# In the docker container, expose the ec2 instance id
export INSTANCE_ID_EC2=$(ec2-metadata --instance-id)

# Run the first Flask app inside a Docker container mapped to host port 5000
sudo docker run -e INSTANCE_ID_EC2="$INSTANCE_ID_EC2" -d -p 5000:5000 mingxiaoyuan/worker:latest

# Run the second Flask app inside a Docker container mapped to host port 5001
sudo docker run -e INSTANCE_ID_EC2="$INSTANCE_ID_EC2" -d -p 5001:5000 mingxiaoyuan/worker:latest
