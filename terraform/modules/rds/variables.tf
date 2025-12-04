# ======
# RDS Module - Variables
# ======

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

# RDS Instance Configuration
variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15.4"
}

variable "allocated_storage" {
  description = "Allocated storage in GB (minimum 20GB)"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage type (gp2, gp3)"
  type        = string
  default     = "gp3"
}

# Master User Configuration
variable "master_username" {
  description = "Master username for RDS"
  type        = string
  default     = "postgres"
}

# Database Names
variable "inventory_db_name" {
  description = "Name of the inventory database"
  type        = string
  default     = "inventory"
}

variable "billing_db_name" {
  description = "Name of the billing database"
  type        = string
  default     = "billing"
}

# Application Users
variable "inventory_db_username" {
  description = "Username for inventory database"
  type        = string
  default     = "inventory_user"
}

variable "billing_db_username" {
  description = "Username for billing database"
  type        = string
  default     = "billing_user"
}

# Network Configuration
variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS"
  type        = string
}

# Backup Configuration
variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Maintenance window (UTC)"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (set false for production)"
  type        = bool
  default     = true
}

# High Availability
variable "multi_az" {
  description = "Enable Multi-AZ (disable for Free Tier)"
  type        = bool
  default     = false
}

# Monitoring
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs export"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms"
  type        = bool
  default     = true
}

# Security
variable "deletion_protection" {
  description = "Enable deletion protection (set true for production)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}