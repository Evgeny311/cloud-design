#!/bin/bash
# ======
# Deploy Applications to K3s Cluster
# ======
# Deploys microservices to K3s using kubectl
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
IMAGE_TAG=${2:-latest}
NAMESPACE="microservices"

print_header "Deploy Applications to K3s"
echo ""
print_info "Environment: $ENVIRONMENT"
print_info "Image Tag:   $IMAGE_TAG"
print_info "Namespace:   $NAMESPACE"
echo ""

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed!"
    exit 1
fi

# Check if kubeconfig is set
if [ -z "$KUBECONFIG" ] && [ ! -f "$HOME/.kube/config" ]; then
    print_error "Kubeconfig not found!"
    print_info "Get kubeconfig from K3s master:"
    echo "  ssh ec2-user@<MASTER_IP> 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/config"
    echo "  sed -i 's/127.0.0.1/<MASTER_IP>/g' ~/.kube/config"
    exit 1
fi

# Test cluster connection
print_info "Testing cluster connection..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster!"
    print_info "Check your kubeconfig and cluster status"
    exit 1
fi

print_success "Connected to cluster"
kubectl get nodes
echo ""

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"

# Create namespace if it doesn't exist
print_header "Creating Namespace"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
print_success "Namespace '$NAMESPACE' ready"
echo ""

# Apply ConfigMaps
print_header "Applying ConfigMaps"
if [ -d "$K8S_DIR/configmaps" ]; then
    kubectl apply -f "$K8S_DIR/configmaps/" -n "$NAMESPACE"
    print_success "ConfigMaps applied"
else
    print_warning "ConfigMaps directory not found"
fi
echo ""

# Apply Secrets
print_header "Applying Secrets"
if [ -d "$K8S_DIR/secrets" ]; then
    # Get secrets from AWS Secrets Manager
    print_info "Retrieving secrets from AWS Secrets Manager..."
    
    REGION=${AWS_DEFAULT_REGION:-eu-north-1}
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    
    # Get RDS credentials
    INVENTORY_SECRET=$(aws secretsmanager get-secret-value \
        --secret-id "cloud-design-${ENVIRONMENT}-inventory-db" \
        --region "$REGION" \
        --query SecretString --output text 2>/dev/null || echo "")
    
    BILLING_SECRET=$(aws secretsmanager get-secret-value \
        --secret-id "cloud-design-${ENVIRONMENT}-billing-db" \
        --region "$REGION" \
        --query SecretString --output text 2>/dev/null || echo "")
    
    if [ -n "$INVENTORY_SECRET" ]; then
        # Create database secret
        kubectl create secret generic database-secret \
            --from-literal=inventory-connection="$INVENTORY_SECRET" \
            --from-literal=billing-connection="$BILLING_SECRET" \
            --namespace="$NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        print_success "Database secrets created"
    else
        print_warning "Could not retrieve secrets from AWS Secrets Manager"
        print_info "Applying secrets from files..."
        kubectl apply -f "$K8S_DIR/secrets/" -n "$NAMESPACE"
    fi
else
    print_warning "Secrets directory not found"
fi
echo ""

# Apply Services
print_header "Applying Services"
if [ -d "$K8S_DIR/services" ]; then
    kubectl apply -f "$K8S_DIR/services/" -n "$NAMESPACE"
    print_success "Services applied"
else
    print_warning "Services directory not found"
fi
echo ""

# Apply Deployments
print_header "Applying Deployments"
if [ -d "$K8S_DIR/deployments" ]; then
    # Update image tags in deployments
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
    
    for deployment in "$K8S_DIR/deployments"/*.yaml; do
        if [ -f "$deployment" ]; then
            SERVICE_NAME=$(basename "$deployment" .yaml)
            print_info "Deploying $SERVICE_NAME..."
            
            # Apply deployment
            kubectl apply -f "$deployment" -n "$NAMESPACE"
            
            # Update image if not using latest
            if [ "$IMAGE_TAG" != "latest" ]; then
                IMAGE_PATH="cloud-design/${ENVIRONMENT}/${SERVICE_NAME}"
                kubectl set image "deployment/${SERVICE_NAME}" \
                    "${SERVICE_NAME}=${ECR_REGISTRY}/${IMAGE_PATH}:${IMAGE_TAG}" \
                    -n "$NAMESPACE" 2>/dev/null || true
            fi
        fi
    done
    print_success "Deployments applied"
else
    print_warning "Deployments directory not found"
fi
echo ""

# Apply Ingress
print_header "Applying Ingress"
if [ -d "$K8S_DIR/ingress" ]; then
    kubectl apply -f "$K8S_DIR/ingress/" -n "$NAMESPACE"
    print_success "Ingress applied"
else
    print_warning "Ingress directory not found"
fi
echo ""

# Apply HPA (if exists)
if [ -d "$K8S_DIR/hpa" ]; then
    print_header "Applying Horizontal Pod Autoscalers"
    kubectl apply -f "$K8S_DIR/hpa/" -n "$NAMESPACE"
    print_success "HPA applied"
    echo ""
fi

# Wait for deployments to be ready
print_header "Waiting for Deployments"
print_info "Waiting for all deployments to be ready..."
kubectl wait --for=condition=available \
    --timeout=300s \
    deployment --all \
    -n "$NAMESPACE" 2>/dev/null || {
    print_warning "Some deployments are not ready yet"
}
echo ""

# Show deployment status
print_header "Deployment Status"
kubectl get all -n "$NAMESPACE"
echo ""

# Get ALB DNS name
print_header "Application Endpoints"
print_info "Getting ALB DNS name from Terraform outputs..."
cd "$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")

if [ -n "$ALB_DNS" ]; then
    echo ""
    print_success "Application is accessible at:"
    echo "  API Gateway:   http://${ALB_DNS}/api"
    echo "  Inventory App: http://${ALB_DNS}/inventory"
    echo "  Billing App:   http://${ALB_DNS}/billing"
    echo ""
else
    print_warning "Could not get ALB DNS name from Terraform"
    print_info "Get it manually with: terraform output alb_dns_name"
fi

print_success "Deployment complete!"
echo ""
print_info "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/api-gateway -n $NAMESPACE"
echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
echo ""