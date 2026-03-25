variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "lambda_runtime" { type = string }
variable "lambda_role_arn" { type = string }
variable "transaction_queue" { type = string }
variable "notification_topic" { type = string }
variable "db_endpoint" { type = string }

# Phase 1: Lambda VPC Configuration
variable "lambda_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC execution"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}
