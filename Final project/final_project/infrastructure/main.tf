# Define the Terraform settings and required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWS provider source
      version = "~> 5.19.0"     # Version constraint for the AWS provider
    }
  }

  required_version = ">= 1.2.0" # Minimum Terraform version required
}

# Configure the AWS provider with credentials and region
provider "aws" {
  region     = "us-east-1"               # AWS region
  access_key = var.AWS_ACCESS_KEY        # AWS access key from variables
  secret_key = var.AWS_SECRET_ACCESS_KEY # AWS secret key from variables
  token      = var.AWS_SESSION_TOKEN     # AWS session token from variables (optional)
}

# Data source to fetch the default VPC information
data "aws_vpc" "default" {
  default = true
}

# Create an AWS key pair for SSH access
resource "aws_key_pair" "key_pair_name" {
  key_name   = var.key_pair_name
  public_key = file("my_terraform_key.pub")
}

# Security group for the Gatekeeper server
resource "aws_security_group" "gatekeeper_sg" {
  name        = "gatekeeper_security_group"
  description = "Allow web traffic to Gatekeeper"
  vpc_id      = data.aws_vpc.default.id # Associate with the default VPC

  # Ingress rule to allow all traffic
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # All protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Egress rule to allow all traffic and specify trusted hosts
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # All protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_groups  = [aws_security_group.trusted_host_sg.id]
  }
}

# Security group for a trusted host with specific inbound rules
resource "aws_security_group" "trusted_host_sg" {
  name        = "trusted_host_security_group"
  description = "Security group for Trusted Host"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule to allow SSH from a specific IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.31.49.42/32"] # Only accept SSH from Gatekeeper
  }

  # Ingress rule to allow HTTP from the same specific IP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.31.49.42/32"] # Only accept HTTP from Gatekeeper
  }

  # Egress rule to allow all outbound traffic and specify proxy security group
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_groups  = [aws_security_group.proxy_sg.id]
  }
}

# Security group for a proxy server with specific inbound rules
resource "aws_security_group" "proxy_sg" {
  name        = "proxy_security_group"
  description = "Security group for Proxy"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule to allow SSH from any IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rule to allow HTTP from any IP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule to allow all outbound traffic and specify MySQL security group
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_groups  = [aws_security_group.mysql_sg.id]
  }
}

# Security group for MySQL server with open inbound and outbound rules
resource "aws_security_group" "mysql_sg" {
  name        = "mysql_security_group"
  description = "Allow MySQL traffic"
  vpc_id      = data.aws_vpc.default.id

  # Ingress rule to allow all inbound traffic
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Egress rule to allow all outbound traffic
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Resource block for deploying MySQL server instance on AWS
resource "aws_instance" "mysql_server" {
  ami             = "ami-0fc5d935ebf8bc3bc" # AMI ID for the instance
  instance_type   = "t2.micro"              # Instance type
  key_name        = aws_key_pair.key_pair_name.key_name
  security_groups = [aws_security_group.mysql_sg.name]
  user_data       = file("./mysql_server_user_data.sh") # User data script for initial setup

  tags = {
    Name = "MySQL Server"
  }
}

resource "aws_instance" "mysql_cluster_manager" {
  ami             = "ami-0fc5d935ebf8bc3bc"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.key_pair_name.key_name
  security_groups = [aws_security_group.mysql_sg.name]
  user_data       = file("./mysql_manager_user_data.sh")

  provisioner "file" {
    source      = "../scripts/ip_addresses.sh"
    destination = "/tmp/ip_addresses.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./my_terraform_key")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "MySQL Cluster Manager"
  }
}

resource "aws_instance" "mysql_cluster_worker" {
  count           = 3
  ami             = "ami-0fc5d935ebf8bc3bc"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.key_pair_name.key_name
  security_groups = [aws_security_group.mysql_sg.name]
  user_data       = file("./mysql_worker_user_data.sh")

  provisioner "file" {
    source      = "../scripts/ip_addresses.sh"
    destination = "/tmp/ip_addresses.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./my_terraform_key")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "MySQL Cluster Worker ${count.index}"
  }
}

# Variable declaration for the private key path
variable "private_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default     = "./my_terraform_key"
}

resource "aws_instance" "mysql_proxy" {
  ami             = "ami-0fc5d935ebf8bc3bc"
  instance_type   = "t2.large"
  key_name        = aws_key_pair.key_pair_name.key_name
  security_groups = [aws_security_group.proxy_sg.name]
  user_data       = file("./mysql_proxy_user_data.sh")

  provisioner "file" {
    source      = "../scripts/ip_addresses.sh"
    destination = "/tmp/ip_addresses.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./my_terraform_key")
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "/home/ubuntu/my_terraform_key"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  tags = {
    Name = "MySQL Proxy Server"
  }
}

resource "aws_instance" "gatekeeper" {
  ami               = "ami-0fc5d935ebf8bc3bc"
  instance_type     = "t2.large"
  key_name          = aws_key_pair.key_pair_name.key_name
  security_groups   = [aws_security_group.gatekeeper_sg.name]
  user_data         = file("./mysql_gatekeeper_user_data.sh")
  private_ip        = "172.31.49.42"
  availability_zone = "us-east-1e"

  provisioner "file" {
    source      = "../scripts/ip_addresses.sh"
    destination = "/tmp/ip_addresses.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./my_terraform_key")
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "/home/ubuntu/my_terraform_key"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  tags = {
    Name = "Gatekeeper Server"
  }
}

resource "aws_instance" "trusted_host" {
  ami             = "ami-0fc5d935ebf8bc3bc"
  instance_type   = "t2.large"
  key_name        = aws_key_pair.key_pair_name.key_name
  security_groups = [aws_security_group.trusted_host_sg.name]
  user_data       = file("./mysql_trusted_host_user_data.sh")

  provisioner "file" {
    source      = "../scripts/ip_addresses.sh"
    destination = "/tmp/ip_addresses.sh"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("./my_terraform_key")
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = var.private_key_path
    destination = "/home/ubuntu/my_terraform_key"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }

  tags = {
    Name = "Trusted Host Server"
  }
}

# Output Public IP of MySQL Cluster Manager
output "mysql_cluster_manager_ip" {
  value = aws_instance.mysql_cluster_manager.public_ip
}

# Output Public IPs of MySQL Cluster Workers
output "mysql_cluster_worker_ips" {
  value = [for instance in aws_instance.mysql_cluster_worker : instance.public_ip]
}

# Output Public IP of MySQL Proxy Server
output "mysql_proxy_server_ip" {
  value = aws_instance.mysql_proxy.public_ip
}

# Output Public IP of Gatekeeper Server
output "gatekeeper_server_ip" {
  value = aws_instance.gatekeeper.public_ip
}

# Output Public IP of Trusted Host Server
output "trusted_host_server_ip" {
  value = aws_instance.trusted_host.public_ip
}

