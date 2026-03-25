variable "project_name" { type = string }
variable "environment"  { type = string }
variable "tags"         { type = map(string) }

# Kept for documentation / future RDS upgrade, not used in LocalStack community
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "cloudbank"
}

variable "db_username" {
  type      = string
  sensitive = true
  default   = "admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "LocalDev123!"
}

variable "enable_rds_instance" {
  description = "Whether to create PostgreSQL RDS instance (Phase 4A)"
  type        = bool
  default     = true
}

# Phase 1: DB subnet IDs for subnet group (from networking module)
variable "db_subnet_ids" {
  description = "Subnet IDs for RDS DB subnet group (private subnets from Phase 1 networking)"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID from networking module"
  type        = string
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS ingress from Lambda"
  type        = string
}
