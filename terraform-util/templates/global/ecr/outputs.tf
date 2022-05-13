output "base_ecr_url" {
  value = aws_ecr_repository.base.repository_url
}

output "base_ecr_arn" {
  value = aws_ecr_repository.base.arn
}
