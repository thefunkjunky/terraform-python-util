output "zones" {
  value = var.zone_domains
}

output "zone_name_servers" {
  value = {
    for uri in var.zone_domains:
      uri => aws_route53_zone.main[uri].name_servers
  }
}

output "zone_ids" {
  value = {
    for uri in var.zone_domains:
      uri => aws_route53_zone.main[uri].zone_id
  }
}

output "acm_arns" {
  value = {
    for uri in var.zone_domains:
      uri => module.zone_acm[uri].acm_arn
  }
}

output "acm_status" {
  value = {
    for uri in var.zone_domains:
      uri => module.zone_acm[uri].acm_status
  }
}

output "ssl_records" {
  value = {
    for uri in var.zone_domains:
      uri => module.zone_acm[uri].ssl_route53_record
  }
}
