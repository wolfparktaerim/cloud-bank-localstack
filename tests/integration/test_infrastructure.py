"""
tests/integration/test_infrastructure.py
Integration tests that run against a live LocalStack instance.
Owner: Member 5

Run: pytest tests/integration/ -v
Requires: LocalStack running + terraform applied + seed data loaded
"""

import os
import json
import boto3
import pytest
import requests

ENDPOINT = os.getenv("LOCALSTACK_ENDPOINT", "http://localhost:4566")
REGION = "ap-southeast-1"
AUTH_URL = os.getenv("AUTH_MOCK_URL", "http://localhost:5001")
NOTIF_URL = os.getenv("NOTIFICATIONS_MOCK_URL", "http://localhost:5002")


def aws_client(service: str):
    return boto3.client(
        service,
        endpoint_url=ENDPOINT,
        region_name=REGION,
        aws_access_key_id="test",
        aws_secret_access_key="test",
    )


# ── S3 Tests ──────────────────────────────────
class TestS3:
    def test_kyc_bucket_exists(self):
        s3 = aws_client("s3")
        buckets = [b["Name"] for b in s3.list_buckets()["Buckets"]]
        assert any("kyc" in b for b in buckets), f"No KYC bucket found. Buckets: {buckets}"

    def test_statements_bucket_exists(self):
        s3 = aws_client("s3")
        buckets = [b["Name"] for b in s3.list_buckets()["Buckets"]]
        assert any("statement" in b for b in buckets), f"No statements bucket found."

    def test_can_upload_and_retrieve_document(self):
        s3 = aws_client("s3")
        bucket = "cloud-bank-kyc-documents-local"
        key = "test/integration-test-doc.json"
        body = json.dumps({"test": True, "user_id": "test-user"})

        s3.put_object(Bucket=bucket, Key=key, Body=body.encode())
        response = s3.get_object(Bucket=bucket, Key=key)
        retrieved = json.loads(response["Body"].read())

        assert retrieved["test"] is True
        assert retrieved["user_id"] == "test-user"

        # Cleanup
        s3.delete_object(Bucket=bucket, Key=key)


# ── DynamoDB Tests ────────────────────────────
class TestDynamoDB:
    def test_user_sessions_table_exists(self):
        dynamodb = aws_client("dynamodb")
        tables = dynamodb.list_tables()["TableNames"]
        assert "cloud-bank-user-sessions" in tables, f"Sessions table not found. Tables: {tables}"

    def test_transaction_ledger_table_exists(self):
        dynamodb = aws_client("dynamodb")
        tables = dynamodb.list_tables()["TableNames"]
        assert "cloud-bank-transaction-ledger" in tables

    def test_can_write_and_read_session(self):
        dynamodb = aws_client("dynamodb")
        table = "cloud-bank-user-sessions"

        dynamodb.put_item(
            TableName=table,
            Item={
                "session_id": {"S": "test-session-123"},
                "user_id":    {"S": "test-user-abc"},
                "email":      {"S": "test@example.com"},
                "expires_at": {"N": "9999999999"},
            }
        )

        response = dynamodb.get_item(
            TableName=table,
            Key={"session_id": {"S": "test-session-123"}}
        )
        item = response.get("Item")
        assert item is not None
        assert item["user_id"]["S"] == "test-user-abc"

        # Cleanup
        dynamodb.delete_item(
            TableName=table,
            Key={"session_id": {"S": "test-session-123"}}
        )


# ── SQS Tests ─────────────────────────────────
class TestSQS:
    def test_transaction_queue_exists(self):
        sqs = aws_client("sqs")
        response = sqs.list_queues(QueueNamePrefix="cloud-bank-transactions")
        assert len(response.get("QueueUrls", [])) > 0, "Transaction queue not found"

    def test_can_send_and_receive_message(self):
        sqs = aws_client("sqs")
        queue_url = sqs.get_queue_url(QueueName="cloud-bank-transactions-local")["QueueUrl"]

        test_msg = {"transaction_id": "test-txn-999", "amount": 25.00, "currency": "SGD"}
        sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(test_msg))

        messages = sqs.receive_message(
            QueueUrl=queue_url, MaxNumberOfMessages=1, WaitTimeSeconds=2
        ).get("Messages", [])

        assert len(messages) > 0, "No messages received from queue"
        body = json.loads(messages[0]["Body"])
        assert body["currency"] == "SGD"

        # Cleanup
        sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=messages[0]["ReceiptHandle"])


