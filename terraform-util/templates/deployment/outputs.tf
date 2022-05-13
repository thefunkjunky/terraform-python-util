output "base_ecr_url" {
  value = data.terraform_remote_state.global_ecr.outputs.base_ecr_url
}

output "db_address" {
  value = aws_db_instance.default_db.address
}

output "acm_arns" {
  value = data.terraform_remote_state.zones.outputs != {} ? data.terraform_remote_state.zones.outputs.acm_arns : {}
}
