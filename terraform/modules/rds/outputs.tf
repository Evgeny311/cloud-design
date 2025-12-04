# ======
# RDS Module - Outputs
# ======

# RDS Instance
output "rds_instance_id" {
  description = "ID of the RDS instance"
  value       = aws_db_instance.main.id
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "rds_endpoint" {
  description = "Connection endpoint for RDS"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "Hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.main.port
}

# Master Credentials
output "master_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "master_password_secret_arn" {
  description = "ARN of the secret containing master password"
  value       = aws_secretsmanager_secret.db_master_password.arn
}

# Inventory Database
output "inventory_db_name" {
  description = "Name of the inventory database"
  value       = var.inventory_db_name
}

output "inventory_db_username" {
  description = "Username for inventory database"
  value       = var.inventory_db_username
  sensitive   = true
}

output "inventory_db_secret_arn" {
  description = "ARN of the secret containing inventory database credentials"
  value       = aws_secretsmanager_secret.inventory_db.arn
}

# Billing Database
output "billing_db_name" {
  description = "Name of the billing database"
  value       = var.billing_db_name
}

output "billing_db_username" {
  description = "Username for billing database"
  value       = var.billing_db_username
  sensitive   = true
}

output "billing_db_secret_arn" {
  description = "ARN of the secret containing billing database credentials"
  value       = aws_secretsmanager_secret.billing_db.arn
}

# Connection Strings (for easy reference)
output "inventory_db_connection_string" {
  description = "Connection string for inventory database"
  value       = "postgresql://${var.inventory_db_username}:PASSWORD@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.inventory_db_name}"
  sensitive   = true
}

output "billing_db_connection_string" {
  description = "Connection string for billing database"
  value       = "postgresql://${var.billing_db_username}:PASSWORD@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${var.billing_db_name}"
  sensitive   = true
}

# Database initialization info
output "database_init_required" {
  description = "Indicates that databases need to be created manually"
  value       = "Run init script to create inventory and billing databases"
}