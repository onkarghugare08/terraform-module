# Terraform Multi-Environment Infrastructure on AWS

Provision separate **development**, **staging**, and **production** environments on AWS using Terraform workspaces and reusable modules.

This repository creates an environment-specific VPC, public subnet, internet gateway, route table, security group, and EC2 instance(s). Workspace-specific values are stored in `dev.tfvars`, `staging.tfvars`, and `prod.tfvars`.

> **Important:** Review the setup notes below before running `terraform apply`. In particular, create the required SSH public key, fix the shared EC2 key-pair name before deploying more than one environment in the same AWS region, and restrict inbound SSH access.

## Architecture

```text
Terraform workspace
(dev / staging / prod)
          |
          v
    Environment .tfvars
          |
          v
       main.tf
          |
          +--------------------+
          |          |         |
          v          v         v
       VPC module  Security   EC2 module
       - VPC       group      - SSH key pair
       - Subnet    module     - EC2 instances
       - IGW       - TCP      - Ubuntu 22.04 AMI
       - Route       ingress
         table
```

## Repository structure

```text
terraform-multi-environment/
├── main.tf
├── providers.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── dev.tfvars
├── staging.tfvars
├── prod.tfvars
└── modules/
    ├── vpc/
    ├── security-group/
    └── ec2-instance/
```

## Technologies

- Terraform `>= 1.5.0`
- AWS provider `~> 6.0`
- AWS VPC, subnet, internet gateway, route table, security group, and EC2
- Terraform workspaces for environment-specific state
- Terraform modules for reusable infrastructure

## Environment configuration

| Setting | Development | Staging | Production |
|---|---|---|---|
| Workspace | `dev` | `staging` | `prod` |
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| Public subnet CIDR | `10.0.1.0/24` | `10.1.1.0/24` | `10.2.1.0/24` |
| EC2 instance type | `t3.micro` | `t3.small` | `t3.small` |
| EC2 instance count | 2 | 3 | 3 |
| Inbound TCP ports | 22, 80 | 22, 80, 443 | 80, 443 |

Deploying all three environments creates **8 EC2 instances in total**, in addition to their networking and security resources. AWS charges may apply.

## Prerequisites

Install and configure the following before deploying:

