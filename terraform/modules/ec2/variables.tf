# =======
# EC2 Module - Variables
# =======

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "k3s_security_group_id" {
  description = "Security group ID for K3s nodes"
  type        = string
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name for K3s nodes"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
}

variable "master_instance_type" {
  description = "Instance type for K3s master node"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "Instance type for K3s worker nodes"
  type        = string
  default     = "t3.small"
}

variable "worker_node_count" {
  description = "Number of K3s worker nodes"
  type        = number
  default     = 2
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.28.5+k3s1"
}

variable "cluster_token" {
  description = "Token for K3s cluster authentication"
  type        = string
  sensitive   = true
}

variable "use_elastic_ip" {
  description = "Whether to use Elastic IP for master node"
  type        = bool
  default     = false
}

variable "ecr_registry_url" {
  description = "ECR registry URL for pulling images"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}