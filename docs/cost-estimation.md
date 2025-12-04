# Cost Estimation

Detailed cost analysis for running the Cloud-Design project on AWS.

---

## AWS Free Tier

### Free Tier Benefits (First 12 Months)

| Service | Free Tier Limit | Value |
|---------|----------------|-------|
| **EC2** | 750 hours/month | t2.micro or t3.micro |
| **RDS** | 750 hours/month | db.t2.micro or db.t3.micro |
| **RDS Storage** | 20 GB | General Purpose SSD |
| **ALB** | 750 hours/month | + 15 LCU |
| **S3** | 5 GB storage | + 20K GET, 2K PUT |
| **Data Transfer** | 15 GB outbound | Per month |
| **CloudWatch** | 10 metrics | + 10 alarms |

**Important:** Free Tier is valid for 12 months from account creation.

---

## Development Environment Cost

### Monthly Cost Breakdown (Free Tier)

| Service | Quantity | Instance Type | Hours | Free Tier | Cost |
|---------|----------|---------------|-------|-----------|------|
| **EC2 - K3s Master** | 1 | t3.medium | 730 | ⚠️ No | $30.37 |
| **EC2 - K3s Workers** | 2 | t3.small | 730 each | ⚠️ Partial | $15.18 × 2 |
| **RDS PostgreSQL** | 1 | db.t3.micro | 730 | ✅ Yes | $0.00 |
| **ALB** | 1 | - | 730 | ✅ Yes | $0.00 |
| **S3 Storage** | ~2 GB | - | - | ✅ Yes | $0.00 |
| **ECR Storage** | ~1 GB | - | - | ⚠️ Partial | $0.10 |
| **Data Transfer** | ~5 GB | - | - | ✅ Yes | $0.00 |
| **CloudWatch** | Basic | - | - | ✅ Yes | $0.00 |
| **Secrets Manager** | 3 secrets | - | - | ⚠️ No | $1.20 |

**Total Monthly Cost (Free Tier):** ~$61.85/month

### Cost Optimization for Development

**Option 1: Use t3.micro only (maximize Free Tier)**
```
1× t3.micro (master) - 400 hours used of 750 free
2× t3.micro (workers) - 350 hours each used of 750 free
Total EC2: Within Free Tier = $0

Total Monthly Cost: ~$1.30/month (ECR + Secrets Manager)
```

**Option 2: Use instances only during testing (4 hours/day)**
```
1× t3.medium × 120 hours/month = $4.87
2× t3.small × 120 hours/month = $2.43 × 2 = $4.86
Total: ~$11/month
```

**Recommended for learning:**
- Deploy infrastructure
- Test thoroughly
- **Destroy with `./scripts/cleanup.sh dev`**
- Cost per session (~4 hours): **$1-2**

---

## Production Environment Cost

### Monthly Cost Breakdown (No Free Tier)

| Service | Quantity | Instance Type | Cost/Month |
|---------|----------|---------------|------------|
| **EC2 - K3s Master** | 1 | t3.large | $60.74 |
| **EC2 - K3s Workers** | 3 | t3.medium | $30.37 × 3 = $91.11 |
| **RDS PostgreSQL** | 1 | db.t3.small (Multi-AZ) | $45.00 |
| **ALB** | 1 | Standard | $22.00 |
| **S3 Storage** | 10 GB | Standard | $0.23 |
| **ECR Storage** | 5 GB | - | $0.50 |
| **Data Transfer** | 50 GB outbound | - | $4.50 |
| **CloudWatch Logs** | 10 GB ingestion | - | $5.00 |
| **CloudWatch Alarms** | 15 alarms | - | $0.00 (10 free) |
| **Secrets Manager** | 3 secrets | - | $1.20 |
| **Elastic IP** | 1 | For master | $3.65 |
| **EBS Volumes** | 4 × 30GB | gp3 | $9.60 |

**Total Monthly Cost (Production):** ~$243.53/month

---

## Cost Comparison: K3s vs EKS

### Our Solution (K3s on EC2)

**Development:**
- EC2 instances: $0 (Free Tier) or $61.85
- Total: **$0-61.85/month**

**Production:**
- EC2 instances: $151.85
- Other services: $91.68
- Total: **$243.53/month**

### Alternative Solution (EKS)

