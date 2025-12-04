# Cloud-Design Architecture Documentation

## Overview

This document describes the architecture of the Cloud-Design project - a microservices-based application deployed on AWS using K3s, Terraform, and modern DevOps practices.

---

## Architecture Diagram

```
        ┌─────────────────────────────────────────────┐
        │               Internet                      │
        └───────────────────────────┬─────────────────┘
                            │
                    ┌───────▼────────┐
                    │  Application   │
                    │ Load Balancer  │
                    │  (AWS ALB)     │
                    └───────┬────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐         ┌───▼────┐         ┌───▼────┐
   │ K3s     │         │ K3s    │         │ K3s    │
   │ Master  │         │ Worker │         │ Worker │
   │ Node    │         │ Node   │         │ Node   │
   │(t3.med) │         │(t3.sm) │         │(t3.sm) │
   └────┬────┘         └───┬────┘         └───┬────┘
        │                  │                   │
        └──────────────────┼───────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼─────┐    ┌──────▼────┐      ┌─────▼─────┐
   │ RabbitMQ │    │   RDS     │      │    ECR    │
   │   Pod    │    │ (PostgreSQL)     │  Docker   │
   │          │    │  - Inventory     │ Registry  │
   └──────────┘    │  - Billing       │           │
                   └───────────┘      |           │
                                      └───────────┘
```

---

## Components

### 1. Networking Layer (VPC)

**VPC Configuration:**
- CIDR: `10.0.0.0/16`
- 2 Availability Zones
- Public Subnets: `10.0.0.0/24`, `10.0.1.0/24`
- Private Subnets: `10.0.10.0/24`, `10.0.11.0/24`
- Internet Gateway for public access
- No NAT Gateway (cost optimization)

**Purpose:**
- Network isolation
- Multi-AZ for high availability
- Separation of public and private resources

---

### 2. Compute Layer (K3s on EC2)

**K3s Cluster:**
- **Master Node:** 1x t3.medium
  - Runs K3s control plane
  - Manages cluster state
  - Schedules workloads
  
- **Worker Nodes:** 2x t3.small
  - Run application pods
  - Distributed across 2 AZs
  - Auto-scaling capable

**Why K3s instead of EKS?**
- Cost optimization (~$72/month savings)
- Full Kubernetes compatibility
- Lightweight and efficient
- Suitable for learning and small deployments
- Easy to upgrade to EKS later

---

### 3. Application Layer (Microservices)

#### 3.1 API Gateway
**Technology:** Python Flask  
**Port:** 3000  
**Replicas:** 2-5 (auto-scaling)  
**Purpose:**
- Single entry point for all requests
- Routes requests to appropriate services
- Request/response transformation

**Endpoints:**
- `GET /health` - Health check
- `GET /api/movies` - Proxy to inventory service
- `POST /api/orders` - Proxy to billing service

#### 3.2 Inventory Service
**Technology:** Python Flask + PostgreSQL  
**Port:** 8080  
**Replicas:** 2-5 (auto-scaling)  
**Purpose:**
- Manages movie inventory
- CRUD operations for movies
- Direct database access

**Database:** `inventory` (PostgreSQL)
- Table: `movies`
- Columns: id, title, director, created_at

#### 3.3 Billing Service
**Technology:** Python Flask + PostgreSQL + RabbitMQ  
**Port:** 8080  
**Replicas:** 2-5 (auto-scaling)  
**Purpose:**
- Processes billing orders
- Consumes messages from RabbitMQ
- Asynchronous order processing

**Database:** `billing` (PostgreSQL)
- Table: `orders`
- Columns: id, user_id, movie_id, price, status, created_at

#### 3.4 Message Queue (RabbitMQ)
**Technology:** RabbitMQ 3.12  
**Port:** 5672 (AMQP), 15672 (Management)  
**Replicas:** 1  
**Purpose:**
- Asynchronous message processing
- Decouples services
- Reliable message delivery

