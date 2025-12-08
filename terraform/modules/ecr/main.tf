# ======
# ECR Module - Docker Container Registry
# ======
# Creates ECR repositories for microservices
# ======

# ECR Repository for API Gateway
resource "aws_ecr_repository" "api_gateway" {
  name                 = "${var.project_name}/${var.environment}/api-gateway"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-api-gateway"
      Service     = "api-gateway"
      Environment = var.environment
    }
  )
}

# ECR Repository for Inventory App
resource "aws_ecr_repository" "inventory_app" {
  name                 = "${var.project_name}/${var.environment}/inventory"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-inventory"
      Service     = "inventory"
      Environment = var.environment
    }
  )
}

# ECR Repository for Billing App
resource "aws_ecr_repository" "billing_app" {
  name                 = "${var.project_name}/${var.environment}/billing"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-billing"
      Service     = "billing"
      Environment = var.environment
    }
  )
}

# ======
# Lifecycle Policies - Clean up old images
# ======

# Lifecycle policy for API Gateway
resource "aws_ecr_lifecycle_policy" "api_gateway" {
  repository = aws_ecr_repository.api_gateway.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy for Inventory App
resource "aws_ecr_lifecycle_policy" "inventory_app" {
  repository = aws_ecr_repository.inventory_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Lifecycle policy for Billing App
resource "aws_ecr_lifecycle_policy" "billing_app" {
  repository = aws_ecr_repository.billing_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${var.untagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ============================================
# Repository Policies - Access Control
# ============================================

# Allow pulling images from K3s nodes
data "aws_iam_policy_document" "ecr_policy" {
  statement {
    sid    = "AllowPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_iam_role_arns
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }

  statement {
    sid    = "AllowPush"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_iam_role_arns
    }

    actions = [
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }
}

resource "aws_ecr_repository_policy" "api_gateway" {
  repository = aws_ecr_repository.api_gateway.name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

resource "aws_ecr_repository_policy" "inventory_app" {
  repository = aws_ecr_repository.inventory_app.name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

resource "aws_ecr_repository_policy" "billing_app" {
  repository = aws_ecr_repository.billing_app.name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}