# Security Best Practices

Security measures implemented in the Cloud-Design project.

---

## Security Principles

This project follows AWS Well-Architected Framework Security Pillar:

1. **Implement a strong identity foundation**
2. **Enable traceability**
3. **Apply security at all layers**
4. **Automate security best practices**
5. **Protect data in transit and at rest**
6. **Keep people away from data**
7. **Prepare for security events**

---

## Network Security

### VPC Configuration

**Network Isolation**
- Dedicated VPC for the project
- Public and private subnets
- No direct internet access to databases

**Security Groups (Stateful Firewall)**

**ALB Security Group:**
```hcl
Inbound:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0

Outbound:
  - All traffic allowed
```

**K3s Nodes Security Group:**
```hcl
Inbound:
  - Port 22 (SSH) from 0.0.0.0/0 (Restrict in production!)
  - Port 6443 (K3s API) from VPC CIDR
  - Port 10250 (Kubelet) from VPC CIDR
  - Ports 30000-32767 (NodePort) from VPC CIDR
  - Port 80, 3000, 8080 from ALB SG only

Outbound:
  - All traffic allowed
```

**RDS Security Group:**
```hcl
Inbound:
  - Port 5432 (PostgreSQL) from K3s Nodes SG only

Outbound:
  - All traffic allowed
```

### Production Recommendations

**SSH Access:**
```hcl
# DON'T (current dev setup)
cidr_blocks = ["0.0.0.0/0"]

# DO (production)
cidr_blocks = ["YOUR_IP/32"]  # Specific IP only

# BETTER (production)
# Use AWS Systems Manager Session Manager (no SSH needed)
```

**Use VPC Endpoints:**
```hcl
# For services that support it
- S3 VPC Endpoint (already implemented)
- ECR VPC Endpoint (recommended)
- Secrets Manager VPC Endpoint (recommended)
```

---

## Identity and Access Management (IAM)

### IAM Roles

**K3s Node Role**
- Principle of least privilege
- Only necessary permissions

**Permissions:**
```hcl
ECR:
  - Get auth token
  - Pull images
  - Batch get/check images

CloudWatch:
  - Create log groups/streams
  - Put log events

S3:
  - Get/Put objects (specific buckets only)
  - List bucket
```

❌ **What's NOT allowed:**
- EC2 instance management
- IAM modifications
- Billing access
- Other AWS services

### Production Improvements

✅ **Use IAM Roles Everywhere:**
- Never use access keys
- Use instance profiles for EC2
- Use service accounts for K8s

✅ **Enable MFA:**
```bash
# For AWS Console users
aws iam enable-mfa-device

# For root account (CRITICAL!)
# Do this immediately in AWS Console
```

✅ **Rotate Credentials:**
```bash
# Automate with AWS Secrets Manager
# Set rotation period: 90 days
```

---

## Data Protection

### Encryption at Rest

✅ **Implemented:**
- RDS: AES-256 encryption ✅
- S3: Server-side encryption (AES-256) ✅
- EBS: Encrypted volumes ✅

✅ **Code:**
```hcl
# RDS
resource "aws_db_instance" "main" {
  storage_encrypted = true
  # ...
}

# S3
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# EBS
resource "aws_instance" "k3s_master" {
  root_block_device {
    encrypted = true
  }
}
```

### Encryption in Transit

✅ **Current:**
- RDS: SSL/TLS enforced
- AWS API calls: HTTPS
- Internal K8s: plaintext (acceptable for dev)

⚠️ **Production Recommendations:**
```bash
# 1. Use HTTPS for ALB
# - Get ACM certificate
# - Update ALB listener

# 2. Enable mTLS between services
# - Use service mesh (Istio/Linkerd)
# - Or implement in application

# 3. Use encrypted RDS connections
# - Enforce SSL in RDS settings
# - Update connection strings
```

---

## Secrets Management

### AWS Secrets Manager

✅ **What We Store:**
- RDS master password
- Database application credentials
- RabbitMQ credentials

✅ **Benefits:**
- Automatic encryption
- Rotation support
- Audit logging
- No hardcoded secrets

✅ **Usage:**
```bash
# Retrieve secret
aws secretsmanager get-secret-value \
  --secret-id cloud-design-dev-inventory-db

# Update secret
aws secretsmanager update-secret \
  --secret-id cloud-design-dev-inventory-db \
  --secret-string '{"username":"new_user","password":"new_pass"}'

# Enable rotation (production)
aws secretsmanager rotate-secret \
  --secret-id cloud-design-dev-inventory-db
```

### Kubernetes Secrets

✅ **Base64 encoded** (not encrypted by default)

⚠️ **Production Recommendations:**
```bash
# 1. Use External Secrets Operator
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml

# 2. Or use Sealed Secrets
kubeseal --cert cert.pem < secret.yaml > sealed-secret.yaml

# 3. Or use HashiCorp Vault
helm install vault hashicorp/vault
```

---

## Application Security

### Container Security

✅ **Non-Root Containers:**
```dockerfile
# Create user
RUN useradd -m -u 1000 appuser

# Switch to user
USER appuser
```

✅ **Minimal Base Images:**
```dockerfile
FROM python:3.11-slim  # Not python:3.11-full
```

