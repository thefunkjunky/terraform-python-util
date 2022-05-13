variable "cluster_name" {
  type = string
  description = "EKS Cluster name"
}

variable "tags" {
  type = map(string)
  description = "A map of tags to add to all resources."
  default = {}
}

variable "ecr_arn" {
  type = string
  description = "The ECR ARN to pull docker images from"

}

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "A list of the desired control plane logging to enable. For more information, see Amazon EKS Control Plane Logging documentation (https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html)"
  default     = []
}

variable  "subnet_ids" {
  type = list(string)
  description = "List of subnet ids to deploy cluster to"
}

variable "cluster_version" {
  type = string
  description = "EKS Cluster version number"
}

variable "node_group_configs" {
  description = "List of hash maps defining the cluster node groups"
}

variable "vpc_id" {
  description = "VPC where the cluster and workers will be deployed."
  type        = string
}
