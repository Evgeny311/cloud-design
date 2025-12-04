#!/bin/bash
# =======
# K3s Worker Node Installation Script
# =======

set -e

# Variables from Terraform
K3S_VERSION="${k3s_version}"
K3S_TOKEN="${cluster_token}"
MASTER_IP="${master_ip}"
AWS_REGION="${region}"

# Log everything
exec > >(tee /var/log/k3s-install.log)
exec 2>&1

echo "============================================"
echo "Starting K3s Worker Node Installation"
echo "============================================"
echo "K3s Version: $K3S_VERSION"
echo "Master IP: $MASTER_IP"
echo "Region: $AWS_REGION"
date

# Update system
echo "Updating system packages..."
yum update -y

# Install required packages
echo "Installing required packages..."
yum install -y \
    curl \
    wget \
    jq \
    amazon-cloudwatch-agent

# Install Docker
echo "Installing Docker..."
yum install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Configure AWS CLI
echo "Configuring AWS CLI..."
aws configure set default.region $AWS_REGION

# Get private IP
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Private IP: $PRIVATE_IP"
echo "Instance ID: $INSTANCE_ID"

# Wait for master to be ready
echo "Waiting for K3s master to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -k -s https://$MASTER_IP:6443/healthz &> /dev/null; then
        echo "Master is ready!"
        break
    fi
    echo "Master not ready yet, waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: Master node did not become ready in time!"
    exit 1
fi

# Install K3s Worker (Agent)
echo "Installing K3s Worker..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
    K3S_URL="https://$MASTER_IP:6443" \
    K3S_TOKEN="$K3S_TOKEN" \
    sh -s - agent \
    --node-ip="$PRIVATE_IP" \
    --node-name="k3s-worker-$INSTANCE_ID"

# Wait for node to join
echo "Waiting for node to join cluster..."
sleep 30

# Configure CloudWatch agent for logs
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/k3s-install.log",
            "log_group_name": "/aws/ec2/k3s-cluster",
            "log_stream_name": "worker-install-$INSTANCE_ID",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/k3s-agent.log",
            "log_group_name": "/aws/ec2/k3s-cluster",
            "log_stream_name": "worker-k3s-$INSTANCE_ID",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Save node info
cat > /home/ec2-user/node-info.txt << EOF
K3s Worker Node Information
===========================
Instance ID: $INSTANCE_ID
Private IP: $PRIVATE_IP
Master IP: $MASTER_IP
K3s Version: $K3S_VERSION
Installation Date: $(date)

This node is connected to master at: https://$MASTER_IP:6443
EOF

chown ec2-user:ec2-user /home/ec2-user/node-info.txt

echo "============================================"
echo "K3s Worker Installation Complete!"
echo "============================================"
echo "Node: k3s-worker-$INSTANCE_ID"
echo "Connected to master: $MASTER_IP"
date