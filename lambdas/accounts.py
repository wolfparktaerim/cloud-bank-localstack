import boto3, json, os, uuid
from datetime import datetime

ENDPOINT       = os.environ.get("LOCALSTACK_ENDPOINT", "http://localstack:4566")
REGION         = os.environ.get("AWS_DEFAULT_REGION",  "ap-southeast-1")
ACCOUNTS_TABLE = os.environ.get("ACCOUNTS_TABLE",      "bank-accounts")

def _table():
    dynamo = boto3.resource("dynamodb", endpoint_url=ENDPOINT, region_name=REGION)
    return dynamo.Table(ACCOUNTS_TABLE)

def _headers():
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
    }

def handler(event, context):
    try:
        body   = json.loads(event.get("body") or "{}")
        action = body.get("action")
        table  = _table()

        if action == "create_account":
            acc_id = body.get("account_id") or f"ACC-{str(uuid.uuid4())[:8].upper()}"
            item   = {
                "account_id":   acc_id,
                "owner":        body.get("owner", "Unknown"),
                "account_type": body.get("account_type", "SAVINGS"),
                "status":       "ACTIVE",
                "created_at":   datetime.utcnow().isoformat(),
            }
            table.put_item(Item=item)
            return {
                "statusCode": 201,
                "headers": _headers(),
                "body": json.dumps({"message": "Account created", "account_id": acc_id}),
            }

        elif action == "get_account":
            resp = table.get_item(Key={"account_id": body["account_id"]})
            item = resp.get("Item")
            if not item:
                return {"statusCode": 404, "headers": _headers(), "body": json.dumps({"error": "Account not found"})}
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps(item, default=str)}

        elif action == "list_accounts":
            resp  = table.scan()
            items = resp.get("Items", [])
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"accounts": items, "count": len(items)}, default=str),
            }

        elif action == "close_account":
            table.update_item(
                Key={"account_id": body["account_id"]},
                UpdateExpression="SET #s = :s",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":s": "CLOSED"},
            )
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"message": f"Account {body['account_id']} closed"}),
            }

        else:
            return {
                "statusCode": 400,
                "headers": _headers(),
                "body": json.dumps({"error": "Invalid action. Use: create_account | get_account | list_accounts | close_account"}),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
