# Deployment Guide

Complete step-by-step guide for deploying the Cloud-Design project to AWS.

---

## Prerequisites

### Required Tools

Install these tools before starting:

```bash
# AWS CLI (v2)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform (>= 1.0)
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# kubectl (>= 1.27)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### AWS Account Setup

1. **Create AWS Account**
   - Go to https://aws.amazon.com
   - Sign up for free tier
   - Enable billing

2. **Create IAM User**
   ```bash
   # In AWS Console:
   # IAM → Users → Add User
   # - Username: terraform-user
   # - Access type: Programmatic access
   # - Permissions: AdministratorAccess (for learning)
   # - Download credentials CSV
   ```

3. **Configure AWS CLI**
   ```bash
   aws configure
   # AWS Access Key ID: <your-key>
   # AWS Secret Access Key: <your-secret>
   # Default region: eu-north-1
   # Default output format: json
   ```

4. **Verify Configuration**
   ```bash
   aws sts get-caller-identity
   # Should show your account ID and user ARN
   ```

---

## Step 1: Initial Setup

### 1.1 Run Setup Script

```bash
cd cloud-design
chmod +x scripts/*.sh
./scripts/setup-aws.sh
```

This script will:
- ✅ Check AWS CLI installation
- ✅ Verify credentials
- ✅ Test permissions
- ✅ Generate SSH keys
- ✅ Check other required tools

### 1.2 Generate SSH Key

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cloud-design-dev -C "cloud-design-dev"
# Don't set a passphrase (press Enter twice)
```

### 1.3 Get Your SSH Public Key

```bash
cat ~/.ssh/cloud-design-dev.pub
# Copy this - you'll need it for terraform.tfvars
```

---

## Step 2: Configure Terraform

### 2.1 Navigate to Environment

```bash
cd terraform/environments/dev
```

### 2.2 Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2.3 Edit terraform.tfvars

```bash
nano terraform.tfvars
# or use your favorite editor
```

**Required changes:**

```hcl
# Your SSH public key (from step 1.3)
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA... your-key-here"

# Generate secure token for K3s
# Run: openssl rand -base64 32
k3s_cluster_token = "your-secure-token-here"

# Optional: Your email for alerts
monitoring_alert_email = "your-email@example.com"
```

### 2.4 Update backend.hcl

```bash
# Get your AWS Account ID
aws sts get-caller-identity --query Account --output text

# Edit backend.hcl
nano backend.hcl

# Replace REPLACE_WITH_ACCOUNT_ID with your account ID
bucket = "cloud-design-dev-terraform-state-123456789012"
```

---

## Step 3: Deploy Infrastructure

### 3.1 Initialize Terraform

**First time setup (bootstrap):**

```bash
cd terraform/environments/dev

# Step 1: Comment out backend block in main.tf
# Edit main.tf and comment out lines 17-23:
#   backend "s3" {
#     # bucket         = "..."
#     # ...
#   }

# Step 2: Initialize without backend
terraform init

# Step 3: Create S3 bucket and DynamoDB table
terraform apply -target=module.s3

# Step 4: Uncomment backend block in main.tf

# Step 5: Reinitialize with backend
terraform init -backend-config=backend.hcl
# Answer "yes" to migrate state to S3
```

**Subsequent runs:**

```bash
terraform init -backend-config=backend.hcl
```

### 3.2 Plan Deployment

```bash
terraform plan
```

Review the plan carefully:
- ✅ Check resource counts
- ✅ Verify instance types
- ✅ Confirm regions and AZs
- ✅ Review estimated costs

### 3.3 Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**This will create:**
- VPC with subnets
- Security groups
- EC2 instances (K3s cluster)
- RDS PostgreSQL instance
- ECR repositories
- ALB load balancer
- S3 buckets
- CloudWatch resources

**Time:** ~15-20 minutes

### 3.4 Save Outputs

```bash
terraform output > ../../outputs.txt
```

Important outputs:
- K3s master public IP
- RDS endpoint
- ECR registry URL
- ALB DNS name

---

## Step 4: Verify Infrastructure

### 4.1 Check K3s Cluster

```bash
# Get master IP from outputs
MASTER_IP=$(terraform output -raw k3s_master_public_ip)

# SSH to master
ssh -i ~/.ssh/cloud-design-dev ec2-user@$MASTER_IP

# Check K3s status
sudo kubectl get nodes
# Should show master + 2 workers in Ready state

# Check system pods
sudo kubectl get pods -A

# Exit
exit
```

### 4.2 Get Kubeconfig

```bash
# From your local machine
MASTER_IP=$(terraform output -raw k3s_master_public_ip)

# Download kubeconfig
ssh -i ~/.ssh/cloud-design-dev ec2-user@$MASTER_IP 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config

# Update server address
sed -i "s/127.0.0.1/$MASTER_IP/g" ~/.kube/config

# Test connection
kubectl get nodes
```

### 4.3 Check RDS

```bash
# Get RDS endpoint
terraform output rds_endpoint

# Should be accessible from K3s nodes only
```

---

## Step 5: Initialize Databases

### 5.1 Get Database Credentials

```bash
# Get secrets from AWS Secrets Manager
aws secretsmanager get-secret-value \
    --secret-id cloud-design-dev-inventory-db \
    --query SecretString --output text | jq .

aws secretsmanager get-secret-value \
    --secret-id cloud-design-dev-billing-db \
    --query SecretString --output text | jq .
```

### 5.2 Run Initialization Script

```bash
cd ../../../terraform/modules/rds

# Run init script
./init-databases.sh \
    <RDS_ENDPOINT> \
    <MASTER_USER> \
    <MASTER_PASSWORD> \
    <INVENTORY_USER> \
    <INVENTORY_PASSWORD> \
    <BILLING_USER> \
    <BILLING_PASSWORD>
```

This creates:
- ✅ `inventory` database
- ✅ `billing` database
- ✅ Users with permissions
- ✅ Initial schema
- ✅ Sample data

---

## Step 6: Build and Push Docker Images

### 6.1 Login to ECR

```bash
cd ../../../

# The script will handle ECR login
# Make sure you have play-with-containers project
ls ../play-with-containers/
# Should show srcs/ directory
```

### 6.2 Build and Push Images

```bash
./scripts/build-and-push-images.sh dev v1.0.0
```

This will:
- ✅ Login to ECR
- ✅ Build api-gateway image
- ✅ Build inventory-app image
- ✅ Build billing-app image
- ✅ Push all images to ECR
- ✅ Tag as v1.0.0 and latest

**Time:** ~10-15 minutes

### 6.3 Verify Images

```bash
# List ECR repositories
aws ecr describe-repositories

# List images in repository
aws ecr list-images --repository-name cloud-design/dev/api-gateway
```

---

## Step 7: Deploy Applications

### 7.1 Update K8s Manifests

```bash
# Get ECR registry URL
ECR_REGISTRY=$(terraform output -raw ecr_registry_url -state=terraform/environments/dev/terraform.tfstate)

# Update deployment manifests with ECR URLs
# This is done automatically by deploy script
```

### 7.2 Deploy to K3s

```bash
./scripts/deploy-applications.sh dev v1.0.0
```

This will:
- ✅ Create namespace
- ✅ Apply ConfigMaps
- ✅ Create Secrets from AWS Secrets Manager
- ✅ Deploy RabbitMQ
- ✅ Deploy microservices
- ✅ Apply HPA
- ✅ Wait for pods to be ready

**Time:** ~5-10 minutes

### 7.3 Verify Deployment

```bash
# Check pods
kubectl get pods -n microservices

# Check services
kubectl get svc -n microservices

# Check HPA
kubectl get hpa -n microservices

# View logs
kubectl logs -f deployment/api-gateway -n microservices
```

---

## Step 8: Test Application

### 8.1 Get ALB DNS

```bash
cd terraform/environments/dev
terraform output alb_dns_name
# Example: cloud-design-dev-alb-1234567890.eu-north-1.elb.amazonaws.com
```

### 8.2 Test Endpoints

```bash
cd ../../..
./scripts/test-endpoints.sh dev
```

Or manually:

```bash
ALB_DNS="<your-alb-dns>"

# Test API Gateway
curl http://$ALB_DNS/api/health

# Test Inventory
curl http://$ALB_DNS/inventory/movies

# Test Billing
curl http://$ALB_DNS/billing/orders
```

### 8.3 Expected Responses

```json
// Health check
{"status": "healthy", "service": "api-gateway"}

// Movies
[
  {
    "id": 1,
    "title": "The Shawshank Redemption",
    "director": "Frank Darabont"
  }
]

// Orders
[
  {
    "id": 1,
    "user_id": 1,
    "movie_id": 1,
    "price": 9.99,
    "status": "completed"
  }
]
```

---

## Step 9: Monitor Application

### 9.1 Access CloudWatch Dashboard

```bash
# Get dashboard URL
terraform output -raw cloudwatch_dashboard_url
```

Or go to:
- AWS Console → CloudWatch → Dashboards

### 9.2 View Logs

```bash
# Application logs
aws logs tail /aws/cloud-design/dev/applications --follow

# K3s logs
aws logs tail /aws/cloud-design/dev/k3s --follow
```

### 9.3 Check Metrics

```bash
# Pod metrics (requires metrics-server)
kubectl top pods -n microservices

# Node metrics
kubectl top nodes
```

---

## Updating Application

### Update Code and Redeploy

```bash
# 1. Make changes to your application code
# in ../play-with-containers/srcs/

# 2. Build new images with new version
./scripts/build-and-push-images.sh dev v1.0.1

# 3. Deploy updated version
./scripts/deploy-applications.sh dev v1.0.1

# 4. Monitor rollout
kubectl rollout status deployment/api-gateway -n microservices
```

### Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/api-gateway -n microservices

# Check rollout history
kubectl rollout history deployment/api-gateway -n microservices
```

---

## Cleanup

### Option 1: Destroy Everything

```bash
./scripts/cleanup.sh dev
```

This will:
- ✅ Delete K8s resources
- ✅ Empty S3 buckets
- ✅ Delete ECR images
- ✅ Run terraform destroy
- ✅ Verify cleanup

**Warning:** This is irreversible!

### Option 2: Manual Cleanup

```bash
# Delete K8s resources
kubectl delete namespace microservices

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy

# Manual verification
aws ec2 describe-instances
aws rds describe-db-instances
```

---

## Troubleshooting

See [troubleshooting.md](troubleshooting.md) for common issues and solutions.

---

## Production Deployment

For production deployment:

1. Use `terraform/environments/prod`
2. Enable Multi-AZ for RDS
3. Enable deletion protection
4. Use HTTPS with ACM certificate
5. Enable SNS alerts
6. Use stronger instance types
7. Set longer backup retention

```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit with production values
terraform init -backend-config=backend.hcl
terraform apply
```

---

## Next Steps

1. **Set up CI/CD** - GitLab CI/CD integration
2. **Add monitoring** - Prometheus + Grafana
3. **Implement logging** - ELK stack
4. **Add tracing** - Jaeger or AWS X-Ray
5. **Security hardening** - WAF, Shield, GuardDuty

---

## Support

For issues or questions:
- Check [troubleshooting.md](troubleshooting.md)
- Review [architecture.md](architecture.md)
- Check AWS CloudWatch logs
- Verify Security Group rules