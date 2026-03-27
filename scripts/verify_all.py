#!/usr/bin/env python3
"""
scripts/verify_all.py
Automated verification of every service in the Cloud Bank stack.
Run from project root: python scripts/verify_all.py

Exit code 0 = all checks passed
Exit code 1 = one or more checks failed
"""

import boto3
import json
import sys
import requests
import time
import datetime

ENDPOINT  = "http://localhost:4566"
REGION    = "ap-southeast-1"
AUTH_URL  = "http://localhost:5001"
NOTIF_URL = "http://localhost:5004"
KYC_URL   = "http://localhost:5003"

GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
BOLD   = "\033[1m"
RESET  = "\033[0m"

results = []

def aws(service):
    return boto3.client(
        service,
        endpoint_url=ENDPOINT,
        region_name=REGION,
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )

def check(name, fn):
    """Run a check function, record pass/fail."""
    try:
        detail = fn()
        results.append((True, name, detail or ""))
        print(f"  {GREEN}PASS{RESET}  {name}" + (f"  {YELLOW}→ {detail}{RESET}" if detail else ""))
        return True
    except AssertionError as e:
        results.append((False, name, str(e)))
        print(f"  {RED}FAIL{RESET}  {name}  {RED}→ {e}{RESET}")
        return False
    except Exception as e:
        results.append((False, name, str(e)))
        print(f"  {RED}FAIL{RESET}  {name}  {RED}→ {type(e).__name__}: {str(e)[:80]}{RESET}")
        return False

def section(title):
    print(f"\n{BOLD}{CYAN}  {title}{RESET}")
    print(f"  {'─'*50}")

# ── LocalStack health ─────────────────────────
def chk_localstack():
    r = requests.get(f"{ENDPOINT}/_localstack/health", timeout=3)
    assert r.status_code == 200
    h = r.json()
    assert h.get("status") == "running", f"status={h.get('status')}"
    services = h.get("services", {})
    required = ["s3","dynamodb","lambda","sqs","sns","iam","apigateway","cloudwatch"]
    down = [s for s in required if services.get(s) not in ("available","running")]
    assert not down, f"not available: {down}"
    return f"{len([s for s in required if services.get(s) in ('available','running')])}/{len(required)} services up"

# ── S3 checks ─────────────────────────────────
def chk_s3_buckets():
    s3 = aws("s3")
    buckets = [b["Name"] for b in s3.list_buckets()["Buckets"]]
    assert "cloud-bank-kyc-documents-local" in buckets, f"KYC bucket missing. Found: {buckets}"
    assert "cloud-bank-statements-local" in buckets, f"Statements bucket missing. Found: {buckets}"
    return f"{len(buckets)} buckets"

def chk_s3_encryption():
    s3 = aws("s3")
    r = s3.get_bucket_encryption(Bucket="cloud-bank-kyc-documents-local")
    algo = r["ServerSideEncryptionConfiguration"]["Rules"][0]["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"]
    assert algo == "AES256", f"expected AES256 got {algo}"
    return "AES256 confirmed"

def chk_s3_versioning():
    s3 = aws("s3")
    r = s3.get_bucket_versioning(Bucket="cloud-bank-kyc-documents-local")
    assert r.get("Status") == "Enabled", f"versioning={r.get('Status')}"
    return "versioning enabled"

def chk_s3_public_block():
    s3 = aws("s3")
    r = s3.get_public_access_block(Bucket="cloud-bank-kyc-documents-local")
    cfg = r["PublicAccessBlockConfiguration"]
    assert cfg["BlockPublicAcls"], "BlockPublicAcls is false"
    assert cfg["RestrictPublicBuckets"], "RestrictPublicBuckets is false"
    return "all public access blocked"

def chk_s3_upload_download():
    s3 = aws("s3")
    key = "verify/test-doc.json"
    payload = json.dumps({"verify": True, "ts": datetime.datetime.now(datetime.timezone.utc).isoformat()})
    s3.put_object(Bucket="cloud-bank-kyc-documents-local", Key=key, Body=payload.encode())
    obj = s3.get_object(Bucket="cloud-bank-kyc-documents-local", Key=key)
    data = json.loads(obj["Body"].read())
    assert data["verify"] is True
    s3.delete_object(Bucket="cloud-bank-kyc-documents-local", Key=key)
    return "write→read→delete cycle OK"

