import boto3, json, os
from datetime import datetime

ENDPOINT   = os.environ.get("LOCALSTACK_ENDPOINT", "http://localstack:4566")
REGION     = os.environ.get("AWS_DEFAULT_REGION",  "ap-southeast-1")
DLQ_URL    = os.environ.get("DLQ_URL",             "")
QUEUE_URL  = os.environ.get("QUEUE_URL",           "")

def _headers():
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
    }

def handler(event, context):
    """Manage the Dead-Letter Queue: peek, stats, purge, redrive."""
    try:
        sqs    = boto3.client("sqs", endpoint_url=ENDPOINT, region_name=REGION)
        body   = json.loads(event.get("body") or "{}")
        action = body.get("action")

        if action == "stats":
            attrs = sqs.get_queue_attributes(
                QueueUrl=DLQ_URL,
                AttributeNames=[
                    "ApproximateNumberOfMessages",
                    "ApproximateNumberOfMessagesNotVisible",
                    "ApproximateNumberOfMessagesDelayed",
                    "CreatedTimestamp",
                    "LastModifiedTimestamp",
                ],
            )["Attributes"]
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({
                    "queue":       "bank-transaction-dlq",
                    "messages":    int(attrs.get("ApproximateNumberOfMessages", 0)),
                    "in_flight":   int(attrs.get("ApproximateNumberOfMessagesNotVisible", 0)),
                    "delayed":     int(attrs.get("ApproximateNumberOfMessagesDelayed", 0)),
                    "created":     attrs.get("CreatedTimestamp", ""),
                    "modified":    attrs.get("LastModifiedTimestamp", ""),
                }),
            }

        elif action == "peek":
            max_msgs = min(int(body.get("max_messages", 5)), 10)
            resp = sqs.receive_message(
                QueueUrl=DLQ_URL,
                MaxNumberOfMessages=max_msgs,
                VisibilityTimeout=0,       # peek — don't hide from other consumers
                WaitTimeSeconds=0,
                AttributeNames=["All"],
                MessageAttributeNames=["All"],
            )
            messages = []
            for m in resp.get("Messages", []):
                messages.append({
                    "message_id":     m["MessageId"],
                    "receipt_handle": m["ReceiptHandle"],
                    "body":           m["Body"],
                    "attributes":     m.get("Attributes", {}),
                    "sent_at":        m.get("Attributes", {}).get("SentTimestamp", ""),
                    "receive_count":  m.get("Attributes", {}).get("ApproximateReceiveCount", "0"),
                })
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"messages": messages, "count": len(messages)}),
            }

        elif action == "delete":
            receipt = body.get("receipt_handle")
            if not receipt:
                return {"statusCode": 400, "headers": _headers(), "body": json.dumps({"error": "receipt_handle is required"})}
            sqs.delete_message(QueueUrl=DLQ_URL, ReceiptHandle=receipt)
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": "Message deleted from DLQ"})}

        elif action == "purge":
            sqs.purge_queue(QueueUrl=DLQ_URL)
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"message": "DLQ purged — all messages removed (may take up to 60s)"}),
            }

        elif action == "redrive":
            """Move messages back from DLQ to the main transaction queue for reprocessing."""
            max_msgs = min(int(body.get("max_messages", 5)), 10)
            resp = sqs.receive_message(
                QueueUrl=DLQ_URL,
MaxNumberOfMessages=max_msgs,
                VisibilityTimeout=30,
                WaitTimeSeconds=0,
            )
            moved = 0
            for m in resp.get("Messages", []):
                sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=m["Body"])
                sqs.delete_message(QueueUrl=DLQ_URL, ReceiptHandle=m["ReceiptHandle"])
                moved += 1
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"message": f"Redrove {moved} message(s) back to transaction queue"}),
            }

        elif action == "send_test":
            """Send a synthetic poison-pill message directly to the DLQ (for testing)."""
            test_msg = {
                "test":       True,
                "account_id": body.get("account_id", "TEST_USER"),
                "action":     body.get("test_action", "deposit"),
                "amount":     body.get("amount", 0),
                "error":      "Synthetically injected test message",
                "ts":         datetime.utcnow().isoformat(),
            }
            resp = sqs.send_message(QueueUrl=DLQ_URL, MessageBody=json.dumps(test_msg))
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"message": "Test message sent to DLQ", "message_id": resp["MessageId"]}),
            }

        else:
            return {
                "statusCode": 400,
                "headers": _headers(),
                "body": json.dumps({"error": "Invalid action. Use: stats | peek | delete | purge | redrive | send_test"}),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }