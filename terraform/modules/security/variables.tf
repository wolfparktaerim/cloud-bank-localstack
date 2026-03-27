variable "project_name"       { type = string }
variable "environment"        { type = string }
variable "tags"               { type = map(string) }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids"  { type = list(string) }
variable "lambda_role_arn"    { type = string }

variable "db_password" {
  type      = string
  sensitive = true
  default   = "LocalDev123!"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
  default   = "local-dev-jwt-secret-replace-in-prod"
}

variable "kyc_api_key" {
  type      = string
  sensitive = true
  default   = "mock-kyc-api-key-local"
}

variable "abs_api_key" {
  type      = string
  sensitive = true
  default   = "mock-abs-api-key-local"
}
