variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "alb_arn" {
  description = "ALB ARN for WAF association"
  type        = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_endpoint" {
  description = "RDS endpoint in host:port format"
  type        = string
}

variable "acm_domain_name" {
  description = "Domain name for ACM certificate request"
  type        = string
}

variable "enable_guardduty" {
  description = "Enable GuardDuty detector provisioning"
  type        = bool
  default     = false
}
