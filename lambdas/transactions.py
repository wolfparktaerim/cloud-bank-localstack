import boto3, json, os, uuid
from pymongo import MongoClient
from datetime import datetime
from aws_xray_sdk.core import xray_recorder, patch_all

patch_all()
xray_recorder.configure(service='lambda-transactions')

ENDPOINT           = os.environ.get("LOCALSTACK_ENDPOINT",     "http://localstack:4566")
REGION             = os.environ.get("AWS_DEFAULT_REGION",      "ap-southeast-1")
AUDIT_BUCKET       = os.environ.get("AUDIT_BUCKET",            "bank-audit-logs")
TRANSACTION_TABLE  = os.environ.get("TRANSACTION_TABLE",       "bank-audit-events")
NOTIFICATION_TOPIC = os.environ.get("NOTIFICATION_TOPIC_ARN",  "")

def _mongo():
    sm    = boto3.client("secretsmanager", endpoint_url=ENDPOINT, region_name=REGION)
    creds = json.loads(sm.get_secret_value(SecretId="db/mongo")["SecretString"])
    return MongoClient(f"mongodb://{creds['username']}:{creds['password']}@{creds['host']}:27017").bank_db

def _headers():
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
    }

def _audit(s3, dynamo_table, acc_id, action, amount, status="SUCCESS"):
    audit_id = str(uuid.uuid4())
    ts       = datetime.utcnow().isoformat()
    record   = {"id": audit_id, "acc": acc_id, "action": action, "amt": amount, "status": status, "ts": ts}

    s3.put_object(
        Bucket=AUDIT_BUCKET,
        Key=f"logs/{acc_id}/{audit_id}.json",
        Body=json.dumps(record),
    )
    dynamo_table.put_item(Item={
        "event_id":   audit_id,
        "timestamp":  ts,
        "account_id": acc_id,
        "action":     action,
        "amount":     str(amount),
        "status":     status,
    })
    return audit_id

def _process_transaction(body, db, s3, table, sns, skip_sns=False):
    """Core transaction logic shared by both API Gateway and SQS invocations.
    Returns (statusCode, response_body_dict).
    Set skip_sns=True when called from SQS to avoid infinite SNS→SQS→Lambda loops.
    """
    action = body.get("action")
    acc_id = body.get("account_id", "GUEST")
    amount = float(body.get("amount", 0))

    # Messages emitted by this Lambda to SNS are for notifications only.
    # If they re-enter through SNS->SQS, skip to avoid applying transactions twice.
    if body.get("notification_only") is True:
        return 200, {"message": "Notification-only event ignored"}

    if action == "deposit":
        db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": amount}}, upsert=True)
        bal = db.accounts.find_one({"id": acc_id}).get("balance", 0)
        msg = f"Deposited ${amount:.2f} into {acc_id}"
        extra = {"balance": round(float(bal), 2)}

    elif action == "withdraw":
        acc = db.accounts.find_one({"id": acc_id})
        if not acc or acc.get("balance", 0) < amount:
            return 400, {"error": "Insufficient funds"}
        db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": -amount}})
        bal = db.accounts.find_one({"id": acc_id}).get("balance", 0)
        msg = f"Withdrew ${amount:.2f} from {acc_id}"
        extra = {"balance": round(float(bal), 2)}

    elif action == "transfer":
        to_acc = body.get("to_account_id", "")
        if not to_acc:
            return 400, {"error": "Missing to_account_id for transfer"}
        if to_acc == acc_id:
            return 400, {"error": "Cannot transfer to the same account"}
        acc    = db.accounts.find_one({"id": acc_id})
        if not acc or acc.get("balance", 0) < amount:
            return 400, {"error": "Insufficient funds"}
        db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": -amount}})
        db.accounts.update_one({"id": to_acc}, {"$inc": {"balance":  amount}}, upsert=True)
        from_bal = db.accounts.find_one({"id": acc_id}).get("balance", 0)
        to_bal = db.accounts.find_one({"id": to_acc}).get("balance", 0)
        msg = f"Transferred ${amount:.2f} from {acc_id} to {to_acc}"
        extra = {
            "from_balance": round(float(from_bal), 2),
            "to_balance": round(float(to_bal), 2),
            "to_account_id": to_acc,
        }

    elif action == "balance":
        acc     = db.accounts.find_one({"id": acc_id})
        balance = acc.get("balance", 0) if acc else 0
        msg     = f"Balance for {acc_id}: ${balance:.2f}"
        aid     = _audit(s3, table, acc_id, action, 0)
        return 200, {"message": msg, "audit_id": aid}

    else:
        return 400, {"error": "Invalid action. Use: deposit | withdraw | transfer | balance"}

    audit_id = _audit(s3, table, acc_id, action, amount)

    if NOTIFICATION_TOPIC and not skip_sns:
        try:
            sns.publish(
                TopicArn=NOTIFICATION_TOPIC,
                Message=json.dumps({
                    "account_id": acc_id,
                    "action": action,
                    "amount": amount,
                    "notification_only": True,
                }),
                Subject=f"Bank Transaction: {action.upper()}",
            )
        except Exception:
            pass  # Non-critical — don't fail the transaction

    return 200, {"message": msg, "audit_id": audit_id, "audit_status": "Recorded", **extra}


def _parse_sqs_body(record_body):
    """Parse an SQS record body. If the message was
forwarded from SNS,
    unwrap the SNS envelope to get the inner Message payload."""
    parsed = json.loads(record_body)
    # SNS → SQS wraps the real payload inside a "Message" key
    if "Message" in parsed and "TopicArn" in parsed:
        return json.loads(parsed["Message"])
    return parsed


def _parse_api_body(event):
    raw = event.get("body") if isinstance(event, dict) else None
    if raw is None:
        return {}
    if isinstance(raw, dict):
        return raw
    return json.loads(raw)


@xray_recorder.capture()
def handler(event, context):
    is_sqs = isinstance(event, dict) and "Records" in event
    try:
        s3     = boto3.client("s3",  endpoint_url=ENDPOINT, region_name=REGION)
        sns    = boto3.client("sns", endpoint_url=ENDPOINT, region_name=REGION)
        dynamo = boto3.resource("dynamodb", endpoint_url=ENDPOINT, region_name=REGION)
        table  = dynamo.Table(TRANSACTION_TABLE)
        db     = _mongo()

        # ── SQS event source (batch of records from bank-transaction-queue) ──
        if is_sqs:
            failures = []
            for record in event["Records"]:
                try:
                    body = _parse_sqs_body(record["body"])
                    code, _ = _process_transaction(body, db, s3, table, sns, skip_sns=True)
                    if code >= 400:
                        # Report non-2xx business errors as failures for retry/DLQ testing.
                        failures.append({"itemIdentifier": record["messageId"]})
                except Exception:
                    failures.append({"itemIdentifier": record["messageId"]})
            # Return partial batch failure response
            return {"batchItemFailures": failures}

        # ── API Gateway / direct invocation ──────────────────────────────────
        body = _parse_api_body(event)
        code, result = _process_transaction(body, db, s3, table, sns)
        return {
            "statusCode": code,
            "headers": _headers(),
            "body": json.dumps(result),
        }

    except Exception as e:
        if is_sqs:
            # For SQS invocations, raise so Lambda marks the batch failed.
            raise
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }