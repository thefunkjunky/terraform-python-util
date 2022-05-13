resource "aws_dynamodb_table" "root-tfstate" {
  name         = "${local.env_prefix}-root-tfstate"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}
