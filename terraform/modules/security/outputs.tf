# =======
# Security Module - Outputs
# =======

# Security Groups
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "k3s_nodes_security_group_id" {
  description = "ID of the K3s nodes security group"
  value       = aws_security_group.k3s_nodes.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

# IAM
output "k3s_node_role_arn" {
  description = "ARN of the K3s node IAM role"
  value       = aws_iam_role.k3s_node.arn
}

output "k3s_node_role_name" {
  description = "Name of the K3s node IAM role"
  value       = aws_iam_role.k3s_node.name
}

output "k3s_node_instance_profile_name" {
  description = "Name of the K3s node instance profile"
  value       = aws_iam_instance_profile.k3s_node.name
}

output "k3s_node_instance_profile_arn" {
  description = "ARN of the K3s node instance profile"
  value       = aws_iam_instance_profile.k3s_node.arn
}

# SSH Key
output "key_pair_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.k3s.key_name
}

output "key_pair_id" {
  description = "ID of the SSH key pair"
  value       = aws_key_pair.k3s.id
}