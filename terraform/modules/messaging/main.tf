# ─────────────────────────────────────────────
# Module: messaging
# Owner: Member 4
# Creates: SQS queues, SNS topics, DLQs
# ─────────────────────────────────────────────

# ── SQS: Transaction Processing Queue ────────
resource "aws_sqs_queue" "transaction_dlq" {
  name                      = "${var.transaction_queue_name}-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name    = "${var.transaction_queue_name}-dlq"
    Purpose = "Dead letter queue for failed transactions"
  })
}

resource "aws_sqs_queue" "transactions" {
  name                       = var.transaction_queue_name
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400   # 1 day
  receive_wait_time_seconds  = 10      # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.transaction_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.tags, {
    Name    = var.transaction_queue_name
    Purpose = "Async transaction processing"
  })
}

# ── SQS: KYC Verification Queue ──────────────
resource "aws_sqs_queue" "kyc_verification" {
  name                       = "${var.project_name}-kyc-verification"
  visibility_timeout_seconds = 300   # 5 min — KYC takes time

  tags = merge(var.tags, {
    Name    = "${var.project_name}-kyc-verification"
    Purpose = "KYC document verification jobs"
  })
}

# ── SNS: User Notifications Topic ────────────
resource "aws_sns_topic" "notifications" {
  name = var.notification_topic_name

  tags = merge(var.tags, {
    Name    = var.notification_topic_name
    Purpose = "Push notifications to users"
  })
}

# ── SNS: Transaction Alerts ───────────────────
resource "aws_sns_topic" "transaction_alerts" {
  name = "${var.project_name}-transaction-alerts"

  tags = merge(var.tags, {
    Name    = "${var.project_name}-transaction-alerts"
    Purpose = "Real-time transaction alerts to users"
  })
}

# ── Subscribe SQS to SNS for transactions ────
resource "aws_sns_topic_subscription" "transactions_sqs" {
  topic_arn = aws_sns_topic.transaction_alerts.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.transactions.arn
}
