# ============================================
# ALB Module - Outputs
# ============================================

# Load Balancer
output "alb_id" {
  description = "ID of the ALB"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch metrics)"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

# Target Groups
output "api_gateway_target_group_arn" {
  description = "ARN of the API Gateway target group"
  value       = aws_lb_target_group.api_gateway.arn
}

output "inventory_app_target_group_arn" {
  description = "ARN of the Inventory App target group"
  value       = aws_lb_target_group.inventory_app.arn
}

output "billing_app_target_group_arn" {
  description = "ARN of the Billing App target group"
  value       = aws_lb_target_group.billing_app.arn
}

# Listeners
output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

# Endpoints
output "api_gateway_endpoint" {
  description = "Endpoint for API Gateway"
  value       = "http://${aws_lb.main.dns_name}/api"
}

output "inventory_app_endpoint" {
  description = "Endpoint for Inventory App"
  value       = "http://${aws_lb.main.dns_name}/inventory"
}

output "billing_app_endpoint" {
  description = "Endpoint for Billing App"
  value       = "http://${aws_lb.main.dns_name}/billing"
}

# All endpoints (for convenience)
output "application_endpoints" {
  description = "All application endpoints"
  value = {
    alb_dns_name  = aws_lb.main.dns_name
    api_gateway   = "http://${aws_lb.main.dns_name}/api"
    inventory_app = "http://${aws_lb.main.dns_name}/inventory"
    billing_app   = "http://${aws_lb.main.dns_name}/billing"
  }
}