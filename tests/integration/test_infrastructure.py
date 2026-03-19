"""
tests/integration/test_infrastructure.py
Integration tests that run against a live LocalStack instance.
Owner: Member 5

Run: pytest tests/integration/ -v
Requires: LocalStack running + terraform applied + seed data loaded
"""

import os
import json
import boto3
import pytest
import requests

ENDPOINT = os.getenv("LOCALSTACK_ENDPOINT", "http://localhost:4566")
REGION = "ap-southeast-1"
AUTH_URL = os.getenv("AUTH_MOCK_URL", "http://localhost:5001")
NOTIF_URL = os.getenv("NOTIFICATIONS_MOCK_URL", "http://localhost:5002")


def aws_client(service: str):
    return boto3.client(
        service,
        endpoint_url=ENDPOINT,
        region_name=REGION,
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )


# ── S3 Tests ──────────────────────────────────
class TestS3:
    def test_kyc_bucket_exists(self):
        s3 = aws_client("s3")
        buckets = [b["Name"] for b in s3.list_buckets()["Buckets"]]
        assert any("kyc" in b for b in buckets), f"No KYC bucket found. Buckets: {buckets}"

    def test_statements_bucket_exists(self):
        s3 = aws_client("s3")
        buckets = [b["Name"] for b in s3.list_buckets()["Buckets"]]
        assert any("statement" in b for b in buckets), f"No statements bucket found."

    def test_can_upload_and_retrieve_document(self):
        s3 = aws_client("s3")
        bucket = "cloud-bank-kyc-documents-local"
        key = "test/integration-test-doc.json"
        body = json.dumps({"test": True, "user_id": "test-user"})

        s3.put_object(Bucket=bucket, Key=key, Body=body.encode())
        response = s3.get_object(Bucket=bucket, Key=key)
        retrieved = json.loads(response["Body"].read())

        assert retrieved["test"] is True
        assert retrieved["user_id"] == "test-user"

        # Cleanup
        s3.delete_object(Bucket=bucket, Key=key)


# ── DynamoDB Tests ────────────────────────────
class TestDynamoDB:
    def test_user_sessions_table_exists(self):
        dynamodb = aws_client("dynamodb")
        tables = dynamodb.list_tables()["TableNames"]
        assert "cloud-bank-user-sessions" in tables, f"Sessions table not found. Tables: {tables}"

    def test_transaction_ledger_table_exists(self):
        dynamodb = aws_client("dynamodb")
        tables = dynamodb.list_tables()["TableNames"]
        assert "cloud-bank-transaction-ledger" in tables

    def test_can_write_and_read_session(self):
        dynamodb = aws_client("dynamodb")
        table = "cloud-bank-user-sessions"

        dynamodb.put_item(
            TableName=table,
            Item={
                "session_id": {"S": "test-session-123"},
                "user_id":    {"S": "test-user-abc"},
                "email":      {"S": "test@example.com"},
                "expires_at": {"N": "9999999999"},
            }
        )

        response = dynamodb.get_item(
            TableName=table,
            Key={"session_id": {"S": "test-session-123"}}
        )
        item = response.get("Item")
        assert item is not None
        assert item["user_id"]["S"] == "test-user-abc"

        # Cleanup
        dynamodb.delete_item(
            TableName=table,
            Key={"session_id": {"S": "test-session-123"}}
        )


# ── SQS Tests ─────────────────────────────────
class TestSQS:
    def test_transaction_queue_exists(self):
        sqs = aws_client("sqs")
        response = sqs.list_queues(QueueNamePrefix="cloud-bank-transactions")
        assert len(response.get("QueueUrls", [])) > 0, "Transaction queue not found"

    def test_can_send_and_receive_message(self):
        sqs = aws_client("sqs")
        queue_url = sqs.get_queue_url(QueueName="cloud-bank-transactions-local")["QueueUrl"]

        test_msg = {"transaction_id": "test-txn-999", "amount": 25.00, "currency": "SGD"}
        sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(test_msg))

        messages = sqs.receive_message(
            QueueUrl=queue_url, MaxNumberOfMessages=1, WaitTimeSeconds=2
        ).get("Messages", [])

        assert len(messages) > 0, "No messages received from queue"
        body = json.loads(messages[0]["Body"])
        assert body["currency"] == "SGD"

        # Cleanup
        sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=messages[0]["ReceiptHandle"])


# ── SNS Tests ─────────────────────────────────
class TestSNS:
    def test_notification_topic_exists(self):
        sns = aws_client("sns")
        topics = [t["TopicArn"] for t in sns.list_topics()["Topics"]]
        assert any("notification" in t for t in topics), f"Notification topic not found. Topics: {topics}"


# ── Mock Auth Service Tests ───────────────────
class TestMockAuth:
    def test_auth_health(self):
        r = requests.get(f"{AUTH_URL}/health", timeout=5)
        assert r.status_code == 200
        assert r.json()["status"] == "ok"

    def test_register_and_login(self):
        # Register
        r = requests.post(f"{AUTH_URL}/register", json={
            "email": "integration-test@example.com",
            "password": "TestPass123!",
            "full_name": "Integration Test",
        }, timeout=5)
        assert r.status_code == 201, f"Register failed: {r.text}"
        user_id = r.json()["user_id"]
        assert user_id is not None

        # Login
        r = requests.post(f"{AUTH_URL}/login", json={
            "email": "integration-test@example.com",
            "password": "TestPass123!",
        }, timeout=5)
        assert r.status_code == 200, f"Login failed: {r.text}"
        data = r.json()
        assert "access_token" in data
        assert data["token_type"] == "Bearer"

        # Verify token
        r = requests.post(f"{AUTH_URL}/verify-token", json={
            "token": data["access_token"]
        }, timeout=5)
        assert r.status_code == 200
        assert r.json()["valid"] is True
        assert r.json()["user_id"] == user_id

    def test_login_wrong_password(self):
        r = requests.post(f"{AUTH_URL}/login", json={
            "email": "integration-test@example.com",
            "password": "WrongPassword!",
        }, timeout=5)
        assert r.status_code == 401


# ── Mock Notifications Tests ──────────────────
class TestMockNotifications:
    def test_notifications_health(self):
        r = requests.get(f"{NOTIF_URL}/health", timeout=5)
        assert r.status_code == 200

    def test_send_email(self):
        r = requests.post(f"{NOTIF_URL}/send-email", json={
            "to": "user@example.com",
            "subject": "Integration Test Email",
            "body": "This is a test email from the integration suite.",
        }, timeout=5)
        assert r.status_code == 200
        assert "message_id" in r.json()

    def test_send_otp(self):
        r = requests.post(f"{NOTIF_URL}/send-otp", json={
            "phone_number": "+6591234567",
        }, timeout=5)
        assert r.status_code == 200
        data = r.json()
        assert "otp" in data
        assert len(data["otp"]) == 6
        assert data["otp"].isdigit()
