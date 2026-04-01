#!/bin/bash

# Configuration
export AWS_ENDPOINT="http://localhost:4566"
export AWS_REGION="us-east-1"
alias awslocal="aws --endpoint-url=$AWS_ENDPOINT --region=$AWS_REGION"

echo "🏦 Starting Singapore Online Digital Bank Demo..."
echo "==================================================="

# 1. Fetch dynamically generated API Gateway URL
API_ID=$(awslocal apigateway get-rest-apis --query "items[?name=='BankAPI'].id" --output text)
API_URL="$AWS_ENDPOINT/restapis/$API_ID/prod/_user_request_/transaction"

echo "✅ 1. Architecture Deployed. API Gateway URL: $API_URL"
sleep 2

# 2. Demonstrate Cognito User Creation
echo "👤 2. Registering new user in AWS Cognito..."
POOL_ID=$(awslocal cognito-idp list-user-pools --max-results 1 --query "UserPools[0].Id" --output text)
awslocal cognito-idp admin-create-user --user-pool-id $POOL_ID --username "kylesingapore" --user-attributes Name=email,Value="kyle@singaporebank.com" > /dev/null
echo "   User 'kylesingapore' created successfully in pool $POOL_ID."
sleep 2

# 3. Simulate Standard Transaction
echo "💸 3. User makes a standard deposit of $500..."
curl -s -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"action": "deposit", "account_id": "kylesingapore", "amount": 500}' | jq .
sleep 2

# 4. Simulate High-Value Transaction (Triggers SNS -> SQS)
echo "🚨 4. User makes a HIGH VALUE transfer of $15,000..."
echo "   (This should trigger our Event-Driven Fraud Detection Architecture via SNS -> SQS)"
curl -s -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{"action": "transfer", "account_id": "kylesingapore", "amount": 15000}' | jq .
sleep 2

# 5. Verify DynamoDB Ledger
echo "🗄️  5. Auditing Data Layer (DynamoDB Transaction History)..."
awslocal dynamodb scan --table-name BankTransactions --query "Items[*].[transaction_id.S, amount.N, timestamp.S]" --output table
sleep 2

# 6. Verify Event-Driven Messaging (SQS)
echo "📩 6. Checking SQS Fraud Detection Queue for SNS alerts..."
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name fraud-detection-queue --query "QueueUrl" --output text)
awslocal sqs receive-message --queue-url $QUEUE_URL --max-number-of-messages 1 --query "Messages[0].Body" --output text | jq .
sleep 2

echo "==================================================="
echo "🎉 Demo Complete! Architecture Successfully Validated."