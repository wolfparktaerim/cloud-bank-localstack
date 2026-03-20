# scripts/setup-windows.ps1
# Windows replacement for bootstrap.sh
# Run in PowerShell from the project root:
#   .\scripts\setup-windows.ps1

$ErrorActionPreference = "Stop"

function Log   { Write-Host "  [setup] $args" -ForegroundColor Green }
function Warn  { Write-Host "  [setup] $args" -ForegroundColor Yellow }
function Fail  { Write-Host "  [ERROR] $args" -ForegroundColor Red; exit 1 }

Write-Host @"

  ███╗   ██╗███████╗ ██████╗ ██████╗  █████╗ ███╗   ██╗██╗  ██╗
  Cloud Bank SG — Windows Setup Script
  LocalStack + Terraform

"@ -ForegroundColor Cyan

# ── 1. Check prerequisites ─────────────────────
Log "Checking prerequisites..."

if (-not (Get-Command docker -ErrorAction SilentlyContinue))  { Fail "Docker not found. Install Docker Desktop from https://docker.com" }
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { Fail "Terraform not found. Run: winget install Hashicorp.Terraform" }
if (-not (Get-Command python -ErrorAction SilentlyContinue))   { Fail "Python not found. Install from https://python.org" }
if (-not (Get-Command aws -ErrorAction SilentlyContinue))      { Fail "AWS CLI not found. Run: winget install Amazon.AWSCLI" }

Log "  OK Docker:    $(docker --version)"
Log "  OK Terraform: $(terraform version -json | python -c 'import sys,json; print(json.load(sys.stdin)[\"terraform_version\"])')"
Log "  OK Python:    $(python --version)"
Log "  OK AWS CLI:   $(aws --version)"

# ── 2. Configure AWS credentials ──────────────
Log "Configuring AWS CLI for LocalStack (dummy credentials)..."
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set region ap-southeast-1
aws configure set output json
Log "  OK AWS CLI configured"

# ── 3. Install Python dependencies ────────────
Log "Installing Python dependencies..."
pip install boto3 flask pyjwt pytest requests --quiet
Log "  OK Python packages installed"

# ── 4. Start Docker services ──────────────────
Log "Starting LocalStack and mock services via Docker Compose..."
docker compose up -d

Log "Waiting for LocalStack to be ready (up to 60s)..."
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    try {
        $health = Invoke-RestMethod -Uri "http://localhost:4566/_localstack/health" -TimeoutSec 3
        if ($health.status -eq "running") {
            Log "  OK LocalStack is healthy"
            $ready = $true
            break
        }
    } catch {}
    Start-Sleep -Seconds 3
    Write-Host -NoNewline "."
}
if (-not $ready) { Fail "LocalStack did not start. Check: docker compose logs localstack" }

# Small wait for mock services
Start-Sleep -Seconds 5
Log "  OK Mock services starting up"

# ── 5. Terraform init & apply ─────────────────
Log "Running Terraform init..."
Set-Location terraform
terraform init

Log "Applying Terraform (creates all AWS resources in LocalStack)..."
terraform apply -var-file="environments/localstack/terraform.tfvars" -auto-approve

Set-Location ..
Log "  OK All infrastructure provisioned"

# ── 6. Seed data ──────────────────────────────
Log "Seeding test data..."
python scripts/seed_data.py
Log "  OK Test data seeded"

# ── 7. Summary ────────────────────────────────
Write-Host @"

  ============================================================
    Setup complete!
  ============================================================

    LocalStack:          http://localhost:4566
    Mock Auth:           http://localhost:5001
    Mock Notifications:  http://localhost:5002

    Run the demo:
      python demo.py

    Run tests:
      pytest tests/unit/
      pytest tests/integration/

    Tear down when done:
      docker compose down
"@ -ForegroundColor Green
