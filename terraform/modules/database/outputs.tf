output "rds_endpoint" {
  value       = try(aws_db_instance.postgres[0].endpoint, "localhost:5432")
  description = "RDS PostgreSQL endpoint address"
}

output "rds_instance_identifier" {
  value       = try(aws_db_instance.postgres[0].id, null)
  description = "RDS instance identifier"
}

output "rds_port" {
  value       = try(aws_db_instance.postgres[0].port, 5432)
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

# Phase 1: DB Subnet Group (for RDS in Phase 4A)
output "db_subnet_group_name" {
  description = "DB subnet group name for RDS instance provisioning (Phase 4A)"
  value       = aws_db_subnet_group.main.name
}
