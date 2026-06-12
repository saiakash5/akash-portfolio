# Reusable Fargate service: task definition + service + logs + IAM.
# Instantiated once per microservice per region.

variable "name" { type = string }
variable "cluster_arn" { type = string }
variable "image" { type = string }
variable "container_port" { type = number }
variable "cpu" { default = 256 }
variable "memory" { default = 512 }

# The active-dormant switch: 1+ in the active region, 0 in the dormant one.
variable "desired_count" { default = 1 }

variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "target_group_arn" { type = string }

variable "environment" {
  type    = map(string)
  default = {}
}

# Optional: grant the task write access to a DynamoDB table.
# grant_dynamodb is a static flag because count cannot depend on the
# (apply-time) table ARN.
variable "grant_dynamodb" {
  type    = bool
  default = false
}

variable "dynamodb_table_arn" {
  type    = string
  default = null
}

# Optional: allow the task to publish to an SNS topic.
variable "grant_sns" {
  type    = bool
  default = false
}

variable "sns_topic_arn" {
  type    = string
  default = null
}

# Lightswitch: scheduled on/off so the service only runs during showcase
# hours. The schedule owns desired_count once enabled.
variable "enable_schedule" {
  type    = bool
  default = false
}

variable "schedule_up_cron" {
  default = "cron(0 8 ? * MON-FRI *)" # 8:00 AM weekdays
}

variable "schedule_down_cron" {
  default = "cron(0 16 ? * * *)" # 4:00 PM every day (safety net for weekend overrides)
}

variable "schedule_timezone" {
  default = "America/Chicago"
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = 14
}

resource "aws_iam_role" "execution" {
  name_prefix = "${var.name}-exec-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name_prefix = "${var.name}-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "dynamodb" {
  count       = var.grant_dynamodb ? 1 : 0
  name_prefix = "${var.name}-ddb-"
  role        = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
      Resource = var.dynamodb_table_arn
    }]
  })
}

resource "aws_iam_role_policy" "sns" {
  count       = var.grant_sns ? 1 : 0
  name_prefix = "${var.name}-sns-"
  role        = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = var.sns_topic_arn
    }]
  })
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([{
    name      = var.name
    image     = var.image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [for k, v in var.environment : { name = k, value = v }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.name
      }
    }
  }])
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true # public subnets, no NAT (cost tradeoff)
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.name
    container_port   = var.container_port
  }

  lifecycle {
    # The lightswitch schedule and manual overrides own desired_count after
    # creation; Terraform must not reset it on every apply.
    ignore_changes = [desired_count]
  }
}

# ---------- Lightswitch (scheduled on/off) ----------

resource "aws_appautoscaling_target" "this" {
  count              = var.enable_schedule ? 1 : 0
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.this.name}"
  min_capacity       = 0
  max_capacity       = 1
}

resource "aws_appautoscaling_scheduled_action" "up" {
  count              = var.enable_schedule ? 1 : 0
  name               = "${var.name}-lightswitch-on"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  schedule           = var.schedule_up_cron
  timezone           = var.schedule_timezone

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}

resource "aws_appautoscaling_scheduled_action" "down" {
  count              = var.enable_schedule ? 1 : 0
  name               = "${var.name}-lightswitch-off"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  schedule           = var.schedule_down_cron
  timezone           = var.schedule_timezone

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}

output "service_name" { value = aws_ecs_service.this.name }
