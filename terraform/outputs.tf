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

output "rds_instance_identifier" {
  description = "RDS PostgreSQL instance identifier"
  value       = module.database.rds_instance_identifier
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value       = module.database.dynamodb_table_names
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito app client ID"
  value       = module.cognito.user_pool_client_id
}

output "cognito_hosted_ui_domain" {
  description = "Cognito hosted UI domain"
  value       = module.cognito.hosted_ui_domain
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.edge.hosted_zone_id
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.edge.alb_dns_name
}

output "api_dns_record" {
  description = "Route53 DNS record pointing to ALB"
  value       = module.edge.api_record_fqdn
}

output "elasticache_cluster_id" {
  description = "ElastiCache Redis cluster id"
  value       = module.data_platform.elasticache_cluster_id
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.data_platform.elasticache_endpoint
}

output "glue_database_name" {
  description = "Glue database name"
  value       = module.data_platform.glue_database_name
}

output "glue_crawler_name" {
  description = "Glue crawler name"
  value       = module.data_platform.glue_crawler_name
}

output "kms_key_arn" {
  description = "Primary KMS key ARN"
  value       = module.security.kms_key_arn
}

output "rds_secret_arn" {
  description = "Secrets Manager secret ARN for RDS credentials"
  value       = module.security.rds_secret_arn
}

output "waf_web_acl_arn" {
  description = "WAFv2 Web ACL ARN"
  value       = module.security.waf_web_acl_arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.security.acm_certificate_arn
}
