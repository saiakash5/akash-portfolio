# WAF on CloudFront: rate limiting + AWS managed reputation/bad-input rules.
# CLOUDFRONT scope must live in us-east-1 (the default provider here).

resource "aws_wafv2_web_acl" "frontend" {
  name  = "${var.project}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Block any single IP exceeding 300 requests per 5 minutes.
  rule {
    name     = "rate-limit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 300
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # IPs with a known-bad reputation (botnets, scanners).
  rule {
    name     = "aws-ip-reputation"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Request patterns known to be exploit attempts (log4j probes, etc.).
  rule {
    name     = "aws-known-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-waf"
    sampled_requests_enabled   = true
  }
}

# Secret header CloudFront stamps on origin requests. The ALB only accepts
# /api/contact requests carrying it, so the contact endpoint can't be spammed
# directly — all writes must pass through CloudFront (and therefore the WAF).
# /api/profile stays open: it's public read-only data and the Route 53
# health check (which can't send custom headers) depends on it.
resource "random_password" "origin_verify" {
  length  = 32
  special = false
}
