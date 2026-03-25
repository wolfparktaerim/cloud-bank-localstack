variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "lambda_security_group_id" {
  type = string
}

variable "enable_elasticache" {
  description = "Enable ElastiCache Redis resources"
  type        = bool
  default     = true
}

variable "enable_glue" {
  description = "Enable AWS Glue resources"
  type        = bool
  default     = true
}

variable "elasticache_cluster_id" {
  description = "ElastiCache cluster identifier"
  type        = string
}

variable "glue_database_name" {
  description = "Glue catalog database name"
  type        = string
}

variable "glue_table_name" {
  description = "Glue catalog table name"
  type        = string
}

variable "glue_s3_target_path" {
  description = "S3 target path for Glue crawler and table"
  type        = string
}
