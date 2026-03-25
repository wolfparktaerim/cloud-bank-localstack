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

variable "public_subnet_ids" {
  type = list(string)
}

variable "lambda_target_function_name" {
  description = "Lambda function name used as ALB target"
  type        = string
}

variable "lambda_target_function_arn" {
  description = "Lambda function ARN used for ALB target registration"
  type        = string
}

variable "route53_zone_name" {
  description = "Hosted zone name for local DNS"
  type        = string
}

variable "route53_record_name" {
  description = "Record name that points to ALB DNS name"
  type        = string
}
