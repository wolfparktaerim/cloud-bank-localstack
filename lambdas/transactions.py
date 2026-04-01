import boto3, json, os, uuid
from pymongo import MongoClient
from datetime import datetime

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

def handler(event, context):
    try:
        s3     = boto3.client("s3",  endpoint_url=ENDPOINT, region_name=REGION)
        sns    = boto3.client("sns", endpoint_url=ENDPOINT, region_name=REGION)
        dynamo = boto3.resource("dynamodb", endpoint_url=ENDPOINT, region_name=REGION)
        table  = dynamo.Table(TRANSACTION_TABLE)
        db     = _mongo()

        body   = json.loads(event.get("body") or "{}")
        action = body.get("action")
        acc_id = body.get("account_id", "GUEST")
        amount = float(body.get("amount", 0))

        if action == "deposit":
            db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": amount}}, upsert=True)
            msg = f"Deposited ${amount:.2f} into {acc_id}"

        elif action == "withdraw":
            acc = db.accounts.find_one({"id": acc_id})
            if not acc or acc.get("balance", 0) < amount:
                return {"statusCode": 400, "headers": _headers(), "body": json.dumps({"error": "Insufficient funds"})}
            db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": -amount}})
            msg = f"Withdrew ${amount:.2f} from {acc_id}"

        elif action == "transfer":
            to_acc = body.get("to_account_id", "")
            acc    = db.accounts.find_one({"id": acc_id})
            if not acc or acc.get("balance", 0) < amount:
                return {"statusCode": 400, "headers": _headers(), "body": json.dumps({"error": "Insufficient funds"})}
            db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": -amount}})
            db.accounts.update_one({"id": to_acc}, {"$inc": {"balance":  amount}}, upsert=True)
            msg = f"Transferred ${amount:.2f} from {acc_id} to {to_acc}"

        elif action == "balance":
            acc     = db.accounts.find_one({"id": acc_id})
            balance = acc.get("balance", 0) if acc else 0
            msg     = f"Balance for {acc_id}: ${balance:.2f}"
            aid     = _audit(s3, table, acc_id, action, 0)
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": msg, "audit_id": aid})}

        else:
            return {"statusCode": 400, "headers": _headers(), "body": json.dumps({"error": "Invalid action. Use: deposit | withdraw | transfer | balance"})}

        audit_id = _audit(s3, table, acc_id, action, amount)

        if NOTIFICATION_TOPIC:
            try:
                sns.publish(
                    TopicArn=NOTIFICATION_TOPIC,
                    Message=json.dumps({"account_id": acc_id, "action": action, "amount": amount}),
                    Subject=f"Bank Transaction: {action.upper()}",
                )
            except Exception:
                pass  # Non-critical — don't fail the transaction

        return {
            "statusCode": 200,
            "headers": _headers(),
            "body": json.dumps({"message": msg, "audit_id": audit_id, "audit_status": "Recorded"}),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
