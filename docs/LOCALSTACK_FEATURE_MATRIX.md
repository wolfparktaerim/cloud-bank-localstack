# LocalStack Feature Implementation Matrix

> Comprehensive feature support tracking for NeoBank SG on LocalStack Student Pro (Ultimate tier)  
> Status: Updated for Phase 2 (Cognito & Auth)  
> Last Updated: March 2026

Legend:
- ✅ **Fully functional** — Full end-to-end behavior implemented and tested
- 🟡 **Partial** — Works with known limitations; documented in test comments
- 📋 **API-valid** — Resource CRUD and state persistence works; traffic enforcement skipped
- ⛔ **Skip** — Not supported; production alternative documented
- 🔄 **In Progress** — Targeted in current/next phase

---

## 5.1 — VPC & Network Infrastructure

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.1.1 Multi-AZ Deployment | 📋 | 1 | `test_vpc_multi_az_subnets` | Subnets tagged to multiple AZs; no physical isolation (single container) |
| 5.1.2 AZ-Level Design | 📋 | 1 | `test_az_subnet_cross_reference` | Subnet-per-AZ layout fully queryable and referenceable |
| 5.1.3 Public Subnet + NACL | 📋 | 1 | `test_public_subnet_nacl` | MapPublicIpOnLaunch, CIDR blocks, IGW, NACL rules persist but not enforced |
| 5.1.4 Private Subnet – Lambda + NACL | 🟡 | 1 | `test_lambda_private_subnet_config` | Lambda accepts VPC config; not isolated on traffic; NACL rules stored |
| 5.1.5 Private Subnet – DB + NACL | 🟡 | 1 | `test_rds_private_subnet_group` | RDS DB subnet group accepted; DB not confined; SQL works normally |
| 5.1.6 Security Groups | 📋 | 1 | `test_security_group_crud` | Full CRUD, rules persistent, queryable; not enforced as firewall |
| 5.1.7 VPC Interface Endpoint | 🟡 | 1 | `test_vpc_endpoint_creation` | Endpoints created; transparent injection on Ultimate tier; DNS resolution tested |
| 5.1.8 Internet Gateway | 📋 | 1 | `test_internet_gateway_attachment` | IGW resource creates, attaches, stored in state; no real internet gating |
| 5.1.9 Route Tables | 📋 | 1 | `test_route_table_associations` | Route CRUD, associations, routes all queryable; not applied to container traffic |

---

## 5.2 — Network & Traffic Management

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.2.1 Route 53 | ✅ | 3 | `test_route53_hosted_zone` | Fully functional; DNS resolution works locally; multi-VPC zones supported |
| 5.2.2 API Gateway (REST + HTTP) | ✅ | 0/3 | `test_apigateway_rest_api` | Both REST and HTTP APIs fully functional with authorizers |
| 5.2.3 ALB/NLB | 🟡 | 3 | `test_alb_listener` | CRUD fully supported; Lambda targets functional; ECS/EC2 targets API-valid only |

---

## 5.3 — Authentication & Authorization

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.3.1 Cognito User Pools | ✅ | 2 | `test_user_pool_creation`, `test_user_signup_and_login` | Full CRUD, sign-up, sign-in, JWT issuance; hosted UI at `/_aws/cognito-idp/` |
| 5.3.2 MFA | 🟡 | 2 | `test_cognito_mfa` | Config accepted; TOTP challenges simulated; no real SMS/email delivery |
| 5.3.3 App Client / Hosted UI | ✅ | 2 | `test_app_client_oauth_flow` | OAuth2 auth code flow settings, app client callbacks/logout URLs, hosted UI domain |
| 5.3.4 JWT Authorizer (API Gateway) | ✅ | 2 | `test_rest_api_cognito_authorizer`, `test_api_call_with_valid_jwt`, `test_api_call_without_jwt_denied` | End-to-end JWT validation via Cognito-issued tokens and API Gateway method protection |
| 5.3.5 Advanced Security (WAF, adaptive auth) | 📋 | 5 | `test_cognito_advanced_security` | Risk scoring, adaptive auth config accepted; not simulated |

---

