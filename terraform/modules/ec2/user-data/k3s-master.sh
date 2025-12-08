#!/bin/bash
# =======
# K3s Master Node Installation Script
# =======

set -e

# Variables from Terraform
K3S_VERSION="${k3s_version}"
K3S_TOKEN="${cluster_token}"
CLUSTER_NAME="${cluster_name}"
AWS_REGION="${region}"
ECR_REGISTRY="${ecr_registry_url}"

# Log everything
exec > >(tee /var/log/k3s-install.log)
exec 2>&1

echo "============================================"
echo "Starting K3s Master Node Installation"
echo "============================================"
echo "K3s Version: $K3S_VERSION"
echo "Cluster Name: $CLUSTER_NAME"
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
    git \
    jq \
    amazon-cloudwatch-agent

# Install Docker (for building images if needed)
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

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Get private IP for K3s
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP: $PRIVATE_IP"

# Install K3s Master
echo "Installing K3s Master..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_SKIP_SELINUX_RPM=true sh -s - server \
    --token="$K3S_TOKEN" \
    --node-ip="$PRIVATE_IP" \
    --advertise-address="$PRIVATE_IP" \
    --cluster-init \
    --disable=traefik \
    --write-kubeconfig-mode=644 \
    --node-name="k3s-master" \
    --kube-apiserver-arg="service-node-port-range=30000-32767"

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
until kubectl get nodes &> /dev/null; do
    echo "Waiting for K3s API server..."
    sleep 5
done

# Label master node
echo "Labeling master node..."
kubectl label node k3s-master node-role.kubernetes.io/master=true --overwrite

# Configure ECR authentication if provided
if [ -n "$ECR_REGISTRY" ]; then
    echo "Configuring ECR authentication..."
    
    # Create ECR credential helper script
    cat > /usr/local/bin/ecr-credential-helper.sh << 'EOFSCRIPT'
#!/bin/bash
AWS_REGION="${region}"
AWS_ACCOUNT_ID=$(echo "$ECR_REGISTRY" | cut -d'.' -f1)
TOKEN=$(aws ecr get-login-password --region $AWS_REGION)
echo "{\"auths\":{\"$ECR_REGISTRY\":{\"auth\":\"$(echo AWS:$TOKEN | base64 -w0)\"}}}"
EOFSCRIPT
    
    chmod +x /usr/local/bin/ecr-credential-helper.sh
    
    # Create ImagePullSecret for ECR
    kubectl create secret docker-registry ecr-secret \
        --docker-server=$ECR_REGISTRY \
        --docker-username=AWS \
        --docker-password=$(aws ecr get-login-password --region $AWS_REGION) \
        --namespace=default || echo "Secret already exists"
fi

# Install Metrics Server for HPA
echo "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch Metrics Server for K3s (disable TLS verification)
kubectl patch deployment metrics-server -n kube-system --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

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
            "log_group_name": "/aws/ec2/${cluster_name}",
            "log_stream_name": "master-install-{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/k3s.log",
            "log_group_name": "/aws/ec2/${cluster_name}",
            "log_stream_name": "master-k3s-{instance_id}",
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

# Copy kubeconfig for ec2-user
echo "Setting up kubeconfig for ec2-user..."
mkdir -p /home/ec2-user/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube
chmod 600 /home/ec2-user/.kube/config

# Create convenience aliases
cat >> /home/ec2-user/.bashrc << 'EOF'

# K3s aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
export KUBECONFIG=/home/ec2-user/.kube/config
EOF

chown ec2-user:ec2-user /home/ec2-user/.bashrc

# Save cluster info
echo "Saving cluster information..."
cat > /home/ec2-user/cluster-info.txt << EOF
K3s Master Node Information
===========================
Cluster Name: $CLUSTER_NAME
K3s Version: $K3S_VERSION
Private IP: $PRIVATE_IP
Installation Date: $(date)

Useful Commands:
---------------
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info

Get kubeconfig:
--------------
sudo cat /etc/rancher/k3s/k3s.yaml

Join worker command:
-------------------
curl -sfL https://get.k3s.io | K3S_URL=https://$PRIVATE_IP:6443 K3S_TOKEN=$K3S_TOKEN sh -
EOF

chown ec2-user:ec2-user /home/ec2-user/cluster-info.txt

# Final status check
echo "============================================"
echo "K3s Master Installation Complete!"
echo "============================================"
kubectl get nodes
echo ""
echo "Cluster is ready!"
date