**Development:**
- EKS Control Plane: $72.00/month
- EC2 Worker Nodes: $30.37 (1× t3.medium)
- NAT Gateway: $32.85/month
- Other services: $1.30
- Total: **$136.52/month**

**Production:**
- EKS Control Plane: $72.00/month
- EC2 Worker Nodes: $91.11 (3× t3.medium)
- NAT Gateway: $65.70/month (2× Multi-AZ)
- Other services: $92.88
- Total: **$321.69/month**

### Savings with K3s

| Environment | K3s Cost | EKS Cost | Savings | Savings % |
|-------------|----------|----------|---------|-----------|
| **Development** | $0-61.85 | $136.52 | $74.67+ | 55%+ |
| **Production** | $243.53 | $321.69 | $78.16 | 24% |
| **Annual (Dev)** | $0-742 | $1,638 | $896+ | 55%+ |

---

## Detailed Cost Analysis

### EC2 Instances (eu-north-1 pricing)

| Instance Type | vCPU | Memory | Price/Hour | Price/Month (730h) |
|---------------|------|--------|------------|--------------------|
| **t3.micro** | 2 | 1 GB | $0.0104 | $7.59 |
| **t3.small** | 2 | 2 GB | $0.0208 | $15.18 |
| **t3.medium** | 2 | 4 GB | $0.0416 | $30.37 |
| **t3.large** | 2 | 8 GB | $0.0832 | $60.74 |

### RDS PostgreSQL (eu-north-1 pricing)

| Instance Class | vCPU | Memory | Price/Hour | Multi-AZ/Hour | Price/Month |
|----------------|------|--------|------------|---------------|-------------|
| **db.t3.micro** | 2 | 1 GB | $0.018 | $0.036 | $13.14 / $26.28 |
| **db.t3.small** | 2 | 2 GB | $0.036 | $0.072 | $26.28 / $52.56 |
| **db.t3.medium** | 2 | 4 GB | $0.073 | $0.146 | $53.29 / $106.58 |

**Storage:** 
- gp3: $0.133/GB-month (20GB = $2.66/month)

**Backup:**
- Same as allocated storage (20GB = $2.66/month for backups beyond retention)

### Load Balancer

| Type | Fixed Cost | LCU Cost | Typical Monthly |
|------|-----------|----------|-----------------|
| **ALB** | $0.0225/hour | $0.008/LCU-hour | $22.00 |

**LCU (Load Balancer Capacity Units):**
- 25 new connections/sec
- 3,000 active connections/min
- 1 GB/hour
- 1,000 rule evaluations/sec

### S3 Storage

| Storage Class | First 50TB | 50-450TB |
|---------------|-----------|----------|
| **Standard** | $0.023/GB | $0.022/GB |
| **Standard-IA** | $0.0125/GB | $0.0125/GB |
| **Glacier** | $0.004/GB | $0.004/GB |

**Requests:**
- PUT: $0.005 per 1,000
- GET: $0.0004 per 1,000

### ECR (Container Registry)

- **Storage:** $0.10/GB-month
- **Data Transfer:** Free to EC2 in same region

### CloudWatch

| Feature | Free Tier | Over Free Tier |
|---------|-----------|----------------|
| **Metrics** | 10 custom | $0.30/metric/month |
| **Alarms** | 10 alarms | $0.10/alarm/month |
| **Logs Ingestion** | 5 GB | $0.50/GB |
| **Logs Storage** | 5 GB | $0.03/GB/month |
| **Dashboard** | 3 dashboards | $3/dashboard/month |

### Secrets Manager

- **Secret:** $0.40/month per secret
- **API Calls:** $0.05 per 10,000 calls

### Data Transfer

| Direction | Cost |
|-----------|------|
| **IN (all sources)** | FREE |
| **OUT to Internet (first 10TB)** | $0.09/GB |
| **OUT to EC2 (same region)** | FREE |
| **OUT to ECR (same region)** | FREE |

---

## Cost Optimization Strategies

### 1. Use Free Tier Effectively

```bash
# Maximize Free Tier
✅ Use t2.micro or t3.micro instances
✅ Use db.t3.micro for RDS
✅ Keep RDS storage under 20GB
✅ Stay under 750 hours/month per service
```

### 2. Deploy Only When Needed

