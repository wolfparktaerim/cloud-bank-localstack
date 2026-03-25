variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "cognito_callback_urls" {
  description = "OAuth callback URLs for Cognito app client"
  type        = list(string)
}

variable "cognito_logout_urls" {
  description = "OAuth logout URLs for Cognito app client"
  type        = list(string)
}

variable "cognito_domain_prefix" {
  description = "Hosted UI domain prefix for Cognito user pool"
  type        = string
}

variable "enable_hosted_ui_domain" {
  description = "Whether to create a Cognito user pool domain"
  type        = bool
  default     = false
}