# ── SNS Tests ─────────────────────────────────
class TestSNS:
    def test_notification_topic_exists(self):
        sns = aws_client("sns")
        topics = [t["TopicArn"] for t in sns.list_topics()["Topics"]]
        assert any("notification" in t for t in topics), f"Notification topic not found. Topics: {topics}"


# ── Mock Auth Service Tests ───────────────────
class TestMockAuth:
    def test_auth_health(self):
        r = requests.get(f"{AUTH_URL}/health", timeout=5)
        assert r.status_code == 200
        assert r.json()["status"] == "ok"

    def test_register_and_login(self):
        # Register
        r = requests.post(f"{AUTH_URL}/register", json={
            "email": "integration-test@example.com",
            "password": "TestPass123!",
            "full_name": "Integration Test",
        }, timeout=5)
        assert r.status_code == 201, f"Register failed: {r.text}"
        user_id = r.json()["user_id"]
        assert user_id is not None

        # Login
        r = requests.post(f"{AUTH_URL}/login", json={
            "email": "integration-test@example.com",
            "password": "TestPass123!",
        }, timeout=5)
        assert r.status_code == 200, f"Login failed: {r.text}"
        data = r.json()
        assert "access_token" in data
        assert data["token_type"] == "Bearer"

        # Verify token
        r = requests.post(f"{AUTH_URL}/verify-token", json={
            "token": data["access_token"]
        }, timeout=5)
        assert r.status_code == 200
        assert r.json()["valid"] is True
        assert r.json()["user_id"] == user_id

    def test_login_wrong_password(self):
        r = requests.post(f"{AUTH_URL}/login", json={
            "email": "integration-test@example.com",
            "password": "WrongPassword!",
        }, timeout=5)
        assert r.status_code == 401


# ── Mock Notifications Tests ──────────────────
class TestMockNotifications:
    def test_notifications_health(self):
        r = requests.get(f"{NOTIF_URL}/health", timeout=5)
        assert r.status_code == 200

    def test_send_email(self):
        r = requests.post(f"{NOTIF_URL}/send-email", json={
            "to": "user@example.com",
            "subject": "Integration Test Email",
            "body": "This is a test email from the integration suite.",
        }, timeout=5)
        assert r.status_code == 200
        assert "message_id" in r.json()

    def test_send_otp(self):
        r = requests.post(f"{NOTIF_URL}/send-otp", json={
            "phone_number": "+6591234567",
        }, timeout=5)
        assert r.status_code == 200
        data = r.json()
        assert "otp" in data
        assert len(data["otp"]) == 6
        assert data["otp"].isdigit()


# ══════════════════════════════════════════════════════════════
# PHASE 1: VPC & NETWORKING TESTS
# ══════════════════════════════════════════════════════════════

class TestVPCFoundation:
    """
    Feature Status: 📋 API-valid (Phase 1)
    VPC and subnet creation, tagging, CIDR assignment — all persist in state.
    No traffic isolation or AZ-level enforcement (single container).
    Tests IaC structure and resource referencing.
    """

    def test_vpc_exists(self):
        """5.1.1/5.1.2: VPC creation and multi-AZ subnet layout."""
        pytest.skip("Phase 1: Implement networking module extensions")

    def test_multi_az_subnets_tagged(self):
        """5.1.1: Subnets tagged to ap-southeast-1a and ap-southeast-1b."""
        pytest.skip("Phase 1: Implement subnet AZ tagging")

    def test_public_subnet_nacl_rules(self):
        """5.1.3: Public subnet NACL with MapPublicIpOnLaunch."""
        pytest.skip("Phase 1: Implement public NACL rules")

    def test_private_subnet_nacl_rules(self):
        """5.1.4/5.1.5: Private subnet NACL rules persist."""
        pytest.skip("Phase 1: Implement private NACL rules")

    def test_security_group_crud(self):
        """5.1.6: Full security group management."""
        pytest.skip("Phase 1: Implement security group CRUD tests")

    def test_internet_gateway_attachment(self):
        """5.1.8: IGW attachment to VPC."""
        pytest.skip("Phase 1: Implement IGW attachment tests")

    def test_route_table_associations(self):
        """5.1.9: Route table CRUD and subnet associations."""
        pytest.skip("Phase 1: Implement route table tests")


