resource "aws_kms_key" "main" {
  description = "Used for deployment secrets"
}

resource "aws_kms_alias" "main" {
  name          = "alias/${environment}-main"
  target_key_id = aws_kms_key.main.key_id
}

% if db_password_encrypted:
data "aws_kms_secrets" "secrets" {
  secret {
    name    = "db_password"
    payload = var.db_password_encrypted
  }
}
% endif
