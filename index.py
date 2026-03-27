import boto3, json, os, uuid
from pymongo import MongoClient
from datetime import datetime

def handler(event, context):
    try:
        s3 = boto3.client('s3', endpoint_url="http://localstack:4566")
        sm = boto3.client('secretsmanager', endpoint_url="http://localstack:4566")
        
        res = sm.get_secret_value(SecretId='db/mongo')
        creds = json.loads(res['SecretString'])
        client = MongoClient(f"mongodb://{creds['username']}:{creds['password']}@{creds['host']}:27017")
        db = client.bank_db

        body = json.loads(event.get("body", "{}"))
        action = body.get("action")
        acc_id = body.get("account_id", "GUEST")
        amount = body.get("amount", 0)

        if action == "deposit":
            db.accounts.update_one({"id": acc_id}, {"$inc": {"balance": amount}}, upsert=True)
            msg = f"Deposited ${amount} into {acc_id}"
        elif action == "balance":
            acc = db.accounts.find_one({"id": acc_id})
            balance = acc.get("balance", 0) if acc else 0
            msg = f"Current balance for {acc_id}: ${balance}"
        else:
            return {"statusCode": 400, "body": json.dumps({"error": "Invalid action"})}

        # Audit Log
        audit_id = str(uuid.uuid4())
        audit_data = {"id": audit_id, "acc": acc_id, "action": action, "amt": amount, "ts": datetime.now().isoformat()}
        s3.put_object(Bucket=os.environ['AUDIT_BUCKET'], Key=f"logs/{acc_id}/{audit_id}.json", Body=json.dumps(audit_data))

        return {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*", # Allows browser 'null' origins
                "Access-Control-Allow-Methods": "POST,OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({"message": msg, "audit_status": "Recorded"})
        }
    except Exception as e:
        return {
            "statusCode": 500, 
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)})
        }