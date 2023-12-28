#!/bin/bash

# Set environment variables for non-interactive frontend and PATH
export DEBIAN_FRONTEND=noninteractive

{
    # Update package listings and upgrade the system
    sudo apt update -y
    sudo apt upgrade -y

    # Install necessary dependencies (Docker)
    sudo apt install -y docker.io

    # Start Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Source the IP addresses
    source /tmp/ip_addresses.sh

    # Pull the latest proxy image from Docker Hub
    echo "Starting Docker image pull at $(date)"
    sudo docker pull mingxiaoyuan/proxy:latest
    echo "Docker image pull completed at $(date)"

    # Changes file permission to the owner
    chmod 600 /home/ubuntu/my_terraform_key

    WORKER_DNS_STRING=$(IFS=,; echo "${WORKER_DNS[*]}")

    # Run the Flask app inside a Docker container
    sudo docker run -e MANAGER_DNS="$MANAGER_DNS" -e WORKER_DNS="$WORKER_DNS_STRING" -p 80:5000 -v /home/ubuntu/my_terraform_key:/etc/proxy/my_terraform_key mingxiaoyuan/proxy:latest

} >> /var/log/progress.log 2>&1
