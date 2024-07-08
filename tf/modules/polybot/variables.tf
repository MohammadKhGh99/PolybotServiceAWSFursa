variable "ami" {
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