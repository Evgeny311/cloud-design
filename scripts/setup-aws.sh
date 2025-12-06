#!/bin/bash
# ======
# AWS Setup Script
# ======
# Sets up AWS CLI and verifies configuration
# ======

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if AWS CLI is installed
print_header "Checking Prerequisites"

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed!"
    print_info "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi
print_success "AWS CLI is installed"

# Check AWS CLI version
AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
print_info "AWS CLI version: $AWS_VERSION"

# Check if credentials are configured
print_header "Checking AWS Credentials"

if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials are not configured!"
    echo ""
    print_info "Configure AWS credentials using one of these methods:"
    echo ""
    echo "1. AWS Configure (recommended for beginners):"
    echo "   aws configure"
    echo ""
    echo "2. Environment variables:"
    echo "   export AWS_ACCESS_KEY_ID='your-access-key'"
    echo "   export AWS_SECRET_ACCESS_KEY='your-secret-key'"
    echo "   export AWS_DEFAULT_REGION='eu-north-1'"
    echo ""
    echo "3. AWS SSO:"
    echo "   aws configure sso"
    echo ""
    exit 1
fi

# Get account information
print_success "AWS credentials are configured"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
REGION=$(aws configure get region)

echo ""
print_info "Account ID: $ACCOUNT_ID"
print_info "User/Role:  $USER_ARN"
print_info "Region:     $REGION"
echo ""

# Check required permissions
print_header "Checking AWS Permissions"

check_permission() {
    local service=$1
    local action=$2
    
    if aws $service $action --dry-run 2>&1 | grep -q "DryRunOperation\|UnauthorizedOperation"; then
        print_success "$service:$action"
    else
        print_warning "$service:$action (may not have permission)"
    fi
}

# Test basic permissions
print_info "Testing basic permissions..."
aws ec2 describe-instances --max-results 1 &> /dev/null && print_success "EC2 permissions" || print_warning "EC2 permissions"
aws rds describe-db-instances --max-results 1 &> /dev/null && print_success "RDS permissions" || print_warning "RDS permissions"
aws s3 ls &> /dev/null && print_success "S3 permissions" || print_warning "S3 permissions"
aws ecr describe-repositories --max-results 1 &> /dev/null && print_success "ECR permissions" || print_warning "ECR permissions"

# Set default region if not set
if [ -z "$REGION" ]; then
    print_warning "Default region is not set"
    read -p "Enter AWS region (e.g., eu-north-1): " INPUT_REGION
    aws configure set region "$INPUT_REGION"
    REGION="$INPUT_REGION"
    print_success "Region set to: $REGION"
fi

# Create SSH key if it doesn't exist
print_header "Checking SSH Keys"

SSH_KEY_PATH="$HOME/.ssh/cloud-design-dev"

if [ ! -f "$SSH_KEY_PATH" ]; then
    print_warning "SSH key not found at $SSH_KEY_PATH"
    read -p "Generate SSH key? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -C "cloud-design-dev" -N ""
        print_success "SSH key generated: $SSH_KEY_PATH"
        print_info "Public key: $SSH_KEY_PATH.pub"
        echo ""
        print_warning "Add this public key to your terraform.tfvars:"
        cat "$SSH_KEY_PATH.pub"
        echo ""
    fi
else
    print_success "SSH key exists: $SSH_KEY_PATH"
fi

# Check if terraform is installed
print_header "Checking Terraform"

if ! command -v terraform &> /dev/null; then
    print_warning "Terraform is not installed"
    print_info "Install from: https://www.terraform.io/downloads"
else
    TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    print_success "Terraform is installed: v$TERRAFORM_VERSION"
fi

# Check if kubectl is installed
print_header "Checking kubectl"

if ! command -v kubectl &> /dev/null; then
    print_warning "kubectl is not installed"
    print_info "Install from: https://kubernetes.io/docs/tasks/tools/"
else
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)
    print_success "kubectl is installed: $KUBECTL_VERSION"
fi

# Check if docker is installed
print_header "Checking Docker"

if ! command -v docker &> /dev/null; then
    print_warning "Docker is not installed"
    print_info "Install from: https://docs.docker.com/get-docker/"
else
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_success "Docker is installed: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_warning "Docker daemon is not running"
        print_info "Start Docker Desktop or run: sudo systemctl start docker"
    fi
fi

# Summary
print_header "Setup Summary"

echo ""
print_info "Your AWS Account ID: $ACCOUNT_ID"
print_info "Your AWS Region: $REGION"
echo ""
print_info "Next steps:"
echo "  1. Copy terraform.tfvars.example to terraform.tfvars"
echo "     cd terraform/environments/dev"
echo "     cp terraform.tfvars.example terraform.tfvars"
echo ""
echo "  2. Edit terraform.tfvars with your values"
echo "     - Add your SSH public key"
echo "     - Set k3s_cluster_token (generate with: openssl rand -base64 32)"
echo "     - Update other values as needed"
echo ""
echo "  3. Update backend.hcl with your Account ID"
echo "     Replace REPLACE_WITH_ACCOUNT_ID with: $ACCOUNT_ID"
echo ""
echo "  4. Initialize Terraform"
echo "     cd terraform/environments/dev"
echo "     terraform init -backend-config=backend.hcl"
echo ""
echo "  5. Deploy infrastructure"
echo "     terraform plan"
echo "     terraform apply"
echo ""

print_success "Setup check complete!"