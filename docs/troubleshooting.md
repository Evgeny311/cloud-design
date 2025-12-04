# Troubleshooting Guide

Common issues and their solutions for the Cloud-Design project.

---

## Table of Contents

1. [AWS Setup Issues](#aws-setup-issues)
2. [Terraform Issues](#terraform-issues)
3. [K3s Cluster Issues](#k3s-cluster-issues)
4. [Database Issues](#database-issues)
5. [Application Issues](#application-issues)
6. [Networking Issues](#networking-issues)
7. [Monitoring Issues](#monitoring-issues)

---

## AWS Setup Issues

### Issue: AWS CLI not configured

**Symptoms:**
```bash
$ aws sts get-caller-identity
Unable to locate credentials
```

**Solution:**
```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-north-1"

# Verify
aws sts get-caller-identity
```

### Issue: Insufficient permissions

**Symptoms:**
```
An error occurred (UnauthorizedOperation) when calling the CreateVpc operation
```

**Solution:**
```bash
# Check current permissions
aws iam get-user

# Your IAM user needs these permissions:
# - EC2 Full Access
# - RDS Full Access
# - S3 Full Access
# - ECR Full Access
# - IAM (for roles)
# - CloudWatch

# For learning, use AdministratorAccess
# For production, create specific policies
```

### Issue: Region mismatch

**Symptoms:**
```
Resource not found in region us-east-1
```

**Solution:**
```bash
# Check current region
aws configure get region

# Set correct region
aws configure set region eu-north-1

# Or use in commands
aws ec2 describe-instances --region eu-north-1
```

---

## Terraform Issues

### Issue: S3 backend doesn't exist

**Symptoms:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:**
```bash
# First time setup
# 1. Comment out backend block in main.tf
# 2. Run terraform init
# 3. Run terraform apply to create S3 bucket
# 4. Uncomment backend block
# 5. Run terraform init -backend-config=backend.hcl

# See deployment-guide.md Step 3.1
```

### Issue: State lock timeout

**Symptoms:**
```
Error acquiring the state lock
Lock Info:
  ID: xxxxx
  Path: cloud-design-dev-terraform-state-xxxxx/dev/terraform.tfstate
```

**Solution:**
```bash
# Someone else is running terraform, or previous run failed

# Option 1: Wait for lock to release (usually 2-5 minutes)

# Option 2: Force unlock (if you're sure no one else is running)
terraform force-unlock <LOCK_ID>

# Option 3: Check DynamoDB
aws dynamodb scan --table-name cloud-design-dev-terraform-locks
```

### Issue: Resource already exists

**Symptoms:**
```
Error: Error creating VPC: VpcLimitExceeded: The maximum number of VPCs has been reached
```

**Solution:**
```bash
# Check existing VPCs
aws ec2 describe-vpcs

# Delete unused VPCs
aws ec2 delete-vpc --vpc-id vpc-xxxxx

# Or increase VPC limit
# AWS Console → Support → Service Limit Increase
```

### Issue: Terraform destroy fails

**Symptoms:**
```
Error: Error deleting S3 Bucket: BucketNotEmpty
```

**Solution:**
```bash
# Run cleanup script
./scripts/cleanup.sh dev

# Or manually:
# 1. Empty S3 buckets
aws s3 rm s3://bucket-name --recursive

# 2. Delete ECR images
aws ecr batch-delete-image \
  --repository-name repo-name \
  --image-ids imageTag=latest

# 3. Try terraform destroy again
terraform destroy
```

---

## K3s Cluster Issues

### Issue: Can't connect to K3s cluster

**Symptoms:**
```bash
$ kubectl get nodes
Unable to connect to the server: dial tcp xxx:6443: i/o timeout
```

**Solution:**
```bash
# 1. Check if master is running
aws ec2 describe-instances --filters "Name=tag:Role,Values=k3s-master"

# 2. Get correct IP
MASTER_IP=$(terraform output -raw k3s_master_public_ip)

# 3. Update kubeconfig
ssh -i ~/.ssh/cloud-design-dev ec2-user@$MASTER_IP \
  'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config

sed -i "s/127.0.0.1/$MASTER_IP/g" ~/.kube/config

# 4. Test
kubectl get nodes
```

### Issue: K3s not starting on EC2

**Symptoms:**
- SSH to master works
- `sudo systemctl status k3s` shows failed

**Solution:**
```bash
# SSH to master
ssh -i ~/.ssh/cloud-design-dev ec2-user@<MASTER_IP>

# Check K3s status
sudo systemctl status k3s

# Check logs
sudo journalctl -u k3s -f

# Common issues:
# - Insufficient memory (use larger instance)
# - Port conflicts
# - Network issues

# Restart K3s
sudo systemctl restart k3s

# If still failing, check installation log
cat /var/log/k3s-install.log
```

### Issue: Worker nodes not joining

**Symptoms:**
```bash
$ kubectl get nodes
NAME         STATUS   ROLES                  AGE
k3s-master   Ready    control-plane,master   5m
# Workers missing
```

**Solution:**
```bash
# SSH to worker
WORKER_IP=$(terraform output -json k3s_worker_public_ips | jq -r '.[0]')
ssh -i ~/.ssh/cloud-design-dev ec2-user@$WORKER_IP

# Check K3s agent status
sudo systemctl status k3s-agent

# Check logs
sudo journalctl -u k3s-agent -f

# Common issues:
# - Wrong master IP
# - Wrong token
# - Network/firewall issues

# Get correct join command from master
ssh ec2-user@<MASTER_IP>
cat /home/ec2-user/cluster-info.txt

# Reinstall on worker
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 \
  K3S_TOKEN=<TOKEN> sh -
```

---

## Database Issues

### Issue: Can't connect to RDS

**Symptoms:**
```
FATAL: could not connect to server: Connection timed out
```

**Solution:**
```bash
# 1. Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier cloud-design-dev-postgres

# 2. Check Security Group
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID>

# 3. Try from K3s node (should work)
ssh ec2-user@<K3S_NODE>
psql -h <RDS_ENDPOINT> -U postgres -d postgres

# 4. Check if accessible from VPC only
# RDS should NOT be publicly accessible
```

### Issue: Database not initialized

**Symptoms:**
```
relation "movies" does not exist
```

**Solution:**
```bash
# Run initialization script
cd terraform/modules/rds

# Get credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id cloud-design-dev-inventory-db

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

### Issue: RDS out of storage

**Symptoms:**
```
ERROR: could not extend file: No space left on device
```

**Solution:**
```bash
# Check storage
aws rds describe-db-instances \
  --db-instance-identifier cloud-design-dev-postgres \
  --query 'DBInstances[0].AllocatedStorage'

# Increase storage (can only increase, not decrease)
aws rds modify-db-instance \
  --db-instance-identifier cloud-design-dev-postgres \
  --allocated-storage 30 \
  --apply-immediately
```

---

## Application Issues

### Issue: Pods not starting

**Symptoms:**
```bash
$ kubectl get pods -n microservices
NAME                           READY   STATUS             RESTARTS   AGE
api-gateway-xxx               0/1     ImagePullBackOff   0          2m
```

**Solution:**
```bash
# Check pod events
kubectl describe pod api-gateway-xxx -n microservices

# Common issues:

# 1. ImagePullBackOff - Can't pull from ECR
# Check ECR credentials
kubectl get secret ecr-secret -n microservices

# Recreate ECR secret
./scripts/deploy-applications.sh dev

# 2. CrashLoopBackOff - Application crashing
kubectl logs api-gateway-xxx -n microservices

# 3. Pending - Resource constraints
kubectl describe node

# Check resource requests/limits
kubectl get pods -n microservices -o yaml | grep -A 5 resources
```

### Issue: Application can't connect to database

**Symptoms:**
```
could not connect to server: Connection refused
```

**Solution:**
```bash
# 1. Check database secret exists
kubectl get secret database-secret -n microservices

# 2. Check secret values
kubectl get secret database-secret -n microservices -o yaml

# 3. Verify RDS endpoint
terraform output rds_endpoint

# 4. Test connection from pod
kubectl exec -it <pod-name> -n microservices -- \
  psql -h <RDS_ENDPOINT> -U inventory_user -d inventory

# 5. Check environment variables
kubectl exec <pod-name> -n microservices -- env | grep DB_
```

### Issue: RabbitMQ connection failed

**Symptoms:**
```
pika.exceptions.AMQPConnectionError: Connection refused
```

**Solution:**
```bash
# 1. Check RabbitMQ pod
kubectl get pod -n microservices -l app=rabbitmq

# 2. Check RabbitMQ logs
kubectl logs -f rabbitmq-xxx -n microservices

# 3. Check service
kubectl get svc rabbitmq-service -n microservices

# 4. Test connection
kubectl exec -it billing-app-xxx -n microservices -- \
  curl http://rabbitmq-service:15672
```

---

## Networking Issues

### Issue: Can't access application via ALB

**Symptoms:**
```bash
$ curl http://ALB-DNS-NAME/api/health
curl: (7) Failed to connect to ALB-DNS-NAME port 80: Connection refused
```

**Solution:**
```bash
# 1. Check ALB status
aws elbv2 describe-load-balancers

# 2. Check target groups
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# 3. Check if targets are healthy
# If unhealthy, check:
# - NodePort services running
# - Health check endpoints working
# - Security groups allow traffic

# 4. Test directly to K3s node
curl http://<K3S_NODE_IP>:30000/health

# 5. Check ALB security group
aws ec2 describe-security-groups --group-ids <ALB_SG_ID>
```

### Issue: DNS resolution fails

**Symptoms:**
```
nslookup: can't resolve 'inventory-app-service'
```

**Solution:**
```bash
# 1. Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check service exists
kubectl get svc -n microservices

# 3. Use full DNS name
# From same namespace: inventory-app-service
# From different namespace: inventory-app-service.microservices
# Full: inventory-app-service.microservices.svc.cluster.local

# 4. Test DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup inventory-app-service.microservices
```

---

## Monitoring Issues

### Issue: No logs in CloudWatch

**Symptoms:**
- CloudWatch log groups exist but no logs

**Solution:**
```bash
# 1. Check CloudWatch agent on EC2
ssh ec2-user@<K3S_NODE>
systemctl status amazon-cloudwatch-agent

# 2. Check IAM permissions
aws iam get-role --role-name cloud-design-dev-k3s-node-role

# 3. Check log group
aws logs describe-log-groups

# 4. Test manually
aws logs put-log-events \
  --log-group-name /aws/cloud-design/dev/applications \
  --log-stream-name test \
  --log-events timestamp=$(date +%s000),message="test"
```

### Issue: Metrics Server not working

**Symptoms:**
```bash
$ kubectl top nodes
error: Metrics API not available
```

**Solution:**
```bash
# 1. Check Metrics Server deployment
kubectl get deployment metrics-server -n kube-system

# 2. Check logs
kubectl logs -n kube-system deployment/metrics-server

# 3. Reinstall (was installed via K3s user-data)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 4. Patch for K3s
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

---

## Common Error Messages

### "Access Denied"

**Cause:** Insufficient IAM permissions

**Solution:**
```bash
# Check permissions
aws iam get-user-policy --user-name <your-user> --policy-name <policy-name>

# Or check attached policies
aws iam list-attached-user-policies --user-name <your-user>
```

### "Resource Limit Exceeded"

**Cause:** AWS service limits reached

**Solution:**
```bash
# Check limits
aws service-quotas list-service-quotas --service-code ec2

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1234567890 \
  --desired-value 20
```

### "Invalid Parameter"

**Cause:** Usually wrong region or resource doesn't exist

**Solution:**
```bash
# Check resource exists
aws ec2 describe-instances --instance-ids i-xxxxx

# Check correct region
aws configure get region
```

---

## Debugging Commands

### Terraform Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Show state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show module.vpc.aws_vpc.main
```

### Kubernetes Debugging

```bash
# Describe resources
kubectl describe pod <pod-name> -n microservices
kubectl describe svc <service-name> -n microservices

# View logs
kubectl logs <pod-name> -n microservices
kubectl logs <pod-name> -n microservices --previous  # Previous container

# Execute commands in pod
kubectl exec -it <pod-name> -n microservices -- /bin/sh

# Port forward for testing
kubectl port-forward pod/<pod-name> 8080:8080 -n microservices

# Get events
kubectl get events -n microservices --sort-by='.lastTimestamp'
```

### AWS Debugging

```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids i-xxxxx

# Check system logs
aws ec2 get-console-output --instance-id i-xxxxx

# Check RDS events
aws rds describe-events --source-identifier cloud-design-dev-postgres
```

---

## Performance Issues

### High CPU Usage

**Solution:**
```bash
# 1. Check metrics
kubectl top pods -n microservices
kubectl top nodes

# 2. Scale horizontally
kubectl scale deployment api-gateway --replicas=5 -n microservices

# 3. Or increase resources
# Edit deployment: increase CPU limits

# 4. Check HPA
kubectl get hpa -n microservices
```

### Slow Database Queries

**Solution:**
```bash
# 1. Check RDS performance insights
# AWS Console → RDS → Performance Insights

# 2. Check slow query log
aws rds describe-db-log-files \
  --db-instance-identifier cloud-design-dev-postgres

# 3. Add indexes
# Connect to database and analyze queries

# 4. Increase RDS instance size
aws rds modify-db-instance \
  --db-instance-identifier cloud-design-dev-postgres \
  --db-instance-class db.t3.small
```

---

## Getting Help

### Documentation
- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Community
- [AWS Forums](https://forums.aws.amazon.com/)
- [Terraform Community](https://discuss.hashicorp.com/)
- [K3s Slack](https://slack.rancher.io/)
- [Kubernetes Slack](https://slack.k8s.io/)

### Support
- AWS Support (paid plans)
- GitHub Issues
- Stack Overflow

---

## Preventive Measures

1. **Always test in dev first**
2. **Use version control (Git)**
3. **Document changes**
4. **Set up monitoring before issues occur**
5. **Regular backups**
6. **Keep dependencies updated**
7. **Review logs regularly**
8. **Cost alerts**

---

## Emergency Procedures

### Complete Infrastructure Failure

```bash
# 1. Check AWS Service Health Dashboard
# https://status.aws.amazon.com/

# 2. Restore from Terraform
cd terraform/environments/dev
terraform apply

# 3. Restore database from backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier cloud-design-dev-postgres-restored \
  --db-snapshot-identifier <snapshot-id>

# 4. Redeploy applications
./scripts/deploy-applications.sh dev
```

### Data Loss

```bash
# 1. Check RDS backups
aws rds describe-db-snapshots \
  --db-instance-identifier cloud-design-dev-postgres

# 2. Restore from snapshot
# See deployment-guide.md

# 3. Check S3 versioning
aws s3api list-object-versions --bucket <bucket-name>

# 4. Restore S3 objects if needed
aws s3api restore-object --bucket <bucket> --key <key>
```

---

## Still Having Issues?

1. Check all sections above
2. Review logs carefully
3. Search error messages online
4. Ask in community forums
5. Consider AWS Support

Remember: Most issues have been encountered by others before!