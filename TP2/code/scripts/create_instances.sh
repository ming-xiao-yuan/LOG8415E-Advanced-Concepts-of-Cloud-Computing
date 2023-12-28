#!/bin/bash

# Access the env variables
source env_vars.sh

# Initialize Terraform
echo -e "Creating instances...\n"
cd ../infrastructure

# Initialize Terraform
terraform.exe init

# Apply the Terraform configuration
terraform.exe apply -auto-approve -var="AWS_ACCESS_KEY=$AWS_ACCESS_KEY" -var="AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" -var="AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN"

# Capture the IP addresses in JSON format
WORKER_IPS_JSON=$(terraform.exe output -json worker_ips)

# Extract IPs from JSON
WORKER_IPS=$(echo $WORKER_IPS_JSON | grep -oP '(?<=")[\d.]+(?=")')

# Fetch the orchestrator public DNS
ORCHESTRATOR_DNS=$(terraform.exe output -raw orchestrator_public_dns)
echo "export ORCHESTRATOR_DNS='$ORCHESTRATOR_DNS'" >> ../scripts/env_vars.sh


# Function to check if a service is up and running
check_service() {
  local url=$1
  http_status_code=$(curl -m 5 -s -o /dev/null -w "%{http_code}" "$url")
  echo $http_status_code
}

# Function to poll a service until it's up or the timeout is reached
poll_service() {
  local url=$1
  local service_name=$2
  SECONDS=0
  TIMEOUT=300 # Set a 5-minute timeout

  echo "Waiting for $service_name service to start..."

  while true; do
      http_status=$(check_service $url)

      if [ "$http_status" -eq 200 ]; then
          echo "$service_name service is now available."
          break
      fi

      if [ $SECONDS -ge $TIMEOUT ]; then
          echo "Timeout reached, $service_name service is not available."
          return 1
      fi

      sleep 10 # Wait for 10 seconds before trying again
  done
  echo "" # Move to the next line after the loop
}

# Check Orchestrator
poll_service "http://$ORCHESTRATOR_DNS/health_check" "Orchestrator"

# Check each worker container
for ip in $WORKER_IPS; do
  poll_service "http://$ip:5000/health_check" "Worker Container 1 at $ip"
  poll_service "http://$ip:5001/health_check" "Worker Container 2 at $ip"
done

# Send the worker IPs to the orchestrator using HTTP POST request
curl -X POST "http://$ORCHESTRATOR_DNS/receive_ips_from_workers" \
    -H "Content-Type: application/json" \
    -d "$WORKER_IPS_JSON"

echo -e "\nWorker IPs sent to the orchestrator successfully."

echo -e "Everything was created successfully\n"
echo -e "-----------\n"
