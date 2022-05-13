locals {
  company = data.terraform_remote_state.common.outputs.company
  realm = data.terraform_remote_state.common.outputs.realm
  realm_prefix = data.terraform_remote_state.common.outputs.realm_prefix
  env_prefix = "${local.realm_prefix}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
