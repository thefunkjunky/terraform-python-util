variable "aws_route53_zone" {
  description = "Terraform resource aws_route53_zone"
}

variable "tags" {
  type = map
  description = "Tags merged to all supported resources"
  default = {}
}
