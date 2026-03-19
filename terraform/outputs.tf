output "api_gateway_url" {
  description = "Base URL for the banking API"
  value       = module.api_gateway.api_url
}

output "kyc_bucket_name" {
  description = "S3 bucket for KYC documents"
  value       = module.storage.kyc_bucket_name
}

output "transaction_queue_url" {
  description = "SQS URL for transaction processing"
  value       = module.messaging.transaction_queue_url
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.database.rds_endpoint
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.database.dynamodb_table_names
}
