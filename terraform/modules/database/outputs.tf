output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "dynamodb_table_names" {
  value = {
    sessions     = aws_dynamodb_table.user_sessions.name
    transactions = aws_dynamodb_table.transaction_ledger.name
    otp          = aws_dynamodb_table.otp_store.name
  }
}