1. [Terraform](https://developer.hashicorp.com/terraform/install) version 1.5 or later.
2. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
3. AWS credentials with permission to create and manage the required VPC, networking, security-group, key-pair, and EC2 resources.
4. OpenSSH `ssh-keygen` to create the key pair used by the EC2 module.

The repository defaults to AWS region **`us-west-2`**. The AWS provider uses the `aws_region` variable in `variables.tf`.

Check your tools and AWS identity:

```bash
terraform -version
aws --version
aws configure
aws sts get-caller-identity
```

`aws configure` prompts for your AWS access key, secret key, default region, and output format. Use credentials appropriate for your account; do not put credentials in Terraform files or commit them to Git.

## Before the first deployment

### 1. Protect the private SSH key

The EC2 module expects this public-key file to exist:

```text
modules/ec2-instance/terra-key.pub
```

Before creating the key, add the private key path to the repository's `.gitignore`:

```gitignore
# Private SSH key used by the EC2 Terraform module
modules/ec2-instance/terra-key
*.pem
```

Then, from the repository root, generate the key pair:

```bash
ssh-keygen -t rsa -b 4096 -f modules/ec2-instance/terra-key
```

When prompted for a passphrase, follow your team's key-management policy. This command creates `terra-key` (private key) and `terra-key.pub` (public key). **Never commit or share the private key.**

### 2. Make the EC2 key-pair name unique per environment

The current `modules/ec2-instance/main.tf` uses the fixed AWS key-pair name `terra-key`. AWS key-pair names must be unique within a region, so creating `dev`, `staging`, and `prod` in the same region can fail when a later workspace tries to create the same key-pair name.

Before deploying multiple environments, change the key-pair resource to use the environment name:

```hcl
resource "aws_key_pair" "my_key_pair" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = file("${path.module}/terra-key.pub")
}
```

This uses the same local public-key file but creates a distinct AWS key-pair name for each environment.

### 3. Restrict inbound access

The security-group module's `allowed_cidr` variable defaults to `0.0.0.0/0`. In the current configuration, development and staging allow inbound TCP port 22, which can expose SSH to the entire internet. For safer use, change the allowed CIDR to your trusted public IP in `/32` format, or add a root input and pass it into the security-group module. Keep only the ports each environment actually needs.

## Initialize and validate Terraform

Run these commands from the repository root:

```bash
terraform init
terraform fmt -recursive
terraform validate
```

The repository currently uses Terraform's **local backend**. The S3 backend block in `providers.tf` is commented out, so state is not being stored remotely by this configuration.

## Create the workspaces

The configuration intentionally blocks plans and applies from Terraform's `default` or any unrecognized workspace. Create the three allowed workspaces once:

```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

If a workspace already exists, do not create it again; select it instead. List and select workspaces with:

```bash
terraform workspace list
terraform workspace select dev
```

Each workspace has its own Terraform state. The matching `.tfvars` file must also be supplied explicitly when planning, applying, or destroying resources.

## Deploy an environment

### Development

```bash
terraform workspace select dev
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### Staging

```bash
terraform workspace select staging
terraform plan -var-file="staging.tfvars"
terraform apply -var-file="staging.tfvars"
```

### Production

```bash
terraform workspace select prod
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

Review the plan carefully before approving the apply prompt. Deploy only the environments you need; production-sized resources may cost more than development resources.

## Verify deployed resources

After applying an environment, confirm the active workspace and inspect the outputs:

```bash
terraform workspace show
terraform output
terraform output instance_id
terraform output instance_public_ip
terraform state list
```

The instance ID and public IP outputs are lists because an environment may create multiple EC2 instances. To get JSON output for scripts:

```bash
terraform output -json instance_public_ip
```

The EC2 instances use an Ubuntu 22.04 AMI. After selecting `dev` or `staging`, you can connect with SSH using one of the public IPs shown by Terraform:

```bash
ssh -i modules/ec2-instance/terra-key ubuntu@<PUBLIC_IP>
```

Replace `<PUBLIC_IP>` with an actual address. SSH will work only if your security-group ingress rule permits your client IP. The current Terraform configuration creates the infrastructure; it does **not** install a web server or deploy an application.

## Destroy resources and avoid ongoing charges

Destroy each environment separately. Select the workspace first and pass the matching variable file:

```bash
terraform workspace select dev
terraform destroy -var-file="dev.tfvars"

terraform workspace select staging
terraform destroy -var-file="staging.tfvars"

terraform workspace select prod
terraform destroy -var-file="prod.tfvars"
```

Check the selected workspace before each destroy. Terraform workspaces maintain separate state, so destroying one workspace does not destroy resources managed in another workspace.

## Troubleshooting

- **Workspace guard error:** Run `terraform workspace show` and select `dev`, `staging`, or `prod` before planning or applying.
- **Public key file error:** Confirm `modules/ec2-instance/terra-key.pub` exists and that the command was run from the repository root.
- **Key pair already exists:** Ensure the environment-specific key-name change in the setup section has been applied, or carefully reconcile the existing AWS key pair before proceeding.
- **AWS authentication or access denied:** Run `aws sts get-caller-identity` and verify that the configured principal has the necessary permissions.
- **CIDR overlap or subnet errors:** Check that the environment is using its matching `.tfvars` file and that the VPC and subnet CIDRs do not overlap with existing networks where that would cause a conflict.

## Upload this README to GitHub

After saving this file as `README.md` in the repository root, review the changes and push them to your repository:

```bash
git add README.md .gitignore
git commit -m "docs: add Terraform project README"
git push origin main
```

---

**Learning outcomes:** Terraform modules, workspace-based environment separation, environment-specific variable files, AWS networking, EC2 provisioning, outputs, Terraform validation, and resource cleanup.
