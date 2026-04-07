import boto3, json, os

ENDPOINT           = os.environ.get("LOCALSTACK_ENDPOINT",    "http://localstack:4566")
REGION             = os.environ.get("AWS_DEFAULT_REGION",     "ap-southeast-1")
ALERT_TOPIC        = os.environ.get("ALERT_TOPIC_ARN",        "")
TRANSACTION_TOPIC  = os.environ.get("TRANSACTION_TOPIC_ARN",  "")

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
        sns    = boto3.client("sns", endpoint_url=ENDPOINT, region_name=REGION)
        ses    = boto3.client("ses", endpoint_url=ENDPOINT, region_name=REGION)

        if action == "send_alert":
            sns.publish(
                TopicArn=ALERT_TOPIC,
                Message=body.get("message", ""),
                Subject=body.get("subject", "Bank Alert"),
            )
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": "Alert published to SNS"})}

        elif action == "send_email":
            ses.send_email(
                Source="noreply@cloudbank.internal",
                Destination={"ToAddresses": [body["to"]]},
                Message={
                    "Subject": {"Data": body.get("subject", "Bank Notification")},
                    "Body":    {"Text": {"Data": body.get("message", "")}},
                },
            )
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": f"Email sent to {body['to']}"})}

        elif action == "subscribe":
            sns.subscribe(
                TopicArn=body.get("topic", ALERT_TOPIC),
                Protocol="email",
                Endpoint=body["email"],
            )
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"message": f"Subscribed {body['email']} to alerts"})}

        elif action == "list_subscriptions":
            resp = sns.list_subscriptions_by_topic(TopicArn=body.get("topic", ALERT_TOPIC))
            return {"statusCode": 200, "headers": _headers(), "body": json.dumps({"subscriptions": resp.get("Subscriptions", [])})}

        else:
            return {
                "statusCode": 400,
                "headers": _headers(),
                "body": json.dumps({"error": "Invalid action. Use: send_alert | send_email | subscribe | list_subscriptions"}),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
