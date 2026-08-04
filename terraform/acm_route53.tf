# Pressupoe que o dominio ja possui uma Hosted Zone publica no Route 53.
resource "aws_route53_zone" "primary" {
  name = var.domain_name
  tags = { Name = "${var.project_name}-${var.environment}-zone" }
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

locals {
  all_validation_options = distinct(concat(
    tolist(aws_acm_certificate.site.domain_validation_options),
    tolist(aws_acm_certificate.cdn.domain_validation_options)
  ))
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in local.all_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn 
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
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
  certificate_arn          = aws_acm_certificate.cdn.arn
  validation_record_fqdns  = [for record in aws_route53_record.validation : record.fqdn]
}

# ---------------------------------------------------------------------------
# Registro DNS final: aponta o subdominio para o CloudFront
# ---------------------------------------------------------------------------
resource "aws_route53_record" "site" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = local.site_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
