# ======
# Monitoring Module - CloudWatch
# ======
# Creates CloudWatch dashboards, log groups,
# and metric filters for monitoring
# ======

# ======
# CloudWatch Log Groups
# ======

# Application logs
resource "aws_cloudwatch_log_group" "applications" {
  name              = "/aws/${var.project_name}/${var.environment}/applications"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-app-logs"
    }
  )
}

# K3s cluster logs
resource "aws_cloudwatch_log_group" "k3s" {
  name              = "/aws/${var.project_name}/${var.environment}/k3s"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-logs"
    }
  )
}

# RDS logs (if enabled)
resource "aws_cloudwatch_log_group" "rds" {
  count = var.enable_rds_logs ? 1 : 0

  name              = "/aws/rds/${var.project_name}/${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-logs"
    }
  )
}

# ======
# CloudWatch Dashboard
# ======

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # EC2 CPU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        x      = 0
        y      = 0
        width  = 12
        height = 6
      },
      # ALB Request Count
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", { stat = "Sum" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "ALB Request Count"
        }
        x      = 12
        y      = 0
        width  = 12
        height = 6
      },
      # ALB Target Response Time
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "ALB Target Response Time"
        }
        x      = 0
        y      = 6
        width  = 12
        height = 6
      },
      # RDS CPU Utilization
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS CPU Utilization"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
        x      = 12
        y      = 6
        width  = 12
        height = 6
      },
      # RDS Database Connections
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Database Connections"
        }
        x      = 0
        y      = 12
        width  = 12
        height = 6
      },
      # RDS Free Storage Space
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "RDS Free Storage Space (Bytes)"
        }
        x      = 12
        y      = 12
        width  = 12
        height = 6
      }
    ]
  })
}

# ======
# Metric Filters - Extract custom metrics
# ======

# Error count metric filter
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = aws_cloudwatch_log_group.applications.name
  pattern        = "[ERROR]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

# API request metric filter
resource "aws_cloudwatch_log_metric_filter" "api_requests" {
  name           = "${var.project_name}-${var.environment}-api-requests"
  log_group_name = aws_cloudwatch_log_group.applications.name
  pattern        = "[timestamp, request_id, method, path, status_code, ...]"

  metric_transformation {
    name      = "APIRequestCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

# ======
# CloudWatch Alarms
# ======

# High error rate alarm
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/${var.environment}"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when error count exceeds threshold"
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# EC2 high CPU alarm
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  count = var.enable_alarms && length(var.ec2_instance_ids) > 0 ? length(var.ec2_instance_ids) : 0

  alarm_name          = "${var.project_name}-${var.environment}-ec2-high-cpu-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when EC2 CPU utilization is high"

  dimensions = {
    InstanceId = var.ec2_instance_ids[count.index]
  }

  tags = var.tags
}

# EC2 status check failed alarm
resource "aws_cloudwatch_metric_alarm" "ec2_status_check" {
  count = var.enable_alarms && length(var.ec2_instance_ids) > 0 ? length(var.ec2_instance_ids) : 0

  alarm_name          = "${var.project_name}-${var.environment}-ec2-status-check-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "Alert when EC2 instance fails status check"

  dimensions = {
    InstanceId = var.ec2_instance_ids[count.index]
  }

  tags = var.tags
}

# ======
# SNS Topic for Alerts (Optional)
# ======

resource "aws_sns_topic" "alerts" {
  count = var.enable_sns_alerts ? 1 : 0

  name = "${var.project_name}-${var.environment}-alerts"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alerts"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  count = var.enable_sns_alerts && var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ======
# CloudWatch Insights Queries (Saved)
# =======

# Query to find errors
resource "aws_cloudwatch_query_definition" "errors" {
  name = "${var.project_name}-${var.environment}-find-errors"

  log_group_names = [
    aws_cloudwatch_log_group.applications.name,
    aws_cloudwatch_log_group.k3s.name
  ]

  query_string = <<-QUERY
    fields @timestamp, @message
    | filter @message like /ERROR/
    | sort @timestamp desc
    | limit 100
  QUERY
}

# Query for API performance
resource "aws_cloudwatch_query_definition" "api_performance" {
  name = "${var.project_name}-${var.environment}-api-performance"

  log_group_names = [
    aws_cloudwatch_log_group.applications.name
  ]

  query_string = <<-QUERY
    fields @timestamp, method, path, status_code, response_time
    | filter status_code >= 400
    | stats avg(response_time), max(response_time), count() by path
    | sort avg(response_time) desc
  QUERY
}

# Query for top requests
resource "aws_cloudwatch_query_definition" "top_requests" {
  name = "${var.project_name}-${var.environment}-top-requests"

  log_group_names = [
    aws_cloudwatch_log_group.applications.name
  ]

  query_string = <<-QUERY
    fields @timestamp, path
    | stats count() as request_count by path
    | sort request_count desc
    | limit 20
  QUERY
}