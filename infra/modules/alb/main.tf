# ALB with path-based routing:
#   /api/profile* -> profile-service (Spring Boot, :8080, health /actuator/health)
#   /api/contact* -> contact-service (FastAPI,     :8001, health /healthz)

variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }

# When true, port 80 redirects to 443 and routing rules attach to the
# HTTPS listener. Kept as a separate static flag (not derived from the
# cert ARN) because count cannot depend on values unknown until apply.
variable "enable_https" {
  type    = bool
  default = false
}

variable "certificate_arn" {
  type    = string
  default = null
}

# When set, /api/contact requests must carry X-Origin-Verify with this value
# (stamped by CloudFront), so writes can't bypass the WAF by hitting the ALB
# directly. Static enable flag for the same count-vs-unknown reason as above.
variable "require_origin_verify" {
  type    = bool
  default = false
}

variable "origin_verify_secret" {
  type      = string
  default   = null
  sensitive = true
}

locals {
  https_enabled = var.enable_https
}

resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "profile" {
  name        = "${var.name}-profile"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_target_group" "contact" {
  name        = "${var.name}-contact"
  port        = 8001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https_enabled ? [1] : []
    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.https_enabled ? [] : [1]
    content {
      type = "fixed-response"

      fixed_response {
        content_type = "application/json"
        message_body = "{\"error\":\"not found\"}"
        status_code  = "404"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":\"not found\"}"
      status_code  = "404"
    }
  }
}

locals {
  rules_listener_arn = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

resource "aws_lb_listener_rule" "profile" {
  listener_arn = local.rules_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.profile.arn
  }

  condition {
    path_pattern {
      values = ["/api/profile*"]
    }
  }
}

resource "aws_lb_listener_rule" "contact" {
  listener_arn = local.rules_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.contact.arn
  }

  condition {
    path_pattern {
      values = ["/api/contact*"]
    }
  }

  dynamic "condition" {
    for_each = var.require_origin_verify ? [1] : []
    content {
      http_header {
        http_header_name = "X-Origin-Verify"
        values           = [var.origin_verify_secret]
      }
    }
  }
}

output "alb_arn" { value = aws_lb.this.arn }
output "alb_dns_name" { value = aws_lb.this.dns_name }
output "alb_zone_id" { value = aws_lb.this.zone_id }
output "profile_tg_arn" { value = aws_lb_target_group.profile.arn }
output "contact_tg_arn" { value = aws_lb_target_group.contact.arn }
