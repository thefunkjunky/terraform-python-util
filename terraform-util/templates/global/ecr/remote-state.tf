resource "aws_dynamodb_table" "tfstate" {
  name         = "${local.realm_prefix}-global-ecr-tfstate"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}
