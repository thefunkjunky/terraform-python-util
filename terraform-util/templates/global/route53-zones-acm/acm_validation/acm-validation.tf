module "zone_acm_validate" {
  for_each           = toset(local.validate_domains)
  source             = "../../../../../../modules/acm-validation"
  acm_arn            = data.terraform_remote_state.zones.outputs.acm_arns[each.key]
  ssl_route53_record = data.terraform_remote_state.zones.outputs.ssl_records[each.key]
}