---

### 4. Data Layer

#### 4.1 RDS PostgreSQL
**Configuration:**
- Instance: db.t3.micro
- Storage: 20GB gp3
- Multi-AZ: No (dev), Yes (prod)
- Backup retention: 7 days

**Databases:**
- `inventory` - Movie inventory data
- `billing` - Order and billing data

**Access:**
- Only accessible from K3s nodes
- Private subnet placement
- Encrypted at rest

#### 4.2 ECR (Container Registry)
**Purpose:**
- Store Docker images
- Version control for containers
- Automatic vulnerability scanning

**Repositories:**
- `cloud-design/dev/api-gateway`
- `cloud-design/dev/inventory-app`
- `cloud-design/dev/billing-app`

---

### 5. Load Balancing (ALB)

**Application Load Balancer:**
- Type: Internet-facing
- Scheme: HTTP (HTTPS optional)
- Health checks on all targets

**Routing Rules:**
- `/api/*` → API Gateway (NodePort 30000)
- `/inventory/*` → Inventory Service (NodePort 30001)
- `/billing/*` → Billing Service (NodePort 30002)

**Target Groups:**
- All K3s nodes registered
- Health checks every 30 seconds
- Automatic unhealthy target removal

---

### 6. Monitoring & Logging

#### CloudWatch
**Dashboards:**
- EC2 CPU/Memory utilization
- ALB request metrics
- RDS performance metrics
- Custom application metrics

**Alarms:**
- High CPU usage (>80%)
- High error rate (>10/5min)
- RDS low storage (<2GB)
- ALB unhealthy targets

**Log Groups:**
- `/aws/cloud-design/applications` - App logs
- `/aws/cloud-design/k3s` - Cluster logs
- `/aws/rds/cloud-design` - Database logs

#### Metrics Server (K3s)
- Pod/Node metrics for HPA
- `kubectl top` commands support

---

### 7. Security

#### Network Security
- Security Groups with minimal access
- ALB: Ports 80, 443 from anywhere
- K3s: Ports 6443, 30000-30002 from ALB
- RDS: Port 5432 from K3s only

#### Secrets Management
- AWS Secrets Manager for database credentials
- Kubernetes Secrets for sensitive data
- No hardcoded passwords in code

#### IAM Roles
- K3s nodes have minimal required permissions
- ECR pull access
- CloudWatch logs write access
- S3 read/write for backups

#### Data Encryption
- RDS encrypted at rest (AES-256)
- S3 encrypted at rest
- TLS in transit (optional)

---

### 8. Storage

#### S3 Buckets
1. **Terraform State**
   - Versioning enabled
   - Lifecycle: 90 days retention
   - DynamoDB for state locking

2. **Application Logs**
   - Lifecycle transitions:
     - 30 days → Standard-IA
     - 90 days → Glacier
     - 180 days → Delete

3. **Backups**
   - Database backups
   - Configuration backups
   - Lifecycle: 365 days retention

---

## Traffic Flow

### User Request Flow

```
1. User → http://alb-dns-name/api/movies
   │
2. ALB → Determines target group (api-gateway)
   │
3. ALB → K3s Node (NodePort 30000)
   │
4. K3s → Routes to api-gateway pod
   │
5. API Gateway → Calls inventory-service:8080
   │
6. Inventory Service → Queries RDS (inventory DB)
   │
7. RDS → Returns movie data
   │
8. Response flows back through the chain
```

### Asynchronous Order Processing

```
1. User → POST /api/orders
   │
2. API Gateway → Forwards to billing service
   │
3. Billing Service → Publishes message to RabbitMQ
   │
4. RabbitMQ → Stores message in queue
   │
5. Billing Worker → Consumes message
   │
6. Billing Worker → Processes order
   │
7. Billing Worker → Updates RDS (billing DB)
```

---

## Scalability

### Horizontal Pod Autoscaler (HPA)