```bash
# Deploy for testing
terraform apply

# Use for 4 hours
# Test thoroughly

# Destroy immediately
./scripts/cleanup.sh dev

# Cost per session: $1-2
```

### 3. Minimize Running Time

```bash
# Stop instances when not in use
aws ec2 stop-instances --instance-ids i-xxxxx

# Or use Lambda to auto-stop at night
# Saves ~16 hours/day
```

### 4. Optimize Instance Sizes

**Development:**
- Use smallest instances that work
- t3.micro often sufficient for testing
- Scale up only if needed

**Production:**
- Right-size based on actual metrics
- Use Reserved Instances for 1-year (save 30-40%)
- Use Savings Plans

### 5. Use Spot Instances (Advanced)

- Save up to 90% on EC2 costs
- Good for dev/test workloads
- Requires handling interruptions

### 6. S3 Lifecycle Policies

Already implemented:
```hcl
30 days → Standard-IA (save 50%)
90 days → Glacier (save 80%)
180 days → Delete
```

### 7. ECR Image Cleanup

Already implemented:
```hcl
Keep last 10 tagged images
Delete untagged after 7 days
```

---

## Cost Monitoring

### Set Up Billing Alerts

1. **AWS Console → Billing → Budgets**

2. **Create Budget:**
   ```
   Name: cloud-design-dev-budget
   Period: Monthly
   Amount: $10 (or your limit)
   ```

3. **Alert Thresholds:**
   - 50% of budget ($5)
   - 80% of budget ($8)
   - 100% of budget ($10)

### Monitor Daily Costs

```bash
# AWS CLI
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics UnblendedCost

# Or check in AWS Console:
# Billing → Cost Explorer
```

### Tag Resources for Cost Tracking

All resources are tagged:
```hcl
tags = {
  Project     = "cloud-design"
  Environment = "dev"
  ManagedBy   = "Terraform"
}
```

Filter costs by tags in Cost Explorer.

---

## Example Scenarios

### Scenario 1: Learning Project (1 month)

**Usage:**
- Deploy 3-4 times per week
- 4 hours per session
- Total: ~50 hours/month

**Cost:**
```
EC2 (50h): 1×t3.medium + 2×t3.small = $6.50
RDS (50h): db.t3.micro = $0.90
Other: $1.30
Total: ~$8.70/month
```

### Scenario 2: Development Environment (always on)

**Usage:**
- Running 24/7 for active development
- Using Free Tier

**Cost:**
```
EC2: Partial Free Tier coverage
RDS: Free Tier (db.t3.micro)
Other: $1.30
Total: ~$61.85/month (or $0 with t3.micro only)
```

### Scenario 3: Production Deployment

**Usage:**
- 24/7 uptime
- High availability
- Multiple environments

**Cost:**
```
Infrastructure: $243.53/month
Additional monitoring: $10/month
Data transfer: $20/month
Total: ~$273.53/month
```

---

## ROI Analysis

### Learning Investment

**Traditional Training:**
- Course: $500-2,000
- Certification: $300
- Total: $800-2,300

**Cloud-Design Project:**
- AWS costs: $10-50 (learning phase)
- Hands-on experience: Priceless
- Portfolio project: ✅
- Interview advantage: ✅

**ROI:** Excellent value for money!

---

## Summary

| Environment | Recommended Approach | Monthly Cost |
|-------------|---------------------|--------------|
| **Learning** | Deploy-Test-Destroy | $8-20 |
| **Development** | Free Tier + t3.micro | $0-10 |
| **Development** | Standard (24/7) | $61.85 |
| **Production** | Full deployment | $243.53 |

### Key Takeaways

1. ✅ **Free Tier is powerful** - Use it strategically
2. ✅ **K3s saves money** - 55% cheaper than EKS for dev
3. ✅ **Deploy-destroy pattern** - Minimal costs for learning
4. ✅ **Monitor actively** - Set up billing alerts
5. ✅ **Clean up resources** - Always destroy when done

---

## Cost Calculator

Use AWS Cost Calculator:
https://calculator.aws/

Enter your specific requirements for accurate estimates.

---

## Questions?

For cost optimization advice:
- Review AWS Free Tier documentation
- Use AWS Cost Explorer
- Check AWS Trusted Advisor
- Consider Reserved Instances for production