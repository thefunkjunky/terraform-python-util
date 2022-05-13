locals {
  clusters = {
  % if k8_clusters:
  % for cluster, k8_configs in k8_clusters.items():
    "<%text>${var.environment}</%text>-${cluster}" = {
      k8_version = "${k8_configs["version"]}",
      node_group_configs = [
      % if "node_groups" in k8_configs:
      % for node_group, node_configs in k8_configs["node_groups"].items():
        {
          name = "<%text>${var.environment}</%text>-${cluster}-${node_group}"
          instance_types = [
            % for instance_type in node_configs["instance_types"]:
            "${instance_type}",
            % endfor
          ]
          % if node_configs["public"]:
          subnet_ids = concat(
            module.vpc_networking.private_subnet_ids,
            module.vpc_networking.public_subnet_ids
          )
          % else:
          subnet_ids = module.vpc_networking.private_subnet_ids
          % endif
          capacity_type = "${node_configs["capacity_type"]}"
          min_nodes = ${node_configs["min_nodes"]}
          max_nodes = ${node_configs["max_nodes"]}
          desired_nodes = ${node_configs["desired_nodes"]}
          node_vol_size = ${node_configs["vol_size"]}
          node_vol_type = "${node_configs["vol_type"]}"
          node_tags = {
          % for key, value in node_configs["node_tags"].items():
            "${key}" = "${value}",
          % endfor
          },
          node_labels = {
          % for key, value in node_configs["node_labels"].items():
            "${key}" = "${value}",
          % endfor
          },
        },
      % endfor
      % endif
      ]
    },
  % endfor
  % endif
  }
}

module "k8-clusters" {
  for_each = local.clusters
  source = "${modules_dir}/eks"
  cluster_name = each.key
  vpc_id = module.vpc_networking.vpc_id
  cluster_version = each.value["k8_version"]
  subnet_ids = concat(
    module.vpc_networking.public_subnet_ids,
    module.vpc_networking.private_subnet_ids
  )
  node_group_configs = each.value["node_group_configs"]
  ecr_arn = data.terraform_remote_state.global_ecr.outputs.base_ecr_arn
}