**Scaling Metrics:**
- CPU utilization > 70%
- Memory utilization > 80%

**Scaling Behavior:**
- Min replicas: 2
- Max replicas: 5
- Scale up: Immediately
- Scale down: 5 minutes stabilization

### Auto Scaling Groups (Future)
- Can add EC2 auto-scaling
- Scale K3s worker nodes based on load

---

## High Availability

### Application Layer
- Multiple replicas (2-5)
- Distributed across nodes
- HPA for automatic scaling

### Database Layer
- Multi-AZ RDS (production)
- Automated backups
- Point-in-time recovery

### Load Balancer
- Multi-AZ deployment
- Health checks
- Automatic failover

---

## Disaster Recovery

### Backup Strategy
1. **RDS Automated Backups**
   - Daily snapshots
   - 7-30 days retention
   - Point-in-time recovery

2. **Configuration Backups**
   - Terraform state in S3
   - K8s manifests in Git
   - Infrastructure as Code

3. **Recovery Objectives**
   - RTO (Recovery Time): ~30 minutes
   - RPO (Recovery Point): ~5 minutes

### Recovery Procedures
1. Restore RDS from snapshot
2. Deploy infrastructure via Terraform
3. Deploy applications via kubectl
4. Verify health checks

---

## Cost Optimization

### Strategies Implemented
1. **K3s instead of EKS** - Save $72/month
2. **No NAT Gateway** - Save $32/month
3. **Single RDS for 2 DBs** - Save $15/month
4. **Minimal instance sizes** - Free Tier eligible
5. **S3 lifecycle policies** - Reduce storage costs
6. **ECR image cleanup** - Remove old images

### Estimated Monthly Cost
- **Development:** $0-$10 (Free Tier)
- **Production:** ~$100-150/month

---

## Technology Stack

### Infrastructure
- **IaC:** Terraform
- **Cloud:** AWS
- **Container Orchestration:** K3s (Kubernetes)
- **Container Runtime:** Docker

### Application
- **Language:** Python 3.11
- **Framework:** Flask
- **Message Queue:** RabbitMQ
- **Database:** PostgreSQL 15

### Monitoring
- **Metrics:** CloudWatch, Metrics Server
- **Logs:** CloudWatch Logs
- **Dashboards:** CloudWatch Dashboards

### CI/CD (Future)
- **GitLab CI/CD** (for code-keeper project)
- **Automated testing**
- **Automated deployments**

---

## Design Decisions

### Why K3s?
- ✅ Cost effective ($0 vs $72/month for EKS)
- ✅ Full Kubernetes compatibility
- ✅ Lightweight and fast
- ✅ Perfect for learning
- ✅ Easy migration to EKS if needed

### Why Single RDS Instance?
- ✅ Free Tier eligible (20GB limit)
- ✅ Sufficient for learning project
- ✅ Easy to separate later
- ✅ Reduces complexity

### Why No NAT Gateway?
- ✅ Save $32/month
- ✅ Public subnets sufficient for learning
- ✅ Still secure with Security Groups
- ✅ Can add later if needed

### Why NodePort Services?
- ✅ Direct ALB integration
- ✅ Simpler than LoadBalancer type
- ✅ No additional costs
- ✅ Works well with K3s

---

## Future Improvements

1. **CI/CD Pipeline**
   - GitLab CI/CD integration
   - Automated testing
   - Automated deployments

2. **Service Mesh**
   - Istio or Linkerd
   - Advanced traffic management
   - mTLS between services

3. **Advanced Monitoring**
   - Prometheus + Grafana
   - Distributed tracing (Jaeger)
   - APM tools

4. **Database Improvements**
   - Read replicas
   - Connection pooling (PgBouncer)
   - Automated backups to S3

5. **Enhanced Security**
   - WAF (Web Application Firewall)
   - AWS Shield for DDoS
   - Automated vulnerability scanning

---

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)