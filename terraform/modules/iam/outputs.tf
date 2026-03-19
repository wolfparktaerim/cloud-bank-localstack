output "lambda_role_arn" {
  value = aws_iam_role.lambda_execution.arn
}

output "lambda_role_name" {
  value = aws_iam_role.lambda_execution.name
}

output "api_gateway_role_arn" {
  value = aws_iam_role.api_gateway.arn
}
