# ======
# RDS Module - PostgreSQL Database
# ======
# Single RDS instance with two databases:
# - inventory
# - billing
# ======

# Random password for master user
resource "random_password" "db_master_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Main RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.postgres_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = var.storage_type
  storage_encrypted    = true

  # Database configuration
  db_name  = "postgres" # Default database
  username = var.master_username
  password = random_password.db_master_password.result
  port     = 5432

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  maintenance_window     = var.maintenance_window
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # High Availability (disable for Free Tier)
  multi_az = var.multi_az

  # Performance Insights (disable for Free Tier)
  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs ? ["postgresql", "upgrade"] : []

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Auto minor version upgrade
  auto_minor_version_upgrade = true

  # Copy tags to snapshots
  copy_tags_to_snapshot = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-postgres"
    }
  )

  lifecycle {
    ignore_changes = [password]
  }
}

# Store master password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_master_password" {
  name = "${var.project_name}-${var.environment}-db-master-password"
  description = "Master password for RDS PostgreSQL instance"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-master-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id = aws_secretsmanager_secret.db_master_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.db_master_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = "postgres"
  })
}

# Store inventory database credentials
resource "aws_secretsmanager_secret" "inventory_db" {
  name = "${var.project_name}-${var.environment}-inventory-db"
  description = "Credentials for inventory database"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-inventory-db"
    }
  )
}

resource "aws_secretsmanager_secret_version" "inventory_db" {
  secret_id = aws_secretsmanager_secret.inventory_db.id
  secret_string = jsonencode({
    username = var.inventory_db_username
    password = random_password.inventory_db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.inventory_db_name
  })
}

# Store billing database credentials
resource "aws_secretsmanager_secret" "billing_db" {
  name = "${var.project_name}-${var.environment}-billing-db"
  description = "Credentials for billing database"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-billing-db"
    }
  )
}

resource "aws_secretsmanager_secret_version" "billing_db" {
  secret_id = aws_secretsmanager_secret.billing_db.id
  secret_string = jsonencode({
    username = var.billing_db_username
    password = random_password.billing_db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.billing_db_name
  })
}

# Random passwords for application databases
resource "random_password" "inventory_db_password" {
  length  = 16
  special = true
}

resource "random_password" "billing_db_password" {
  length  = 16
  special = true
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_storage" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS database connections"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.tags
}