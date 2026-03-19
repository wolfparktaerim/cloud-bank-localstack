# ─────────────────────────────────────────────
# Module: monitoring
# Owner: Member 4
# Creates: CloudWatch dashboards, alarms, log groups
# ─────────────────────────────────────────────

# ── CloudWatch Log Groups ─────────────────────
resource "aws_cloudwatch_log_group" "application" {
  name              = "/cloud-bank/application"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/cloud-bank/api-gateway"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "transactions" {
  name              = "/cloud-bank/transactions"
  retention_in_days = 90   # Regulatory requirement: keep transaction logs longer
  tags              = var.tags
}

# ── CloudWatch Metric Alarms ──────────────────

# Alert if transaction Lambda errors spike
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

# Alert if SQS queue depth grows too large
resource "aws_cloudwatch_metric_alarm" "transaction_queue_depth" {
  alarm_name          = "${var.project_name}-transaction-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "Transaction queue is backing up — possible processing issue"

  dimensions = {
    QueueName = "${var.project_name}-transactions"
  }

  tags = var.tags
}

# ── CloudWatch Dashboard ──────────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Lambda Invocations"
          period = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-transactions"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-accounts"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-auth"]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "Lambda Errors"
          period = 300
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-transactions"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.project_name}-accounts"]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title  = "SQS Queue Depth"
          period = 60
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", "${var.project_name}-transactions"]
          ]
        }
      }
    ]
  })
}
