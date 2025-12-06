#!/bin/bash
# ============================================
# K3s Setup Script (Placeholder)
# ============================================
# This script is not currently used.
# K3s installation is automated via Terraform
# user-data scripts in terraform/modules/ec2/
# ============================================
#
# K3s is installed automatically when EC2 instances
# are created by Terraform using these scripts:
#   - terraform/modules/ec2/user-data/k3s-master.sh
#   - terraform/modules/ec2/user-data/k3s-worker.sh
#
# This file is reserved for future use cases:
#   1. Manual K3s installation on existing EC2
#   2. Local K3s installation for development
#   3. K3s version upgrades
#   4. Troubleshooting and recovery
#
# ============================================

echo "This script is not implemented yet."
echo ""
echo "K3s is installed automatically via Terraform user-data."
echo "See: terraform/modules/ec2/user-data/"
echo ""
echo "For manual installation, use:"
echo "  curl -sfL https://get.k3s.io | sh -"
echo ""

exit 0