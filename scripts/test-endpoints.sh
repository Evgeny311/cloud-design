#!/bin/bash
# ======
# Test Application Endpoints
# ======
# Tests all microservices endpoints
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
ALB_DNS=${2:-}

print_header "Testing Application Endpoints"
echo ""

# Get ALB DNS from Terraform if not provided
if [ -z "$ALB_DNS" ]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    TERRAFORM_DIR="$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    if [ -d "$TERRAFORM_DIR" ]; then
        cd "$TERRAFORM_DIR"
        ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    fi
fi

if [ -z "$ALB_DNS" ]; then
    print_error "ALB DNS not found!"
    print_info "Usage: $0 <environment> <alb-dns-name>"
    print_info "   or: $0 dev (will auto-detect from Terraform)"
    exit 1
fi

print_info "Testing environment: $ENVIRONMENT"
print_info "ALB DNS: $ALB_DNS"
echo ""

# Test function
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    print_info "Testing $name..."
    echo "  URL: $url"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$response" == "$expected_status" ]; then
        print_success "$name responded with $response"
    else
        print_error "$name failed! Expected $expected_status, got $response"
        return 1
    fi
    echo ""
}

# Test ALB health
print_header "Testing Load Balancer"
test_endpoint "ALB Root" "http://${ALB_DNS}/" 404  # Expected 404 for root

# Test API Gateway
print_header "Testing API Gateway"
test_endpoint "API Gateway Health" "http://${ALB_DNS}/api/health" 200
test_endpoint "API Gateway Root" "http://${ALB_DNS}/api/" 200

# Test Inventory App
print_header "Testing Inventory App"
test_endpoint "Inventory Health" "http://${ALB_DNS}/inventory/health" 200
test_endpoint "Inventory Movies" "http://${ALB_DNS}/inventory/movies" 200

# Test Billing App
print_header "Testing Billing App"
test_endpoint "Billing Health" "http://${ALB_DNS}/billing/health" 200
test_endpoint "Billing Orders" "http://${ALB_DNS}/billing/orders" 200

# Detailed API tests
print_header "Detailed API Tests"

# Test GET movies
print_info "GET /inventory/movies"
curl -s "http://${ALB_DNS}/inventory/movies" | jq . 2>/dev/null || curl -s "http://${ALB_DNS}/inventory/movies"
echo ""

# Test GET orders
print_info "GET /billing/orders"
curl -s "http://${ALB_DNS}/billing/orders" | jq . 2>/dev/null || curl -s "http://${ALB_DNS}/billing/orders"
echo ""

# Summary
print_header "Test Summary"
echo ""
print_success "All endpoint tests completed!"
echo ""
print_info "Application URLs:"
echo "  API Gateway:   http://${ALB_DNS}/api"
echo "  Inventory App: http://${ALB_DNS}/inventory"
echo "  Billing App:   http://${ALB_DNS}/billing"
echo ""
print_info "To test manually:"
echo "  curl http://${ALB_DNS}/api/health"
echo "  curl http://${ALB_DNS}/inventory/movies"
echo "  curl http://${ALB_DNS}/billing/orders"
echo ""