#!/bin/bash

# Access the environment variables
source env_vars.sh

# Change to the infrastructure directory
cd ../infrastructure

# Initialize and apply Terraform configuration
echo -e "Creating instances...\n"
terraform init
terraform apply -auto-approve -var="AWS_ACCESS_KEY=$AWS_ACCESS_KEY" -var="AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" -var="AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN" -var="private_key_path=../infrastructure/my_terraform_key"

# Ensure terraform apply completed successfully
if [ $? -ne 0 ]; then
    echo "Terraform apply failed. Exiting."
    exit 1
fi

# Capture the IP addresses
MANAGER_IP=$(terraform output -raw mysql_cluster_manager_ip)
WORKER_IPS=$(terraform output -json mysql_cluster_worker_ips | grep -oP '(?<=\[|\,)\s*"\K[^"]+')
PROXY_IP=$(terraform output -raw mysql_proxy_server_ip)
GATEKEEPER_IP=$(terraform output -raw gatekeeper_server_ip)
TRUSTED_HOST_IP=$(terraform output -raw trusted_host_server_ip)


# Export the IPs to a file
echo "MANAGER_IP=$MANAGER_IP" > ../scripts/ip_addresses.sh
echo "WORKER_IPS=(${WORKER_IPS[@]})" >> ../scripts/ip_addresses.sh
echo "PROXY_IP=$PROXY_IP" >> ../scripts/ip_addresses.sh
echo "GATEKEEPER_IP=$GATEKEEPER_IP" >> ../scripts/ip_addresses.sh
echo "TRUSTED_HOST_IP=$TRUSTED_HOST_IP" >> ../scripts/ip_addresses.sh



# Convert IP addresses and transfer the file to the Manager EC2 instance
cd ../scripts
echo -e "Converting IP addresses...\n"
./convert_ip_addresses.sh
scp -o StrictHostKeyChecking=no -i ../infrastructure/my_terraform_key ip_addresses.sh ubuntu@$MANAGER_IP:/tmp/ip_addresses.sh

# Transfer ip_addresses.sh to each Worker EC2 instance
for WORKER_IP in ${WORKER_IPS[@]}; do
    scp -o StrictHostKeyChecking=no -i ../infrastructure/my_terraform_key ip_addresses.sh ubuntu@$WORKER_IP:/tmp/ip_addresses.sh
done

# Transfer ip_addresses.sh to the Proxy EC2 instance
scp -o StrictHostKeyChecking=no -i ../infrastructure/my_terraform_key ip_addresses.sh ubuntu@$PROXY_IP:/tmp/ip_addresses.sh

# Transfer ip_addresses.sh to the Gatekeeper EC2 instance
scp -o StrictHostKeyChecking=no -i ../infrastructure/my_terraform_key ip_addresses.sh ubuntu@$GATEKEEPER_IP:/tmp/ip_addresses.sh

# Transfer ip_addresses.sh to the Trusted Host EC2 instance
scp -o StrictHostKeyChecking=no -i ../infrastructure/my_terraform_key ip_addresses.sh ubuntu@$TRUSTED_HOST_IP:/tmp/ip_addresses.sh
