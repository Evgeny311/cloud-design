#!/bin/bash
# ======
# Cleanup Script
# ======
# Destroys all AWS resources created by Terraform
# WARNING: This is DESTRUCTIVE!
# ======

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}======${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Configuration
ENVIRONMENT=${1:-dev}

print_header "CLEANUP - DESTROY ALL RESOURCES"
echo ""
print_warning "This will DESTROY all AWS resources for environment: $ENVIRONMENT"
print_warning "This action is IRREVERSIBLE!"
echo ""

# Confirmation
read -p "Are you absolutely sure? Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    print_info "Cleanup cancelled"
    exit 0
fi

echo ""
read -p "Type the environment name '$ENVIRONMENT' to confirm: " ENV_CONFIRM
if [ "$ENV_CONFIRM" != "$ENVIRONMENT" ]; then
    print_error "Environment name doesn't match. Cleanup cancelled."
    exit 1
fi

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Step 1: Delete Kubernetes resources
print_header "Step 1: Cleaning up Kubernetes Resources"
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    print_info "Deleting all resources in microservices namespace..."
    kubectl delete namespace microservices --ignore-not-found=true --timeout=60s || true
    print_success "Kubernetes resources cleaned up"
else
    print_warning "kubectl not available or cluster not accessible, skipping K8s cleanup"
fi
echo ""

# Step 2: Empty S3 buckets (required before Terraform destroy)
print_header "Step 2: Emptying S3 Buckets"
print_info "Finding S3 buckets..."

BUCKETS=$(aws s3 ls | grep "cloud-design-${ENVIRONMENT}" | awk '{print $3}' || true)

if [ -n "$BUCKETS" ]; then
    for BUCKET in $BUCKETS; do
        print_info "Emptying bucket: $BUCKET"
        aws s3 rm "s3://${BUCKET}" --recursive 2>/dev/null || true
        
        # Delete all versions if versioning is enabled
        aws s3api delete-objects \
            --bucket "$BUCKET" \
            --delete "$(aws s3api list-object-versions \
                --bucket "$BUCKET" \
                --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
                --output json 2>/dev/null)" 2>/dev/null || true
        
        print_success "Bucket emptied: $BUCKET"
    done
else
    print_info "No S3 buckets found"
fi
echo ""

# Step 3: Delete ECR images
print_header "Step 3: Cleaning ECR Repositories"
print_info "Deleting ECR images..."

REPOS=$(aws ecr describe-repositories \
    --query "repositories[?contains(repositoryName, 'cloud-design/$ENVIRONMENT')].repositoryName" \
    --output text 2>/dev/null || true)

if [ -n "$REPOS" ]; then
    for REPO in $REPOS; do
        print_info "Deleting images in: $REPO"
        
        IMAGE_IDS=$(aws ecr list-images \
            --repository-name "$REPO" \
            --query 'imageIds[*]' \
            --output json 2>/dev/null || echo "[]")
        
        if [ "$IMAGE_IDS" != "[]" ]; then
            aws ecr batch-delete-image \
                --repository-name "$REPO" \
                --image-ids "$IMAGE_IDS" 2>/dev/null || true
            print_success "Images deleted from: $REPO"
        fi
    done
else
    print_info "No ECR repositories found"
fi
echo ""

# Step 4: Terraform Destroy
print_header "Step 4: Running Terraform Destroy"
print_warning "This may take 10-15 minutes..."
echo ""

if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found!"
    print_info "Run Terraform destroy manually: cd $TERRAFORM_DIR && terraform destroy"
    exit 1
fi

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    print_info "Initializing Terraform..."
    terraform init -backend-config=backend.hcl
fi

# Run terraform destroy
print_info "Running terraform destroy..."
terraform destroy -auto-approve || {
    print_error "Terraform destroy failed!"
    print_info "Some resources might need manual deletion"
    print_info "Common issues:"
    echo "  1. S3 buckets not empty (we tried to empty them)"
    echo "  2. ENI attachments (wait a few minutes)"
    echo "  3. Security groups in use"
    echo ""
    print_info "Try running again: ./scripts/cleanup.sh $ENVIRONMENT"
    exit 1
}

print_success "Terraform destroy completed"
echo ""

# Step 5: Verify cleanup
print_header "Step 5: Verifying Cleanup"

# Check for remaining EC2 instances
EC2_COUNT=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=cloud-design" \
              "Name=tag:Environment,Values=$ENVIRONMENT" \
              "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null | wc -w || echo "0")

if [ "$EC2_COUNT" -gt 0 ]; then
    print_warning "$EC2_COUNT EC2 instances still exist"
else
    print_success "No EC2 instances found"
fi

# Check for remaining RDS instances
RDS_COUNT=$(aws rds describe-db-instances \
    --query "DBInstances[?contains(DBInstanceIdentifier, 'cloud-design-$ENVIRONMENT')].DBInstanceIdentifier" \
    --output text 2>/dev/null | wc -w || echo "0")

if [ "$RDS_COUNT" -gt 0 ]; then
    print_warning "$RDS_COUNT RDS instances still exist"
else
    print_success "No RDS instances found"
fi

# Check for remaining Load Balancers
ALB_COUNT=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, 'cloud-design-$ENVIRONMENT')].LoadBalancerArn" \
    --output text 2>/dev/null | wc -w || echo "0")

if [ "$ALB_COUNT" -gt 0 ]; then
    print_warning "$ALB_COUNT Load Balancers still exist"
else
    print_success "No Load Balancers found"
fi

echo ""

# Final summary
print_header "Cleanup Summary"
echo ""

if [ "$EC2_COUNT" -eq 0 ] && [ "$RDS_COUNT" -eq 0 ] && [ "$ALB_COUNT" -eq 0 ]; then
    print_success "All resources cleaned up successfully!"
    echo ""
    print_info "Note: Some resources may take a few minutes to fully terminate"
    print_info "Check AWS Console to verify complete cleanup"
else
    print_warning "Some resources may still exist"
    print_info "Wait a few minutes and check AWS Console"
    print_info "You may need to manually delete:"
    echo "  - Elastic Network Interfaces (ENI)"
    echo "  - Security Groups (if referenced)"
    echo "  - S3 buckets (if versioning issues)"
fi

echo ""
print_info "To check remaining resources:"
echo "  aws ec2 describe-instances --filters 'Name=tag:Environment,Values=$ENVIRONMENT'"
echo "  aws rds describe-db-instances"
echo "  aws elbv2 describe-load-balancers"
echo "  aws s3 ls | grep cloud-design-$ENVIRONMENT"
echo ""

print_success "Cleanup script completed!"