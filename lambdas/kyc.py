import boto3, json, os, uuid
from datetime import datetime
from boto3.dynamodb.conditions import Attr

ENDPOINT   = os.environ.get("LOCALSTACK_ENDPOINT", "http://localstack:4566")
REGION     = os.environ.get("AWS_DEFAULT_REGION",  "ap-southeast-1")
KYC_BUCKET = os.environ.get("KYC_BUCKET",          "bank-kyc-documents")
KYC_TABLE  = os.environ.get("KYC_TABLE",           "bank-kyc-status")

def _table():
    dynamo = boto3.resource("dynamodb", endpoint_url=ENDPOINT, region_name=REGION)
    return dynamo.Table(KYC_TABLE)

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
        s3     = boto3.client("s3", endpoint_url=ENDPOINT, region_name=REGION)
        table  = _table()

        if action == "submit_kyc":
            kyc_id  = str(uuid.uuid4())
            user_id = body["user_id"]
            ts      = datetime.utcnow().isoformat()

            table.put_item(Item={
                "kyc_id":       kyc_id,
                "user_id":      user_id,
                "full_name":    body.get("full_name", ""),
                "id_type":      body.get("id_type", "PASSPORT"),
                "id_number":    body.get("id_number", ""),
                "status":       "PENDING",
                "submitted_at": ts,
            })
            s3.put_object(
                Bucket=KYC_BUCKET,
                Key=f"submissions/{user_id}/{kyc_id}.json",
                Body=json.dumps({"kyc_id": kyc_id, "user_id": user_id, "ts": ts}),
            )
            return {
                "statusCode": 201,
                "headers": _headers(),
                "body": json.dumps({"message": "KYC submitted", "kyc_id": kyc_id}),
            }

        elif action == "check_status":
            resp  = table.scan(FilterExpression=Attr("user_id").eq(body["user_id"]))
            items = sorted(resp.get("Items", []), key=lambda x: x.get("submitted_at", ""), reverse=True)
            if not items:
                return {"statusCode": 404, "headers": _headers(), "body": json.dumps({"error": "No KYC submission found"})}
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps(items[0], default=str)}

        elif action == "approve_kyc":
            table.update_item(
                Key={"kyc_id": body["kyc_id"]},
                UpdateExpression="SET #s = :s, reviewed_at = :ts",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":s": "APPROVED", ":ts": datetime.utcnow().isoformat()},
            )
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": f"KYC {body['kyc_id']} approved"})}

        elif action == "reject_kyc":
            table.update_item(
                Key={"kyc_id": body["kyc_id"]},
                UpdateExpression="SET #s = :s, rejection_reason = :r, reviewed_at = :ts",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={
                    ":s":  "REJECTED",
                    ":r":  body.get("reason", "Insufficient documentation"),
                    ":ts": datetime.utcnow().isoformat(),
                },
            )
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": f"KYC {body['kyc_id']} rejected"})}

        else:
            return {
                "statusCode": 400,
                "headers": _headers(),
                "body": json.dumps({"error": "Invalid action. Use: submit_kyc | check_status | approve_kyc | reject_kyc"}),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
