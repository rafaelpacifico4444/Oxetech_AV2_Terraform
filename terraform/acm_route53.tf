data "aws_route53_zone" "primary" {
  zone_id = var.route53_zone_id
}

locals {
  site_fqdn = var.subdomain == "" ? var.domain_name : "${var.subdomain}.${var.domain_name}"
}

# ---------------------------------------------------------------------------
# Certificado regional (mesma regiao do ALB) - usado pelo listener HTTPS do ALB
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "site" {
  domain_name       = local.site_fqdn
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }

  tags = { Name = "${var.project_name}-${var.environment}-acm-regional" }
}

resource "aws_route53_record" "validation" {
  name    = tolist(aws_acm_certificate.site.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.site.domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.site.domain_validation_options)[0].resource_record_value]
  ttl     = 60

  zone_id = data.aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [aws_route53_record.validation.fqdn]
}

# ---------------------------------------------------------------------------
# Certificado em us-east-1 - obrigatorio para uso no CloudFront
# ---------------------------------------------------------------------------
resource "aws_acm_certificate" "cdn" {
  provider          = aws.us_east_1
  domain_name       = local.site_fqdn
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }

  tags = { Name = "${var.project_name}-${var.environment}-acm-cloudfront" }
}

resource "aws_acm_certificate_validation" "cdn" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cdn.arn
  validation_record_fqdns = [aws_route53_record.validation.fqdn]
}

# ---------------------------------------------------------------------------
# Registro DNS final: aponta o subdominio para o CloudFront
# ---------------------------------------------------------------------------
resource "aws_route53_record" "site" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = local.site_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
