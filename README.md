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

| Member   | Responsibility                              |
| -------- | ------------------------------------------- |
| Member 1 | Terraform Core — Networking, IAM, Providers |
| Member 2 | Compute & API — Lambda, ECS, API Gateway    |
| Member 3 | Data Layer — RDS, DynamoDB, S3              |
| Member 4 | Messaging — SQS, SNS, EventBridge           |
| Member 5 | Python Mocks, CI/CD, Tests                  |

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
| Terraform      | >= 1.6  | https://terraform.io                             |
| Python         | >= 3.10 | https://python.org                               |
| AWS CLI        | >= 2.x  | https://aws.amazon.com/cli/                      |
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

# 3. Pip install 
pip install boto3 flask pyjwt pytest requests
#If you wish to install a Python library that isn't in Homebrew, use a virtual environment:
python3 -m venv path/to/venv
source path/to/venv/bin/activate
python3 -m pip install xyz

# 4. Seed LocalStack with test data
cd ..
python scripts/seed_data.py

# 5. Terraform to create services
# chmod +x scripts/bootstrap.sh  --optional
./scripts/bootstrap.sh

# 6. Verify everything is running
# chmod +x scripts/health_check.sh -- optional 
./scripts/health_check.sh

#7. Run stimulated services
python demo.py

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

## 📚 Implementation Phases

This project follows a phased rollout of LocalStack Student Pro features (7 phases total).

| Phase | Focus | Status | Docs |
|-------|-------|--------|------|
| **0** | Foundation alignment | ✅ Complete | [Feature Matrix](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-0-foundation) |
| **1** | VPC & Networking | ✅ Complete | [Phase 1 Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-1-networking) |
| **2** | Cognito & Auth | 🔄 Next | [Phase 2 Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-2-cognito-auth) |
| **3** | Route 53 & Edge Services | 📋 Planned | [Phase 3 Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-3-edge-services) |
| **4A** | Application & RDS | 📋 Planned | [Phase 4A Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-4a-application--rds) |
| **4B** | ElastiCache & Glue | 📋 Planned | [Phase 4B Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-4b-elasticache--glue--mongo) |
| **5** | Security & IAM Enforcement | 📋 Planned | [Phase 5 Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-5-security--iam-enforcement) |
| **6** | Observability | 📋 Planned | [Phase 6 Plan](docs/LOCALSTACK_FEATURE_MATRIX.md#phase-6-reliability--observability) |

See [docs/LOCALSTACK_FEATURE_MATRIX.md](docs/LOCALSTACK_FEATURE_MATRIX.md) for the complete feature-by-feature support matrix with status labels and test scaffolding.

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

**LocalStack Tier: Student Pro (Ultimate) ⭐**

All services below are emulated locally. This project uses the Ultimate tier, which provides:
- Real containerized database engines (RDS PostgreSQL, ElastiCache Redis)
- Real IAM policy enforcement (`ENFORCE_IAM=1`)
- VPC endpoint transparent injection
- Lambda remote debugging and hot reloading
- Comprehensive service coverage

| Service          | Purpose                     | Status | Phase |
| ---------------- | --------------------------- | ------ | ----- |
| API Gateway      | REST API entry point        | ✅ Working | 0 |
| Lambda           | Business logic              | ✅ Working | 0 |
| DynamoDB         | User sessions, transactions | ✅ Working | 0 |
| RDS (PostgreSQL) | Core accounts data          | 🔄 Phase 4A | — |
| Route 53         | DNS and service discovery   | 🔄 Phase 3 | — |
| Cognito          | User authentication         | 🔄 Phase 2 | — |
| S3               | KYC documents, statements   | ✅ Working | 0 |
| SQS              | Async transaction queue     | ✅ Working | 0 |
| SNS              | Push notifications          | ✅ Working | 0 |
| IAM              | Roles & policies (enforced) | ✅ Working | 0 |
| CloudWatch       | Logs & metrics              | ✅ Working | 0 |
| ElastiCache      | Redis caching               | 🔄 Phase 4B | — |
| KMS              | Encryption key management   | ✅ Working | 0 |
| Secrets Manager  | Credential storage          | ✅ Working | 0 |
| ELBv2 (ALB/NLB)  | Load balancing              | 🔄 Phase 3 | — |
| WAFv2            | Web application firewall    | 🔄 Phase 5 | — |
| GuardDuty        | Threat detection            | 🔄 Phase 5 | — |
| CloudTrail       | Audit logging               | 🔄 Phase 6 | — |

**Full feature matrix:** See [docs/LOCALSTACK_FEATURE_MATRIX.md](docs/LOCALSTACK_FEATURE_MATRIX.md) for detailed status (fully-functional / partial / api-valid / skip).

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
# Run all tests
pytest

# Run only fully-functional feature tests (no known limitations)
pytest -k "test_s3 or test_dynamodb or test_snp"

# Run unit tests (no LocalStack required)
pytest tests/unit/ -v

# Run integration tests (requires LocalStack running)
pytest tests/integration/ -v

# View all available test markers
pytest --markers
```

---

## Phase 0 — Foundation Alignment (Complete ✅)

This phase prepared the infrastructure for progressive feature implementation.

### What Changed

1. **Expanded LocalStack Service Coverage**
   - Added 12 new services to docker-compose: `cognito-idp`, `route53`, `elbv2`, `wafv2`, `acm`, `kms`, `cloudtrail`, `glue`, `elasticache`, `backup`, `guardduty`
   - Enabled `ENFORCE_IAM=1` for real IAM policy validation (Ultimate tier feature)
   - All services now route through LocalStack endpoint (http://localhost:4566)

2. **Terraform Provider Updates**
   - Added endpoints for all new services in [terraform/providers.tf](terraform/providers.tf#L1)
   - Added `availability_zones` and `enable_iam_enforcement` variables for consistent multi-AZ wiring

3. **Feature Acceptance Matrix**
   - Created [docs/LOCALSTACK_FEATURE_MATRIX.md](docs/LOCALSTACK_FEATURE_MATRIX.md)
   - Maps all 50+ features to LocalStack support status (fully-functional / partial / api-valid / skip)
   - Shows which phase each feature is targeted in
   - Includes test stubs and implementation notes

4. **Test Scaffolding**
   - Added 60+ placeholder test stubs organized by feature group (VPC, Cognito, Route53, RDS, etc.)
   - Each test is labeled with its feature status and target phase
   - Tests use `pytest.skip()` with phase and feature details
   - Custom pytest markers for filtering (`@pytest.mark.phase_1`, `@pytest.mark.fully_functional`, etc.)

### How to Use

**View Feature Support Status:**
```bash
# See which features are ready now vs. future phases
cat docs/LOCALSTACK_FEATURE_MATRIX.md
```

**Run Only Currently-Implemented Tests:**
```bash
# Tests that pass now (Phase 0 + existing code)
pytest tests/integration/TestS3 tests/integration/TestDynamoDB tests/integration/TestSQS tests/integration/TestSNS -v
```

**See What's Coming:**
```bash
# View placeholder tests for Phase 1 (Networking)
grep -A 5 "class TestVPC" tests/integration/test_infrastructure.py

# View placeholder tests for Phase 2 (Cognito Auth)
grep -A 5 "class TestCognito" tests/integration/test_infrastructure.py
```

---

## Testing

```bash
# Run all tests
pytest

# Run unit tests (no LocalStack required)
pytest tests/unit/ -v

# Run integration tests (requires LocalStack running)
pytest tests/integration/ -v

# View all available test markers
pytest --markers
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
