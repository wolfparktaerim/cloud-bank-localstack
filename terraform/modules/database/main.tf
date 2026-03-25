# ─────────────────────────────────────────────
# Module: database
# Owner: Member 3
# Creates: DynamoDB tables for all banking data
#
# Note: RDS/PostgreSQL requires LocalStack Pro.
#       In community edition we use DynamoDB for
#       all storage. Architecture doc explains the
#       trade-off and how real deployment uses RDS.
# ─────────────────────────────────────────────

# ── DynamoDB: Core Accounts ───────────────────
resource "aws_dynamodb_table" "accounts" {
  name         = "${var.project_name}-accounts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "account_id"

  attribute {
    name = "account_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-accounts"
    Purpose = "Core bank account records (replaces RDS in local sim)"
  })
}

# ── DynamoDB: User Sessions ───────────────────
resource "aws_dynamodb_table" "user_sessions" {
  name         = "${var.project_name}-user-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "user_id"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-user-sessions"
    Purpose = "JWT session tokens with TTL auto-expiry"
  })
}

# ── DynamoDB: Transaction Ledger ──────────────
resource "aws_dynamodb_table" "transaction_ledger" {
  name         = "${var.project_name}-transaction-ledger"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "account_id"
  range_key    = "transaction_id"

  attribute {
    name = "account_id"
    type = "S"
  }

  attribute {
    name = "transaction_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "TransactionDateIndex"
    hash_key        = "account_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-transaction-ledger"
    Purpose = "Immutable transaction history"
  })
}

# ── DynamoDB: OTP Store ───────────────────────
resource "aws_dynamodb_table" "otp_store" {
  name         = "${var.project_name}-otp-store"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "phone_number"

  attribute {
    name = "phone_number"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-otp-store"
    Purpose = "OTP codes with automatic TTL expiry"
  })
}

# ─────────────────────────────────────────────────────────────
# PHASE 1: RDS DB Subnet Group (prepared for Phase 4A)
# ─────────────────────────────────────────────────────────────
# Phase 4A will use this subnet group for RDS instance deployment.
# This is set up in Phase 1 to establish the dependency chain:
# Phase 1 (networking) → Phase 4A (RDS instance creation)

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = merge(var.tags, {
    Name    = "${var.project_name}-db-subnet-group"
    Purpose = "Multi-AZ RDS subnet group for PostgreSQL (Phase 4A)"
  })
}

resource "aws_db_instance" "postgres" {
  count = var.enable_rds_instance ? 1 : 0

  identifier             = "${var.project_name}-postgres"
  allocated_storage      = 20
  max_allocated_storage  = 100
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]

  publicly_accessible    = false
  multi_az               = false
  storage_encrypted      = false
  skip_final_snapshot    = true
  deletion_protection    = false
  backup_retention_period = 0

  tags = merge(var.tags, {
    Name    = "${var.project_name}-postgres"
    Purpose = "Core banking relational datastore (Phase 4A)"
  })
}
