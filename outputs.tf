output "workspace" {
  description = "Active workspace / environment"
  value       = terraform.workspace
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnet_id" {
  value = module.vpc.subnet_id
}

output "security_group_id" {
  value = module.security_group.sg_id
}

output "instance_id" {
  value = module.ec2_instance.instance_id
}

output "instance_public_ip" {
  value = module.ec2_instance.public_ip
}

output "instance_type" {
  value = var.instance_type
}
