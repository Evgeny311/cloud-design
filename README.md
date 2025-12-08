# Cloud-Design - AWS Microservices Deployment

> **DevOps Project:** Deploy a microservices-based application on AWS using Terraform, K3s, and modern cloud practices.

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange)](https://aws.amazon.com)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/K3s-Lightweight_K8s-blue)](https://k3s.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)](https://postgresql.org)

---

## 📋 Project Overview

This project demonstrates a complete cloud-native microservices deployment on AWS, implementing DevOps best practices and modern cloud architecture.

**Key Features:**
- ✅ Infrastructure as Code with Terraform
- ✅ Lightweight Kubernetes (K3s) orchestration
- ✅ Microservices architecture with Python Flask
- ✅ AWS managed services (RDS, ECR, ALB, CloudWatch)
- ✅ Cost-optimized for Free Tier eligibility
- ✅ Production-ready monitoring and logging
- ✅ Security best practices implemented

---

## 🏗️ Architecture

```
                    ┌─────────────┐
                    │   Internet  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ ALB (Load   │
                    │  Balancer)  │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐        ┌───▼────┐        ┌───▼────┐
   │   K3s   │        │  K3s   │        │  K3s   │
   │ Master  │        │ Worker │        │ Worker │
   │(t2.micro)       │(t2.micro)       │(t2.micro)
   └────┬────┘        └───┬────┘        └───┬────┘
        │                 │                  │
        └─────────────────┼──────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
   ┌────▼─────┐    ┌─────▼─────┐    ┌─────▼─────┐
   │ RabbitMQ │    │    RDS    │    │    ECR    │
   │   Pod    │    │PostgreSQL │    │  Docker   │
   │          │    │(inventory │    │ Registry  │
   └──────────┘    │ + billing)│    └───────────┘
                   └───────────┘
```

---

## 🎯 Components

| Component | Technology | Port | Purpose |
|-----------|-----------|------|---------|
| **API Gateway** | Python Flask | 3000 | Routes requests to microservices |
| **Inventory Service** | Python Flask + PostgreSQL | 8080 | Manages movie inventory (CRUD) |
| **Billing Service** | Python Flask + PostgreSQL + RabbitMQ | 8080 | Processes orders asynchronously |
| **Message Queue** | RabbitMQ 3.12 | 5672, 15672 | Decouples billing service |
| **Databases** | Amazon RDS (PostgreSQL 15) | 5432 | Stores inventory & billing data |
| **Container Registry** | Amazon ECR | - | Docker image storage & scanning |
| **Load Balancer** | AWS ALB | 80, 443 | Distributes traffic across K3s nodes |
| **Monitoring** | AWS CloudWatch | - | Logs, metrics, dashboards, alarms |
| **Orchestration** | K3s on EC2 | 6443 | Lightweight Kubernetes cluster |

---

## 📁 Project Structure

```
cloud-design/
├── README.md                          # This file
├── docs/                              # Detailed documentation
│   ├── architecture.md                # Architecture deep-dive
│   ├── cost-estimation.md             # Cost analysis ($0-5/month in Free Tier)
│   ├── deployment-guide.md            # Step-by-step deployment instructions
│   ├── security.md                    # Security best practices
│   └── troubleshooting.md             # Common issues & solutions
│
├── terraform/                         # Infrastructure as Code
│   ├── modules/                       # Reusable Terraform modules
│   │   ├── vpc/                       # VPC, subnets, internet gateway
│   │   ├── ec2/                       # K3s cluster EC2 instances
│   │   ├── rds/                       # PostgreSQL RDS database
│   │   ├── alb/                       # Application Load Balancer
│   │   ├── ecr/                       # Elastic Container Registry
│   │   ├── s3/                        # S3 buckets (state, logs, backups)
│   │   └── cloudwatch/                # Monitoring, logging, alarms
│   │
│   └── environments/                  # Environment-specific configs
│       ├── dev/                       # Development (Free Tier optimized)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── backend.hcl
│       │   └── terraform.tfvars.example
│       └── prod/                      # Production (future)
│
├── k8s/                               # Kubernetes manifests
│   ├── namespace.yaml
│   ├── configmaps/
│   ├── secrets/
│   ├── deployments/
│   ├── services/
│   └── hpa/                           # Horizontal Pod Autoscaling
│
├── scripts/                           # Automation scripts
│   ├── setup-aws.sh                   # AWS prerequisites check
│   ├── build-and-push-images.sh       # Build & push to ECR
│   ├── deploy-applications.sh         # Deploy to K3s cluster
│   ├── test-endpoints.sh              # Test application endpoints
│   └── cleanup.sh                     # Destroy all resources
│
└── monitoring/                        # Monitoring configurations
    ├── dashboards/
    └── alerts/
```

---

## 💰 Cost Estimation

### Development (Free Tier Eligible)

| Service | Instance Type | Free Tier | Monthly Cost |
|---------|--------------|-----------|--------------|
| **EC2** (3 instances) | t2.micro | ✅ 750h/month | **$0** |
| **RDS** | db.t3.micro | ✅ 750h/month | **$0** |
| **ALB** | - | ✅ 750h/month | **$0** |
| **S3** | ~2GB | ✅ 5GB free | **$0** |
| **ECR** | ~1GB | ⚠️ Partial | **$0.50** |
| **CloudWatch** | Logs + Metrics | ⚠️ Partial | **$1-2** |
| **Secrets Manager** | 3 secrets | ❌ No | **$1.20** |

**Total: $2-5/month** (within Free Tier) 💰

### After Free Tier (12 months)
- **~$60-70/month** for 24/7 operation
- **~$3-8/month** using Deploy-Test-Destroy strategy

**📊 Detailed breakdown:** See [docs/cost-estimation.md](docs/cost-estimation.md)

**💡 Cost Savings vs EKS:**
- EKS Control Plane: $72/month
- K3s on EC2: **$0/month**
- **Annual savings: ~$860!** 🎉

---

## 🚀 Quick Start

### Prerequisites

Ensure you have these tools installed:

- ✅ **AWS Account** with billing enabled
- ✅ **AWS CLI** (v2) configured
- ✅ **Terraform** >= 1.0
- ✅ **kubectl** >= 1.27
- ✅ **Docker** installed
- ✅ **Git** for version control

Check prerequisites:
```bash
./scripts/setup-aws.sh
```

---

### 1️⃣ Clone and Setup

```bash
# Clone repository
git clone <your-repo>
cd cloud-design

# Generate SSH key for EC2 instances
ssh-keygen -t rsa -b 4096 -f ~/.ssh/cloud-design-dev -C "cloud-design-dev"
# Press Enter twice (no passphrase)

# Copy your public key
cat ~/.ssh/cloud-design-dev.pub
```

---

### 2️⃣ Configure Terraform

```bash
cd terraform/environments/dev

# Create your configuration from example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Required changes:**
```hcl
# Paste your SSH public key
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAA... your-key-here"

# Generate secure token
# Run: openssl rand -base64 32
k3s_cluster_token = "your-secure-token-here"

# Optional: your email for alerts
monitoring_alert_email = "your-email@example.com"
```

**✅ Default values are already optimized for Free Tier!**

---

### 3️⃣ Deploy Infrastructure

```bash
# Initialize Terraform (first time only)
# See docs/deployment-guide.md for detailed bootstrap instructions
terraform init -backend-config=backend.hcl

# Review what will be created
terraform plan

# Deploy infrastructure (15-20 minutes)
terraform apply
```

This creates:
- ✅ VPC with public/private subnets
- ✅ K3s cluster (1 master + 2 workers)
- ✅ RDS PostgreSQL database
- ✅ Application Load Balancer
- ✅ ECR repositories
- ✅ S3 buckets & CloudWatch monitoring

---

### 4️⃣ Initialize Databases

```bash
cd ../../../terraform/modules/rds

# Get credentials from AWS Secrets Manager
# See deployment-guide.md for detailed instructions

# Run initialization script
./init-databases.sh \
  <RDS_ENDPOINT> \
  <MASTER_USER> \
  <MASTER_PASSWORD> \
  <INVENTORY_USER> \
  <INVENTORY_PASSWORD> \
  <BILLING_USER> \
  <BILLING_PASSWORD>
```

---

### 5️⃣ Build & Deploy Applications

```bash
cd ../../../../

# Build Docker images and push to ECR (10-15 minutes)
./scripts/build-and-push-images.sh dev v1.0.0

# Deploy to K3s cluster (5-10 minutes)
./scripts/deploy-applications.sh dev v1.0.0

# Verify deployment
kubectl get pods -n microservices
```

---

### 6️⃣ Test Application

```bash
# Automated testing
./scripts/test-endpoints.sh dev

# Or manually
ALB_DNS=$(terraform output -raw alb_dns_name -state=terraform/environments/dev/terraform.tfstate)

# Test API Gateway
curl http://$ALB_DNS/api/health

# Get movies from inventory
curl http://$ALB_DNS/inventory/movies

# Get orders from billing
curl http://$ALB_DNS/billing/orders
```

**Expected responses:**
```json
// Health check
{"status": "healthy", "service": "api-gateway"}

// Movies
[{"id": 1, "title": "The Shawshank Redemption", "director": "Frank Darabont"}]

// Orders
[{"id": 1, "user_id": 1, "movie_id": 1, "price": 9.99, "status": "completed"}]
```

---

## 📚 Detailed Documentation

| Document | Description |
|----------|-------------|
| [Architecture Overview](docs/architecture.md) | Deep-dive into system design, data flow, and component interactions |
| [Deployment Guide](docs/deployment-guide.md) | Complete step-by-step deployment instructions with troubleshooting |
| [Cost Estimation](docs/cost-estimation.md) | Detailed cost analysis, optimization strategies, and Free Tier usage |
| [Security Best Practices](docs/security.md) | Network security, IAM, encryption, and compliance guidelines |
| [Troubleshooting](docs/troubleshooting.md) | Common issues, error messages, and solutions |

---

## 🛠️ Development Workflow

### Update Application Code

```bash
# 1. Make changes in ../play-with-containers/srcs/

# 2. Rebuild and push new version
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

## 📊 Monitoring & Logging

### CloudWatch Dashboard

```bash
# Get dashboard URL
terraform output -raw cloudwatch_dashboard_url -state=terraform/environments/dev/terraform.tfstate
```

### View Logs

```bash
# Application logs
aws logs tail /aws/cloud-design/dev/applications --follow

# K3s cluster logs
aws logs tail /aws/cloud-design/dev/k3s --follow

# Or using kubectl
kubectl logs -f deployment/api-gateway -n microservices
```

### Metrics

```bash
# Pod metrics
kubectl top pods -n microservices

# Node metrics
kubectl top nodes

# HPA status
kubectl get hpa -n microservices
```

---

## 🔒 Security

This project implements AWS Well-Architected Framework security best practices:

- ✅ **Network isolation:** VPC with public/private subnets
- ✅ **Encryption at rest:** RDS, S3, EBS volumes (AES-256)
- ✅ **Secrets management:** AWS Secrets Manager (no hardcoded credentials)
- ✅ **Least privilege IAM:** Minimal permissions for EC2 instances
- ✅ **Security Groups:** Restricted access (ALB → K3s → RDS)
- ✅ **Container scanning:** ECR automatic vulnerability scanning
- ✅ **Audit logging:** CloudWatch Logs for all components

**📖 Details:** See [docs/security.md](docs/security.md)

---

## 🧹 Cleanup

### ⚠️ Destroy All Resources

**Warning:** This will permanently delete all infrastructure!

```bash
# Automated cleanup
./scripts/cleanup.sh dev

# Confirm by typing 'yes' and 'dev'
```

This will:
1. Delete all Kubernetes resources
2. Empty S3 buckets
3. Delete ECR images
4. Run `terraform destroy`
5. Verify complete cleanup

### Manual Cleanup

```bash
# Delete K8s resources
kubectl delete namespace microservices

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy

# Verify
aws ec2 describe-instances --filters "Name=tag:Project,Values=cloud-design"
```

---

## 🎓 Learning Outcomes

By completing this project, you will learn:

- ✅ Infrastructure as Code with Terraform
- ✅ AWS cloud services (VPC, EC2, RDS, ALB, ECR, CloudWatch)
- ✅ Kubernetes orchestration (K3s)
- ✅ Container technologies (Docker, ECR)
- ✅ Microservices architecture patterns
- ✅ CI/CD concepts and automation
- ✅ Monitoring and observability
- ✅ Cloud security best practices
- ✅ Cost optimization strategies

---

## 🐛 Troubleshooting

### Common Issues

**Terraform errors during apply:**
- See [docs/troubleshooting.md](docs/troubleshooting.md#terraform-issues)

**K3s nodes not joining:**
- Check security groups: `aws ec2 describe-security-groups`
- Verify K3s token matches on all nodes
- Review logs: `sudo journalctl -u k3s -f`

**Pods not starting:**
- Check ECR credentials: `kubectl get secret ecr-secret -n microservices`
- View pod logs: `kubectl logs <pod-name> -n microservices`
- Describe pod: `kubectl describe pod <pod-name> -n microservices`

**Can't access application via ALB:**
- Check target health: `aws elbv2 describe-target-health --target-group-arn <arn>`
- Verify NodePort services: `kubectl get svc -n microservices`
- Test directly: `curl http://<node-ip>:30000/health`

**📖 Full troubleshooting guide:** [docs/troubleshooting.md](docs/troubleshooting.md)

---

## 🏆 Project Requirements Checklist

This project fulfills all Cloud-Design requirements:

- ✅ Set up AWS environment for microservices
- ✅ Deploy microservices to AWS
- ✅ Implement monitoring, logging, and scaling
- ✅ Implement security measures (VPC, encryption, Secrets Manager)
- ✅ Private resources accessible only from VPC
- ✅ Optimize for varying workloads (HPA)
- ✅ Infrastructure as Code (Terraform)
- ✅ Container orchestration (K3s/Kubernetes)
- ✅ Cost optimization strategies
- ✅ Comprehensive documentation

---

## 👨‍💻 Author

**eandreyc**  
Kood/Jõhvi DevOps Curriculum

---

## 📄 License

This project is part of the Kood/Jõhvi educational program.

---

## ⚠️ Important Notes

### Cost Management

- 🎯 **Set up billing alerts:** AWS Console → Billing → Budgets → Create ($10-20 threshold)
- 🎯 **Use Deploy-Test-Destroy strategy** for minimal costs during learning
- 🎯 **Monitor daily costs:** AWS Console → Cost Explorer
- 🎯 **Always destroy resources** when not in use: `./scripts/cleanup.sh dev`

### Production Deployment

This configuration is optimized for **development and testing**. For production:

- ⬆️ Upgrade to larger instances (t3.small/medium)
- ✅ Enable Multi-AZ for RDS
- ✅ Increase backup retention (7-30 days)
- ✅ Enable HTTPS with ACM certificate
- ✅ Add WAF for web application firewall
- ✅ Enable deletion protection
- ✅ Implement CI/CD pipeline
- ✅ Add monitoring alerts (SNS)

---

## 🆘 Getting Help

- 📖 **Documentation:** Check [docs/](docs/) folder
- 🐛 **Common Issues:** See [troubleshooting.md](docs/troubleshooting.md)
- 💬 **Community:** Kood/Jõhvi Discord
- 📧 **Feedback:** Create an issue in the repository

---

## 🚀 Next Steps

After successfully deploying:

1. **Explore CloudWatch dashboards** - Monitor application performance
2. **Test auto-scaling** - Generate load and watch HPA in action
3. **Try deployment updates** - Update code and redeploy
4. **Review security** - Audit IAM policies and security groups
5. **Optimize costs** - Analyze usage and implement savings