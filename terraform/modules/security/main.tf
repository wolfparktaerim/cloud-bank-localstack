# ─────────────────────────────────────────────
# Module: security
# Owner: Member 1
# Layer: 1 — no dependencies
# Creates: Secrets Manager secrets, Network ACLs
#
# KMS NOTE:
#   aws_kms_key is NOT supported in LocalStack
#   community edition — it always returns
#   UnrecognizedClientException regardless of config.
#
#   KMS is simulated via a local placeholder:
#   - scripts/mock_kms.py creates a fake key entry
#     in a local JSON file (localstack-data/kms.json)
#   - The key ARN placeholder is output from this module
#   - All resources that reference kms_key_id use
#     the placeholder ARN so Terraform accepts the config
#   - In real AWS: replace placeholder with actual
#     aws_kms_key resource and remove mock script
# ─────────────────────────────────────────────

# ── Secrets Manager ───────────────────────────
# Stores all credentials — Lambdas read these at runtime
# instead of having secrets in environment variables

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-db-password"
  description             = "RDS PostgreSQL master password"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}-jwt-secret"
  description             = "JWT signing secret for auth service"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret
}

resource "aws_secretsmanager_secret" "kyc_api_key" {
  name                    = "${var.project_name}-kyc-api-key"
  description             = "API key for KYC provider (mock: localhost:5003)"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "kyc_api_key" {
  secret_id     = aws_secretsmanager_secret.kyc_api_key.id
  secret_string = var.kyc_api_key
}

resource "aws_secretsmanager_secret" "abs_api_key" {
  name                    = "${var.project_name}-abs-api-key"
  description             = "API key for ABS interbank gateway (mock: localhost:5006)"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "abs_api_key" {
  secret_id     = aws_secretsmanager_secret.abs_api_key.id
  secret_string = var.abs_api_key
}

# ── Network ACLs — Default Deny ───────────────
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.0.0/16"
    from_port  = 0
    to_port    = 65535
  }
  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.0.0/16"
    from_port  = 0
    to_port    = 65535
  }
  egress {
    rule_no    = 300
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(var.tags, { Name = "${var.project_name}-private-nacl" })
}

resource "aws_network_acl" "public" {
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    rule_no    = 300
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 65535
  }

  tags = merge(var.tags, { Name = "${var.project_name}-public-nacl" })
}
