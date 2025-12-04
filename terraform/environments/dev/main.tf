# ======
# Development Environment - Main Configuration
# ======

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration for remote state
  backend "s3" {
    # These values should be provided via backend config file
    # terraform init -backend-config=backend.hcl
    # bucket         = "cloud-design-dev-terraform-state-ACCOUNT_ID"
    # key            = "dev/terraform.tfstate"
    # region         = "eu-north-1"
    # encrypt        = true
    # dynamodb_table = "cloud-design-dev-terraform-locks"
  }
}

# AWS Provider
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Common tags
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

# =======
# VPC Module
# =======

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  cluster_name       = "${var.project_name}-${var.environment}-k3s"

  tags = local.common_tags
}

# ======
# Security Module
# ======

module "security" {
  source = "../../modules/security"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = module.vpc.vpc_cidr
  ssh_public_key  = var.ssh_public_key

  tags = local.common_tags
}

# ======
# S3 Module
# ======

module "s3" {
  source = "../../modules/s3"

  project_name           = var.project_name
  environment            = var.environment
  logs_retention_days    = var.logs_retention_days
  backups_retention_days = var.backups_retention_days

  tags = local.common_tags
}

# =======
# ECR Module
# =======

module "ecr" {
  source = "../../modules/ecr"

  project_name                   = var.project_name
  environment                    = var.environment
  image_tag_mutability           = var.ecr_image_tag_mutability
  scan_on_push                   = var.ecr_scan_on_push
  max_image_count                = var.ecr_max_image_count
  untagged_image_retention_days  = var.ecr_untagged_retention_days
  allowed_iam_role_arns          = [module.security.k3s_node_role_arn]

  tags = local.common_tags
}

# ======
# RDS Module
# ======

module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  instance_class          = var.rds_instance_class
  postgres_version        = var.rds_postgres_version
  allocated_storage       = var.rds_allocated_storage
  storage_type            = var.rds_storage_type
  master_username         = var.rds_master_username
  inventory_db_name       = var.rds_inventory_db_name
  billing_db_name         = var.rds_billing_db_name
  inventory_db_username   = var.rds_inventory_db_username
  billing_db_username     = var.rds_billing_db_username
  db_subnet_group_name    = module.vpc.db_subnet_group_name
  rds_security_group_id   = module.security.rds_security_group_id
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window
  skip_final_snapshot     = var.rds_skip_final_snapshot
  multi_az                = var.rds_multi_az
  enable_cloudwatch_logs  = var.rds_enable_cloudwatch_logs
  enable_cloudwatch_alarms = var.rds_enable_cloudwatch_alarms
  deletion_protection     = var.rds_deletion_protection

  tags = local.common_tags
}

# =======
# EC2 Module (K3s Cluster)
# =======

module "ec2" {
  source = "../../modules/ec2"

  project_name              = var.project_name
  environment               = var.environment
  region                    = var.region
  cluster_name              = "${var.project_name}-${var.environment}-k3s"
  public_subnet_ids         = module.vpc.public_subnet_ids
  k3s_security_group_id     = module.security.k3s_nodes_security_group_id
  iam_instance_profile_name = module.security.k3s_node_instance_profile_name
  key_pair_name             = module.security.key_pair_name
  master_instance_type      = var.k3s_master_instance_type
  worker_instance_type      = var.k3s_worker_instance_type
  worker_node_count         = var.k3s_worker_node_count
  k3s_version               = var.k3s_version
  cluster_token             = var.k3s_cluster_token
  use_elastic_ip            = var.k3s_use_elastic_ip
  ecr_registry_url          = module.ecr.registry_url

  tags = local.common_tags

  depends_on = [module.vpc, module.security, module.ecr]
}

# ======
# ALB Module
# ======

module "alb" {
  source = "../../modules/alb"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  alb_security_group_id     = module.security.alb_security_group_id
  k3s_instance_ids          = concat([module.ec2.k3s_master_id], module.ec2.k3s_worker_ids)
  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_cloudwatch_alarms  = var.alb_enable_cloudwatch_alarms
  acm_certificate_arn       = var.alb_acm_certificate_arn

  tags = local.common_tags

  depends_on = [module.ec2]
}

# ======
# Monitoring Module
# ======

module "monitoring" {
  source = "../../modules/monitoring"

  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  log_retention_days = var.monitoring_log_retention_days
  enable_rds_logs    = var.monitoring_enable_rds_logs
  enable_alarms      = var.monitoring_enable_alarms
  enable_sns_alerts  = var.monitoring_enable_sns_alerts
  alert_email        = var.monitoring_alert_email
  ec2_instance_ids   = concat([module.ec2.k3s_master_id], module.ec2.k3s_worker_ids)

  tags = local.common_tags

  depends_on = [module.ec2, module.rds, module.alb]
}