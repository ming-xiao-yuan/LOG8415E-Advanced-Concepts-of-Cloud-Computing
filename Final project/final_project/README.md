# Scaling Database and Cloud Design Pattern

This project demonstrates a scalable database system and cloud design patterns, utilizing AWS services, Terraform for infrastructure automation, and Python for application logic.

## Prerequisites

Before running the application, ensure Python and Terraform are installed on your local machine.

### Installation on Windows

- **Python**: Download and install Python from [python.org](https://www.python.org/downloads/windows/). Follow the website's installation instructions.
  
- **Terraform**: Download Terraform from [terraform.io](https://www.terraform.io/downloads.html). Unzip the package and add the executable to your system's PATH.

### Installation on Linux

- **Python**:
  ```bash
  sudo apt-get install python3.8
  ```

- **Terraform**:
  ```bash
  sudo apt-get install terraform
  ```

## Environment Setup

Set up the Proxy, Gatekeeper, and Trusted Host by installing dependencies from the `requirements.txt` in each component's directory:

```bash
pip install -r requirements.txt
```

## Deployment

1. Navigate to the `scripts` folder in your project directory.
2. Execute the deployment script with the following command:
   ```bash
   bash run.sh
   ```
3. You will be prompted to enter your AWS credentials - AWS access key, AWS secret access key, and AWS session token. These credentials can be obtained from your AWS EC2 console.

The `run.sh` script will automate the deployment process, setting up the necessary infrastructure on AWS. This includes creating EC2 instances for the Gatekeeper, Trusted Host, Proxy, MySQL Cluster Manager, and the MySQL Cluster Worker nodes.

## Usage

After the deployment is complete, the `send_request.py` script will be executed automatically. This script will send 20 write requests to the `direct_table`, `random_table`, and `customized_table`. It will also send 20 read requests for each type of hit (direct, random, and customized). This process is crucial for demonstrating the application's capability to handle and route various types of requests through the system.

## Monitoring and Verification

To ensure the system is functioning as intended, you can manually log into the Gatekeeper, Trusted Host, and Proxy instances through the AWS EC2 console. This step allows you to verify the successful processing and routing of the requests across the different components of the system.

## Conclusion

This project serves as a practical example of implementing a scalable database system and cloud design patterns. It showcases the integration of AWS services, Terraform for infrastructure automation, and Python for application logic, demonstrating efficient handling of database requests in a cloud environment.