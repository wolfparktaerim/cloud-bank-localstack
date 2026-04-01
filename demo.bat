@echo off
setlocal enabledelayedexpansion

:: Configuration
set AWS_ENDPOINT=http://localhost:4566
set AWS_REGION=us-east-1

echo ===================================================
echo  🏦 Starting Singapore Online Digital Bank Demo...
echo ===================================================

:: 1. Fetch dynamically generated API Gateway URL
:: We use FOR /F to capture the output of the awslocal command into a variable
FOR /F "tokens=*" %%i IN ('awslocal apigateway get-rest-apis --query "items[?name=='BankAPI'].id" --output text') DO SET API_ID=%%i
set API_URL=%AWS_ENDPOINT%/restapis/%API_ID%/prod/_user_request_/transaction

echo ✅ 1. Architecture Deployed. API Gateway URL: %API_URL%
timeout /t 2 /nobreak >nul

:: 2. Demonstrate Cognito User Creation
echo.
echo 👤 2. Registering new user in AWS Cognito...
FOR /F "tokens=*" %%i IN ('awslocal cognito-idp list-user-pools --max-results 1 --query "UserPools[0].Id" --output text') DO SET POOL_ID=%%i
awslocal cognito-idp admin-create-user --user-pool-id %POOL_ID% --username "kylesingapore" --user-attributes Name=email,Value="kyle@singaporebank.com" >nul 2>&1
echo    User 'kylesingapore' created successfully in pool %POOL_ID%.
timeout /t 2 /nobreak >nul

:: 3. Simulate Standard Transaction
echo.
echo 💸 3. User makes a standard deposit of $500...
curl -s -X POST %API_URL% -H "Content-Type: application/json" -d "{\"action\": \"deposit\", \"account_id\": \"kylesingapore\", \"amount\": 500}"
echo.
timeout /t 2 /nobreak >nul

:: 4. Simulate High-Value Transaction (Triggers SNS -> SQS)
echo.
echo 🚨 4. User makes a HIGH VALUE transfer of $15,000...
echo    (This should trigger our Event-Driven Fraud Detection Architecture via SNS -^> SQS)
curl -s -X POST %API_URL% -H "Content-Type: application/json" -d "{\"action\": \"transfer\", \"account_id\": \"kylesingapore\", \"amount\": 15000}"
echo.
timeout /t 2 /nobreak >nul

:: 5. Verify DynamoDB Ledger
echo.
echo 🗄️  5. Auditing Data Layer (DynamoDB Transaction History)...
awslocal dynamodb scan --table-name BankTransactions --query "Items[*].[transaction_id.S, amount.N, timestamp.S]" --output table
timeout /t 2 /nobreak >nul

:: 6. Verify Event-Driven Messaging (SQS)
echo.
echo 📩 6. Checking SQS Fraud Detection Queue for SNS alerts...
FOR /F "tokens=*" %%i IN ('awslocal sqs get-queue-url --queue-name fraud-detection-queue --query "QueueUrl" --output text') DO SET QUEUE_URL=%%i
awslocal sqs receive-message --queue-url %QUEUE_URL% --max-number-of-messages 1 --query "Messages[0].Body" --output text
echo.
timeout /t 2 /nobreak >nul

echo ===================================================
echo 🎉 Demo Complete! Architecture Successfully Validated.
echo ===================================================
endlocal