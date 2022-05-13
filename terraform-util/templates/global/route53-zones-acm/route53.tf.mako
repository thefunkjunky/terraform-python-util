resource "aws_route53_zone" "main" {
  for_each = toset(var.zone_domains)
  name = each.key
}

module "zone_acm" {
  for_each = toset(var.zone_domains)
  source = "../${modules_dir}/zone-acm"
  aws_route53_zone = aws_route53_zone.main[each.key]
}

resource "aws_route53_record" "sub-ns" {
  for_each = var.outside_sub_domains
  zone_id = aws_route53_zone.main[each.value.root_domain].zone_id
  name    = each.key
  type    = "NS"
  ttl     = "30"
  records = each.value.nameservers
}
