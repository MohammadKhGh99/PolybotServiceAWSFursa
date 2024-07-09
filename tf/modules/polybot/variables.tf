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
  default     = ["us-east-1a"]  # Default to an AZ, but can be overridden
}

variable "subnets" {
  description = "The subnets"
  type        = list(string)
#   default     = ["us-east-1a"]
}

variable "env" {
  description = "Deployment environment"
  type        = string
}