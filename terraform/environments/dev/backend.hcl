# ======
# Backend Configuration for Development
# ======
# Usage: terraform init -backend-config=backend.hcl
# ======

# S3 bucket for storing Terraform state
bucket = "cloud-design-dev-terraform-state-711893265334"

# Path to state file within the bucket
key = "dev/terraform.tfstate"

# AWS region
region = "eu-north-1"

# Enable encryption
encrypt = true

# DynamoDB table for state locking
dynamodb_table = "cloud-design-dev-terraform-locks"

# ======
# SETUP INSTRUCTIONS:
# ======
# 1. Get your AWS Account ID:
#    aws sts get-caller-identity --query Account --output text
#
# 2. Replace REPLACE_WITH_ACCOUNT_ID with your actual account ID
#
# 3. First time setup (chicken-egg problem):
#    a. Comment out the backend block in main.tf
#    b. Run: terraform init
#    c. Run: terraform apply (creates S3 bucket and DynamoDB table)
#    d. Uncomment backend block in main.tf
#    e. Run: terraform init -backend-config=backend.hcl
#    f. Answer "yes" to migrate state to S3
#
# 4. Subsequent runs:
#    terraform init -backend-config=backend.hcl
#    terraform plan
#    terraform apply
# ======