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
