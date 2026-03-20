#!/usr/bin/env bash
# scripts/health_check.sh
# Verifies all services are running correctly.
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} $name"
    ((PASS++)) || true
  else
    echo -e "  ${RED}✗${NC} $name"
    ((FAIL++)) || true
  fi
}

echo ""
echo "  Cloud Bank SG — Health Check"
echo "  ─────────────────────────────────────────"

echo ""
echo "  Infrastructure:"
check "LocalStack running"              "curl -sf http://localhost:4566/_localstack/health"
check "Mock Auth service"               "curl -sf http://localhost:5001/health"
check "Mock Notifications service"      "curl -sf http://localhost:5004/health"

echo ""
echo "  AWS Services (via LocalStack):"
check "S3 reachable"                    "aws --endpoint-url=http://localhost:4566 s3 ls"
check "DynamoDB reachable"              "aws --endpoint-url=http://localhost:4566 dynamodb list-tables"
check "SQS reachable"                   "aws --endpoint-url=http://localhost:4566 sqs list-queues"
check "SNS reachable"                   "aws --endpoint-url=http://localhost:4566 sns list-topics"
check "Lambda reachable"                "aws --endpoint-url=http://localhost:4566 lambda list-functions"
check "API Gateway reachable"           "aws --endpoint-url=http://localhost:4566 apigateway get-rest-apis"

echo ""
echo "  Provisioned Resources:"
check "KYC S3 bucket exists"            "aws --endpoint-url=http://localhost:4566 s3 ls s3://cloud-bank-kyc-documents-local"
check "Statements S3 bucket exists"     "aws --endpoint-url=http://localhost:4566 s3 ls s3://cloud-bank-statements-local"
check "Sessions DynamoDB table exists"  "aws --endpoint-url=http://localhost:4566 dynamodb describe-table --table-name cloud-bank-user-sessions"
check "Transaction queue exists"        "aws --endpoint-url=http://localhost:4566 sqs get-queue-url --queue-name cloud-bank-transactions-local"

echo ""
echo "  ─────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}All $PASS checks passed ✅${NC}"
else
  echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed ✗${NC}"
  echo ""
  echo "  Tip: run ./scripts/bootstrap.sh if services aren't running."
  exit 1
fi
echo ""
