# ======
# Security Module - Security Groups & IAM
# ======

# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - allow all
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
    }
  )
}

# Security Group for K3s Cluster Nodes
resource "aws_security_group" "k3s_nodes" {
  name        = "${var.project_name}-${var.environment}-k3s-nodes-sg"
  description = "Security group for K3s cluster nodes"
  vpc_id      = var.vpc_id

  # SSH access (для управления и отладки)
  ingress {
    description = "SSH from anywhere (restrict in production!)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API Server
  ingress {
    description = "K3s API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
  }

  # Kubelet API
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # NodePort Services (30000-32767)
  ingress {
    description = "K3s NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    self        = true
  }

  # HTTP from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Application ports from ALB
  ingress {
    description     = "API Gateway from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Apps from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow all traffic between K3s nodes
  ingress {
    description = "Allow all from K3s nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Outbound - allow all
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-nodes-sg"
    }
  )
}

# Security Group for RDS Databases
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS PostgreSQL databases"
  vpc_id      = var.vpc_id

  # PostgreSQL from K3s nodes only
  ingress {
    description     = "PostgreSQL from K3s nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s_nodes.id]
  }

  # Outbound - allow all (для updates и patches)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )
}

# ======
# IAM Roles & Policies
# ======

# IAM Role for EC2 instances (K3s nodes)
resource "aws_iam_role" "k3s_node" {
  name = "${var.project_name}-${var.environment}-k3s-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-node-role"
    }
  )
}

# IAM Policy for K3s nodes - ECR access
resource "aws_iam_role_policy" "k3s_ecr_policy" {
  name = "${var.project_name}-${var.environment}-k3s-ecr-policy"
  role = aws_iam_role.k3s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for K3s nodes - CloudWatch logs
resource "aws_iam_role_policy" "k3s_cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-k3s-cloudwatch-policy"
  role = aws_iam_role.k3s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# IAM Policy for K3s nodes - S3 access (for backups and logs)
resource "aws_iam_role_policy" "k3s_s3_policy" {
  name = "${var.project_name}-${var.environment}-k3s-s3-policy"
  role = aws_iam_role.k3s_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile for K3s nodes
resource "aws_iam_instance_profile" "k3s_node" {
  name = "${var.project_name}-${var.environment}-k3s-node-profile"
  role = aws_iam_role.k3s_node.name

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-node-profile"
    }
  )
}

# Key Pair for SSH access (import existing or create new)
resource "aws_key_pair" "k3s" {
  key_name   = "${var.project_name}-${var.environment}-k3s-key"
  public_key = var.ssh_public_key

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-key"
    }
  )
}