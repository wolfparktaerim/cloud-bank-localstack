import boto3, json, os, uuid
from datetime import datetime

# Initialize clients (LocalStack endpoints)
endpoint = "http://localstack:4566"
dynamodb = boto3.client('dynamodb', endpoint_url=endpoint)
sns = boto3.client('sns', endpoint_url=endpoint)
sqs = boto3.client('sqs', endpoint_url=endpoint)
cw_logs = boto3.client('logs', endpoint_url=endpoint)

def handler(event, context):
    print("X-Ray Trace ID:", context.aws_request_id) # Mock tracing
    
    try:
        body = json.loads(event.get("body", "{}"))
        action = body.get("action")
        acc_id = body.get("account_id", "GUEST")
        amount = body.get("amount", 0)
        
        tx_id = str(uuid.uuid4())
        
        # 1. Mock RDS Interaction (Core Ledger)
        msg = f"Processed {action} of ${amount} for {acc_id} via RDS Ledger."
        
        # 2. Write to DynamoDB (Audit/History)
        dynamodb.put_item(
            TableName='BankTransactions',
            Item={
                'transaction_id': {'S': tx_id},
                'account': {'S': acc_id},
                'amount': {'N': str(amount)},
                'timestamp': {'S': datetime.now().isoformat()}
            }
        )

        # 3. SNS Pub/Sub for Large Transactions (Event-Driven)
        if amount > 10000:
            sns.publish(
                TopicArn="arn:aws:sns:us-east-1:000000000000:high-value-transactions",
                Message=json.dumps({"tx_id": tx_id, "acc": acc_id, "amount": amount, "flag": "REVIEW"})
            )

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"message": msg, "transaction_id": tx_id})
        }
        
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}