✅ **Multi-Stage Builds:**
```dockerfile
# Build stage
FROM python:3.11-slim as builder
# ... install dependencies

# Runtime stage
FROM python:3.11-slim
COPY --from=builder /root/.local /root/.local
```

✅ **Image Scanning:**
```hcl
# ECR automatic scanning
scan_on_push = true
```

### Kubernetes Security

✅ **Security Context:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  # Optional: more restrictions
  # readOnlyRootFilesystem: true
  # allowPrivilegeEscalation: false
```

✅ **Resource Limits:**
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

✅ **Network Policies (Future):**
```yaml
# Restrict pod-to-pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## Monitoring and Logging

### CloudWatch Logs

✅ **What We Log:**
- Application logs
- K3s cluster logs
- RDS logs (optional)
- ALB access logs

✅ **Retention:**
- Development: 7 days
- Production: 30-90 days

✅ **Access:**
```bash
# View logs
aws logs tail /aws/cloud-design/dev/applications --follow

# Search logs
aws logs filter-log-events \
  --log-group-name /aws/cloud-design/dev/applications \
  --filter-pattern "ERROR"
```

### CloudWatch Alarms

✅ **Configured Alarms:**
- High CPU usage (>80%)
- High error rate (>10/5min)
- RDS storage low (<2GB)
- ALB unhealthy targets

### Audit Logging

⚠️ **Enable AWS CloudTrail (Production):**
```hcl
resource "aws_cloudtrail" "main" {
  name                          = "cloud-design-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}
```

---

## Incident Response

### Preparation

✅ **Backups:**
- RDS: Automated daily backups (7-30 days)
- S3: Versioning enabled
- Terraform state: Versioned in S3

✅ **Monitoring:**
- CloudWatch Dashboards
- CloudWatch Alarms
- SNS notifications (optional)

### Response Procedures

**Security Incident:**
```bash
# 1. Identify affected resources
aws cloudtrail lookup-events

# 2. Isolate compromised instances
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxx \
  --groups sg-isolated

# 3. Rotate credentials
./scripts/rotate-credentials.sh

# 4. Review logs
aws logs filter-log-events --filter-pattern "ERROR"

# 5. Restore from backup if needed
terraform apply
```

**Data Breach:**
```bash
# 1. Notify stakeholders
# 2. Isolate affected systems
# 3. Review access logs
# 4. Change all credentials
# 5. Investigate root cause
# 6. Implement fixes
# 7. Document incident
```

---

## Compliance

### Data Privacy

✅ **GDPR Considerations:**
- Data encryption at rest and in transit
- Data retention policies (S3 lifecycle)
- Right to be forgotten (manual process)
- Data minimization

⚠️ **For Production:**
- Implement data access controls
- Add audit logging
- Document data flows
- Privacy policy

### Security Frameworks

This project aligns with:
- ✅ AWS Well-Architected Framework
- ✅ CIS AWS Foundations Benchmark (partial)
- ✅ NIST Cybersecurity Framework (basic)

---

## Security Checklist

### Development Environment

- [x] Use IAM roles (not access keys)
- [x] Encrypt data at rest
- [x] Use Secrets Manager
- [x] Enable CloudWatch logging
- [x] Minimal Security Group rules
- [ ] Restrict SSH to specific IP
- [ ] Enable MFA
- [ ] Use HTTPS (optional for dev)

### Production Environment

- [ ] All dev checklist items
- [ ] Enable AWS CloudTrail
- [ ] Enable AWS Config
- [ ] Use AWS WAF
- [ ] Enable AWS GuardDuty
- [ ] Implement backup/restore procedures
- [ ] Security group rules to specific IPs only
- [ ] Multi-AZ for high availability
- [ ] Regular security assessments
- [ ] Incident response plan
- [ ] Regular penetration testing

---

## Security Tools

### AWS Security Services

**Already Using:**
- ✅ AWS Secrets Manager
- ✅ CloudWatch
- ✅ Security Groups
- ✅ IAM

**Recommended for Production:**
- AWS WAF - Web application firewall
- AWS Shield - DDoS protection
- AWS GuardDuty - Threat detection
- AWS Inspector - Vulnerability scanning
- AWS Config - Configuration monitoring
- AWS CloudTrail - Audit logging

### Third-Party Tools

**Container Security:**
- Trivy - Container vulnerability scanning
- Snyk - Dependency scanning
- Aqua Security - Runtime protection

**Kubernetes Security:**
- kube-bench - CIS benchmark testing
- Falco - Runtime security
- OPA Gatekeeper - Policy enforcement

---

## Regular Security Tasks

### Daily
- Monitor CloudWatch alarms
- Review error logs
- Check for failed login attempts

### Weekly
- Review Security Group rules
- Check IAM permissions
- Scan containers for vulnerabilities

### Monthly
- Review and rotate credentials
- Update dependencies
- Security audit
- Review CloudTrail logs

### Quarterly
- Penetration testing
- Security training
- Disaster recovery drill
- Update security documentation

---

## Security Resources

### Documentation
- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [K3s Security Documentation](https://docs.k3s.io/security)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

### Training
- AWS Security Fundamentals
- Certified Information Systems Security Professional (CISSP)
- Certified Kubernetes Security Specialist (CKS)

---

## Questions?

For security concerns:
- Review AWS Trusted Advisor
- Check AWS Security Hub
- Consult AWS Support
- Hire security consultant for production deployments