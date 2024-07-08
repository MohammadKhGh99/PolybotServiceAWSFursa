terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0"
    }
  }

  required_version = ">= 1.7.0"
}

provider "aws" {
  region = var.region
}

resource "aws_instance" "mgh-polybot-tf-instance" {
  count           = var.instance_count
  ami             = var.ami
  instance_type   = var.instance_type
  security_groups = [aws_security_group.mgh-instance-sg.id]
  subnet_id       = module.mgh-vpc.public_subnets[0]  # element(module.mgh-vpc.subnet_ids, count.index)

  tags = {
    Name = "mgh-instance"
  }
}

resource "aws_security_group" "mgh-polybot-tf-sg" {
    name        = "mgh-polybot-tf-sg"
    description = "Allow SSH and HTTP inbound traffic"
    vpc_id      = module.mgh-vpc.vpc_id

    # ssh
    ingress {
      from_port = 22
      to_port   = 22
      protocol  = "tcp"
      cidr_blocks = []
    }
}

# TODO - IAM role for S3 bucket