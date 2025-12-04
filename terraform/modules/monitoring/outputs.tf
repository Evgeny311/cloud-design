# ======
# Monitoring Module - Outputs
# ======

# Log Groups
output "applications_log_group_name" {
  description = "Name of the applications log group"
  value       = aws_cloudwatch_log_group.applications.name
}

output "applications_log_group_arn" {
  description = "ARN of the applications log group"
  value       = aws_cloudwatch_log_group.applications.arn
}

output "k3s_log_group_name" {
  description = "Name of the K3s log group"
  value       = aws_cloudwatch_log_group.k3s.name
}

output "k3s_log_group_arn" {
  description = "ARN of the K3s log group"
  value       = aws_cloudwatch_log_group.k3s.arn
}

output "rds_log_group_name" {
  description = "Name of the RDS log group"
  value       = var.enable_rds_logs ? aws_cloudwatch_log_group.rds[0].name : null
}

# Dashboard
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

# SNS Topic
output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = var.enable_sns_alerts ? aws_sns_topic.alerts[0].arn : null
}

# Metric Filters
output "error_metric_name" {
  description = "Name of the error count metric"
  value       = aws_cloudwatch_log_metric_filter.error_count.name
}

output "api_requests_metric_name" {
  description = "Name of the API requests metric"
  value       = aws_cloudwatch_log_metric_filter.api_requests.name
}

# Saved Queries
output "saved_queries" {
  description = "Names of saved CloudWatch Insights queries"
  value = {
    errors          = aws_cloudwatch_query_definition.errors.name
    api_performance = aws_cloudwatch_query_definition.api_performance.name
    top_requests    = aws_cloudwatch_query_definition.top_requests.name
  }
}