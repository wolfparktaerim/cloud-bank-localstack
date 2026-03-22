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
import os

import pg8000

LOCALSTACK_ENDPOINT = "http://localhost:4566"
REGION = "ap-southeast-1"
RDS_DB_NAME = os.getenv("DB_NAME", "cloudbank")
RDS_DB_USERNAME = os.getenv("DB_USERNAME", "admin")
RDS_DB_PASSWORD = os.getenv("DB_PASSWORD", "LocalDev123!")

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


def get_rds_connection_info() -> dict:
    """Resolve RDS endpoint/port from LocalStack RDS API with env overrides."""
    endpoint_override = os.getenv("RDS_ENDPOINT")
    port_override = os.getenv("RDS_PORT")
    if endpoint_override:
        return {
            "host": endpoint_override,
            "port": int(port_override or "5432"),
            "database": RDS_DB_NAME,
            "user": RDS_DB_USERNAME,
            "password": RDS_DB_PASSWORD,
        }

    rds = client("rds")
    instances = rds.describe_db_instances().get("DBInstances", [])
    if not instances:
        raise RuntimeError("No RDS instances found. Run terraform apply and ensure LocalStack Pro RDS is enabled.")

    instance = instances[0]
    address = instance["Endpoint"]["Address"]
    port = int(instance["Endpoint"]["Port"])

    return {
        "host": address,
        "port": port,
        "database": RDS_DB_NAME,
        "user": RDS_DB_USERNAME,
        "password": RDS_DB_PASSWORD,
    }


def seed_rds_accounts(users: list):
    log("Seeding RDS PostgreSQL accounts table...")
    cfg = get_rds_connection_info()

    conn = pg8000.dbapi.connect(
        host=cfg["host"],
        port=cfg["port"],
        database=cfg["database"],
        user=cfg["user"],
        password=cfg["password"],
        timeout=10,
    )

    try:
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS accounts (
                account_id VARCHAR(64) PRIMARY KEY,
                user_id VARCHAR(64) NOT NULL,
                email VARCHAR(255) NOT NULL,
                full_name VARCHAR(255) NOT NULL,
                currency VARCHAR(8) NOT NULL DEFAULT 'SGD',
                balance NUMERIC(14,2) NOT NULL DEFAULT 0,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )

        inserted = 0
        for user in users:
            account_id = f"acct-{user['user_id']}"
            cur.execute(
                """
                INSERT INTO accounts (account_id, user_id, email, full_name, currency, balance)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (account_id) DO UPDATE
                SET email = EXCLUDED.email,
                    full_name = EXCLUDED.full_name
                """,
                (account_id, user["user_id"], user["email"], user["name"], "SGD", 1000.00),
            )
            inserted += 1

        conn.commit()
        log(f"  ✓ Seeded {inserted} account rows in RDS ({cfg['host']}:{cfg['port']})")
    finally:
        conn.close()


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
        seed_rds_accounts(users)
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
