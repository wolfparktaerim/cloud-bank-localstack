# AWS Cloud Bank — LocalStack Pro

A production-grade banking system simulated entirely in a local environment using LocalStack Pro. Implements a full multi-AZ AWS architecture across sections 5.1–5.8 of the Cloud Bank design document.

---

## Architecture Overview

| Section                  | Services                                                                                                                         |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| 5.1 Networking           | VPC, 6 Subnets (AZ1 + AZ2), NACLs, Security Groups, NAT Gateway, Internet Gateway, Route Tables, VPC Endpoints                   |
| 5.2 Traffic Management   | Route 53 private hosted zone · **ALB** (bank-alb, internet-facing, AZ1 + AZ2) with 6 Lambda target groups and path-based routing |
| 5.3 Auth & Authorization | Cognito User Pool, MFA (TOTP), App Client, Hosted Domain                                                                         |
| 5.5 Application Tier     | 6 Lambda functions (auth, accounts, transactions, notifications, kyc, dlq), per-Lambda IAM roles, X-Ray tracing                  |
| 5.6 Storage              | Secrets Manager, S3 (audit logs, KYC docs), RDS PostgreSQL, DynamoDB (4 tables), ElastiCache Redis                               |
| 5.7 Security             | KMS master key, WAF v2 (Common + SQLi rules), ACM Certificate                                                                    |
| 5.8 Reliability          | SNS (2 topics), SQS (queue + DLQ), CloudWatch alarms, CloudTrail, AWS Backup                                                     |

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.3
- [Python 3.9+](https://www.python.org/downloads/)
- A LocalStack Pro auth token in `.env` as `LS_AUTH_TOKEN`

---

## Deployment

Ensure Docker Desktop is running

```bash
docker compose up -d
chmod +x reset.sh
./reset.sh
python3 -m http.server 8000
pkill -f "python3 -m http.server 8000"
```

The script will:

1. Destroy any previous environment
2. Restart Docker containers (LocalStack Pro + MongoDB)
3. Package all 6 Lambda functions as separate zip files
4. Run `terraform init` and `terraform apply`
5. Write `config.js` — the dashboard will auto-load both the API Gateway URL and the ALB URL

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

| Field    | Value                                                            |
| -------- | ---------------------------------------------------------------- |
| Username | `testuser`                                                       |
| Email    | `test@cloudbank.com`                                             |
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

| Field      | Value      |
| ---------- | ---------- |
| Account ID | `ACC-001`  |
| Owner Name | `John Doe` |
| Type       | `SAVINGS`  |

Click **Create Account**. Expected:

```json
{ "message": "Account created", "account_id": "ACC-001" }
```

#### 2b. Create a second account (needed for transfer testing)

| Field      | Value      |
| ---------- | ---------- |
| Account ID | `ACC-002`  |
| Owner Name | `Jane Doe` |
| Type       | `CHECKING` |

#### 2c. List all accounts

Leave Account ID blank and click **List All**. Both accounts should appear.

#### 2d. Get a single account

Enter `ACC-001` and click **Get Account**.

---

### Step 3 — Transactions (MongoDB + S3 + SNS)

Navigate to the **Transactions** tab.

> Each transaction writes an audit record to **S3** (`bank-audit-logs`) and **DynamoDB** (`bank-audit-events`), then publishes to **SNS** (`bank-transaction-events`).

#### 3a. Deposit

| Field      | Value     |
| ---------- | --------- |
| Account ID | `USER_01` |
| Amount     | `500`     |

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

| Field      | Value     |
| ---------- | --------- |
| Account ID | `USER_01` |
| Amount     | `100`     |

Click **Withdraw**. Balance should now be $400.

#### 3d. Insufficient funds (error case)

Try withdrawing `$9999` from `USER_01`. Expected:

```json
{ "error": "Insufficient funds" }
```

#### 3e. Transfer

| Field       | Value     |
| ----------- | --------- |
| Account ID  | `USER_01` |
| Amount      | `50`      |
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

| Field     | Value       |
| --------- | ----------- |
| User ID   | `USER_01`   |
| Full Name | `John Doe`  |
| ID Type   | `PASSPORT`  |
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

| Field   | Value                          |
| ------- | ------------------------------ |
| Subject | `Test Alert`                   |
| Message | `System check from Cloud Bank` |

Click **Publish to SNS**. Expected:

```json
{ "message": "Alert published to SNS" }
```

#### 5b. Send email (SES)

> LocalStack SES runs in sandbox mode — both sender and recipient must be verified. Terraform provisions `noreply@cloudbank.internal` (sender) and `admin@cloudbank.com` (test recipient) via `aws_ses_email_identity`. Use only these addresses when testing locally.

| Field   | Value                   |
| ------- | ----------------------- |
| To      | `admin@cloudbank.com`   |
| Subject | `Test Email`            |
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

# X-Ray traces (after triggering Lambdas)
# macOS/Linux:
aws --endpoint-url=http://localhost:4566 --output json xray get-trace-summaries \
  --region ap-southeast-1 \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Windows/PowerShell:
aws --endpoint-url=http://localhost:4566 --output json xray get-trace-summaries \
  --region ap-southeast-1 \
  --start-time $((Get-Date).AddHours(-1).ToString('u').Replace(' ', 'T')) \
  --end-time $((Get-Date).ToString('u').Replace(' ', 'T'))
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

### Step 8 — X-Ray Tracing

To verify that AWS X-Ray tracing is enabled and working for the Lambda functions (as per section 5.5 of the architecture):

#### 8a. Trigger Lambda executions

Perform actions that invoke Lambdas to generate traces, such as:

- Making a deposit or withdrawal via the **Transactions** tab in the dashboard.
- Running a load test: `k6 run --env API_BASE=$(terraform output -raw api_base_url) load-test/k6.js`

Wait 5-10 seconds for traces to be recorded.

#### 8b. Query traces via AWS CLI

Use these commands to inspect X-Ray traces:

```bash
# List recent trace summaries (shows TraceId, duration, status)
# macOS/Linux:
aws --endpoint-url=http://localhost:4566 --output json xray get-trace-summaries \
  --region ap-southeast-1 \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Windows/PowerShell:
aws --endpoint-url=http://localhost:4566 --output json xray get-trace-summaries \
  --region ap-southeast-1 \
  --start-time $((Get-Date).AddHours(-1).ToString('u').Replace(' ', 'T')) \
  --end-time $((Get-Date).ToString('u').Replace(' ', 'T'))

# Get detailed trace data for a specific TraceId (replace <TraceId> from above)
aws --endpoint-url=http://localhost:4566 --output json xray batch-get-traces \
  --trace-ids <TraceId> --region ap-southeast-1
```

Expected output: Traces with segments for Lambda functions (e.g., `lambda-transactions`), including sub-segments for downstream services like DynamoDB, S3, and MongoDB calls.

If no traces appear, ensure Lambdas have X-Ray enabled in `main.tf` and IAM roles include `AWSXRayDaemonWriteAccess`.

---

## Load Testing

Three scripts live in [load-test/](load-test/). Pick whichever tool you have installed.

### Install

```bash
# k6 (recommended)
brew install k6          # macOS
choco install k6         # Windows

# Locust (Python alternative — no extra install if you already have pip)
pip install locust
```

---

### k6 — full user journey (`k6.js`)

Runs every microservice in a realistic sequence per VU:
`register → login → create accounts → deposit → withdraw → transfer → KYC → notify → DLQ stats`

```bash
# Against API Gateway
k6 run --env API_BASE=$(terraform output -raw api_base_url) load-test/k6.js

# Against the ALB
k6 run --env API_BASE=$(terraform output -raw alb_base_url) load-test/k6.js

# Higher load
k6 run --env API_BASE=$(terraform output -raw api_base_url) \
       --vus 20 --duration 2m load-test/k6.js

# Save raw results for further analysis
k6 run --env API_BASE=$(terraform output -raw api_base_url) \
       --out json=load-test/results.json load-test/k6.js
```

Default profile: ramp 0→5 VUs (20s) → hold 10 VUs (1m) → spike 20 VUs (20s) → ramp down.

**Thresholds** (test fails if breached):

| Metric                  | Threshold          |
| ----------------------- | ------------------ |
| Overall p95 latency     | < 3 000 ms         |
| Per-service p95 latency | < 1 500 – 3 000 ms |
| HTTP failure rate       | < 10%              |
| Application error rate  | < 10%              |

A custom summary is printed at the end and saved to `load-test/summary.txt`.

---

### k6 — API Gateway vs ALB comparison (`k6-compare.js`)

Runs the same deposit/withdraw workload against both endpoints **simultaneously** using k6 scenarios, then prints a side-by-side latency table.

```bash
k6 run \
  --env API_BASE=$(terraform output -raw api_base_url) \
  --env ALB_BASE=$(terraform output -raw alb_base_url) \
  load-test/k6-compare.js
```

Output:

```
╔══════════════════════════════════════════════════════════════════╗
║         CLOUD BANK — API GATEWAY vs ALB COMPARISON              ║
╠══════════════════════════════════════════════════════════════════╣
║                    API Gateway          ALB                      ║
╠══════════════════════════════════════════════════════════════════╣
║  p50 latency    142ms            138ms                           ║
║  p95 latency    310ms            298ms                           ║
...
```

---

### Locust — Python web UI (`locust.py`)

Locust runs a weighted task mix (deposits/balance checks most frequent, KYC/DLQ least frequent) and provides a live web dashboard.

**Headless (CI-friendly):**

```bash
locust -f load-test/locust.py --headless \
       --users 10 --spawn-rate 2 --run-time 2m \
       --host $(terraform output -raw api_base_url)
```

**With live web UI — open `http://localhost:8089`:**

```bash
locust -f load-test/locust.py \
       --host $(terraform output -raw api_base_url)
```

Against the ALB:

```bash
locust -f load-test/locust.py \
       --host $(terraform output -raw alb_base_url)
```

**Task weights** (higher = more frequent):

| Task              | Weight | Why                        |
| ----------------- | ------ | -------------------------- |
| deposit           | 3      | most common banking action |
| balance           | 3      | read-heavy workload        |
| withdraw          | 2      | less frequent than deposit |
| transfer          | 2      | inter-account              |
| get/list accounts | 1      | metadata reads             |
| KYC submit/check  | 1      | infrequent lifecycle event |
| send alert        | 1      | operational                |
| DLQ stats         | 1      | monitoring                 |

---

### What to expect on LocalStack

| Consideration                 | Detail                                                                                                           |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **All load hits one machine** | Docker + LocalStack + MongoDB all share your CPU/RAM — you're benchmarking your laptop, not a distributed system |
| **Bottleneck**                | MongoDB container for `/transactions` — it processes all deposits, withdrawals, and transfers sequentially       |
| **Lambda "cold starts"**      | LocalStack simulates them but they're much faster than real AWS                                                  |
| **Realistic numbers**         | p95 of 200–800ms is typical locally; real AWS would be 50–200ms for warmed Lambdas                               |
| **Error handling**            | Insufficient-funds responses (400) are expected under load — the scripts treat them as non-failures              |

---

## Load Balancer (ALB)

### Architecture

```
Internet
    │  HTTP :80
    ▼
┌─────────────────────────────────────────────┐
│  bank-alb  (Application Load Balancer)      │
│  public-az1 (10.0.1.0/24)                  │
│  public-az2 (10.0.4.0/24)                  │
│                                             │
│  Listener rules (path-based):               │
│    /auth          → bank-tg-auth            │
│    /accounts      → bank-tg-accounts        │
│    /transactions  → bank-tg-transactions    │
│    /kyc           → bank-tg-kyc             │
│    /notifications → bank-tg-notifications   │
│    /dlq           → bank-tg-dlq             │
│    (default)      → 404 fixed-response      │
└─────────────┬───────────────────────────────┘
              │  Lambda invoke
              ▼
   Lambda functions (private-lambda subnets)
```

The ALB sits in front of the same Lambda functions as API Gateway, providing a second entry point that demonstrates real AWS path-based load balancing. Both endpoints call identical code.

### Get the ALB URL

After `./reset.sh`:

```bash
terraform output alb_base_url
# → http://bank-alb.elb.localhost.localstack.cloud:4566
```

```bash
# Or inspect all ALB outputs at once
terraform output | grep alb
```

### Test via curl

Set the ALB base URL in a variable:

```bash
export ALB=$(terraform output -raw alb_base_url)
```

**Deposit through the ALB:**

```bash
curl -s -X POST "$ALB/transactions" \
  -H "Content-Type: application/json" \
  -d '{"action":"deposit","account_id":"USER_ALB","amount":250}' | jq
```

**Register a user through the ALB:**

```bash
curl -s -X POST "$ALB/auth" \
  -H "Content-Type: application/json" \
  -d '{"action":"register","username":"albuser","email":"alb@cloudbank.com","password":"MyP@ssword123!"}' | jq
```

**Create an account through the ALB:**

```bash
curl -s -X POST "$ALB/accounts" \
  -H "Content-Type: application/json" \
  -d '{"action":"create_account","account_id":"ALB-001","owner_name":"ALB User","account_type":"SAVINGS"}' | jq
```

**Hit an unknown path (verifies default 404 rule):**

```bash
curl -s "$ALB/unknown" | jq
# → {"error":"Route not found — use /auth /accounts /transactions /kyc /notifications /dlq"}
```

### Verify the ALB via AWS CLI

```bash
# Describe the load balancer
aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers \
  --region ap-southeast-1 | jq '.LoadBalancers[] | {Name,DNSName,State}'

# List all target groups
aws --endpoint-url=http://localhost:4566 elbv2 describe-target-groups \
  --region ap-southeast-1 | jq '.TargetGroups[] | {Name:.TargetGroupName, Type:.TargetType}'

# Check target health for the auth target group (replace ARN from previous command)
aws --endpoint-url=http://localhost:4566 elbv2 describe-target-health \
  --target-group-arn <arn-of-bank-tg-auth> \
  --region ap-southeast-1 | jq

# List listener rules
aws --endpoint-url=http://localhost:4566 elbv2 describe-rules \
  --listener-arn <arn-of-http-listener> \
  --region ap-southeast-1 | jq '.Rules[] | {Priority, Conditions, Actions}'
```

### Visualise: side-by-side comparison

Run the same request through both endpoints and confirm identical results:

```bash
export API=$(terraform output -raw api_base_url)
export ALB=$(terraform output -raw alb_base_url)

# API Gateway path
curl -s -X POST "$API/transactions" \
  -H "Content-Type: application/json" \
  -d '{"action":"deposit","account_id":"COMPARE_01","amount":100}' | jq

# ALB path (same Lambda, different ingress)
curl -s -X POST "$ALB/transactions" \
  -H "Content-Type: application/json" \
  -d '{"action":"deposit","account_id":"COMPARE_01","amount":100}' | jq
```

Both calls reach the same `lambda_transactions` function and write to the same MongoDB instance.

### Switch the dashboard between API Gateway and ALB

1. Open `index.html` in your browser
2. Go to the **Settings** tab
3. Click **Switch API Base to ALB** — all tab requests now go through the ALB
4. Click **Switch API Base to API Gateway** to revert

---

## Common Issues

| Error                              | Cause                  | Fix                                               |
| ---------------------------------- | ---------------------- | ------------------------------------------------- |
| `CORS error` in browser            | API URL not set        | Paste `api_base_url` output into the Settings tab |
| `Insufficient funds`               | Account has no balance | Run a deposit first                               |
| `No KYC submission found`          | Wrong User ID          | Use the exact ID from the submit step             |
| Lambda `error: ...` on transaction | MongoDB not ready      | Wait 10s after `./reset.sh` and retry             |
| 403 on any endpoint                | JWT expired            | Log in again via the Auth tab                     |

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

The batch script mirrors `reset.sh` exactly — it packages all 6 Lambdas (including `dlq`), deploys infrastructure, and writes both `apiBase` and `albBase` into `config.js`.

To test the ALB from PowerShell after deployment:

```powershell
$ALB = terraform output -raw alb_base_url

# Deposit via ALB
Invoke-RestMethod -Method Post -Uri "$ALB/transactions" `
  -ContentType "application/json" `
  -Body '{"action":"deposit","account_id":"WIN_01","amount":100}' | ConvertTo-Json

# Verify ALB in AWS CLI
aws --endpoint-url=http://localhost:4566 elbv2 describe-load-balancers --region ap-southeast-1

# Check X-Ray traces (after triggering Lambdas)
aws --endpoint-url=http://localhost:4566 --output json xray get-trace-summaries `
  --region ap-southeast-1 `
  --start-time $((Get-Date).AddHours(-1).ToString('u').Replace(' ', 'T')) `
  --end-time $((Get-Date).ToString('u').Replace(' ', 'T'))
```