class TestVPCEndpoints:
    """
    Feature Status: 🟡 Partial (Phase 1)
    VPC interface endpoints created and stored.
    Ultimate tier supports transparent DNS resolution.
    """

    def test_vpc_endpoint_creation(self):
        """5.1.7: VPC interface endpoint for private access."""
        pytest.skip("Phase 1: Implement VPC endpoint tests")


class TestNetworkForLambda:
    """
    Feature Status: 🟡 Partial (Phase 1)
    Lambda accepts VPC configuration (subnet IDs, security group IDs).
    Lambda is not traffic-isolated; NACL rules stored but not enforced.
    """

    def test_lambda_vpc_config(self):
        """5.1.4: Lambda function with VPC subnet and security group."""
        pytest.skip("Phase 1: Implement Lambda VPC wiring")


class TestNetworkForRDS:
    """
    Feature Status: 🟡 Partial (Phase 1)
    RDS accepts DB subnet group configuration.
    DB is not network-confined; SQL operations work normally.
    """

    def test_rds_db_subnet_group(self):
        """5.1.5: RDS DB subnet group for multi-AZ deployment."""
        pytest.skip("Phase 1: Implement RDS subnet group")


# ══════════════════════════════════════════════════════════════
# PHASE 2: COGNITO & AUTHENTICATION TESTS
# ══════════════════════════════════════════════════════════════

class TestCognitoUserPool:
    """
    Feature Status: ✅ Fully functional (Phase 2)
    User pool creation, sign-up, sign-in, JWT token issuance.
    Hosted UI available at /_aws/cognito-idp/
    """

    def test_user_pool_creation(self):
        """5.3.1: Create Cognito user pool."""
        pytest.skip("Phase 2: Implement Cognito user pool tests")

    def test_user_signup_and_login(self):
        """5.3.1: Sign-up and sign-in flow with JWT issuance."""
        pytest.skip("Phase 2: Implement Cognito auth flow")

    def test_app_client_oauth_flow(self):
        """5.3.3: Cognito app client OAuth2 authorization code flow."""
        pytest.skip("Phase 2: Implement OAuth2 flow tests")


class TestCognitoMFA:
    """
    Feature Status: 🟡 Partial (Phase 2)
    MFA configuration accepted at API level.
    TOTP challenges simulated; no real SMS/email delivery.
    """

    def test_mfa_config(self):
        """5.3.2: MFA configuration in user pool."""
        pytest.skip("Phase 2: Implement MFA config tests")

    def test_totp_challenge_flow(self):
        """5.3.2: Simulated TOTP challenge (no real delivery)."""
        pytest.skip("Phase 2: Implement TOTP simulation")


class TestAPIGatewayAuthorizer:
    """
    Feature Status: ✅ Fully functional (Phase 2)
    API Gateway validates Cognito-issued JWTs locally.
    End-to-end auth → API call flow fully testable.
    """

    def test_rest_api_cognito_authorizer(self):
        """5.3.4: REST API method with Cognito JWT authorizer."""
        pytest.skip("Phase 2: Implement JWT authorizer tests")

    def test_api_call_with_valid_jwt(self):
        """5.3.4: API call with valid Cognito JWT token."""
        pytest.skip("Phase 2: Implement JWT validation tests")

    def test_api_call_without_jwt_denied(self):
        """5.3.4: API call without JWT is denied."""
        pytest.skip("Phase 2: Implement JWT denial tests")


class TestCognitoAdvancedSecurity:
    """
    Feature Status: 📋 API-valid (Phase 2)
    Advanced security plan configurable at API level.
    Risk scoring, adaptive auth, compromised credentials not simulated.
    Documented as production-only behavior.
    """

    def test_advanced_security_plan_config(self):
        """5.3.5: Advanced security plan configuration."""
        pytest.skip("Phase 2: Implement advanced security config")


# ══════════════════════════════════════════════════════════════
# PHASE 3: EDGE SERVICES TESTS
# ══════════════════════════════════════════════════════════════

