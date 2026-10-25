# Guard: refuse to deploy from the "default" (or any unknown) workspace
resource "terraform_data" "workspace_guard" {
  lifecycle {
    precondition {
      condition     = contains(local.allowed_workspaces, terraform.workspace)
      error_message = "Workspace '${terraform.workspace}' is not allowed. Use one of: ${join(", ", local.allowed_workspaces)}."
    }
  }
}

# Latest Ubuntu 22.04 LTS AMI (Canonical) in the selected region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vpc" {
  source = "./modules/vpc"

  cidr               = var.vpc_cidr
  public_subnet_cidr = var.subnet_cidr
  environment        = local.environment
  project_name       = var.project_name

  depends_on = [terraform_data.workspace_guard]
}

module "security_group" {
  source = "./modules/security-group"

  vpc_id        = module.vpc.vpc_id
  ingress_ports = var.ingress_ports
  environment   = local.environment
  project_name  = var.project_name
}

module "ec2_instance" {
  source = "./modules/ec2-instance"

  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.subnet_id
  security_group_ids = module.security_group.sg_id

  environment  = local.environment
  project_name = var.project_name
  instance_count = var.instance_count
}
