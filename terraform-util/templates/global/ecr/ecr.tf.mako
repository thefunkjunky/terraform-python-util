locals {
  common_repos = [
    % for repo in ecr_common_repos:
    ${repo},
    % endfor
  ]
}

resource "aws_ecr_repository" "base" {
    name                 = local.realm_prefix
    image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository" "common" {
  for_each = toset(local.common_repos)
  name                 = "common/<%text>${each.key}</%text>"
  image_tag_mutability = "IMMUTABLE"
}