class TestRoute53:
    """
    Feature Status: ✅ Fully functional (Phase 3)
    Hosted zones, A/CNAME/alias records, health checks all work.
    LocalStack DNS server resolves custom domains locally.
    """

    def test_hosted_zone_creation(self):
        """5.2.1: Route 53 hosted zone creation."""
        pytest.skip("Phase 3: Implement Route 53 hosted zone tests")

    def test_dns_record_resolution(self):
        """5.2.1: Custom domain DNS resolution."""
        pytest.skip("Phase 3: Implement DNS resolution tests")


class TestApplicationLoadBalancer:
    """
    Feature Status: 🟡 Partial (Phase 3)
    ELBv2 CRUD fully supported; Lambda targets fully functional.
    ECS/EC2 targets are API-valid only.
    """

    def test_alb_creation(self):
        """5.2.3: ALB creation with listeners."""
        pytest.skip("Phase 3: Implement ALB tests")

    def test_alb_target_group_lambda(self):
        """5.2.3: ALB target group with Lambda targets."""
        pytest.skip("Phase 3: Implement ALB Lambda target tests")

    def test_alb_health_check(self):
        """5.2.3: ALB health check configuration."""
        pytest.skip("Phase 3: Implement ALB health check tests")


# ══════════════════════════════════════════════════════════════
# PHASE 4A: APPLICATION & RDS TESTS
# ══════════════════════════════════════════════════════════════

class TestRDSPostgreSQL:
    """
    Feature Status: 🟡 Partial (Phase 4A)
    Real PostgreSQL engine locally (Ultimate tier).
    Full SQL engine — schemas, migrations, transactions work.
    Aurora-specific APIs not emulated.
    """

    def test_rds_instance_creation(self):
        """5.6.1: RDS PostgreSQL instance creation."""
        pytest.skip("Phase 4A: Implement RDS provisioning tests")

    def test_rds_sql_operations(self):
        """5.6.1: Basic SQL operations (CREATE TABLE, INSERT, SELECT)."""
        pytest.skip("Phase 4A: Implement RDS SQL tests")

    def test_rds_connection_from_lambda(self):
        """5.6.1: Lambda → RDS connection and queries."""
        pytest.skip("Phase 4A: Implement Lambda-RDS integration tests")


class TestLambdaVPCExecution:
    """
    Feature Status: ✅ Fully functional (Phase 4A)
    Lambda executes in VPC; can reach RDS and other VPC resources.
    Event source mappings, layers, environment variables all work.
    """

    def test_lambda_with_reserved_concurrency(self):
        """5.5.1: Lambda reserved concurrency."""
        pytest.skip("Phase 4A: Implement Lambda concurrency tests")

    def test_lambda_layers(self):
        """5.5.1: Lambda layers for dependencies."""
        pytest.skip("Phase 4A: Implement Lambda layers tests")


# ══════════════════════════════════════════════════════════════
# PHASE 4B: ELASTICACHE & GLUE & MONGO TESTS
# ══════════════════════════════════════════════════════════════

class TestElastiCacheRedis:
    """
    Feature Status: 🟡 Partial (Phase 4B)
    Real Redis engine locally (Ultimate tier).
    Cluster mode config and replication group APIs accepted.
    Core Redis operations (GET/SET/pub-sub/sorted sets) work perfectly.
    """

    def test_elasticache_cluster_creation(self):
        """5.6.3: ElastiCache Redis cluster creation."""
        pytest.skip("Phase 4B: Implement ElastiCache provisioning tests")

    def test_redis_basic_operations(self):
        """5.6.3: Redis GET/SET/DEL operations."""
        pytest.skip("Phase 4B: Implement Redis operation tests")

    def test_redis_pubsub_from_lambda(self):
        """5.6.3: Lambda → Redis pub/sub."""
        pytest.skip("Phase 4B: Implement Redis pub/sub tests")


class TestGlue:
    """
    Feature Status: 🟡 Partial (Phase 4B)
    Glue v2 provider default (v4.13+).
    Databases, tables, crawlers, job definitions supported.
    ETL job execution functional (Ultimate tier).
    """

    def test_glue_database_creation(self):
        """5.6.5: AWS Glue database creation."""
        pytest.skip("Phase 4B: Implement Glue database tests")

    def test_glue_table_definition(self):
        """5.6.5: Glue table definition with schema."""
        pytest.skip("Phase 4B: Implement Glue table tests")

    def test_glue_crawler_job(self):
        """5.6.5: Glue crawler job for data discovery."""
        pytest.skip("Phase 4B: Implement Glue crawler tests")


