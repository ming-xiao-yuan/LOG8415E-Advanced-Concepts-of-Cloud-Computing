terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.19.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_ACCESS_KEY
  token      = var.AWS_SESSION_TOKEN
}

resource "aws_security_group" "security_group" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


data "aws_vpc" "default" {
  default = true
}

resource "aws_key_pair" "key_pair_name" {
  key_name   = var.key_pair_name
  public_key = file("key_pair_Test.pub")
}


resource "aws_instance" "orchestrator" {
  ami                    = "ami-03a6eaae9938c858c"
  instance_type          = "m4.large"
  key_name               = aws_key_pair.key_pair_name.key_name
  vpc_security_group_ids = [aws_security_group.security_group.id]
  availability_zone      = "us-east-1d"
  user_data              = file("./orchestrator_user_data.sh")
  tags = {
    Name = "Orchestrator"
  }
}

resource "aws_instance" "workers" {
  ami           = "ami-03a6eaae9938c858c"
  instance_type = "m4.large"
  root_block_device {
    volume_type = "gp2"
    volume_size = 100
  }
  key_name               = aws_key_pair.key_pair_name.key_name
  vpc_security_group_ids = [aws_security_group.security_group.id]
  availability_zone      = "us-east-1d"
  user_data              = file("./worker_user_data.sh")
  count                  = 4
  tags = {
    Name = "Worker-${count.index}"
  }
}

# Fetch details about worker instances
data "aws_instances" "worker_details" {
  instance_tags = {
    Role = "Worker"
  }
}
# Output the public dns of the Orchestrator
output "orchestrator_public_dns" {
  value = aws_instance.orchestrator.public_dns
}

# Output the public IPs of worker instances
output "worker_ips" {
  description = "The public IPs of worker instances"
  value       = aws_instance.workers[*].public_ip
}
