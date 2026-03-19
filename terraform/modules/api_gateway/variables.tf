variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "lambda_invoke_arns" { type = map(string) }