class TestMongoDBSidecar:
    """
    Feature Status: 🟡 Partial (Phase 4B)
    MongoDB not an AWS service — no LocalStack emulation.
    Separate mongo:7 container in Docker Compose (non-AWS sidecar).
    App connects to it independently.
    """

    def test_mongodb_connection(self):
        """5.6.4: MongoDB sidecar connection (non-AWS)."""
        pytest.skip("Phase 4B: Implement MongoDB connection tests")

    def test_mongodb_crud_operations(self):
        """5.6.4: MongoDB CRUD operations."""
        pytest.skip("Phase 4B: Implement MongoDB CRUD tests")


# ══════════════════════════════════════════════════════════════
# PHASE 5: SECURITY & IAM ENFORCEMENT TESTS
# ══════════════════════════════════════════════════════════════

class TestIAMEnforcement:
    """
    Feature Status: ✅ Fully functional (Phase 5)
    ENFORCE_IAM=1 enables real IAM policy evaluation.
    Explainable IAM shows why calls are allowed/denied.
    IAM Policy Stream gives live audit view.
    """

    def test_iam_policy_enforcement_enabled(self):
        """5.7.7: ENFORCE_IAM=1 active in LocalStack config."""
        pytest.skip("Phase 5: Implement IAM enforcement verification")

    def test_lambda_execution_role_permissions(self):
        """5.7.7: Lambda can execute only with allowed permissions."""
        pytest.skip("Phase 5: Implement Lambda permission tests")

    def test_explainable_iam_deny_reason(self):
        """5.7.7: Explainable IAM shows specific deny reason."""
        pytest.skip("Phase 5: Implement Explainable IAM tests")


class TestKMS:
    """
    Feature Status: ✅ Fully functional (Phase 5)
    Key creation, encrypt/decrypt, policies, grants, rotation.
    Used internally for S3 SSE-KMS, Secrets Manager, DynamoDB encryption.
    """

    def test_kms_key_creation(self):
        """5.7.5: KMS symmetric key creation."""
        pytest.skip("Phase 5: Implement KMS key tests")

    def test_kms_encrypt_decrypt(self):
        """5.7.5: KMS encrypt and decrypt operations."""
        pytest.skip("Phase 5: Implement KMS crypto tests")

    def test_s3_sse_kms_encryption(self):
        """5.7.5: S3 objects encrypted with KMS."""
        pytest.skip("Phase 5: Implement S3 KMS encryption tests")


class TestSecretsManager:
    """
    Feature Status: ✅ Fully functional (Phase 5)
    Full CRUD, versioning, resource policies, rotation.
    Wire up Lambda rotation functions locally.
    Use for all credentials, DB passwords, API keys.
    """

    def test_secret_creation_and_retrieval(self):
        """5.7.6: Secrets Manager create/retrieve."""
        pytest.skip("Phase 5: Implement Secrets Manager tests")

    def test_secret_rotation_lambda(self):
        """5.7.6: Lambda rotation function for secrets."""
        pytest.skip("Phase 5: Implement secret rotation tests")

    def test_rds_credentials_in_secrets(self):
        """5.7.6: RDS master credentials stored in Secrets Manager."""
        pytest.skip("Phase 5: Implement RDS secret integration")


class TestWAFv2:
    """
    Feature Status: 📋 API-valid (Phase 5)
    Web ACLs, rule groups, IP sets, managed rule references all creatable.
    Association with API Gateway and ALB accepted.
    Rules not enforced on traffic — test on staging.
    """

    def test_wafv2_web_acl_creation(self):
        """5.7.2: WAFv2 Web ACL creation."""
        pytest.skip("Phase 5: Implement WAFv2 ACL tests")

    def test_wafv2_api_gateway_association(self):
        """5.7.2: WAFv2 association with API Gateway."""
        pytest.skip("Phase 5: Implement WAFv2 API GW binding")


