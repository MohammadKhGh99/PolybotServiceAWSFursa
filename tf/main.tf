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
resource "aws_vpc" "mgh-polybot-vpc" {
  cidr_block = "10.0.0.0/16"
}

# Load Balancer
resource "aws_lb" "mgh-polybot-yolo-alb" {
  name               = "mgh-polybot-yolo-alb"
  internal           = false
  # TODO - availability zones
  # TODO - ip address type
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mgh-polybot-yolo-alb.id]
  subnets            = [aws_subnet.mgh-polybot-subnet1.id, aws_subnet.mgh-polybot-subnet2.id]
}

# https:8443 listener for load balancer
