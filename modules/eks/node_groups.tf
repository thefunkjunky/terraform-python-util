resource "aws_eks_node_group" "eks" {
  for_each = {for ng in var.node_group_configs: ng.name => ng}
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = each.value.subnet_ids
  capacity_type   = each.value.capacity_type
  instance_types  = each.value.instance_types
  disk_size       = each.value.node_vol_size
  tags            = each.value.node_tags
  labels          = each.value.node_labels

  scaling_config {
    desired_size = each.value.desired_nodes
    max_size     = each.value.max_nodes
    min_size     = each.value.min_nodes
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    # aws_security_group_rule.workers_egress_internet,
    # aws_security_group_rule.workers_ingress_self,
    # aws_security_group_rule.workers_ingress_cluster,
    # aws_security_group_rule.workers_ingress_cluster_kubelet,
    # aws_security_group_rule.workers_ingress_cluster_https,
    # aws_security_group_rule.workers_ingress_cluster_primary,
    # aws_security_group_rule.cluster_primary_ingress_workers,
    aws_iam_role_policy_attachment.eks-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-AmazonEC2ContainerRegistryReadOnly,
  ]

  # Ignore # nodes in cluster changing since it's autoscaling
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
