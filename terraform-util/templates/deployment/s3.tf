resource "aws_s3_bucket" "default" {
  bucket = "${local.env_prefix}-default"
  acl    = "private"

  versioning {
    enabled = true
  }
}
