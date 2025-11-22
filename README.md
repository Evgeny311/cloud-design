
# Cloud-Design - AWS Microservices Deployment

## Project Overview

This project deploys a microservices-based application on AWS using Terraform, EKS, and modern DevOps practices.

### Architecture

[Architecture diagram will be here]

### Components

- **Inventory App** - Manages movie inventory
- **Billing App** - Processes orders via RabbitMQ
- **API Gateway** - Routes requests to services
- **PostgreSQL RDS** - Databases (inventory + billing)
- **Amazon MQ** - RabbitMQ managed service
- **EKS** - Kubernetes orchestration
- **CloudWatch** - Monitoring and logging

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Cost Estimation](#cost-estimation)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- AWS Account with billing enabled
- AWS CLI configured
- Terraform >= 1.0
- kubectl >= 1.27
- Docker
- Git

---

## Project Structure
```
cloud-design/
├── README.md
├── docs/                    # Documentation
├── terraform/              # Infrastructure as Code
│   ├── modules/           # Reusable Terraform modules
│   └── environments/      # Environment-specific configs
├── k8s/                   # Kubernetes manifests
├── docker/                # Dockerfiles
├── monitoring/            # Monitoring configs
└── scripts/               # Automation scripts
```

---

## Cost Estimation

[Will be filled in docs/cost-estimation.md]

---

## Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo>
cd cloud-design
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Deploy Applications
```bash
./scripts/deploy-applications.sh
```

### 4. Test
```bash
./scripts/test-endpoints.sh
```

---

## Detailed Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment-guide.md)
- [Cost Estimation](docs/cost-estimation.md)
- [Security Best Practices](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)

---

## Infrastructure Components

### AWS Services Used

- **VPC** - Network isolation
- **EKS** - Kubernetes cluster
- **RDS** - PostgreSQL databases
- **Amazon MQ** - RabbitMQ
- **ECR** - Docker registry
- **ALB** - Load balancing
- **CloudWatch** - Logging & monitoring
- **Secrets Manager** - Credentials
- **Certificate Manager** - HTTPS

---

## Development

[To be filled]

---

## Cleanup
```bash
./scripts/cleanup.sh
```

**Warning:** This will destroy all resources!

---

## Author

#eandreyc

---

## License

This project is part of the Kood/Jõhvi DevOps curriculum.

---

**Note:** Always monitor your AWS costs and clean up resources when not in use!
EOF