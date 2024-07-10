terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0"
    }
  }

  backend "s3" {
    bucket = "mgh-my-bucket"
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

  azs = data.aws_availability_zones.available_azs.names
  # TODO - subnets
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  # TODO - Route tables

  enable_nat_gateway = false

}

# availability zones
data "aws_availability_zones" "available_azs" {
  state = "available"
}

# ami
data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical owner ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Load Balancer
module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "mgh-polybot-yolo-alb"
  vpc_id  = module.mgh-vpc.vpc_id
  subnets = var.public_subnets

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    telegram_https1 = {
      from_port   = 8443
      to_port     = 8443
      ip_protocol = "tcp"
      description = "Allow traffic from telegram on port 8443 from 149.154.160.0/20"
      cidr_ipv4   = "149.154.160.0/20"
    }
    telegram_https1 = {
      from_port   = 8443
      to_port     = 8443
      ip_protocol = "tcp"
      description = "Allow traffic from telegram on port 8443 from 91.108.4.0/22"
      cidr_ipv4   = "91.108.4.0/22"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }

  listeners = {
    ex-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "mgh-polybot-tg"
        target_group_arn = module.alb.target_groups["ex-instance"].arn
        type            = "forward"
      }
    }
    ex-https = {
      port            = 8443
      protocol        = "HTTPS"
      certificate_arn = "arn:aws:acm:us-east-1:700935310038:certificate/8f548d7b-74da-4b0a-b515-17a7b8bc5944"
      forward = {
        target_group_key = "mgh-polybot-tg"
        target_group_arn = module.alb.target_groups["ex-instance"].arn
        type            = "forward"
      }
    }
  }

  target_groups = {
    ex-instance = {
      target_id = module.mgh-polybot.instance_ids[0]
      name = "mgh-polybot-tg"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
    }
  }
}

resource "aws_lb_target_group_attachment" "target-group-attach-0" {
  target_group_arn = module.alb.target_groups["ex-instance"].arn
  target_id        = module.mgh-polybot.instance_ids[0]
  port             = 80
}

resource "aws_lb_target_group_attachment" "target-group-attach-1" {
  target_group_arn = module.alb.target_groups["ex-instance"].arn
  target_id        = module.mgh-polybot.instance_ids[1]
  port             = 80
}

# resource "aws_lb" "mgh-polybot-yolo-alb" {
#   name               = "mgh-polybot-yolo-alb"
#   internal           = false
#   vpc_id             = module.mgh-vpc.vpc_id
#   # TODO - availability zones
#   # TODO - ip address type
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.mgh-polybot-yolo-alb-sg.id]
#   subnets            = module.mgh-vpc.public_subnets
# }
#
# resource "aws_security_group" "mgh-polybot-yolo-alb-sg" {
#     vpc_id = module.mgh-vpc.vpc_id
#
#     ingress {
#       description = "Allow traffic from telegram on port 8443 from 149.154.160.0/20"
#       from_port = 8443
#       to_port = 8443
#       protocol = "tcp"
#       cidr_blocks = ["149.154.160.0/20"]
#     }
#
#     ingress {
#       description = "Allow traffic from telegram on port 8443 from 91.108.4.0/22"
#       from_port = 8443
#       to_port = 8443
#       protocol = "tcp"
#       cidr_blocks = ["91.108.4.0/22"]
#     }
#
#     ingress {
#       description = "Allow traffic from outside using HTTP on port 80 (yolo making POST request)"
#       from_port = 80
#       to_port = 80
#       protocol = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#
#     egress {
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
# }

# https:8443 listener for load balancer

# S3 Bucket
resource "aws_s3_bucket" "mgh-tf-bucket" {
  bucket = "mgh-tf-bucket"
}

module "mgh-polybot" {
  source = "./modules/polybot"

  vpc_id = module.mgh-vpc.vpc_id
  availability_zones = data.aws_availability_zones.available_azs.names
  ami_id = data.aws_ami.ubuntu_ami.id
  env = var.env
  instance_region = var.region
  public_subnets = var.public_subnets
}

resource "aws_sqs_queue" "mgh-sqs-q" {
  name = "mgh-sqs-q"
}

resource "aws_dynamodb_table" "mgh-dynamo-db" {
  name = "mgh-objects-detection-db"
  hash_key = "prediction_id"
  read_capacity = 1
  write_capacity = 1

  attribute {
    name = "prediction_id"
    type = "S"
  }
}

# resource "aws_secretsmanager_secret" "mgh-secrets-manager" {
#   name = "mgh-secrets-manager"
#
# }