@echo off
setlocal enabledelayedexpansion

echo 🧹 Cleaning up existing environment...

REM 1. Kill lingering processes (ignores error if not running)
taskkill /F /IM terraform.exe /T >nul 2>&1
timeout /t 2 /nobreak >nul

REM 2. Attempt a clean teardown if state exists
IF EXIST "terraform.tfstate" (
    echo 🗑️  Tearing down existing cloud resources...
    terraform destroy -auto-approve -lock=false
)

REM 3. Wipe state and temp files
if exist ".terraform.tfstate.lock.info" del /f /q ".terraform.tfstate.lock.info"
if exist ".terraform\" rd /s /q ".terraform"
if exist "terraform.tfstate*" del /f /q "terraform.tfstate*"
if exist "lambda.zip" del /f /q "lambda.zip"

REM 4. Reset Containers
docker-compose down -v
docker-compose up -d

echo ⏳ Waiting for LocalStack Services (S3, SecretsManager, Iam)...

REM HEALTH CHECK LOOP (Windows Batch Version)
set MAX_RETRIES=30
set COUNT=0

:loop
curl -s http://localhost:4566/_localstack/health | findstr /C:"\"s3\": \"available\"" >nul
if %ERRORLEVEL% EQU 0 (
    goto :ready
)

set /a COUNT+=1
if %COUNT% GEQ %MAX_RETRIES% (
    echo ❌ LocalStack failed to initialize in time.
    exit /b 1
)

<nul set /p=.
timeout /t 2 /nobreak >nul
goto :loop

:ready
echo.
echo ✅ LocalStack Services are READY.

REM 5. Package App Tier
echo 📦 Packaging Bank Logic...
if exist "package" rd /s /q "package"
mkdir "package"

pip install --target "%CD%\package" pymongo >nul
copy "index.py" "package\" >nul

REM Zip the package (Requires PowerShell if 'zip' utility isn't installed)
powershell -Command "Compress-Archive -Path 'package\*' -DestinationPath 'lambda.zip' -Force"

REM 6. Re-deploy
echo 🏗️  Re-deploying Architecture...
terraform init
terraform apply -auto-approve -lock=false

echo ✅ Clean deployment finished.
terraform output api_url