output "instance_ids" {
  description = "The IDs of the EC2 instances"
  value       = aws_instance.mgh-polybot-tf-instance[*].id
}

output "public_ips" {
  description = "The public IPs of the EC2 instances"
  value       = aws_instance.mgh-polybot-tf-instance[*].public_ip
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.mgh-polybot-tf-sg.id
}

output "polybot-ami" {
  description = "ID of the EC2 instance AMI"
  value       = var.ami_id
}

# output "s3_bucket_id" {
#   description = "The ID of the S3 bucket"
#   value       = aws_s3_bucket.mgh-bucket.id
# }

# output "vpc_id" {
#   description = "The ID of the VPC"
#   value       = module.mgh-vpc.vpc_id
# }

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = var.public_subnets
}
#
# output "private_subnet_ids" {
#   description = "The IDs of the private subnets"
#   value       = module.mgh-vpc.private_subnets
# }

output "availability_zones" {
  description = "The availability zone"
  value       = var.availability_zones
}

# output "region" {
#   description = "The region"
#   value       = var.instance_region
# }

output "env" {
  description = "The environment"
  value       = var.env
}

output "ami_id" {
  description = "The AMI ID"
  value       = var.ami_id
}

output "instance_count" {
  description = "The number of instances"
  value       = var.instance_count
}

output "instance_type" {
  description = "The instance type"
  value       = var.instance_type
}

output "instance_region" {
  description = "The instance region"
  value       = var.instance_region
}

output "sqs_queue_url" {
  description = "The SQS queue URL"
  value = var.sqs_queue_url
}

output "bucket_name" {
  description = "The S3 bucket name"
  value = var.bucket_name
}

output "dynamo_db_table" {
  description = "The DynamoDB table name"
  value = var.dynamo_db_table
}

output "TF_VAR_botToken" {
  description = "The bot token"
  value = var.TF_VAR_botToken
}