# ─────────────────────────────────────────────
# Module: database
# Owner: Member 3
# Creates: RDS PostgreSQL, DynamoDB tables
# ─────────────────────────────────────────────

# ── RDS PostgreSQL (core banking accounts) ───
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "15.3"
  instance_class    = var.db_instance_class
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name = aws_db_subnet_group.main.name
  skip_final_snapshot  = true   # LocalStack — skip snapshot on destroy

  tags = merge(var.tags, {
    Name    = "${var.project_name}-postgres"
    Purpose = "Core banking accounts and transactions"
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
    Purpose = "JWT session tokens and refresh tokens"
  })
}

# ── DynamoDB: Transaction Ledger ─────────────
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

# ── DynamoDB: OTP / 2FA ───────────────────────
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
