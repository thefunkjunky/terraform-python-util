resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  version  = var.cluster_version
  enabled_cluster_log_types = var.cluster_enabled_log_types
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = var.subnet_ids
    # security_group_ids      = compact([aws_security_group.cluster])
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKSVPCResourceController,
    # aws_security_group_rule.cluster_egress_internet,
    # aws_security_group_rule.cluster_https_worker_ingress,
  ]

  tags = var.tags
}
