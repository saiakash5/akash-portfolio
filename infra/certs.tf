# ACM certificates + DNS validation.
#
# Three certs because of two AWS rules:
#  - CloudFront only accepts certs from us-east-1
#  - An ALB only accepts certs from its own region
#
#   site cert (us-east-1):    thesaiakash.com + www  -> CloudFront
#   api cert  (us-east-1):    api.thesaiakash.com    -> primary ALB
#   api cert  (us-west-2):    api.thesaiakash.com    -> secondary ALB

data "aws_route53_zone" "main" {
  name = var.domain_name
}

# ---------- Site cert (CloudFront) ----------

resource "aws_acm_certificate" "site" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "site_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true # zone has stale validation CNAMEs from an old cert
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.site_validation : r.fqdn]
}

# ---------- API cert, primary region ----------

resource "aws_acm_certificate" "api_primary" {
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "api_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_primary.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = data.aws_route53_zone.main.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "api_primary" {
  certificate_arn         = aws_acm_certificate.api_primary.arn
  validation_record_fqdns = [for r in aws_route53_record.api_validation : r.fqdn]
}

# ---------- API cert, secondary region ----------
# Same domain, so it reuses the validation records created above.

resource "aws_acm_certificate" "api_secondary" {
  count             = var.enable_secondary ? 1 : 0
  provider          = aws.secondary
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "api_secondary" {
  count           = var.enable_secondary ? 1 : 0
  provider        = aws.secondary
  certificate_arn = aws_acm_certificate.api_secondary[0].arn

  validation_record_fqdns = [for r in aws_route53_record.api_validation : r.fqdn]
}
