# =======
# ECR Module - Outputs
# =======

# API Gateway Repository
output "api_gateway_repository_url" {
  description = "URL of the API Gateway ECR repository"
  value       = aws_ecr_repository.api_gateway.repository_url
}

output "api_gateway_repository_arn" {
  description = "ARN of the API Gateway ECR repository"
  value       = aws_ecr_repository.api_gateway.arn
}

output "api_gateway_repository_name" {
  description = "Name of the API Gateway ECR repository"
  value       = aws_ecr_repository.api_gateway.name
}

# Inventory App Repository
output "inventory_app_repository_url" {
  description = "URL of the Inventory App ECR repository"
  value       = aws_ecr_repository.inventory_app.repository_url
}

output "inventory_app_repository_arn" {
  description = "ARN of the Inventory App ECR repository"
  value       = aws_ecr_repository.inventory_app.arn
}

output "inventory_app_repository_name" {
  description = "Name of the Inventory App ECR repository"
  value       = aws_ecr_repository.inventory_app.name
}

# Billing App Repository
output "billing_app_repository_url" {
  description = "URL of the Billing App ECR repository"
  value       = aws_ecr_repository.billing_app.repository_url
}

output "billing_app_repository_arn" {
  description = "ARN of the Billing App ECR repository"
  value       = aws_ecr_repository.billing_app.arn
}

output "billing_app_repository_name" {
  description = "Name of the Billing App ECR repository"
  value       = aws_ecr_repository.billing_app.name
}

# Registry Information
output "registry_id" {
  description = "Registry ID (AWS Account ID)"
  value       = aws_ecr_repository.api_gateway.registry_id
}

output "registry_url" {
  description = "Base ECR registry URL"
  value       = split("/", aws_ecr_repository.api_gateway.repository_url)[0]
}

# All repository URLs (for convenience)
output "all_repository_urls" {
  description = "Map of all repository URLs"
  value = {
    api_gateway   = aws_ecr_repository.api_gateway.repository_url
    inventory_app = aws_ecr_repository.inventory_app.repository_url
    billing_app   = aws_ecr_repository.billing_app.repository_url
  }
}

# Docker login command
output "docker_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${split(".", aws_ecr_repository.api_gateway.repository_url)[3]} | docker login --username AWS --password-stdin ${split("/", aws_ecr_repository.api_gateway.repository_url)[0]}"
}