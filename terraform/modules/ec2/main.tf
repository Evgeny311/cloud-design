# =======
# EC2 Module - K3s Cluster Nodes
# =======

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =======
# K3s Master Node
# =======

resource "aws_instance" "k3s_master" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.master_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.k3s_security_group_id]
  iam_instance_profile   = var.iam_instance_profile_name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user-data/k3s-master.sh", {
    cluster_token    = var.cluster_token
    k3s_version      = var.k3s_version
    cluster_name     = var.cluster_name
    ecr_registry_url = var.ecr_registry_url
    region           = var.region
  })

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.project_name}-${var.environment}-k3s-master"
      Role                                        = "k3s-master"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    ignore_changes = [user_data]
  }
}

# =======
# K3s Worker Nodes
# =======

resource "aws_instance" "k3s_worker" {
  count = var.worker_node_count

  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.worker_instance_type
  subnet_id              = var.public_subnet_ids[count.index % length(var.public_subnet_ids)]
  vpc_security_group_ids = [var.k3s_security_group_id]
  iam_instance_profile   = var.iam_instance_profile_name
  key_name               = var.key_pair_name

  user_data = templatefile("${path.module}/user-data/k3s-worker.sh", {
    master_ip     = aws_instance.k3s_master.private_ip
    cluster_token = var.cluster_token
    k3s_version   = var.k3s_version
    region        = var.region
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  depends_on = [aws_instance.k3s_master]

  tags = merge(
    var.tags,
    {
      Name                                        = "${var.project_name}-${var.environment}-k3s-worker-${count.index + 1}"
      Role                                        = "k3s-worker"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    ignore_changes = [user_data]
  }
}

# =======
# Elastic IP for K3s Master
# =======

resource "aws_eip" "k3s_master" {
  count    = var.use_elastic_ip ? 1 : 0
  instance = aws_instance.k3s_master.id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-master-eip"
    }
  )
}

# ======
# CloudWatch Log Group for K3s
# ======

resource "aws_cloudwatch_log_group" "k3s" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}-k3s"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-k3s-logs"
    }
  )
}