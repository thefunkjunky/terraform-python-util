output "acm_arn" {
  value = aws_acm_certificate.betteromics.arn
}

output "acm_status" {
  value = aws_acm_certificate.betteromics.status
}

output "ssl_route53_record" {
  value = aws_route53_record.betteromics-ssl
}
