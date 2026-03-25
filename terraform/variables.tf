variable "aws_region" {
  description = "AWS region — Singapore for this project"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "localstack"
}

variable "project_name" {
  description = "Project name used as prefix for all resource names"
  type        = string
  default     = "cloud-bank"
}

variable "availability_zones" {
  description = "Availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "enable_iam_enforcement" {
  description = "Enable real IAM policy enforcement (LocalStack Pro/Ultimate feature)"
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

# ── Compute ──────────────────────────────────
variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

# ── Database ─────────────────────────────────
variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Core banking database name"
  type        = string
  default     = "cloudbank"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  default     = "LocalDev123!"   # Override in prod-sim with secrets manager
  sensitive   = true
}

variable "enable_rds_instance" {
  description = "Enable PostgreSQL RDS instance provisioning for Phase 4A"
  type        = bool
  default     = true
}

# ── S3 ───────────────────────────────────────
variable "kyc_bucket_name" {
  description = "S3 bucket for KYC documents"
  type        = string
  default     = "cloud-bank-kyc-documents"
}

variable "statements_bucket_name" {
  description = "S3 bucket for account statements"
  type        = string
  default     = "cloud-bank-statements"
}

# ── Messaging ────────────────────────────────
variable "transaction_queue_name" {
  description = "SQS queue for transaction processing"
  type        = string
  default     = "cloud-bank-transactions"
}

variable "notification_topic_name" {
  description = "SNS topic for user notifications"
  type        = string
  default     = "cloud-bank-notifications"
}

# ── Cognito ──────────────────────────────────
variable "cognito_callback_urls" {
  description = "OAuth callback URLs for Cognito app client"
  type        = list(string)
  default     = ["http://localhost:3000/callback"]
}

variable "cognito_logout_urls" {
  description = "OAuth logout URLs for Cognito app client"
  type        = list(string)
  default     = ["http://localhost:3000/logout"]
}

variable "cognito_domain_prefix" {
  description = "Hosted UI domain prefix for Cognito user pool"
  type        = string
  default     = "cloud-bank-local-auth"
}

variable "enable_cognito_hosted_ui_domain" {
  description = "Create Cognito hosted UI domain (can hang in some LocalStack versions)"
  type        = bool
  default     = false
}

# ── Phase 3: Edge services ───────────────────
variable "route53_zone_name" {
  description = "Hosted zone name for Route53 local DNS"
  type        = string
  default     = "cloud-bank.local"
}

variable "route53_record_name" {
  description = "DNS record name that points to API ALB"
  type        = string
  default     = "api.cloud-bank.local"
}

# ── Phase 4B: Data platform ──────────────────
variable "enable_elasticache" {
  description = "Enable ElastiCache Redis provisioning"
  type        = bool
  default     = true
}

variable "enable_glue" {
  description = "Enable AWS Glue catalog/crawler/job provisioning"
  type        = bool
  default     = true
}

variable "elasticache_cluster_id" {
  description = "ElastiCache cluster identifier"
  type        = string
  default     = "cloud-bank-redis"
}

variable "glue_database_name" {
  description = "Glue catalog database name"
  type        = string
  default     = "cloud_bank_analytics"
}

variable "glue_table_name" {
  description = "Glue catalog table name"
  type        = string
  default     = "transactions_raw"
}

variable "glue_s3_target_path" {
  description = "S3 path used by Glue table and crawler"
  type        = string
  default     = "s3://cloud-bank-statements-local/glue"
}

# ── Phase 5: Security ────────────────────────
variable "acm_domain_name" {
  description = "Domain name for ACM certificate request"
  type        = string
  default     = "cloud-bank.local"
}

variable "enable_guardduty" {
  description = "Enable GuardDuty detector provisioning"
  type        = bool
  default     = false
}
