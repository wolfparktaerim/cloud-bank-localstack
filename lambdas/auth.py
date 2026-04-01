import boto3, json, os

ENDPOINT  = os.environ.get("LOCALSTACK_ENDPOINT", "http://localstack:4566")
REGION    = os.environ.get("AWS_DEFAULT_REGION", "ap-southeast-1")
CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID", "")
POOL_ID   = os.environ.get("USER_POOL_ID", "")

def _cognito():
    return boto3.client("cognito-idp", endpoint_url=ENDPOINT, region_name=REGION)

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
        cog    = _cognito()

        if action == "register":
            username = body["username"]
            password = body["password"]
            email    = body.get("email", "")

            cog.admin_create_user(
                UserPoolId=POOL_ID,
                Username=username,
                TemporaryPassword=password,
                UserAttributes=[
                    {"Name": "email",          "Value": email},
                    {"Name": "email_verified", "Value": "true"},
                ],
                MessageAction="SUPPRESS",
            )
            cog.admin_set_user_password(
                UserPoolId=POOL_ID,
                Username=username,
                Password=password,
                Permanent=True,
            )
            return {
                "statusCode": 201,
                "headers": _headers(),
                "body": json.dumps({"message": f"User '{username}' registered successfully"}),
            }

        elif action == "login":
            resp   = cog.admin_initiate_auth(
                UserPoolId=POOL_ID,
                ClientId=CLIENT_ID,
                AuthFlow="ADMIN_USER_PASSWORD_AUTH",
                AuthParameters={
                    "USERNAME": body["username"],
                    "PASSWORD": body["password"],
                },
            )
            tokens = resp.get("AuthenticationResult", {})
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({
                    "message":       "Login successful",
                    "access_token":  tokens.get("AccessToken"),
                    "id_token":      tokens.get("IdToken"),
                    "refresh_token": tokens.get("RefreshToken"),
                }),
            }

        elif action == "get_user":
            user  = cog.admin_get_user(UserPoolId=POOL_ID, Username=body["username"])
            attrs = {a["Name"]: a["Value"] for a in user.get("UserAttributes", [])}
            return {
                "statusCode": 200,
                "headers": _headers(),
                "body": json.dumps({"username": body["username"], "attributes": attrs}),
            }

        else:
            return {
                "statusCode": 400,
                "headers": _headers(),
                "body": json.dumps({"error": "Invalid action. Use: register | login | get_user"}),
            }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