class TestGuardDuty:
    """
    Feature Status: 📋 API-valid (Phase 5)
    Detector CRUD, finding types, member accounts all API-valid.
    No actual threat detection.
    Inject mock findings via API for testing response workflows.
    """

    def test_guardduty_detector_creation(self):
        """5.7.1: GuardDuty detector creation."""
        pytest.skip("Phase 5: Implement GuardDuty detector tests")

    def test_guardduty_mock_finding_injection(self):
        """5.7.1: Inject mock findings via API."""
        pytest.skip("Phase 5: Implement mock finding injection")


class TestACM:
    """
    Feature Status: 🟡 Partial (Phase 5)
    Certificate import and request APIs supported.
    Ultimate tier HTTPS/TLS support lets you use custom TLS certificates.
    """

    def test_acm_certificate_import(self):
        """5.7.4: ACM certificate import."""
        pytest.skip("Phase 5: Implement ACM certificate import")


# ══════════════════════════════════════════════════════════════
# PHASE 6: OBSERVABILITY TESTS
# ══════════════════════════════════════════════════════════════

class TestCloudWatch:
    """
    Feature Status: 🟡 Partial (Phase 6)
    Log groups, log streams, metric filters, alarms supported.
    Lambda and API Gateway automatically emit logs.
    Alarm state transitions work; alarm actions need manual wiring.
    """

    def test_cloudwatch_log_group_creation(self):
        """5.8.1: CloudWatch log group creation."""
        pytest.skip("Phase 6: Implement CloudWatch log group tests")

    def test_lambda_logs_emitted(self):
        """5.8.1: Lambda function logs automatically emitted."""
        pytest.skip("Phase 6: Implement Lambda logging tests")

    def test_cloudwatch_metric_alarm(self):
        """5.8.1: CloudWatch alarm on Lambda error metric."""
        pytest.skip("Phase 6: Implement CloudWatch alarm tests")


class TestCloudTrail:
    """
    Feature Status: 🟡 Partial (Phase 6)
    Trail CRUD and event lookup APIs supported.
    Coverage not comprehensive across all services.
    Good for testing audit-log processing code.
    """

    def test_cloudtrail_trail_creation(self):
        """5.8.4: CloudTrail trail creation."""
        pytest.skip("Phase 6: Implement CloudTrail trail tests")

    def test_cloudtrail_event_lookup(self):
        """5.8.4: CloudTrail event lookup for audited operations."""
        pytest.skip("Phase 6: Implement CloudTrail event lookup")


class TestBackup:
    """
    Feature Status: 🟡 Partial (Phase 6)
    Backup plans, vaults, backup jobs APIs all functional.
    Job lifecycle (created → running → completed) simulated.
    No actual snapshots — test backup scheduling logic.
    """

    def test_backup_plan_creation(self):
        """5.8.5: AWS Backup plan creation."""
        pytest.skip("Phase 6: Implement Backup plan tests")

    def test_backup_job_lifecycle(self):
        """5.8.5: Backup job state transitions."""
        pytest.skip("Phase 6: Implement Backup job lifecycle tests")


# ══════════════════════════════════════════════════════════════
# PYTEST MARKERS FOR FILTER-BY-STATUS
# ══════════════════════════════════════════════════════════════

def pytest_configure(config):
    """Register custom markers for feature status filtering."""
    config.addinivalue_line(
        "markers", "fully_functional: tests for features with complete end-to-end support"
    )
    config.addinivalue_line(
        "markers", "partial: tests for features with known limitations"
    )
    config.addinivalue_line(
        "markers", "api_valid: tests for IaC structure and state persistence only"
    )
    config.addinivalue_line(
        "markers", "skip_feature: tests for unsupported features (production-only)"
    )
    config.addinivalue_line(
        "markers", "phase_0: Phase 0 tests (foundation alignment)"
    )
    config.addinivalue_line(
        "markers", "phase_1: Phase 1 tests (networking)"
    )
    config.addinivalue_line(
        "markers", "phase_2: Phase 2 tests (cognito auth)"
    )
    config.addinivalue_line(
        "markers", "phase_3: Phase 3 tests (edge services)"
    )
    config.addinivalue_line(
        "markers", "phase_4a: Phase 4A tests (app + RDS)"
    )
    config.addinivalue_line(
        "markers", "phase_4b: Phase 4B tests (elasticache + glue)"
    )
    config.addinivalue_line(
        "markers", "phase_5: Phase 5 tests (security + IAM)"
    )
    config.addinivalue_line(
        "markers", "phase_6: Phase 6 tests (observability)"
    )
