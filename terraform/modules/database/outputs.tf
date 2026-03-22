output "rds_endpoint" {
  value       = aws_db_instance.postgres.address
  description = "RDS PostgreSQL endpoint"
}

output "rds_port" {
  value       = aws_db_instance.postgres.port
  description = "RDS PostgreSQL port"
}

output "dynamodb_table_names" {
  value = {
    accounts     = aws_dynamodb_table.accounts.name
    sessions     = aws_dynamodb_table.user_sessions.name
    transactions = aws_dynamodb_table.transaction_ledger.name
    otp          = aws_dynamodb_table.otp_store.name
  }
}
