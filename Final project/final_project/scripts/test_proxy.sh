#!/bin/bash

# Access the ip addresses
source ip_addresses.sh

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

  echo "Waiting 2 minutes before starting the health check..."
  sleep 120 # Wait for 2 minutes before starting the health check

  echo "Waiting for $service_name service at $url to start..."

  while true; do
      http_status=$(check_service $url)

      echo "Checking $service_name service... HTTP status: $http_status"

      if [ "$http_status" -eq 200 ]; then
          echo "$service_name service is now available."
          break
      fi

      if [ $SECONDS -ge $TIMEOUT ]; then
          echo "Timeout reached, $service_name service at $url is not available."
          return 1
      fi

      echo "Service not ready yet. Waiting for 10 seconds before retrying..."
      sleep 10 # Wait for 10 seconds before trying again
  done

  echo "Completed waiting for $service_name service."
}

# Check Proxy service
poll_service "http://$GATEKEEPER_DNS/health_check" "Proxy"

echo "Gatekeeper is ready. Waiting 4 minutes before launching request.py..."
sleep 240 # Wait for an additional 4 minutes

# Export the PROXY_DNS environment variable
export GATEKEEPER_DNS=$GATEKEEPER_DNS
echo "GATEKEEPER_DNS is set to: $GATEKEEPER_DNS"

echo "Executing request.py..."
python ../requests/send_requests.py
