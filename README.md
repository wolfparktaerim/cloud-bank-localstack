# AWS Cloud Bank — LocalStack Pro

A production-grade banking system simulated entirely in a local environment using LocalStack Pro. Implements a full multi-AZ AWS architecture across sections 5.1–5.8 of the Cloud Bank design document.

---

## Architecture Overview

| Section | Services |
|---------|----------|
| 5.1 Networking | VPC, 6 Subnets (AZ1 + AZ2), NACLs, Security Groups, NAT Gateway, Internet Gateway, Route Tables, VPC Endpoints |
| 5.2 Traffic Management | Route 53 private hosted zone |
| 5.3 Auth & Authorization | Cognito User Pool, MFA (TOTP), App Client, Hosted Domain |
| 5.5 Application Tier | 5 Lambda functions (auth, accounts, transactions, notifications, kyc), per-Lambda IAM roles, X-Ray tracing |
| 5.6 Storage | Secrets Manager, S3 (audit logs, KYC docs), RDS PostgreSQL, DynamoDB (4 tables), ElastiCache Redis |
| 5.7 Security | KMS master key, WAF v2 (Common + SQLi rules), ACM Certificate |
| 5.8 Reliability | SNS (2 topics), SQS (queue + DLQ), CloudWatch alarms, CloudTrail, AWS Backup |

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- [Python 3.9+](https://www.python.org/downloads/)
- A LocalStack Pro auth token in `.env` as `LS_AUTH_TOKEN`

---

## Deployment

```bash
chmod +x reset.sh
./reset.sh
```

The script will:
1. Destroy any previous environment
2. Restart Docker containers (LocalStack Pro + MongoDB)
3. Package all 5 Lambda functions as separate zip files
4. Run `terraform init` and `terraform apply`
5. Write `config.js` — the dashboard will auto-load the API URL

Once complete, open `index.html` directly in a browser.

---

## Testing Guide

### Step 0 — Confirm deployment

After `./reset.sh` finishes you should see output like:

```
api_base_url = "http://localhost:4566/_aws/execute-api/abc12345/prod"
cognito_user_pool_id  = "ap-southeast-1_xxxxxxxx"
cognito_client_id     = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
```

The dashboard at `index.html` reads these from `config.js` automatically — no copy-paste needed.

---

### Step 1 — Auth (Cognito)

Navigate to the **Auth** tab.

#### 1a. Register a user

| Field | Value |
|-------|-------|
| Username | `testuser` |
| Email | `test@cloudbank.com` |
| Password | `MyP@ssword123!` (min 12 chars, upper + lower + number + symbol) |

Click **Register**. Expected response:
```json
{ "message": "User 'testuser' registered successfully" }
```

#### 1b. Login

Use the same username and password. Click **Login — get JWT**.

Expected response:
```json
{
  "message": "Login successful",
  "access_token": "eyJ...",
  "id_token": "eyJ...",
  "refresh_token": "eyJ..."
}
```

The JWT token is saved automatically. The status indicator in the top-right changes from **Not authenticated** to **Authenticated**.

#### 1c. Get user details

Enter `testuser` and click **Get User** to confirm the account exists in Cognito.

---

### Step 2 — Accounts (DynamoDB)

Navigate to the **Accounts** tab.

#### 2a. Create an account

| Field | Value |
|-------|-------|
| Account ID | `ACC-001` |
| Owner Name | `John Doe` |
| Type | `SAVINGS` |

Click **Create Account**. Expected:
```json
{ "message": "Account created", "account_id": "ACC-001" }
```

#### 2b. Create a second account (needed for transfer testing)

| Field | Value |
|-------|-------|
| Account ID | `ACC-002` |
| Owner Name | `Jane Doe` |
| Type | `CHECKING` |

#### 2c. List all accounts

Leave Account ID blank and click **List All**. Both accounts should appear.

#### 2d. Get a single account

Enter `ACC-001` and click **Get Account**.

---

### Step 3 — Transactions (MongoDB + S3 + SNS)

Navigate to the **Transactions** tab.

> Each transaction writes an audit record to **S3** (`bank-audit-logs`) and **DynamoDB** (`bank-audit-events`), then publishes to **SNS** (`bank-transaction-events`).

#### 3a. Deposit

| Field | Value |
|-------|-------|
| Account ID | `USER_01` |
| Amount | `500` |

Click **Deposit**. Expected:
```json
{
  "message": "Deposited $500.00 into USER_01",
  "audit_id": "uuid-here",
  "audit_status": "Recorded"
}
```

#### 3b. Check balance

Same account, click **Check Balance**:
```json
{ "message": "Balance for USER_01: $500.00", "audit_id": "uuid-here" }
```

#### 3c. Withdraw

| Field | Value |
|-------|-------|
| Account ID | `USER_01` |
| Amount | `100` |

Click **Withdraw**. Balance should now be $400.

#### 3d. Insufficient funds (error case)

Try withdrawing `$9999` from `USER_01`. Expected:
```json
{ "error": "Insufficient funds" }
```

#### 3e. Transfer

| Field | Value |
|-------|-------|
| Account ID | `USER_01` |
| Amount | `50` |
| Transfer To | `USER_02` |

Click **Transfer**. Then check balance on both accounts.

#### 3f. Verify S3 audit log (AWS CLI)

```bash
aws --endpoint-url=http://localhost:4566 s3 ls s3://bank-audit-logs/logs/USER_01/ --recursive
```

Expected: one `.json` file per transaction.

```bash
aws --endpoint-url=http://localhost:4566 s3 cp \
  s3://bank-audit-logs/logs/USER_01/<audit-id>.json -
```

#### 3g. Verify DynamoDB audit table

```bash
aws --endpoint-url=http://localhost:4566 dynamodb scan \
  --table-name bank-audit-events \
  --region ap-southeast-1
```

---

### Step 4 — KYC (S3 + DynamoDB)

Navigate to the **KYC** tab.

#### 4a. Submit KYC

| Field | Value |
|-------|-------|
| User ID | `USER_01` |
| Full Name | `John Doe` |
| ID Type | `PASSPORT` |
| ID Number | `P12345678` |

Click **Submit KYC**. Save the `kyc_id` from the response.

```json
{ "message": "KYC submitted", "kyc_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" }
```

#### 4b. Check status

Enter `USER_01` in **User ID** and click **Check Status**:
```json
{ "kyc_id": "...", "status": "PENDING", "submitted_at": "..." }
```

#### 4c. Approve KYC

Paste the `kyc_id` into the **KYC ID** field and click **Approve**:
```json
{ "message": "KYC xxxxxxxx approved" }
```

#### 4d. Check status again

Status should now be `APPROVED`.

#### 4e. Verify KYC document in S3

```bash
aws --endpoint-url=http://localhost:4566 s3 ls \
  s3://bank-kyc-documents/submissions/USER_01/ --recursive
```

---

### Step 5 — Notifications (SNS + SES)

Navigate to the **Notifications** tab.

#### 5a. Send SNS alert

| Field | Value |
|-------|-------|
| Subject | `Test Alert` |
| Message | `System check from Cloud Bank` |

Click **Publish to SNS**. Expected:
```json
{ "message": "Alert published to SNS" }
```

#### 5b. Send email (SES)

> LocalStack SES runs in sandbox mode — both sender and recipient must be verified. Terraform provisions `noreply@cloudbank.internal` (sender) and `admin@cloudbank.com` (test recipient) via `aws_ses_email_identity`. Use only these addresses when testing locally.

| Field | Value |
|-------|-------|
| To | `admin@cloudbank.com` |
| Subject | `Test Email` |
| Message | `Hello from Cloud Bank` |

Click **Send Email**:
```json
{ "message": "Email sent to admin@cloudbank.com" }
```

#### 5c. Subscribe an email to alerts

Enter an email and click **Subscribe**:
```json
{ "message": "Subscribed user@example.com to alerts" }
```

#### 5d. List subscriptions

Click **List Subscriptions** to confirm the subscription was created.

#### 5e. Verify SNS topics (AWS CLI)

```bash
aws --endpoint-url=http://localhost:4566 sns list-topics --region ap-southeast-1
```

---

### Step 6 — Verify infrastructure via AWS CLI

These commands confirm the underlying AWS resources were created correctly.

```bash
# Cognito User Pool
aws --endpoint-url=http://localhost:4566 cognito-idp list-user-pools \
  --max-results 10 --region ap-southeast-1

# DynamoDB tables
aws --endpoint-url=http://localhost:4566 dynamodb list-tables \
  --region ap-southeast-1

# Secrets Manager
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets \
  --region ap-southeast-1

# KMS keys
aws --endpoint-url=http://localhost:4566 kms list-keys \
  --region ap-southeast-1

# SQS queues
aws --endpoint-url=http://localhost:4566 sqs list-queues \
  --region ap-southeast-1

# CloudTrail trails
aws --endpoint-url=http://localhost:4566 cloudtrail describe-trails \
  --region ap-southeast-1

# WAF ACLs
aws --endpoint-url=http://localhost:4566 wafv2 list-web-acls \
  --scope REGIONAL --region ap-southeast-1

# RDS instances
aws --endpoint-url=http://localhost:4566 rds describe-db-instances \
  --region ap-southeast-1

# ElastiCache clusters
aws --endpoint-url=http://localhost:4566 elasticache describe-cache-clusters \
  --region ap-southeast-1
```

---

### Step 7 — Dead Letter Queue test

Trigger a transaction failure that will automatically send the message to the DLQ after 3 retry attempts:

**Option A: Quick Test (uses test message injection)**

```bash
export API_BASE=$(grep 'apiBase:' config.js | awk -F'"' '{print $2}')
export API_DLQ="$API_BASE/dlq"

# Send test message to DLQ
curl -X POST "$API_DLQ" -H "Content-Type: application/json" \
  -d '{"action":"send_test","account_id":"TEST_DLQ","amount":500}' | jq

# View DLQ stats
curl -X POST "$API_DLQ" -H "Content-Type: application/json" \
  -d '{"action":"stats"}' | jq

# Peek at messages
curl -X POST "$API_DLQ" -H "Content-Type: application/json" \
  -d '{"action":"peek"}' | jq

# Redrive back to main queue
curl -X POST "$API_DLQ" -H "Content-Type: application/json" \
  -d '{"action":"redrive"}' | jq
```

**Option B: Real Failure Test (triggers actual Lambda retries → DLQ)**

Run the automated test script:
```bash
./test_dlq_real_failure.sh
```

Windows / PowerShell (no Bash required):
```powershell
./test_dlq_real_failure.ps1
```

This publishes a malformed transaction to SNS that will fail Lambda processing 3 times, then automatically move to the DLQ.

---

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `CORS error` in browser | API URL not set | Paste `api_base_url` output into the Settings tab |
| `Insufficient funds` | Account has no balance | Run a deposit first |
| `No KYC submission found` | Wrong User ID | Use the exact ID from the submit step |
| Lambda `error: ...` on transaction | MongoDB not ready | Wait 10s after `./reset.sh` and retry |
| 403 on any endpoint | JWT expired | Log in again via the Auth tab |

---

## Re-deploy from scratch

```bash
./reset.sh
```

This destroys all existing resources, rebuilds all Lambda packages, and re-deploys the full stack. Takes ~60 seconds.

---

## Windows

```bat
reset.bat
```
