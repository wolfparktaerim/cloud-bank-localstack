#!/usr/bin/env bash
# scripts/bootstrap.sh
# One-command setup for new team members.
# Run this once after cloning the repo.
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[bootstrap]${NC} $1"; }
warn() { echo -e "${YELLOW}[bootstrap]${NC} $1"; }
fail() { echo -e "${RED}[bootstrap] ERROR:${NC} $1"; exit 1; }

echo ""
echo "  ███╗   ██╗███████╗ ██████╗ ██████╗  █████╗ ███╗   ██╗██╗  ██╗"
echo "  ████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝"
echo "  ██╔██╗ ██║█████╗  ██║   ██║██████╔╝███████║██╔██╗ ██║█████╔╝ "
echo "  ██║╚██╗██║██╔══╝  ██║   ██║██╔══██╗██╔══██║██║╚██╗██║██╔═██╗ "
echo "  ██║ ╚████║███████╗╚██████╔╝██████╔╝██║  ██║██║ ╚████║██║  ██╗"
echo "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝"
echo "  Cloud Bank SG — LocalStack + Terraform Setup"
echo ""

# ── 1. Check prerequisites ────────────────────
log "Checking prerequisites..."

command -v docker    &>/dev/null || fail "Docker not found. Install from https://docker.com"
command -v terraform &>/dev/null || fail "Terraform not found. Run: brew install terraform"
command -v python3   &>/dev/null || fail "Python 3 not found. Install from https://python.org"
command -v aws       &>/dev/null || fail "AWS CLI not found. Run: brew install awscli"

TERRAFORM_VERSION=$(terraform version -json | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])")
log "  ✓ Docker:    $(docker --version | cut -d' ' -f3 | tr -d ',')"
log "  ✓ Terraform: $TERRAFORM_VERSION"
log "  ✓ Python:    $(python3 --version | cut -d' ' -f2)"
log "  ✓ AWS CLI:   $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"

# ── 2. Configure fake AWS credentials for LocalStack ──
log "Configuring AWS CLI for LocalStack..."
aws configure set aws_access_key_id     "test"
aws configure set aws_secret_access_key "test"
aws configure set region                "ap-southeast-1"
aws configure set output                "json"
log "  ✓ AWS CLI configured (dummy credentials for LocalStack)"

# ── 3. Start LocalStack via Docker Compose ────
log "Starting LocalStack..."
docker compose up -d localstack

log "Waiting for LocalStack to be ready..."
for i in {1..30}; do
  if curl -sf http://localhost:4566/_localstack/health | python3 -c "import sys,json; h=json.load(sys.stdin); sys.exit(0 if h.get('status')=='running' else 1)" 2>/dev/null; then
    log "  ✓ LocalStack is healthy"
    break
  fi
  if [ "$i" -eq 30 ]; then
    fail "LocalStack did not start in time. Check: docker compose logs localstack"
  fi
  echo -n "."
  sleep 2
done

# ── 4. Start mock services ────────────────────
log "Starting Python mock services (auth, notifications)..."
docker compose up -d mock-auth mock-email
sleep 3

# Quick health check on mock services
curl -sf http://localhost:5001/health > /dev/null && log "  ✓ mock-auth is healthy" || warn "  ⚠ mock-auth not ready yet"
curl -sf http://localhost:5002/health > /dev/null && log "  ✓ mock-notifications is healthy" || warn "  ⚠ mock-notifications not ready yet"

# ── 5. Terraform init & apply ─────────────────
log "Initialising Terraform..."
cd terraform
terraform init -upgrade

log "Validating Terraform configuration..."
terraform validate && log "  ✓ Terraform config is valid" || fail "Terraform validation failed"

log "Applying Terraform (this provisions all AWS resources in LocalStack)..."
terraform apply \
  -var-file="environments/localstack/terraform.tfvars" \
  -auto-approve

log "  ✓ All infrastructure provisioned in LocalStack"

# ── 6. Seed test data ─────────────────────────
cd ..
log "Seeding LocalStack with test data..."
python3 scripts/seed_data.py && log "  ✓ Test data seeded" || warn "  ⚠ Seed script failed — you can run it manually: python3 scripts/seed_data.py"

# ── 7. Print summary ──────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo "  LocalStack:         http://localhost:4566"
echo "  Mock Auth:          http://localhost:5001"
echo "  Mock Notifications: http://localhost:5002"
echo ""
echo "  Useful commands:"
echo "    ./scripts/health_check.sh   — verify everything is running"
echo "    ./scripts/destroy.sh        — tear down everything"
echo "    python3 scripts/seed_data.py — re-seed test data"
echo ""
echo "  Run tests:"
echo "    pytest tests/unit/"
echo "    pytest tests/integration/"
echo ""
