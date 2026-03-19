# ─────────────────────────────────────────────
# Module: compute
# Owner: Member 2
# Creates: Lambda functions for each service
# ─────────────────────────────────────────────

locals {
  # Each Lambda maps to a service folder in services/
  lambdas = {
    accounts     = { handler = "handler.lambda_handler", description = "Account management" }
    transactions = { handler = "handler.lambda_handler", description = "Transaction processing" }
    kyc          = { handler = "handler.lambda_handler", description = "KYC verification" }
    auth         = { handler = "handler.lambda_handler", description = "Authentication (wraps mock)" }
    notifications = { handler = "handler.lambda_handler", description = "Notification dispatch" }
  }
}

# ── Zip placeholder for each Lambda ──────────
# In real workflow: CI/CD zips the services/ folder
data "archive_file" "lambda_placeholder" {
  for_each    = local.lambdas
  type        = "zip"
  output_path = "${path.module}/builds/${each.key}.zip"

  source {
    content  = "def lambda_handler(event, context): return {'statusCode': 200, 'body': '${each.key} placeholder'}"
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "service" {
  for_each = local.lambdas

  function_name = "${var.project_name}-${each.key}"
  description   = each.value.description
  role          = var.lambda_role_arn
  runtime       = var.lambda_runtime
  handler       = each.value.handler
  timeout       = 30
  memory_size   = 256

  filename         = data.archive_file.lambda_placeholder[each.key].output_path
  source_code_hash = data.archive_file.lambda_placeholder[each.key].output_base64sha256

  environment {
    variables = {
      ENVIRONMENT          = var.environment
      PROJECT_NAME         = var.project_name
      TRANSACTION_QUEUE    = var.transaction_queue
      NOTIFICATION_TOPIC   = var.notification_topic
      DB_ENDPOINT          = var.db_endpoint
      # Auth mock URL — points to Python mock service in docker-compose
      AUTH_MOCK_URL        = "http://mock-auth:5001"
    }
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${each.key}"
    Service = each.key
  })
}

# ── Lambda: SQS Event Source Mapping ─────────
# Transactions Lambda is triggered by the SQS queue
resource "aws_lambda_event_source_mapping" "transaction_queue_trigger" {
  event_source_arn = var.transaction_queue
  function_name    = aws_lambda_function.service["transactions"].arn
  batch_size       = 10
  enabled          = true
}

# ── CloudWatch Log Groups ─────────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = local.lambdas
  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = 7

  tags = var.tags
}
