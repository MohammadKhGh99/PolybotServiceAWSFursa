terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0"
    }
  }

  backend "s3" {
    bucket = "mgh-state-bucket"
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

  azs = var.availability_zones
  public_subnets = var.public_subnets

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

# subnet 1
# resource "aws_subnet" "mgh-subnet-1" {
#   vpc_id     = module.mgh-vpc.vpc_id
#   cidr_block = var.subnets[0]
#   availability_zone = var.availability_zones[0]
#
#   tags = {
#     Name = "mgh-subnet-1"
#   }
# }
#
# # subnet 1
# resource "aws_subnet" "mgh-subnet-2" {
#   vpc_id     = module.mgh-vpc.vpc_id
#   cidr_block = var.subnets[1]
#   availability_zone = var.availability_zones[1]
#
#   tags = {
#     Name = "mgh-subnet-2"
#   }
# }

# Load Balancer
resource "aws_lb" "mgh-polybot-yolo-alb" {
  name               = "mgh-polybot-yolo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mgh-polybot-yolo-alb-sg.id]
  subnets            = module.mgh-vpc.public_subnets
  tags = {
    Name = "mgh-polybot-yolo-alb"
  }
}

resource "aws_security_group" "mgh-polybot-yolo-alb-sg" {
  vpc_id = module.mgh-vpc.vpc_id

  ingress {
    description = "Allow traffic from telegram on port 8443 from 149.154.160.0/20"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["149.154.160.0/20", "91.108.4.0/22"]
  }

  ingress {
    description = "Allow traffic from outside using HTTP on port 80 (yolo making POST request)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

resource "aws_alb_listener" "mgh-alb-http-listener" {
  load_balancer_arn = aws_lb.mgh-polybot-yolo-alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.mgh-polybot-alb-tg.arn
  }
}

resource "aws_alb_listener" "mgh-alb-https-listener" {
  load_balancer_arn = aws_lb.mgh-polybot-yolo-alb.arn
  port              = 8443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "arn:aws:acm:us-east-1:700935310038:certificate/8f548d7b-74da-4b0a-b515-17a7b8bc5944"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.mgh-polybot-alb-tg.arn
  }
}

resource "aws_alb_target_group" "mgh-polybot-alb-tg" {
  name        = "mgh-polybot-alb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.mgh-vpc.vpc_id
}

# resource "aws_lb_target_group_attachment" "target-group-attach-0" {
#   target_group_arn = aws_alb_target_group.mgh-polybot-alb-tg.arn
#   target_id        = module.mgh-polybot.instance_ids[0]
#   port             = 80
# }
#
# resource "aws_lb_target_group_attachment" "target-group-attach-1" {
#   target_group_arn = aws_alb_target_group.mgh-polybot-alb-tg.arn
#   target_id        = module.mgh-polybot.instance_ids[1]
#   port             = 80
# }

# S3 Bucket
resource "aws_s3_bucket" "mgh-my-bucket" {
  bucket = "mgh-my-bucket"
}

module "mgh-polybot" {
  source = "./modules/polybot"

  vpc_id = module.mgh-vpc.vpc_id
  availability_zones = module.mgh-vpc.azs
  ami_id = data.aws_ami.ubuntu_ami.id
  env = var.env
  instance_region = var.region
  public_subnets = module.mgh-vpc.public_subnets
  sqs_queue_url = aws_sqs_queue.mgh-sqs-q.id
  bucket_name = aws_s3_bucket.mgh-my-bucket.bucket
  dynamo_db_table = aws_dynamodb_table.mgh-dynamo-db.name
  TF_VAR_botToken = var.TF_VAR_botToken
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

# resource "aws_secretsmanager_secret" "mgh-secret-manager" {
#   name = "mgh-secret-manager"
#
# }

# resource "aws_secretsmanager_secret" "bot_token" {
#   name = "mgh-secret-manager"
# }
#
# resource "aws_secretsmanager_secret_version" "mgh-secret-manager" {
#   secret_id     = aws_secretsmanager_secret.mgh-secret-manager.id
#   secret_string = jsonencode({
#     "TELEGRAM_TOKEN" = var.TF_VAR_botToken
#   })
# }