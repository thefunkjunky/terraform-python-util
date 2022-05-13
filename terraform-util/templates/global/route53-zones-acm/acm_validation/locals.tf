locals {
  realm_prefix = data.terraform_remote_state.common.outputs.realm_prefix
  validate_domains = data.terraform_remote_state.zones.outputs != {} ? [
    for uri in data.terraform_remote_state.zones.outputs.zones: 
    uri if data.terraform_remote_state.zones.outputs.acm_status[uri] == "ISSUED"
  ] : []
}
