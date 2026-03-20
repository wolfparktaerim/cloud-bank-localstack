# scripts/restart.ps1
# Cleanly restarts all services. Run this if anything is broken.
# Usage: .\scripts\restart.ps1

Write-Host "`n  Stopping all containers..." -ForegroundColor Yellow
docker compose down

Write-Host "  Checking for port conflicts..." -ForegroundColor Yellow

$ports = @(5001, 5003, 5004)
foreach ($port in $ports) {
    $result = netstat -ano | Select-String ":$port "
    if ($result) {
        $result | ForEach-Object {
            $parts = $_.ToString().Trim() -split '\s+'
            $pid = $parts[-1]
            if ($pid -match '^\d+$' -and $pid -ne "0") {
                Write-Host "  Killing process on port $port (PID $pid)" -ForegroundColor Yellow
                try { taskkill /PID $pid /F 2>$null } catch {}
            }
        }
    }
}

Write-Host "  Starting all services..." -ForegroundColor Green
docker compose up -d --build

Write-Host "  Waiting for LocalStack (up to 60s)..." -ForegroundColor Yellow
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 3
    try {
        $h = Invoke-RestMethod "http://localhost:4566/_localstack/health" -TimeoutSec 3
        if ($h.status -eq "running") { $ready = $true; break }
    } catch {}
    Write-Host -NoNewline "."
}

if (-not $ready) {
    Write-Host "`n  LocalStack not ready — check: docker compose logs localstack" -ForegroundColor Red
    exit 1
}

Write-Host "`n  Waiting for mock services..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

# Health check all services
$services = @(
    @{ Name="LocalStack";       Url="http://localhost:4566/_localstack/health" },
    @{ Name="Mock Auth";        Url="http://localhost:5001/health" },
    @{ Name="Mock Notifications"; Url="http://localhost:5004/health" },
    @{ Name="Mock KYC";         Url="http://localhost:5003/health" }
)

Write-Host ""
foreach ($svc in $services) {
    try {
        $r = Invoke-RestMethod $svc.Url -TimeoutSec 3
        Write-Host "  OK  $($svc.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  --  $($svc.Name) (may still be starting)" -ForegroundColor Yellow
    }
}

Write-Host @"

  ============================================================
  Services restarted. Run Terraform if needed:

    cd terraform
    terraform init
    terraform apply -var-file="environments/localstack/terraform.tfvars" -auto-approve
    cd ..
    python scripts/seed_data.py

  Then run the demo:
    python demo.py
  ============================================================
"@ -ForegroundColor Green
