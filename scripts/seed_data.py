#!/usr/bin/env python3
"""
scripts/seed_data.py
Seeds LocalStack with realistic test data for development and integration testing.
Owner: Member 5

Run after bootstrap: python3 scripts/seed_data.py
"""

import boto3
import json
import uuid
import datetime
import random
import sys

LOCALSTACK_ENDPOINT = "http://localhost:4566"
REGION = "ap-southeast-1"

# Boto3 client factory pointing at LocalStack
def client(service: str):
    return boto3.client(
        service,
        endpoint_url=LOCALSTACK_ENDPOINT,
        region_name=REGION,
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )


def log(msg: str):
    print(f"  [seed] {msg}")


# ── Seed DynamoDB: User Sessions ──────────────
def seed_user_sessions():
    log("Seeding DynamoDB user sessions table...")
    dynamodb = client("dynamodb")
    table_name = "cloud-bank-user-sessions"

    test_users = [
        {"user_id": "user-001", "email": "alice@example.com", "name": "Alice Tan"},
        {"user_id": "user-002", "email": "bob@example.com",   "name": "Bob Lim"},
        {"user_id": "user-003", "email": "carol@example.com", "name": "Carol Ng"},
    ]

    for user in test_users:
        session_id = str(uuid.uuid4())
        expires_at = int((datetime.datetime.utcnow() + datetime.timedelta(hours=1)).timestamp())
        dynamodb.put_item(
            TableName=table_name,
            Item={
                "session_id": {"S": session_id},
                "user_id":    {"S": user["user_id"]},
                "email":      {"S": user["email"]},
                "created_at": {"S": datetime.datetime.utcnow().isoformat()},
                "expires_at": {"N": str(expires_at)},
            }
        )
    log(f"  ✓ Seeded {len(test_users)} user sessions")
    return test_users


# ── Seed DynamoDB: Transaction Ledger ─────────
def seed_transactions(users: list):
    log("Seeding DynamoDB transaction ledger...")
    dynamodb = client("dynamodb")
    table_name = "cloud-bank-transaction-ledger"

    transaction_types = ["CREDIT", "DEBIT", "TRANSFER"]
    merchants = ["FairPrice", "Grab", "Shopee", "SingTel", "SP Group", "HDB", "NTUC"]
    count = 0

    for user in users:
        account_id = f"acct-{user['user_id']}"
        # Seed 5 transactions per user
        for i in range(5):
            txn_id = str(uuid.uuid4())
            txn_type = random.choice(transaction_types)
            amount = round(random.uniform(5.0, 500.0), 2)
            created_at = (
                datetime.datetime.utcnow() - datetime.timedelta(days=random.randint(0, 30))
            ).isoformat()

            dynamodb.put_item(
                TableName=table_name,
                Item={
                    "account_id":    {"S": account_id},
                    "transaction_id": {"S": txn_id},
                    "type":          {"S": txn_type},
                    "amount":        {"N": str(amount)},
                    "currency":      {"S": "SGD"},
                    "description":   {"S": f"{txn_type} - {random.choice(merchants)}"},
                    "status":        {"S": "COMPLETED"},
                    "created_at":    {"S": created_at},
                }
            )
            count += 1

    log(f"  ✓ Seeded {count} transactions across {len(users)} accounts")


# ── Seed S3: Sample KYC document placeholders ─
def seed_s3_documents(users: list):
    log("Seeding S3 KYC document placeholders...")
    s3 = client("s3")
    bucket = "cloud-bank-kyc-documents-local"
    count = 0

    for user in users:
        # Simulate a KYC NRIC document upload
        key = f"kyc/{user['user_id']}/nric-front.txt"
        s3.put_object(
            Bucket=bucket,
            Key=key,
            Body=json.dumps({
                "user_id": user["user_id"],
                "document_type": "NRIC",
                "side": "front",
                "uploaded_at": datetime.datetime.utcnow().isoformat(),
                "status": "pending_review",
            }).encode(),
            ContentType="application/json",
        )
        count += 1

    log(f"  ✓ Seeded {count} KYC document placeholders in S3")


# ── Seed SQS: Sample pending transactions ─────
def seed_sqs_messages():
    log("Seeding SQS transaction queue with sample messages...")
    sqs = client("sqs")

    queue_url_response = sqs.get_queue_url(QueueName="cloud-bank-transactions-local")
    queue_url = queue_url_response["QueueUrl"]

    messages = [
        {
            "transaction_id": str(uuid.uuid4()),
            "from_account": "acct-user-001",
            "to_account": "acct-user-002",
            "amount": 50.00,
            "currency": "SGD",
            "type": "TRANSFER",
            "initiated_at": datetime.datetime.utcnow().isoformat(),
        },
        {
            "transaction_id": str(uuid.uuid4()),
            "from_account": "acct-user-003",
            "to_account": None,
            "amount": 120.50,
            "currency": "SGD",
            "type": "DEBIT",
            "description": "Grab - Food delivery",
            "initiated_at": datetime.datetime.utcnow().isoformat(),
        },
    ]

    for msg in messages:
        sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(msg),
        )

    log(f"  ✓ Seeded {len(messages)} messages in transaction queue")


# ── Main ──────────────────────────────────────
def main():
    print("")
    print("  Cloud Bank SG — Seeding Test Data")
    print("  ────────────────────────────────────────")

    try:
        users = seed_user_sessions()
        seed_transactions(users)
        seed_s3_documents(users)
        seed_sqs_messages()

        print("")
        print("  ✅ All seed data loaded successfully!")
        print("")
        print("  Test credentials:")
        print("    alice@example.com  (user-001)")
        print("    bob@example.com    (user-002)")
        print("    carol@example.com  (user-003)")
        print("")

    except Exception as e:
        print(f"\n  ❌ Seed failed: {e}")
        print("     Make sure LocalStack is running: docker compose up -d localstack")
        sys.exit(1)


if __name__ == "__main__":
    main()
