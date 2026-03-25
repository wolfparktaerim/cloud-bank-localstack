variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "cloudtrail_s3_bucket_name" { type = string }
variable "cloudtrail_trail_name" { type = string }
variable "backup_vault_name" { type = string }
variable "backup_plan_name" { type = string }
