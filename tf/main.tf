terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0"
    }
  }

  backend "s3" {
    bucket = "mgh-tf-bucket"
    key    = "tfstate.json"
    region = "us-east-1"
  }

  required_version = ">= 1.7.0"
}

provider "aws" {
  region  = var.region
}

# VPC
module "mgh-vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "mgh-vpc"
  cidr = "10.0.0.0/16"

  # TODO - availability zones
  azs = ["us-east-1a", "us-east-1b"]
  # TODO - subnets
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  # TODO - Route tables

  enable_nat_gateway = false

}

resource "aws_vpc" "mgh-polybot-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Load Balancer
resource "aws_lb" "mgh-polybot-yolo-alb" {
  name               = "mgh-polybot-yolo-alb"
  internal           = false
  vpc_id             = aws_vpc.mgh-polybot-vpc.id
  # TODO - availability zones
  # TODO - ip address type
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mgh-polybot-yolo-alb-sg.id]
  subnets            = module.mgh-vpc.public_subnets
}

resource "aws_security_group" "mgh-polybot-yolo-alb-sg" {
    vpc_id = aws_vpc.mgh-polybot-vpc.id

    ingress {
      description = "Allow traffic from telegram on port 8443 from 149.154.160.0/20"
      from_port = 8443
      to_port = 8443
      protocol = "tcp"
      cidr_blocks = ["149.154.160.0/20"]
    }

    ingress {
      description = "Allow traffic from telegram on port 8443 from 91.108.4.0/22"
      from_port = 8443
      to_port = 8443
      protocol = "tcp"
      cidr_blocks = ["91.108.4.0/22"]
    }

    ingress {
      description = "Allow traffic from outside using HTTP on port 80 (yolo making POST request)"
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}

# https:8443 listener for load balancer

# S3 Bucket
resource "aws_s3_bucket" "mgh-tf-bucket" {
  bucket = "mgh-tf-bucket"
}