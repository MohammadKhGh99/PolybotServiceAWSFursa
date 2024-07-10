variable "ami_id" {
  description = "EC2 Ubuntu AMI"
  type        = string
}

variable "instance_count" {
    description = "Number of EC2 instances to deploy"
    type        = number
    default     = 2
}

variable "instance_type" {
    description = "EC2 instance type"
    type        = string
    default     = "t2.micro"
}

variable "instance_region" {
  description = "The region to deploy the EC2 instances"
  type        = string
}

variable "availability_zones" {
  description = "The availability zone to deploy the resources"
  type        = list(string)
}

variable "public_subnets" {
  description = "The subnets"
  type        = list(string)
#   default     = ["us-east-1a"]
}

variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "sqs_queue_url" {
  description = "The SQS queue URL"
  type        = string
}

variable "bucket_name" {
  description = "The S3 bucket name"
  type        = string
}

variable "dynamo_db_table" {
  description = "The DynamoDB table name"
  type        = string
}

variable "TF_VAR_botToken" {
  description = "The bot token"
  type        = string
}