resource "aws_acm_certificate" "betteromics" {
  domain_name       = var.aws_route53_zone.name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    { Name = var.aws_route53_zone.name }, var.tags
  )

}


resource "aws_route53_record" "betteromics-ssl" {
  for_each = {
    for dvo in aws_acm_certificate.betteromics.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.aws_route53_zone.zone_id
}
