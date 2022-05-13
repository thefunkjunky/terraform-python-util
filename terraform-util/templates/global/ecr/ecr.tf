locals {
  common_repos = [
    "authentication",
    "comments",
    "middle",
    "tag_manager",
    "search/db_changes_indexer",
    "search/logstash_batch_indexer",
    "search/s3_file_indexer",
  ]
  datafactory_repos = [
    "api",
    "ui",
  ]
}

resource "aws_ecr_repository" "base" {
    name                 = local.realm_prefix
    image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository" "data_factory" {
  for_each = toset(local.datafactory_repos)
  name                 = "data_factory/${each.key}"
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository" "common" {
  for_each = toset(local.common_repos)
  name                 = "common/${each.key}"
  image_tag_mutability = "IMMUTABLE"
}
