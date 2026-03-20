output "rds_endpoint" {
  value       = "localhost:5432"
  description = "RDS not available in LocalStack community — using DynamoDB instead"
}

output "dynamodb_table_names" {
  value = {
    accounts     = aws_dynamodb_table.accounts.name
    sessions     = aws_dynamodb_table.user_sessions.name
    transactions = aws_dynamodb_table.transaction_ledger.name
    otp          = aws_dynamodb_table.otp_store.name
  }
}
