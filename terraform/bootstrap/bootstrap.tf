terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Intentionally LOCAL state here — this config creates the bucket that
  # the *main* Terraform config will later use as its remote backend.
  # It can't manage its own backend bucket, so this one stays local
  # and is run once, rarely touched again.
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for all Project Bedrock resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally-unique name for the Terraform remote state bucket"
  type        = string
  default     = "project-bedrock-tfstate-alt-soe-tin-o25-0324"
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Safety net: prevents accidental deletion of this bucket via
  # `terraform destroy` on the bootstrap config later.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = "tinyuka-2025-capstone"
    Purpose = "terraform-remote-state"
    "key" = "terraform-remote-state"
    
  }
}

# Versioning lets you recover a previous state file if something
# corrupts or overwrites the current one.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest — Terraform state can contain sensitive values.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access — this bucket should never be reachable
# from outside your AWS account.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  description = "Name of the S3 bucket created for Terraform remote state"
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_region" {
  value = var.aws_region
}
