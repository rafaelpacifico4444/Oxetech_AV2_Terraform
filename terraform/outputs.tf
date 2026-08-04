output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.lab.id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "DNS name do Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "cloudfront_domain_name" {
  description = "Domain name da distribuicao CloudFront"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "website_url" {
  description = "URL final do site (via Route 53 + CloudFront)"
  value       = "https://${local.site_fqdn}"
}

output "rds_endpoint" {
  description = "Endpoint do banco RDS"
  value       = aws_db_instance.lab.endpoint
  sensitive   = true
}

output "bucket_name" {
  description = "Nome do bucket S3"
  value       = aws_s3_bucket.assets.bucket
}
