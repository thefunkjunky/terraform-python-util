variable "acm_arn" {
  type = string
  description = "Terraform acm certificate arn to validate"
}

variable "ssl_route53_record" {
  description = "Terraform resource aws_route53_record (ssl) to validate"
}
