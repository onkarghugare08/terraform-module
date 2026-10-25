variable "vpc_id" {
  description = "VPC to create the security group in"
  type        = string
}

variable "ingress_ports" {
  description = "TCP ports to allow inbound"
  type        = list(number)
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach ingress ports"
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}
