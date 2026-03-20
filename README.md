# 🏦 NeoBank SG — Cloud Infrastructure (LocalStack + Terraform)

> Online Digital Banking Platform — Cloud Engineering & Management Project  
> Simulated AWS infrastructure for 13,000,000 users in Singapore

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Team](#team)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [AWS Services](#aws-services)
- [Python Mock Services](#python-mock-services)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Project Overview

This repository simulates a production-grade AWS cloud infrastructure for a Singapore-based online digital bank, built using:

- **LocalStack** — AWS cloud emulation locally
- **Terraform** — Infrastructure as Code (IaC)
- **Python** — Mock services for unsupported LocalStack features
- **Docker Compose** — Local orchestration

---

## Team

| Member   | GitHub    | Responsibility                              |
| -------- | --------- | ------------------------------------------- |
| Member 1 | @username | Terraform Core — Networking, IAM, Providers |
| Member 2 | @username | Compute & API — Lambda, ECS, API Gateway    |
| Member 3 | @username | Data Layer — RDS, DynamoDB, S3              |
| Member 4 | @username | Messaging — SQS, SNS, EventBridge           |
| Member 5 | @username | Python Mocks, CI/CD, Tests                  |

---

## Architecture

```
Internet → API Gateway → Lambda Functions → DynamoDB / RDS (PostgreSQL)
                                         → SQS / SNS (async events)
                                         → S3 (documents)
IAM (roles & policies for all services)
CloudWatch (logs & monitoring)
Cognito (auth) → Python Mock in LocalStack free tier
```

---

## Prerequisites

Install these before starting:

| Tool           | Version | Install                                          |
| -------------- | ------- | ------------------------------------------------ |
| Docker Desktop | Latest  | https://docker.com                               |
| Terraform      | >= 1.6  | `brew install terraform` or https://terraform.io |
| Python         | >= 3.10 | https://python.org                               |
| AWS CLI        | >= 2.x  | `brew install awscli`                            |
| Git            | Latest  | Pre-installed on most systems                    |

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/wolfparktaerim/cloud-bank-localstack.git
cd cloud-bank-localstack

# 2. Run Docker
docker compose up -d

# 3. Initialize Terraform
cd terraform
terraform init
terraform apply -var-file="environments/localstack/terraform.tfvars" -auto-approve

# 4. Seed LocalStack with test data
cd ..
python scripts/seed_data.py

# 5. Verify everything is running
./scripts/health_check.sh
```

---

## Project Structure

```
cloud-bank/
├── .github/
│   ├── workflows/              # CI/CD pipelines
│   └── ISSUE_TEMPLATE/         # Bug report & feature templates
├── terraform/
│   ├── modules/                # Reusable Terraform modules (one per service)
│   ├── environments/
│   │   ├── localstack/         # Local dev config
│   │   └── prod-sim/           # Production-like simulation
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── services/                   # Python microservices / mock services
│   ├── auth/                   # Cognito mock
│   ├── accounts/
│   ├── transactions/
│   ├── notifications/
│   └── kyc/
├── scripts/                    # Setup, teardown, seeding scripts
├── tests/
│   ├── integration/            # Tests against live LocalStack
│   └── unit/
├── docs/
│   ├── architecture/           # Diagrams
│   └── adr/                    # Architecture Decision Records
├── docker-compose.yml
└── localstack.env
```

---

## Development Workflow

See [CONTRIBUTING.md](CONTRIBUTING.md) for full details.

```bash
# Daily workflow
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name

# ... make changes ...

git add .
git commit -m "feat: add DynamoDB accounts table"
git push origin feature/your-feature-name
# Open PR → develop on GitHub
```

---

## AWS Services

| Service          | Purpose                     | LocalStack Support |
| ---------------- | --------------------------- | ------------------ |
| API Gateway      | REST API entry point        | ✅ Free            |
| Lambda           | Business logic              | ✅ Free            |
| DynamoDB         | User sessions, transactions | ✅ Free            |
| RDS (PostgreSQL) | Core accounts data          | ✅ Free            |
| S3               | KYC documents, statements   | ✅ Free            |
| SQS              | Async transaction queue     | ✅ Free            |
| SNS              | Push notifications          | ✅ Free            |
| IAM              | Roles & policies            | ✅ Free            |
| CloudWatch       | Logs & metrics              | ✅ Free            |
| Cognito          | User auth                   | ⚠️ Python Mock     |
| SES              | Email notifications         | ⚠️ Python Mock     |
| WAF              | Security / rate limiting    | ⚠️ Python Mock     |

---

## Python Mock Services

Services not supported in LocalStack free tier are mocked in `services/`:

```bash
# Start all mock services
cd services
pip install -r requirements.txt
python run_mocks.py
```

---

## Testing

```bash
# Run unit tests
pytest tests/unit/

# Run integration tests (requires LocalStack running)
pytest tests/integration/

# Run all tests
pytest
```

---

## Troubleshooting

**LocalStack not starting?**

```bash
docker-compose down -v
docker-compose up -d
```

**Terraform state issues?**

```bash
cd terraform
terraform init -reconfigure
```

**Port 4566 already in use?**

```bash
lsof -i :4566
kill -9 <PID>
```
