# Root configuration: two regional stacks (active + dormant), global DynamoDB
# table, ECR repositories, and Route 53 failover DNS.
#
# Usage:
#   terraform init
#   terraform plan -out tf.plan
#   terraform apply tf.plan

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket       = "akash-portfolio-tfstate-871716941934"
    key          = "akash-portfolio/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # S3-native locking (Terraform 1.10+), no DynamoDB needed
  }
}

provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

variable "project" { default = "akash-portfolio" }
variable "primary_region" { default = "us-east-1" }
variable "secondary_region" { default = "us-west-2" }

variable "domain_name" { default = "thesaiakash.com" }

# false = deploy only the primary region (cuts idle cost roughly in half).
# Flip to true when you want the full active-dormant DR setup.
variable "enable_secondary" { default = true }

# Image tags are passed by CI after pushing to ECR.
variable "profile_image_tag" { default = "latest" }
variable "contact_image_tag" { default = "latest" }

# ---------- ECR (images replicate; one repo per service in primary) ----------

resource "aws_ecr_repository" "profile" {
  name = "${var.project}/profile-service"
  force_delete = true
}

resource "aws_ecr_repository" "contact" {
  name = "${var.project}/contact-service"
  force_delete = true
}

# Replicate images to the secondary region so the dormant stack can pull
# locally during a regional failover.
resource "aws_ecr_replication_configuration" "this" {
  replication_configuration {
    rule {
      destination {
        region      = var.secondary_region
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}

data "aws_caller_identity" "current" {}

# Keep only the 10 most recent images per repo.
resource "aws_ecr_lifecycle_policy" "profile" {
  repository = aws_ecr_repository.profile.name
  policy     = local.ecr_lifecycle
}

resource "aws_ecr_lifecycle_policy" "contact" {
  repository = aws_ecr_repository.contact.name
  policy     = local.ecr_lifecycle
}

locals {
  ecr_lifecycle = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ---------- DynamoDB global table (auto multi-region replication) ----------

resource "aws_dynamodb_table" "messages" {
  name         = "${var.project}-messages"
  billing_mode = "PAY_PER_REQUEST" # ~free at portfolio traffic
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  # This single block is the entire cross-region DB replication story.
  replica {
    region_name = var.secondary_region
  }

  # Global tables require streams.
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}

# ---------- Regional stacks ----------

locals {
  registry      = "${data.aws_caller_identity.current.account_id}.dkr.ecr"
  profile_image = "${local.registry}.%s.amazonaws.com/${var.project}/profile-service"
  contact_image = "${local.registry}.%s.amazonaws.com/${var.project}/contact-service"
}

module "primary" {
  source = "./modules/region-stack"

  # Short name: target-group names (name + "-profile") must fit 32 chars,
  # IAM role name_prefix 38.
  name                = "portfolio-primary"
  active              = true
  profile_image       = "${format(local.profile_image, var.primary_region)}:${var.profile_image_tag}"
  contact_image       = "${format(local.contact_image, var.primary_region)}:${var.contact_image_tag}"
  dynamodb_table_name = aws_dynamodb_table.messages.name
  dynamodb_table_arn  = aws_dynamodb_table.messages.arn
  certificate_arn     = aws_acm_certificate_validation.api_primary.certificate_arn
  enable_https        = true

  enable_sns           = true
  sns_topic_arn        = aws_sns_topic.contact.arn
  enable_origin_verify = true
  origin_verify_secret = random_password.origin_verify.result
}

module "secondary" {
  count  = var.enable_secondary ? 1 : 0
  source = "./modules/region-stack"
  providers = {
    aws = aws.secondary
  }

  name                = "portfolio-secondary"
  active              = false # dormant: infra exists, 0 running tasks
  profile_image       = "${format(local.profile_image, var.secondary_region)}:${var.profile_image_tag}"
  contact_image       = "${format(local.contact_image, var.secondary_region)}:${var.contact_image_tag}"
  dynamodb_table_name = aws_dynamodb_table.messages.name
  dynamodb_table_arn  = aws_dynamodb_table.messages.arn
  certificate_arn     = aws_acm_certificate_validation.api_secondary[0].certificate_arn
  enable_https        = true

  enable_sns           = true
  sns_topic_arn        = aws_sns_topic.contact.arn
  enable_origin_verify = true
  origin_verify_secret = random_password.origin_verify.result
}

# ---------- Route 53 failover ----------

resource "aws_route53_health_check" "primary_api" {
  fqdn              = module.primary.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/api/profile" # must be a path the ALB actually routes
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "api_primary" {
  zone_id        = data.aws_route53_zone.main.zone_id
  name           = "api.${var.domain_name}"
  type           = "A"
  set_identifier = "primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary_api.id

  alias {
    name                   = module.primary.alb_dns_name
    zone_id                = module.primary.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api_secondary" {
  count          = var.enable_secondary ? 1 : 0
  zone_id        = data.aws_route53_zone.main.zone_id
  name           = "api.${var.domain_name}"
  type           = "A"
  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.secondary[0].alb_dns_name
    zone_id                = module.secondary[0].alb_zone_id
    evaluate_target_health = true
  }
}

# ---------- Outputs ----------

output "primary_alb" { value = module.primary.alb_dns_name }
output "secondary_alb" {
  value = var.enable_secondary ? module.secondary[0].alb_dns_name : null
}
output "api_url" { value = "https://api.${var.domain_name}" }
output "ecr_profile_repo" { value = aws_ecr_repository.profile.repository_url }
output "ecr_contact_repo" { value = aws_ecr_repository.contact.repository_url }
output "dynamodb_table" { value = aws_dynamodb_table.messages.name }
