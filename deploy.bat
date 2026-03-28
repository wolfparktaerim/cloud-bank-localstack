
@echo off
setlocal enabledelayedexpansion

REM 1. Load Environment Variables from .env
if exist .env (
    echo 🔑 Loading environment variables from .env...
    for /f "tokens=*" %%i in ('type .env ^| findstr /v "^#"') do (
        set "%%i"
    )
)

REM 2. Package Lambda with dependencies
echo 📦 Packaging Lambda...

if exist "package" rd /s /q "package"
if exist "lambda.zip" del /f /q "lambda.zip"
mkdir "package"

REM Install Python dependencies into the package folder
pip install --target "%CD%\package" pymongo >nul

REM Copy the application logic
copy "index.py" "package\" >nul

REM Use PowerShell to create the zip file (Native Windows alternative to 'zip')
powershell -Command "Compress-Archive -Path 'package\*' -DestinationPath 'lambda.zip' -Force"

REM 3. Start Infrastructure
docker-compose up -d

echo ⏳ Waiting 15s for LocalStack...
timeout /t 15 /nobreak >nul

REM 4. Deploy with Terraform
terraform init
terraform apply -auto-approve

echo 🚀 Deployment complete!
terraform output api_url

pause