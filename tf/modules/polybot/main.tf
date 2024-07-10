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
  region = var.instance_region
}

resource "aws_instance" "mgh-polybot-tf-instance" {
  count           = var.instance_count
  instance_type   = var.instance_type
  security_groups = [aws_security_group.mgh-polybot-tf-sg.id]
  iam_instance_profile = aws_iam_instance_profile.mgh-polybot-role-profile1.name
  availability_zone = element(var.availability_zones, count.index)
  subnet_id = element(var.public_subnets, count.index)
  ami = var.ami_id

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install ca-certificates curl -y
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              chmod a+r /etc/apt/keyrings/docker.asc

              # Add the repository to Apt sources:
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update

              # Install docker
              apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

              sudo usermod -aG docker ubuntu
              systemctl enable docker
              systemctl start docker
              docker run -d -p 8443:8443 --name polybot --restart always -e TELEGRAM_APP_URL=https://alb.mohammadgh.click:8443 -e BUCKET_NAME=mgh-tf-bucket mohammadgh99/polybot:v0.0.8
              EOF

  tags = {
    Name = "mgh-instance-${count.index + 1}",
    Environment = var.env
  }
}

resource "aws_iam_role" "mgh-polybot-role" {
  name = "mgh-polybot-ec2-role"
  description = "Allows EC2 instances to call S3, DynamoDB, SQS, and SecretManager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.mgh-polybot-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "dynamodb_full_access" {
  role       = aws_iam_role.mgh-polybot-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "secrets_manager_full_access" {
  role       = aws_iam_role.mgh-polybot-role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "sqs_full_access" {
  role       = aws_iam_role.mgh-polybot-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_instance_profile" "mgh-polybot-role-profile1" {
  name = "mgh-polybot-role-profile1"
  role = aws_iam_role.mgh-polybot-role.name
}

resource "aws_security_group" "mgh-polybot-tf-sg" {
  name        = "mgh-polybot-tf-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id = var.vpc_id

  # ssh
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = []
  }

  # HTTPS
  ingress {
    from_port = 8443
    to_port   = 8443
    protocol  = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



