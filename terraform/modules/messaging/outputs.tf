output "transaction_queue_url" {
  value = aws_sqs_queue.transactions.url
}

output "transaction_queue_arn" {
  value = aws_sqs_queue.transactions.arn
}

output "kyc_queue_url" {
  value = aws_sqs_queue.kyc_verification.url
}

output "kyc_queue_arn" {
  value = aws_sqs_queue.kyc_verification.arn
}

output "notification_topic_arn" {
  value = aws_sns_topic.notifications.arn
}

output "transaction_alerts_topic_arn" {
  value = aws_sns_topic.transaction_alerts.arn
}
