# 🏦 Singapore Online Digital Bank - Enterprise Architecture

## 🏗️ Architecture Overview

This project simulates a production-grade, highly scalable online banking platform designed to support 13,000,000 users in Singapore. It utilizes a secure multi-tier AWS architecture simulated via LocalStack Pro.

### 🌐 1. Edge & Networking Layer

- **Route 53 & CloudFront:** Acts as the entry point. Route 53 handles DNS routing, while CloudFront caches static frontend assets and mitigates DDoS attacks.
- **VPC & Subnets:** \* **Public Subnet:** Contains the Internet Gateway (IGW), Application Load Balancer (ALB), and NAT Gateway.
  - **Private Subnet:** Highly secure zone containing API Gateway, Lambda functions, and all databases. No direct internet access.
- **ALB (Application Load Balancer):** Routes incoming traffic from CloudFront to the internal API Gateway.

### 🔐 2. Security & Compliance Layer

- **Amazon Cognito:** Manages user registration, authentication, and JWT token generation.
- **AWS KMS:** Manages encryption keys to encrypt data at rest in RDS, DynamoDB, and S3.
- **AWS ACM:** Provisions SSL/TLS certificates for in-transit encryption.
- **Secrets Manager:** Securely stores database credentials and API keys.
- **IAM:** Enforces strict Least Privilege access for all Lambda functions and services.

### ⚙️ 3. Compute Layer (Application Logic)

- **API Gateway:** Acts as the private entry point for microservices, validating Cognito JWT tokens.
- **AWS Lambda (Python):** Serverless microservices running the core banking logic (e.g., `UserService`, `TransactionService`, `NotificationService`).

### 🗄️ 4. Data Layer (Purpose-Built Databases)

We use a polyglot persistence strategy, matching the database to the specific data type:

- **Amazon RDS (PostgreSQL):** _Core Banking Ledger._ Used for highly structured, ACID-compliant data (User accounts, current balances, definitive state).
- **Amazon DynamoDB:** _Transaction History & Audit._ A NoSQL key-value store used for high-throughput write operations (transaction logs, session states).
- **Amazon ElastiCache (Redis):** _Caching Layer._ Caches frequent read operations (e.g., "Check Balance") to reduce RDS load and ensure sub-millisecond latency.
- **Amazon S3:** _Cold Storage & Backups._ Stores generated monthly PDF statements, static assets, and automated database backups.

### 📩 5. Messaging & Event-Driven Layer

- **Amazon SNS (Simple Notification Service):** Publishes events (e.g., "Large Transfer Detected").
- **Amazon SQS (Simple Queue Service):** Subscribes to SNS topics to decouple asynchronous tasks. For example, triggering a background Lambda to generate a PDF receipt or run fraud detection without slowing down the user's API response.

### 👁️ 6. Observability & Monitoring

- **CloudWatch:** Centralized logging for Lambda, plus alarms for high error rates.
- **AWS X-Ray:** Distributed tracing to track a transaction's journey from API Gateway through Lambda to the databases.
- **CloudTrail:** Audits all AWS API calls for compliance and security forensics.

## 🚀 How to Run

### 1. Prerequisites

- Docker & Docker Compose
- Terraform
- Python 3.9 (for packaging dependencies)
- AWS CLI (optional, for manual verification)

### 2. Initial Setup

Clone the project and ensure your `.env` file has the correct LocalStack token.

### 3. Deployment

Run the automated reset and deploy script:

```bash
chmod +x reset.sh deploy.sh
./reset.sh

# for windows: ./deploy.bat ./reset.bat

```
