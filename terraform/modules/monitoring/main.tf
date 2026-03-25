# ─────────────────────────────────────────────
# Module: monitoring
# Owner: Member 4
# Creates: CloudWatch alarms
#
# Notes on LocalStack community limitations:
#   - CloudWatch Logs (log groups) → not supported
#   - CloudWatch Dashboard → not reliably persisted
#   - CloudWatch Alarms → supported, kept below
# ─────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "transaction_lambda_errors" {
  alarm_name          = "${var.project_name}-transaction-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Transaction Lambda error rate is too high"

  dimensions = {
    FunctionName = "${var.project_name}-transactions"
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "transaction_queue_depth" {
  alarm_name          = "${var.project_name}-transaction-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Transaction queue is backing up"

  dimensions = {
    QueueName = "${var.project_name}-transactions-local"
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "transactions_lambda" {
  name              = "/aws/lambda/${var.project_name}-transactions"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudtrail" "main" {
  name                          = var.cloudtrail_trail_name
  s3_bucket_name                = var.cloudtrail_s3_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = false

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags
}

resource "aws_backup_vault" "main" {
  name = var.backup_vault_name

  tags = var.tags
}

resource "aws_backup_plan" "main" {
  name = var.backup_plan_name

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    completion_window = 120
  }

  tags = var.tags
}
