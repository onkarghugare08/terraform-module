terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local backend: each workspace stores state in terraform.tfstate.d/<workspace>/
  # For a remote backend, uncomment (bucket + lock table must exist first).
  # With S3, state key becomes: env:/<workspace>/terraweek/terraform.tfstate
  #
  # backend "s3" {
  #   bucket         = "onkar_bucket_terraform"
  #   key            = "terraweek/terraform.tfstate"
  #   region         = "us-west-2"
  #   dynamodb_table = "terraweek-state-lock"
  #   encrypt        = true
  #   use_lockefile   = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
