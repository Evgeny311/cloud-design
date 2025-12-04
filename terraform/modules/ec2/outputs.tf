# =======
# EC2 Module - Outputs
# =======

# Master Node
output "k3s_master_id" {
  description = "ID of the K3s master node"
  value       = aws_instance.k3s_master.id
}

output "k3s_master_private_ip" {
  description = "Private IP of the K3s master node"
  value       = aws_instance.k3s_master.private_ip
}

output "k3s_master_public_ip" {
  description = "Public IP of the K3s master node"
  value       = aws_instance.k3s_master.public_ip
}

output "k3s_master_public_dns" {
  description = "Public DNS of the K3s master node"
  value       = aws_instance.k3s_master.public_dns
}

output "k3s_master_elastic_ip" {
  description = "Elastic IP of the K3s master node (if enabled)"
  value       = var.use_elastic_ip ? aws_eip.k3s_master[0].public_ip : null
}

# Worker Nodes
output "k3s_worker_ids" {
  description = "IDs of the K3s worker nodes"
  value       = aws_instance.k3s_worker[*].id
}

output "k3s_worker_private_ips" {
  description = "Private IPs of the K3s worker nodes"
  value       = aws_instance.k3s_worker[*].private_ip
}

output "k3s_worker_public_ips" {
  description = "Public IPs of the K3s worker nodes"
  value       = aws_instance.k3s_worker[*].public_ip
}

# Cluster Info
output "cluster_endpoint" {
  description = "K3s cluster API endpoint"
  value       = "https://${aws_instance.k3s_master.public_ip}:6443"
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.k3s_master.public_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}

# CloudWatch
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.k3s.name
}