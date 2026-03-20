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
