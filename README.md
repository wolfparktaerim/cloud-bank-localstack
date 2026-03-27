# 🏦 AWS 3-Tier Banking Architecture (LocalStack)

This project simulates a secure, production-grade banking infrastructure using a 3-tier architecture entirely contained within a local environment.

## 🏗️ The Architecture

1. **Presentation Tier (Public)**: AWS API Gateway serves as the entry point, handling REST requests and CORS pre-flight checks.
2. **Application Tier (Private Logic)**: Python Lambda function containing the banking logic. It retrieves DB credentials from **AWS Secrets Manager** and processes transactions.
3. **Data Tier (Isolated)**:
   - **MongoDB**: A private container holding account balances. No ports are exposed to the host machine; it is only reachable by the Lambda.
   - **Amazon S3**: Used as an immutable Audit Log, storing JSON receipts for every transaction.

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
# for windows: ./reset.bat
./reset.sh
```