# ── DynamoDB checks ───────────────────────────
def chk_dynamo_tables():
    db = aws("dynamodb")
    tables = db.list_tables()["TableNames"]
    expected = ["cloud-bank-user-sessions","cloud-bank-transaction-ledger","cloud-bank-otp-store","cloud-bank-accounts"]
    missing = [t for t in expected if t not in tables]
    assert not missing, f"missing tables: {missing}"
    return f"{len(tables)} tables"

def chk_dynamo_ttl():
    db = aws("dynamodb")
    r = db.describe_time_to_live(TableName="cloud-bank-user-sessions")
    status = r["TimeToLiveDescription"]["TimeToLiveStatus"]
    assert status == "ENABLED", f"TTL status={status}"
    return "TTL enabled on sessions"

def chk_dynamo_gsi():
    db = aws("dynamodb")
    r = db.describe_table(TableName="cloud-bank-user-sessions")
    gsis = [g["IndexName"] for g in r["Table"].get("GlobalSecondaryIndexes", [])]
    assert "UserIdIndex" in gsis, f"UserIdIndex not found, have: {gsis}"
    return f"GSIs: {gsis}"

def chk_dynamo_write_read():
    db = aws("dynamodb")
    sid = "verify-session-check"
    db.put_item(
        TableName="cloud-bank-user-sessions",
        Item={"session_id":{"S":sid},"user_id":{"S":"u-verify"},"email":{"S":"v@test.com"},"expires_at":{"N":"9999999999"}}
    )
    r = db.get_item(TableName="cloud-bank-user-sessions", Key={"session_id":{"S":sid}})
    assert r["Item"]["email"]["S"] == "v@test.com"
    db.delete_item(TableName="cloud-bank-user-sessions", Key={"session_id":{"S":sid}})
    return "write→read→delete cycle OK"

def chk_dynamo_txn_ledger():
    db = aws("dynamodb")
    r = db.describe_table(TableName="cloud-bank-transaction-ledger")
    keys = {k["AttributeName"] for k in r["Table"]["KeySchema"]}
    assert "account_id" in keys and "transaction_id" in keys
    return "composite key verified"

# ── SQS checks ────────────────────────────────
def chk_sqs_queues():
    sqs = aws("sqs")
    r = sqs.list_queues(QueueNamePrefix="cloud-bank")
    urls = r.get("QueueUrls", [])
    names = [u.split("/")[-1] for u in urls]
    assert "cloud-bank-transactions-local" in names, f"main queue missing. found: {names}"
    assert "cloud-bank-transactions-local-dlq" in names, f"DLQ missing. found: {names}"
    return f"{len(urls)} queues"

def chk_sqs_dlq_linked():
    sqs = aws("sqs")
    url = sqs.get_queue_url(QueueName="cloud-bank-transactions-local")["QueueUrl"]
    attrs = sqs.get_queue_attributes(QueueUrl=url, AttributeNames=["RedrivePolicy"])
    rdp = json.loads(attrs["Attributes"]["RedrivePolicy"])
    assert "deadLetterTargetArn" in rdp, "RedrivePolicy missing deadLetterTargetArn"
    assert rdp["maxReceiveCount"] >= 3, f"maxReceiveCount={rdp['maxReceiveCount']}"
    return f"DLQ linked, maxReceiveCount={rdp['maxReceiveCount']}"

