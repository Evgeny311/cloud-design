#!/bin/bash
# ======
# Test Application Endpoints
# ======

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Get Master Node IP
MASTER_IP=$(cd terraform/environments/dev && terraform output -raw k3s_master_public_ip)

print_info "Master Node IP: $MASTER_IP"
echo ""

# Test endpoints via NodePort
print_info "Testing API Gateway (NodePort 30000)..."
curl -s "http://${MASTER_IP}:30000/" | jq .
echo ""

print_info "Testing Inventory App (NodePort 30001)..."
curl -s "http://${MASTER_IP}:30001/api/movies" | jq .
echo ""

print_info "Testing Billing App (NodePort 30002)..."
curl -s "http://${MASTER_IP}:30002/api/orders" | jq .
echo ""

print_success "All tests completed!"