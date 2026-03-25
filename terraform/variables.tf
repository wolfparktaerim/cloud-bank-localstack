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