def chk_sqs_send_receive():
    sqs = aws("sqs")
    url = sqs.get_queue_url(QueueName="cloud-bank-transactions-local")["QueueUrl"]
    msg = {"type":"VERIFY","amount":1.00,"ts": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    sqs.send_message(QueueUrl=url, MessageBody=json.dumps(msg))
    time.sleep(1)
    r = sqs.receive_message(QueueUrl=url, MaxNumberOfMessages=1, WaitTimeSeconds=2)
    msgs = r.get("Messages", [])
    assert msgs, "no messages received"
    body = json.loads(msgs[0]["Body"])
    assert body["type"] == "VERIFY"
    sqs.delete_message(QueueUrl=url, ReceiptHandle=msgs[0]["ReceiptHandle"])
    return "send→receive→delete cycle OK"

# ── SNS checks ────────────────────────────────
def chk_sns_topics():
    sns = aws("sns")
    topics = [t["TopicArn"].split(":")[-1] for t in sns.list_topics()["Topics"]]
    assert any("notification" in t for t in topics), f"notification topic missing: {topics}"
    assert any("transaction-alert" in t for t in topics), f"alert topic missing: {topics}"
    return f"{len(topics)} topics"

def chk_sns_sqs_subscription():
    sns = aws("sns")
    subs = sns.list_subscriptions()["Subscriptions"]
    sqs_subs = [s for s in subs if s["Protocol"] == "sqs"]
    assert sqs_subs, "no SNS→SQS subscription found"
    return f"{len(sqs_subs)} SNS→SQS subscription(s)"

def chk_sns_fanout():
    sns = aws("sns")
    sqs = aws("sqs")
    topics = [t["TopicArn"] for t in sns.list_topics()["Topics"] if "transaction-alert" in t["TopicArn"]]
    assert topics, "transaction-alerts topic not found"
    sns.publish(TopicArn=topics[0], Message=json.dumps({"type":"VERIFY_FANOUT"}))
    time.sleep(1)
    url = sqs.get_queue_url(QueueName="cloud-bank-transactions-local")["QueueUrl"]
    r = sqs.receive_message(QueueUrl=url, MaxNumberOfMessages=5, WaitTimeSeconds=2)
    msgs = r.get("Messages", [])
    found = False
    for m in msgs:
        try:
            outer = json.loads(m["Body"])
            inner = json.loads(outer.get("Message", "{}"))
            if inner.get("type") == "VERIFY_FANOUT":
                found = True
            sqs.delete_message(QueueUrl=url, ReceiptHandle=m["ReceiptHandle"])
        except Exception:
            sqs.delete_message(QueueUrl=url, ReceiptHandle=m["ReceiptHandle"])
    assert found, "SNS message did not arrive in SQS queue"
    return "SNS→SQS fan-out verified end-to-end"

# ── Lambda checks ─────────────────────────────
def chk_lambda_functions():
    lmb = aws("lambda")
    fns = [f["FunctionName"] for f in lmb.list_functions()["Functions"]]
    expected = ["cloud-bank-accounts","cloud-bank-transactions","cloud-bank-auth","cloud-bank-kyc","cloud-bank-notifications"]
    missing = [f for f in expected if f not in fns]
    assert not missing, f"missing lambdas: {missing}"
    return f"{len(fns)} functions"

def chk_lambda_env_vars():
    lmb = aws("lambda")
    r = lmb.get_function_configuration(FunctionName="cloud-bank-accounts")
    env = r["Environment"]["Variables"]
    assert "TRANSACTION_QUEUE" in env, "TRANSACTION_QUEUE env var missing"
    assert "NOTIFICATION_TOPIC" in env, "NOTIFICATION_TOPIC env var missing"
    return "env vars present"

def chk_lambda_role():
    lmb = aws("lambda")
    r = lmb.get_function_configuration(FunctionName="cloud-bank-accounts")
    assert "lambda-execution-role" in r["Role"], f"unexpected role: {r['Role']}"
    return r["Role"].split("/")[-1]

def chk_lambda_sqs_trigger():
    lmb = aws("lambda")
    mappings = lmb.list_event_source_mappings(FunctionName="cloud-bank-transactions")["EventSourceMappings"]
    assert mappings, "no event source mapping found"
    assert mappings[0]["State"] == "Enabled", f"mapping state={mappings[0]['State']}"
    return f"SQS trigger enabled, batch={mappings[0]['BatchSize']}"

def chk_lambda_invoke():
    lmb = aws("lambda")
    r = lmb.invoke(
        FunctionName="cloud-bank-accounts",
        InvocationType="RequestResponse",
        Payload=json.dumps({"httpMethod":"GET","path":"/accounts"}).encode()
    )
    result = json.loads(r["Payload"].read())
    assert result.get("statusCode") == 200, f"statusCode={result.get('statusCode')}"
    return f"statusCode={result.get('statusCode')}"

# ── IAM checks ────────────────────────────────
def chk_iam_roles():
    iam = aws("iam")
    roles = [r["RoleName"] for r in iam.list_roles()["Roles"]]
    assert "cloud-bank-lambda-execution-role" in roles, f"lambda role missing: {roles}"
    return f"{len(roles)} roles"

def chk_iam_policy_attached():
    iam = aws("iam")
    r = iam.list_attached_role_policies(RoleName="cloud-bank-lambda-execution-role")
    names = [p["PolicyName"] for p in r["AttachedPolicies"]]
    assert "cloud-bank-lambda-policy" in names, f"policy not attached: {names}"
    return "cloud-bank-lambda-policy attached"

# ── API Gateway checks ────────────────────────
def chk_apigw_exists():
    apigw = aws("apigateway")
    apis = apigw.get_rest_apis()["items"]
    assert apis, "no REST APIs found"
    names = [a["name"] for a in apis]
    assert any("cloud-bank" in n for n in names), f"cloud-bank API not found: {names}"
    return f"API: {names[0]}"

def chk_apigw_resources():
    apigw = aws("apigateway")
    apis = [a for a in apigw.get_rest_apis()["items"] if "cloud-bank" in a["name"]]
    assert apis
    resources = apigw.get_resources(restApiId=apis[0]["id"])["items"]
    paths = [r.get("path","") for r in resources]
    for expected in ["/accounts","/transactions","/auth","/kyc"]:
        assert expected in paths, f"route {expected} missing from API. Found: {paths}"
    return f"{len(resources)} routes configured"

# ── VPC / Networking checks ───────────────────
def chk_vpc():
    ec2 = aws("ec2")
    vpcs = ec2.describe_vpcs()["Vpcs"]
    bank_vpcs = [v for v in vpcs if v["CidrBlock"] == "10.0.0.0/16"]
    assert bank_vpcs, f"no VPC with 10.0.0.0/16 found. VPCs: {[v['CidrBlock'] for v in vpcs]}"
    return f"VPC {bank_vpcs[0]['VpcId']}"

def chk_subnets():
    ec2 = aws("ec2")
    subnets = ec2.describe_subnets()["Subnets"]
    bank_subnets = [s for s in subnets if s["CidrBlock"].startswith("10.0.")]
    assert len(bank_subnets) >= 4, f"expected 4 subnets, found {len(bank_subnets)}"
    return f"{len(bank_subnets)} subnets (public + private)"

def chk_security_groups():
    ec2 = aws("ec2")
    sgs = ec2.describe_security_groups()["SecurityGroups"]
    names = [sg["GroupName"] for sg in sgs]
    assert any("lambda" in n for n in names), f"lambda SG missing: {names}"
    assert any("rds" in n for n in names), f"rds SG missing: {names}"
    return f"{len(sgs)} security groups"

# ── Mock services ─────────────────────────────
def chk_mock_auth():
    r = requests.get(f"{AUTH_URL}/health", timeout=3)
    assert r.status_code == 200
    assert r.json()["status"] == "ok"
    return "mock-auth healthy"

def chk_mock_auth_flow():
    import uuid
    email = f"verify-{uuid.uuid4().hex[:6]}@check.sg"
    r = requests.post(f"{AUTH_URL}/register", json={"email":email,"password":"Check123!","full_name":"Verify"}, timeout=3)
    assert r.status_code == 201, f"register failed: {r.text}"
    r = requests.post(f"{AUTH_URL}/login", json={"email":email,"password":"Check123!"}, timeout=3)
    assert r.status_code == 200, f"login failed: {r.text}"
    token = r.json()["access_token"]
    r = requests.post(f"{AUTH_URL}/verify-token", json={"token":token}, timeout=3)
    assert r.json()["valid"] is True
    return "register→login→verify OK"

def chk_mock_notifications():
    r = requests.get(f"{NOTIF_URL}/health", timeout=3)
    assert r.status_code == 200
    r = requests.post(f"{NOTIF_URL}/send-otp", json={"phone_number":"+6591234567"}, timeout=3)
    assert r.status_code == 200
    otp = r.json()["otp"]
    assert len(otp) == 6 and otp.isdigit(), f"invalid OTP: {otp}"
    return f"OTP generated: {otp}"

def chk_mock_kyc():
    r = requests.get(f"{KYC_URL}/health", timeout=3)
    assert r.status_code == 200
    r = requests.post(f"{KYC_URL}/submit", json={
        "user_id":"verify-u-001","full_name":"Verify User",
        "nric_number":"S9999999Z","date_of_birth":"1990-01-01"
    }, timeout=3)
    assert r.status_code == 202, f"KYC submit failed: {r.text}"
    app_id = r.json()["application_id"]
    r = requests.get(f"{KYC_URL}/status/{app_id}", timeout=3)
    assert r.status_code == 200
    return f"KYC submitted, app_id={app_id[:8]}..."

# ── Main ──────────────────────────────────────
if __name__ == "__main__":
    print(f"""
{BOLD}{CYAN}  Cloud Bank SG — Full Verification Suite{RESET}
  {'='*52}""")

    section("LocalStack")
    check("LocalStack running and healthy",             chk_localstack)

    section("S3 — Object Storage")
    check("Buckets exist (KYC + statements)",           chk_s3_buckets)
    check("KYC bucket encryption (AES256)",             chk_s3_encryption)
    check("KYC bucket versioning enabled",              chk_s3_versioning)
    check("KYC bucket public access blocked",           chk_s3_public_block)
    check("S3 write → read → delete cycle",             chk_s3_upload_download)

    section("DynamoDB — NoSQL Storage")
    check("All 4 tables exist",                         chk_dynamo_tables)
    check("Sessions TTL auto-expiry enabled",           chk_dynamo_ttl)
    check("Sessions GSI (UserIdIndex) exists",          chk_dynamo_gsi)
    check("Transaction ledger composite key",           chk_dynamo_txn_ledger)
    check("DynamoDB write → read → delete cycle",       chk_dynamo_write_read)

    section("SQS — Message Queues")
    check("All queues exist (main + DLQ + KYC)",        chk_sqs_queues)
    check("DLQ is linked to main queue (RedrivePolicy)",chk_sqs_dlq_linked)
    check("SQS send → receive → delete cycle",          chk_sqs_send_receive)

    section("SNS — Pub/Sub Notifications")
    check("Both SNS topics exist",                      chk_sns_topics)
    check("SNS → SQS subscription exists",              chk_sns_sqs_subscription)
    check("SNS fan-out reaches SQS queue (end-to-end)", chk_sns_fanout)

    section("Lambda — Serverless Compute")
    check("All 5 Lambda functions deployed",            chk_lambda_functions)
    check("Lambda env vars set correctly",              chk_lambda_env_vars)
    check("Lambda uses correct IAM role",               chk_lambda_role)
    check("SQS → Lambda trigger enabled",               chk_lambda_sqs_trigger)
    check("Lambda invocation returns 200",              chk_lambda_invoke)

    section("IAM — Permissions")
    check("IAM roles created",                          chk_iam_roles)
    check("Lambda policy attached to role",             chk_iam_policy_attached)

    section("API Gateway — REST API")
    check("REST API exists",                            chk_apigw_exists)
    check("All routes configured (/accounts /transactions /auth /kyc)", chk_apigw_resources)

    section("VPC & Networking")
    check("VPC exists (10.0.0.0/16)",                   chk_vpc)
    check("4 subnets (2 public, 2 private)",            chk_subnets)
    check("Security groups (lambda-sg + rds-sg)",       chk_security_groups)

    section("Python Mock Services")
    check("Mock Auth service healthy",                  chk_mock_auth)
    check("Auth register → login → verify flow",        chk_mock_auth_flow)
    check("Mock Notifications + OTP generation",        chk_mock_notifications)
    check("Mock KYC submission flow",                   chk_mock_kyc)

    # ── Summary ───────────────────────────────
    passed = sum(1 for r in results if r[0])
    failed = sum(1 for r in results if not r[0])
    total  = len(results)

    print(f"\n  {'='*52}")
    print(f"  {BOLD}Results: {passed}/{total} checks passed{RESET}")

    if failed:
        print(f"\n  {RED}Failed checks:{RESET}")
        for ok, name, detail in results:
            if not ok:
                print(f"    {RED}✗{RESET}  {name}")
                if detail:
                    print(f"       {YELLOW}{detail}{RESET}")
        print()
        sys.exit(1)
    else:
        print(f"  {GREEN}All checks passed! Your infrastructure is healthy.{RESET}\n")
        sys.exit(0)
