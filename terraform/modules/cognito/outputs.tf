output "user_pool_id" {
  description = "Cognito user pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_client_id" {
  description = "Cognito app client ID"
  value       = aws_cognito_user_pool_client.main.id
}

output "hosted_ui_domain" {
  description = "Cognito hosted UI domain prefix"
  value       = try(aws_cognito_user_pool_domain.main[0].domain, null)
}
