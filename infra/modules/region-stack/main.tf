# One complete regional backend stack: VPC -> ALB -> ECS (2 services).
# Instantiated in us-east-1 (active) and us-west-2 (dormant).

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

variable "name" { type = string }

# false = dormant region: all infra exists (pilot light) but services run 0 tasks.
variable "active" { type = bool }

variable "profile_image" { type = string }
variable "contact_image" { type = string }
variable "dynamodb_table_name" { type = string }
variable "dynamodb_table_arn" { type = string }

# Regional ACM cert for the ALB's HTTPS listener (must be issued in this
# stack's region). Null = HTTP only.
variable "certificate_arn" {
  type    = string
  default = null
}

variable "enable_https" {
  type    = bool
  default = false
}

data "aws_region" "current" {}

module "network" {
  source = "../network"
  name   = var.name
}

resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "alb" {
  source            = "../alb"
  name              = var.name
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.public_subnet_ids
  security_group_id = module.network.alb_sg_id
  certificate_arn   = var.certificate_arn
  enable_https      = var.enable_https
}

module "profile_service" {
  source            = "../ecs-service"
  name              = "${var.name}-profile"
  cluster_arn       = aws_ecs_cluster.this.arn
  image             = var.profile_image
  container_port    = 8080
  desired_count     = var.active ? 1 : 0
  subnet_ids        = module.network.public_subnet_ids
  security_group_id = module.network.services_sg_id
  target_group_arn  = module.alb.profile_tg_arn
}

module "contact_service" {
  source            = "../ecs-service"
  name               = "${var.name}-contact"
  cluster_arn        = aws_ecs_cluster.this.arn
  image              = var.contact_image
  container_port     = 8001
  desired_count      = var.active ? 1 : 0
  subnet_ids         = module.network.public_subnet_ids
  security_group_id  = module.network.services_sg_id
  target_group_arn   = module.alb.contact_tg_arn
  grant_dynamodb     = true
  dynamodb_table_arn = var.dynamodb_table_arn

  environment = {
    TABLE_NAME = var.dynamodb_table_name
    AWS_REGION = data.aws_region.current.name
  }
}

output "alb_dns_name" { value = module.alb.alb_dns_name }
output "alb_zone_id" { value = module.alb.alb_zone_id }
