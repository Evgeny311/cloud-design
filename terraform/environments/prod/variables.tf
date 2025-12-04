# ======
# Development Environment - Variables
# ======

# General
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloud-design"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# SSH Key
variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
}

# S3
variable "logs_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}

variable "backups_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

# ECR
variable "ecr_image_tag_mutability" {
  description = "Image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep"
  type        = number
  default     = 10
}

variable "ecr_untagged_retention_days" {
  description = "Days to keep untagged images"
  type        = number
  default     = 7
}

# RDS
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15.4"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_storage_type" {
  description = "Storage type"
  type        = string
  default     = "gp3"
}

variable "rds_master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

variable "rds_inventory_db_name" {
  description = "Inventory database name"
  type        = string
  default     = "inventory"
}

variable "rds_billing_db_name" {
  description = "Billing database name"
  type        = string
  default     = "billing"
}

variable "rds_inventory_db_username" {
  description = "Inventory database username"
  type        = string
  default     = "inventory_user"
}

variable "rds_billing_db_username" {
  description = "Billing database username"
  type        = string
  default     = "billing_user"
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "rds_maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "rds_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs export"
  type        = bool
  default     = false
}

variable "rds_enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

# K3s
variable "k3s_master_instance_type" {
  description = "Instance type for K3s master"
  type        = string
  default     = "t3.medium"
}

variable "k3s_worker_instance_type" {
  description = "Instance type for K3s workers"
  type        = string
  default     = "t3.small"
}

variable "k3s_worker_node_count" {
  description = "Number of K3s worker nodes"
  type        = number
  default     = 2
}

variable "k3s_version" {
  description = "K3s version"
  type        = string
  default     = "v1.28.5+k3s1"
}

variable "k3s_cluster_token" {
  description = "K3s cluster token"
  type        = string
  sensitive   = true
}

variable "k3s_use_elastic_ip" {
  description = "Use Elastic IP for master node"
  type        = bool
  default     = false
}

# ALB
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "alb_enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for ALB"
  type        = bool
  default     = true
}

variable "alb_acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = ""
}

# Monitoring
variable "monitoring_log_retention_days" {
  description = "CloudWatch log retention days"
  type        = number
  default     = 7
}

variable "monitoring_enable_rds_logs" {
  description = "Enable RDS log group"
  type        = bool
  default     = true
}

variable "monitoring_enable_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

variable "monitoring_enable_sns_alerts" {
  description = "Enable SNS email alerts"
  type        = bool
  default     = false
}

variable "monitoring_alert_email" {
  description = "Email for SNS alerts"
  type        = string
  default     = ""
}