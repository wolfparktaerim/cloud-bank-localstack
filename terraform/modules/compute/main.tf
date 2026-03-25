# ─────────────────────────────────────────────
# Module: compute
# Owner: Member 2
# Creates: Lambda functions for each service
# Note: CloudWatch log groups omitted — logs service
#       not available in LocalStack community edition.
#       Lambdas still write logs internally.
# ─────────────────────────────────────────────

terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

locals {
  lambdas = {
    accounts      = { handler = "handler.lambda_handler", description = "Account management" }
    transactions  = { handler = "handler.lambda_handler", description = "Transaction processing" }
    kyc           = { handler = "handler.lambda_handler", description = "KYC verification" }
    auth          = { handler = "handler.lambda_handler", description = "Authentication (wraps mock)" }
    notifications = { handler = "handler.lambda_handler", description = "Notification dispatch" }
  }
}

# ── Write a placeholder handler.py then zip it ──
resource "local_file" "placeholder_handler" {
  content  = "def lambda_handler(event, context):\n    return {'statusCode': 200, 'body': 'placeholder'}\n"
  filename = "${path.module}/builds/handler.py"
}

data "archive_file" "placeholder_zip" {
  type        = "zip"
  source_file = local_file.placeholder_handler.filename
  output_path = "${path.module}/builds/placeholder.zip"
  depends_on  = [local_file.placeholder_handler]
}

# ── Lambda functions ──────────────────────────
resource "aws_lambda_function" "service" {
  for_each = local.lambdas

  function_name    = "${var.project_name}-${each.key}"
  description      = each.value.description
  role             = var.lambda_role_arn
  runtime          = var.lambda_runtime
  handler          = each.value.handler
  timeout          = 30
  memory_size      = 256

  filename         = data.archive_file.placeholder_zip.output_path
  source_code_hash = data.archive_file.placeholder_zip.output_base64sha256

  environment {
    variables = {
      ENVIRONMENT        = var.environment
      PROJECT_NAME       = var.project_name
      TRANSACTION_QUEUE  = var.transaction_queue
      NOTIFICATION_TOPIC = var.notification_topic
      DB_ENDPOINT        = var.db_endpoint
      AUTH_MOCK_URL      = "http://localhost:5001"
    }
  }

  # Phase 1: VPC Configuration for Lambda
  # Allows Lambda to execute within the VPC and access RDS/ElastiCache
  vpc_config {
    subnet_ids         = var.lambda_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${each.key}"
    Service = each.key
  })

  lifecycle {
    # LocalStack may not preserve reserved concurrency semantics consistently.
    ignore_changes = [reserved_concurrent_executions]
  }

  depends_on = [data.archive_file.placeholder_zip]
}

# ── SQS trigger for transactions Lambda ───────
resource "aws_lambda_event_source_mapping" "transaction_queue_trigger" {
  event_source_arn = var.transaction_queue
  function_name    = aws_lambda_function.service["transactions"].arn
  batch_size       = 10
  enabled          = true
}
