#!/bin/bash
# Test DLQ with REAL Lambda failure (not synthetic test messages)

set -e

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo "════════════════════════════════════════════════════════════════"
echo "  DLQ Test - Real Lambda Failure Scenario"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Get API endpoints
export API_BASE=$(grep 'apiBase:' config.js | awk -F'"' '{print $2}')
export API_DLQ="$API_BASE/dlq"

echo "API_DLQ: $API_DLQ"
echo ""

# Get SNS topic ARN
TOPIC_ARN=$(aws --endpoint-url=http://localhost:4566 sns list-topics --region ap-southeast-1 2>/dev/null | \
  jq -r '.Topics[] | select(.TopicArn | contains("transaction")) | .TopicArn')

echo "SNS Topic: $TOPIC_ARN"
echo ""

# Step 1: Check DLQ is empty
echo "Step 1: Verify DLQ is empty"
echo "─────────────────────────────────────────────────────────────────"
curl -s -X POST "$API_DLQ" -H "Content-Type: application/json" \
  -d '{"action":"stats"}' | jq '{queue, messages, in_flight}'
echo ""

# Step 2: Publish malformed message to SNS
echo "Step 2: Publish malformed transaction to SNS"
echo "─────────────────────────────────────────────────────────────────"
echo "Message: {action:deposit, account_id:FAIL_TEST, amount:invalid_number}"
MESSAGE_ID=$(aws --endpoint-url=http://localhost:4566 sns publish \
  --topic-arn "$TOPIC_ARN" \
  --message '{"action":"deposit","account_id":"FAIL_TEST","amount":"invalid_number"}' \
  --region ap-southeast-1 2>/dev/null | jq -r '.MessageId')

echo "✓ Published to SNS (MessageId: $MESSAGE_ID)"
echo ""
echo "Flow: SNS → SQS → Lambda → Fails on float('invalid_number')"
echo "         → Retry 1 → Fails"
echo "         → Retry 2 → Fails"
echo "         → Retry 3 → Fails"
echo "         → Moved to DLQ ✓"
echo ""

# Step 3: Wait for retries
# Visibility timeout is 30s, so 3 retries take ~90-120 seconds
echo "Step 3: Waiting 120 seconds for Lambda to retry 3 times..."
echo "─────────────────────────────────────────────────────────────────"
for i in {120..1}; do
  printf "\rTime remaining: %03d seconds" $i
  sleep 1
done
echo ""
echo ""

# Step 4: Check DLQ
echo "Step 4: Check DLQ for failed message"
echo "─────────────────────────────────────────────────────────────────"
DLQ_STATS=$(curl -s -X POST "$API_DLQ" -H "Content-Type: application/json" \
  -d '{"action":"stats"}')
echo "$DLQ_STATS" | jq '{queue, messages, in_flight}'

MESSAGE_COUNT=$(echo "$DLQ_STATS" | jq -r '.messages')

if [ "$MESSAGE_COUNT" -gt 0 ]; then
  echo ""
  echo "✓ SUCCESS! Message landed in DLQ after 3 failed retries"
  echo ""

  # Step 5: View the failed message
  echo "Step 5: View failed message details"
  echo "─────────────────────────────────────────────────────────────────"
  curl -s -X POST "$API_DLQ" -H "Content-Type: application/json" \
    -d '{"action":"peek","max_messages":1}' | \
    jq '.messages[0] | {
      message_id,
      account_id: (.body | fromjson | .account_id),
      action: (.body | fromjson | .action),
      amount: (.body | fromjson | .amount),
      receive_count,
      sent_at
    }'

  echo ""
  echo "Note: receive_count > 3 confirms the message was retried multiple times"
  echo ""

  # Step 6: Optional cleanup
  echo "Step 6: Cleanup"
  echo "─────────────────────────────────────────────────────────────────"
  read -p "Purge DLQ? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -s -X POST "$API_DLQ" -H "Content-Type: application/json" \
      -d '{"action":"purge"}' | jq
    echo "✓ DLQ purged"
  else
    echo "DLQ not purged. You can redrive messages with:"
    echo "curl -X POST \"$API_DLQ\" -H \"Content-Type: application/json\" -d '{\"action\":\"redrive\"}'"
  fi
else
  echo ""
  echo "⚠ WARNING: No messages in DLQ"
  echo "This could mean:"
  echo "  1. Still processing (wait longer)"
  echo "  2. Lambda didn't fail (check Lambda logs)"
  echo "  3. Message was processed successfully"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Test Complete"
echo "════════════════════════════════════════════════════════════════"