# ADR-001: Use LocalStack for AWS Simulation

**Date:** 2025-01-01  
**Status:** Accepted  
**Owners:** All team members

---

## Context

We need to develop and test cloud infrastructure for a Singapore digital bank without incurring real AWS costs during development, and without requiring real AWS accounts for every team member.

## Decision

We will use **LocalStack** (free tier) to simulate AWS services locally, combined with **Python Flask mock services** for AWS features not covered by the free tier (Cognito, SES, Rekognition).

## Consequences

**Positive:**
- Zero AWS cost during development
- Every team member can run the full stack locally
- CI/CD can run full integration tests without cloud access
- Faster iteration — no network latency to real AWS

**Negative:**
- Some LocalStack behaviours differ slightly from real AWS
- Cognito, WAF, Rekognition require custom mocks
- Must maintain two configurations (LocalStack + prod-sim)

---

# ADR-002: Terraform Module-per-Service Structure

**Date:** 2025-01-01  
**Status:** Accepted

## Decision

Each AWS service category (networking, compute, database, etc.) gets its own Terraform module owned by a specific team member.

## Consequences

- Minimises merge conflicts (each member works in their own folder)
- Clear ownership and accountability
- Modules can be tested independently
- Slightly more boilerplate (variables/outputs per module)

---

# ADR-003: DynamoDB for Sessions and Transactions, RDS for Accounts

**Date:** 2025-01-01  
**Status:** Accepted

## Decision

- **DynamoDB** for user sessions (TTL auto-expiry), OTP codes, and transaction ledger (high write throughput)
- **RDS PostgreSQL** for core account data (ACID compliance required for balances)

## Consequences

- Sessions/OTPs auto-expire via DynamoDB TTL — no cleanup job needed
- Account balances benefit from PostgreSQL ACID transactions
- Dual-database adds some complexity but maps to real banking architecture
