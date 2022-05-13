resource "aws_acm_certificate_validation" "betteromics" {
  certificate_arn         = var.acm_arn
  validation_record_fqdns = [for record in var.ssl_route53_record : record.fqdn]
}
