# Root backend remote state

resource "aws_kms_key" "tfstate" {
  description = "Used for encrypted state"
}


resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.realm_prefix}-tfstate"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.tfstate.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = {
    Name = "${var.company} ${var.realm} Terraform State"
  }
}


resource "aws_dynamodb_table" "backend-tfstate" {
  name         = "${local.realm_prefix}-backend-tfstate"
  hash_key     = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}

