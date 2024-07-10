output "vpc_id" {
  value = module.mgh-vpc.vpc_id
}
output "public_subnet_ids" {
  value = module.mgh-vpc.public_subnets
}