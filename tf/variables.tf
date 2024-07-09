variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
   description = "AWS region"
   type        = string
}

variable "subnets" {
  description = "The subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "The availability zone to deploy the resources"
  type        = list(string)
}