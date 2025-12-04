# ======
# Development Environment - Outputs
# ======

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# K3s Cluster
output "k3s_master_public_ip" {
  description = "K3s master node public IP"
  value       = module.ec2.k3s_master_public_ip
}

output "k3s_master_private_ip" {
  description = "K3s master node private IP"
  value       = module.ec2.k3s_master_private_ip
}

output "k3s_worker_public_ips" {
  description = "K3s worker nodes public IPs"
  value       = module.ec2.k3s_worker_public_ips
}

output "k3s_cluster_endpoint" {
  description = "K3s cluster API endpoint"
  value       = module.ec2.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig"
  value       = module.ec2.kubeconfig_command
  sensitive   = true
}

# RDS
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.rds_endpoint
}

output "rds_address" {
  description = "RDS address"
  value       = module.rds.rds_address
}

output "inventory_db_secret_arn" {
  description = "ARN of inventory database secret"
  value       = module.rds.inventory_db_secret_arn
}

output "billing_db_secret_arn" {
  description = "ARN of billing database secret"
  value       = module.rds.billing_db_secret_arn
}

# ECR
output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.ecr.all_repository_urls
}

output "ecr_registry_url" {
  description = "ECR registry URL"
  value       = module.ecr.registry_url
}

output "docker_login_command" {
  description = "Command to login to ECR"
  value       = module.ecr.docker_login_command
  sensitive   = true
}

# ALB
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "application_endpoints" {
  description = "Application endpoints"
  value       = module.alb.application_endpoints
}

# S3
output "terraform_state_bucket" {
  description = "Terraform state bucket name"
  value       = module.s3.terraform_state_bucket_name
}

output "logs_bucket" {
  description = "Logs bucket name"
  value       = module.s3.logs_bucket_name
}

output "backups_bucket" {
  description = "Backups bucket name"
  value       = module.s3.backups_bucket_name
}

# Monitoring
output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "log_groups" {
  description = "CloudWatch log group names"
  value = {
    applications = module.monitoring.applications_log_group_name
    k3s          = module.monitoring.k3s_log_group_name
    rds          = module.monitoring.rds_log_group_name
  }
}

# Connection Information
output "ssh_connection_commands" {
  description = "SSH commands to connect to nodes"
  value = {
    master   = "ssh -i ~/.ssh/${module.security.key_pair_name}.pem ec2-user@${module.ec2.k3s_master_public_ip}"
    workers  = [for ip in module.ec2.k3s_worker_public_ips : "ssh -i ~/.ssh/${module.security.key_pair_name}.pem ec2-user@${ip}"]
  }
  sensitive = true
}

# Quick Start Guide
output "quick_start_guide" {
  description = "Quick start commands"
  value = <<-EOT
    ======
    Cloud Design - Development Environment
    ======
    
    1. SSH to K3s Master:
       ${module.ec2.kubeconfig_command}
    
    2. Access Applications:
       API Gateway:   ${module.alb.api_gateway_endpoint}
       Inventory App: ${module.alb.inventory_app_endpoint}
       Billing App:   ${module.alb.billing_app_endpoint}
    
    3. View Logs:
       aws logs tail ${module.monitoring.applications_log_group_name} --follow
    
    4. CloudWatch Dashboard:
       ${module.monitoring.dashboard_url}
    
    5. Initialize Databases:
       cd terraform/modules/rds
       ./init-databases.sh ${module.rds.rds_endpoint} <credentials>
    
    6. Docker Login (ECR):
       ${module.ecr.docker_login_command}
    
    ======
  EOT
}