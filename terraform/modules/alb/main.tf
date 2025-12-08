# ============================================
# ALB Module - Application Load Balancer
# ============================================
# Creates ALB for routing traffic to K3s cluster
# ============================================

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# ============================================
# Target Groups
# ============================================

# Target Group for API Gateway (port 3000)
resource "aws_lb_target_group" "api_gateway" {
  name     = "${var.project_name}-${var.environment}-api-gw-tg"
  port     = 30000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-api-gateway-tg"
      Service = "api-gateway"
    }
  )
}

# Target Group for Inventory App (port 8080)
resource "aws_lb_target_group" "inventory_app" {
  name     = "${var.project_name}-${var.environment}-inventory-tg"
  port     = 30001
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-inventory-tg"
      Service = "inventory-app"
    }
  )
}

# Target Group for Billing App (port 8080)
resource "aws_lb_target_group" "billing_app" {
  name     = "${var.project_name}-${var.environment}-billing-tg"
  port     = 30002
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name    = "${var.project_name}-${var.environment}-billing-tg"
      Service = "billing-app"
    }
  )
}

# ============================================
# Target Group Attachments (K3s Nodes)
# ============================================

# Attach K3s nodes to API Gateway target group
resource "aws_lb_target_group_attachment" "api_gateway" {
  count = length(var.k3s_instance_ids)

  target_group_arn = aws_lb_target_group.api_gateway.arn
  target_id        = var.k3s_instance_ids[count.index]
  port             = 30000
}

# Attach K3s nodes to Inventory App target group
resource "aws_lb_target_group_attachment" "inventory_app" {
  count = length(var.k3s_instance_ids)

  target_group_arn = aws_lb_target_group.inventory_app.arn
  target_id        = var.k3s_instance_ids[count.index]
  port             = 30001
}

# Attach K3s nodes to Billing App target group
resource "aws_lb_target_group_attachment" "billing_app" {
  count = length(var.k3s_instance_ids)

  target_group_arn = aws_lb_target_group.billing_app.arn
  target_id        = var.k3s_instance_ids[count.index]
  port             = 30002
}

# ============================================
# HTTP Listener (Port 80)
# ============================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = var.tags
}

# ============================================
# Listener Rules - Path-based routing
# ============================================

# Route /api/* to API Gateway
resource "aws_lb_listener_rule" "api_gateway" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "api-gateway-rule"
    }
  )
}

# Route /inventory/* to Inventory App
resource "aws_lb_listener_rule" "inventory_app" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inventory_app.arn
  }

  condition {
    path_pattern {
      values = ["/inventory/*"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "inventory-app-rule"
    }
  )
}

# Route /billing/* to Billing App
resource "aws_lb_listener_rule" "billing_app" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.billing_app.arn
  }

  condition {
    path_pattern {
      values = ["/billing/*"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "billing-app-rule"
    }
  )
}

# ============================================
# HTTPS Listener (Port 443) - Optional
# ============================================

# Uncomment if you have ACM certificate
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
#   certificate_arn   = var.acm_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.api_gateway.arn
#   }
# }

# ============================================
# CloudWatch Alarms for ALB
# ============================================

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "Alert when ALB has unhealthy targets"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.api_gateway.arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Alert when target response time is high"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when there are too many 5xx errors"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = var.tags
}