## 5.4 — Presentation Layer

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.4.1 AWS Amplify | 🟡 | 4B | `test_amplify_sdk` | SDK fully works locally; hosting CI/CD not emulated; serve frontend separately |

---

## 5.5 — Application Tier

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.5.1 Lambda (all runtimes) | ✅ | 4A | `test_lambda_execution` | Full multi-runtime support; layers, env vars, VPC config, event source mappings |

---

## 5.6 — Storage Tier

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.6.1 RDS (Aurora / PostgreSQL) | 🟡 | 4A | `test_rds_instance` | Real PostgreSQL engine locally; Aurora-specific APIs not emulated |
| 5.6.2 DynamoDB | ✅ | 0 | `test_dynamodb_tables` | GSIs, LSIs, Streams, TTL, transactions, PartiQL all supported |
| 5.6.3 ElastiCache (Redis) | 🟡 | 4B | `test_elasticache_redis` | Real Redis engine locally (Ultimate); cluster mode config, replication group APIs accepted |
| 5.6.4 MongoDB | 🟡 | 4B | `test_mongodb_sidecar` | Non-AWS service; separate mongo:7 Docker Compose container; not LocalStack emulated |
| 5.6.5 AWS Glue (ETL / catalog) | 🟡 | 4B | `test_glue_database` | Databases, tables, crawlers, job definitions supported; ETL job execution functional |

---

## 5.7 — Security

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.7.1 GuardDuty | 📋 | 5 | `test_guardduty_detector` | Detector CRUD, finding types API-valid; inject mock findings for testing |
| 5.7.2 WAF (WAFv2) | 📋 | 5 | `test_wafv2_web_acl` | Web ACLs, rule groups, IP sets creatable; rules not enforced; test on staging |
| 5.7.3 Shield | ⛔ | — | — | Not supported; production-only control; skip locally |
| 5.7.4 ACM (Certificates) | 🟡 | 5 | `test_acm_certificate` | Import/request APIs supported; Ultimate tier HTTPS/TLS support available |
| 5.7.5 KMS | ✅ | 5 | `test_kms_key_operations` | Full key CRUD, encrypt/decrypt, policies, grants, rotation, multi-region keys |
| 5.7.6 Secrets Manager | ✅ | 5 | `test_secrets_manager_crud` | Full CRUD, versioning, rotation wiring; use for all local credentials |
| 5.7.7 IAM Roles & Policies | ✅ | 5 | `test_iam_enforcement` | Full CRUD; ENFORCE_IAM=1 enables real policy enforcement (Ultimate) |

---

## 5.8 — Reliability & Observability

| Feature | Status | Phase | Test | Notes |
|---------|--------|-------|------|-------|
| 5.8.1 CloudWatch (Logs + Metrics + Alarms) | 🟡 | 6 | `test_cloudwatch_alarm` | Log groups, streams, metric filters, alarms supported; Lambda/API GW emit logs |
| 5.8.2 X-Ray | 🟡 | 6 | `test_xray_segments` | API supported; trace segment submission works; service map generation limited; low ROI |
| 5.8.3 SNS | ✅ | 0 | `test_sns_topic_subscription` | Topics, subscriptions, filtering, delivery policies all work; fan-out patterns testable |
| 5.8.4 CloudTrail | 🟡 | 6 | `test_cloudtrail_event_logging` | Trail CRUD and event lookup supported; coverage partial; good for audit processing |
| 5.8.5 Backup | 🟡 | 6 | `test_backup_plan` | Plans, vaults, job lifecycle simulated; job definitions work; not actual snapshots |

---

## Implementation Notes by Phase

### Phase 0 (Foundation)
- ✅ Expanded LocalStack service list in docker-compose
- ✅ Added ENFORCE_IAM=1 for real policy validation
- ✅ Normalized AZ variables
- ✅ This matrix created with placeholder test stubs

### Phase 1 (Networking) ✅ COMPLETE
- ✅ Route tables and route associations (public → IGW, private → internal)
- ✅ NACLs for public (http/https/ssh/ephemeral) and private (internal VPC + ephemeral)
- ✅ DB subnet group for RDS multi-AZ (Phase 4A dependency)
- ✅ Lambda VPC wiring (subnet_ids + security_group_ids)
- ✅ Output exports for AZ cross-referencing and subnet group name
- ✅ Integration tests implemented and passing for VPC foundation
- ⚠️ VPC endpoints scaffolded (commented) pending Phase 1+ expansion
- Route tables, NACLs, subnet associations
- DB subnet groups and RDS SG associations
- VPC endpoint placeholders
- Lambda VPC wiring

