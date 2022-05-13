module "vpc_networking" {
  source = "${modules_dir}/vpc_networking"

  account_id = local.account_id
  environment = local.env_prefix
  allow_public_ssh = var.allow_public_ssh
  domain_name = var.vpc_domain
  private_subnets = var.private_subnets
  public_subnets = var.public_subnets
  region = var.region
  vpc_cidr = var.vpc_cidr
  vpc_name = var.vpc_name
  vpc_private_cidr = var.vpc_private_cidr
  vpc_public_cidr = var.vpc_public_cidr
  vpc_tags = {
  % for key, value in vpc_tags.items():
    "${key}" = "${value}",
  % endfor
  % if k8_clusters:
  % for cluster in k8_clusters:
    "kubernetes.io/cluster/<%text>${var.environment}</%text>-${cluster}" = "shared",
  % endfor
  % endif
  }
  public_subnet_tags = {
  % if k8_clusters:
    "kubernetes.io/role/elb" = 1,
  % for cluster in k8_clusters:
    "kubernetes.io/cluster/<%text>${var.environment}</%text>-${cluster}" = "shared",
  % endfor
  % endif
  % for key, value in public_subnet_tags.items():
    "${key}" = "${value}",
  % endfor
  }
  private_subnet_tags = {
  % if k8_clusters:
    "kubernetes.io/role/internal-elb" = 1,
  % for cluster in k8_clusters:
    "kubernetes.io/cluster/<%text>${var.environment}</%text>-${cluster}" = "shared",
  % endfor
  % endif
  % for key, value in private_subnet_tags.items():
    "${key}" = "${value}",
  % endfor
  }
}
