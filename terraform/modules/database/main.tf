# ─────────────────────────────────────────────
# Module: database
# Owner: Member 3
# Creates: DynamoDB tables for all banking data
#
# Note: RDS/PostgreSQL in this project targets
#       LocalStack Pro. DynamoDB resources are
#       retained for session/ledger/OTP flows and
#       backwards compatibility in existing demos.
# ─────────────────────────────────────────────

# ── RDS PostgreSQL ───────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.project_name}-postgres-${var.environment}"
  engine                  = "postgres"
  engine_version          = "15"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [var.rds_security_group_id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  deletion_protection     = false

  tags = merge(var.tags, {
    Name    = "${var.project_name}-postgres-${var.environment}"
    Purpose = "Core account database"
  })
}

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
