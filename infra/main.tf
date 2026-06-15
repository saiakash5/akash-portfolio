# Root configuration — full serverless.
#   Frontend:  S3 + CloudFront            (frontend.tf)
#   Content:   DynamoDB + Lambda + API GW (content.tf)
#   Contact:   Lambda → DynamoDB + SNS    (content.tf + notifications.tf)
#   Auth:      Cognito                    (content.tf)
#   Edge:      WAF + ACM + Route 53       (waf.tf, certs.tf, frontend.tf)
# No ECS / ALB / VPC — nothing to keep awake, contact form runs 24/7.
#
#   terraform init && terraform apply

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    # Retained only so Terraform can destroy the old origin-verify secret;
    # remove after the next apply.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket       = "akash-portfolio-tfstate-871716941934"
    key          = "akash-portfolio/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.primary_region
}

variable "project" { default = "akash-portfolio" }
variable "primary_region" { default = "us-east-1" }
variable "domain_name" { default = "thesaiakash.com" }

data "aws_caller_identity" "current" {}

# ---------- Contact messages table (single region) ----------

resource "aws_dynamodb_table" "messages" {
  name         = "${var.project}-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  # Streams stay enabled: DynamoDB forbids disabling streams in the same
  # operation that removes the global-table replica. Harmless (nothing reads
  # the stream) and avoids a multi-step migration.
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

output "dynamodb_table" { value = aws_dynamodb_table.messages.name }