### Phase 2 (Cognito Auth) ✅ COMPLETE
- ✅ Cognito user pool, app client, and hosted UI domain provisioned
- ✅ Sign-up, admin-confirm, and sign-in JWT issuance flow implemented in tests
- ✅ API Gateway Cognito authorizer wired to protected methods (`/accounts`, `/transactions`, `/kyc`)
- ✅ API authorization behavior tests added (valid JWT accepted, missing JWT denied)
- ✅ MFA configuration path validated at API level (simulated)

### Phase 3 (Edge Services) ✅ COMPLETE
- ✅ Route53 hosted zone and CNAME record for API domain
- ✅ Application Load Balancer with HTTP listener in public subnets
- ✅ Lambda target group attachment and invoke permissions
- ✅ Integration tests implemented for Route53 and ALB CRUD/attachment flow

### Phase 4A (Application + RDS)
- Real RDS PostgreSQL instance
- Lambda handler improvements
- Secrets Manager wiring for credentials

### Phase 4B (ElastiCache + Glue + Mongo)
- ElastiCache Redis with real command testing
- Glue databases, crawlers, jobs
- MongoDB sidecar container

### Phase 5 (Security + IAM Enforcement)
- ENFORCE_IAM=1 validation workflows
- Explainable IAM for troubleshooting
- WAFv2, GuardDuty, KMS, ACM integration
- Shield documented as skip

### Phase 6 (Reliability)
- CloudWatch logs, metrics, alarms
- SNS alarm actions
- CloudTrail audit workflows
- Backup job lifecycle

---

## LocalStack Tier Capabilities

### Free Tier (Reference)
- Basic services (S3, DynamoDB, Lambda, SQS, SNS, API Gateway)
- No RDS, no Cognito, no KMS, no containerized engines

### Pro Tier (Reference)
- RDS with real PostgreSQL/MySQL engines
- ElastiCache with real Redis
- Additional services
- IAM basic support

### **Ultimate Tier (Our Setup) ⭐**
- All Pro features
- Remote debugging for Lambda
- Hot reloading
- ENFORCE_IAM=1 for real policy evaluation
- Explainable IAM
- TransparentVPC endpoint injection
- Comprehensive service coverage
- **This project uses Ultimate — leverage these features fully**

---

## Testing Strategy

All tests should be labeled with their current status:

```python
# Example test format
class TestNetworking:
    @pytest.mark.feature_status("api-valid")  # Use marker for filtering
    def test_vpc_multi_az_subnets(self):
        """
        Status: API-valid (Phase 1)
        Subnets can be tagged to multiple AZs in LocalStack.
        No physical isolation (single container environment).
        Tests IaC structure, not traffic isolation.
        """
```

This allows running only fully-functional tests (`pytest -m fully_functional`), or viewing known-limitation tests (`pytest -m partial`).

---

## Quick Reference: What Works End-to-End Today

✅ DynamoDB workflows (GSI, TTL, Streams)
✅ Lambda execution and event source mappings
✅ API Gateway REST APIs
✅ S3 with versioning and encryption
✅ SQS/SNS messaging
✅ IAM roles and policies (with ENFORCE_IAM=1)
✅ Secrets Manager

---

## Quick Reference: What Requires Phase Implementation

✅ Cognito
✅ Route 53
✅ ALB/NLB
🔄 RDS (Phase 4A)
🔄 ElastiCache (Phase 4B)
🔄 WAFv2, KMS, full security stack (Phase 5)
🔄 CloudWatch, CloudTrail, Backup (Phase 6)

---

## Resources

- [LocalStack Capabilities Coverage](https://docs.localstack.cloud/user-guide/aws-service-coverage/)
- [LocalStack Pro/Ultimate Differences](https://docs.localstack.cloud/getting-started/installation/#editions)
- [LocalStack IAM Enforcement](https://docs.localstack.cloud/user-guide/iam/)
