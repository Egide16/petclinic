# Regional certificate for the ALB's HTTPS listener.
resource "aws_acm_certificate" "alb" {
  count             = local.use_custom_domain ? 1 : 0
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# CloudFront always requires its certificate in us-east-1.
resource "aws_acm_certificate" "cloudfront" {
  count             = local.use_custom_domain ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.use_custom_domain ? {
    (local.fqdn) = aws_acm_certificate.alb[0].domain_validation_options
  } : {}

  zone_id = data.aws_route53_zone.main[0].zone_id

  name = one([
    for dvo in each.value : dvo.resource_record_name
  ])

  type = one([
    for dvo in each.value : dvo.resource_record_type
  ])

  records = [
    one([
      for dvo in each.value : dvo.resource_record_value
    ])
  ]

  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "alb" {
  count = local.use_custom_domain ? 1 : 0

  certificate_arn = aws_acm_certificate.alb[0].arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}

resource "aws_acm_certificate_validation" "cloudfront" {
  count    = local.use_custom_domain ? 1 : 0
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.cloudfront[0].arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}
