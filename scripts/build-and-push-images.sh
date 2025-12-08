#!/bin/bash
# ======
# Build and Push Docker Images to ECR
# ======
# Builds Docker images for all microservices
# and pushes them to AWS ECR
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

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Configuration
ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}
REGION=${AWS_DEFAULT_REGION:-eu-north-1}

print_header "Build and Push Docker Images"
echo ""
print_info "Environment: $ENVIRONMENT"
print_info "Image Tag:   $IMAGE_TAG"
print_info "AWS Region:  $REGION"
echo ""

# Check prerequisites
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed!"
    exit 1
fi

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    print_error "Failed to get AWS Account ID. Check your credentials."
    exit 1
fi

print_info "AWS Account ID: $ACCOUNT_ID"

# ECR Registry URL
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
print_info "ECR Registry: $ECR_REGISTRY"
echo ""

# Login to ECR
print_header "Logging in to ECR"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
print_success "Logged in to ECR"
echo ""

# Project root (assuming script is in scripts/ directory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker"

# Microservices to build
declare -a SERVICES=("api-gateway-app" "inventory-app" "billing-app")

# Build and push each service
for SERVICE in "${SERVICES[@]}"; do
    print_header "Building $SERVICE"
    
    SERVICE_NAME=$(echo "$SERVICE" | sed 's/-app$//')
    IMAGE_NAME="cloud-design/${ENVIRONMENT}/${SERVICE_NAME}"
    FULL_IMAGE="${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    print_info "Building: $FULL_IMAGE"
    
    # Check if Dockerfile exists
    DOCKERFILE="$DOCKER_DIR/$SERVICE/Dockerfile"
    if [ ! -f "$DOCKERFILE" ]; then
        print_error "Dockerfile not found: $DOCKERFILE"
        continue
    fi
    
    # Build image
    docker build \
        -t "$IMAGE_NAME:$IMAGE_TAG" \
        -t "$IMAGE_NAME:latest" \
        -t "$FULL_IMAGE" \
        -f "$DOCKERFILE" \
        "$PROJECT_ROOT" || {
        print_error "Failed to build $SERVICE"
        continue
    }
    
    print_success "Built: $IMAGE_NAME:$IMAGE_TAG"
    
    # Push to ECR
    print_info "Pushing to ECR..."
    docker push "$FULL_IMAGE" || {
        print_error "Failed to push $SERVICE to ECR"
        continue
    }
    
    # Also push latest tag
    if [ "$IMAGE_TAG" != "latest" ]; then
        docker push "${ECR_REGISTRY}/${IMAGE_NAME}:latest" || true
    fi
    
    print_success "Pushed: $FULL_IMAGE"
    echo ""
done

# Summary
print_header "Build Summary"
echo ""
print_info "Images built and pushed:"
for SERVICE in "${SERVICES[@]}"; do
    SERVICE_NAME=$(echo "$SERVICE" | sed 's/-app$//')
    IMAGE_NAME="cloud-design/${ENVIRONMENT}/${SERVICE_NAME}"
    echo "  • ${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
done
echo ""
print_success "All images built and pushed successfully!"
echo ""
print_info "Next steps:"
echo "  1. Deploy to K3s cluster:"
echo "     ./scripts/deploy-applications.sh $ENVIRONMENT $IMAGE_TAG"
echo ""
echo "  2. Or manually update deployments:"
echo "     kubectl set image deployment/api-gateway api-gateway=${ECR_REGISTRY}/cloud-design/${ENVIRONMENT}/api-gateway:${IMAGE_TAG}"
echo ""