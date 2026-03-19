#!/usr/bin/env bash
# scripts/destroy.sh
# Tears down all LocalStack resources and stops containers.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[destroy]${NC} $1"; }
warn() { echo -e "${YELLOW}[destroy]${NC} $1"; }

echo ""
warn "⚠  This will destroy ALL LocalStack resources and stop all containers."
read -p "   Are you sure? (yes/no): " confirm
[ "$confirm" = "yes" ] || { echo "Aborted."; exit 0; }
echo ""

# ── 1. Terraform destroy ──────────────────────
log "Destroying Terraform-managed resources..."
cd terraform
if [ -f ".terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
  terraform destroy \
    -var-file="environments/localstack/terraform.tfvars" \
    -auto-approve
  log "  ✓ Terraform resources destroyed"
else
  warn "  No Terraform state found — skipping"
fi
cd ..

# ── 2. Stop Docker containers ─────────────────
log "Stopping Docker containers..."
docker compose down -v
log "  ✓ All containers stopped and volumes removed"

# ── 3. Clean up local state ───────────────────
log "Cleaning up local Terraform state..."
rm -rf terraform/.terraform terraform/terraform.tfstate terraform/terraform.tfstate.backup terraform/.terraform.lock.hcl
log "  ✓ Terraform state cleaned"

echo ""
echo -e "${GREEN}  ✅ Everything torn down cleanly.${NC}"
echo "     Run ./scripts/bootstrap.sh to start fresh."
echo ""
