output "api_url" {
  value       = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.banking_api.id}/${var.environment}/_user_request_"
  description = "LocalStack API Gateway base URL"
}

output "api_id" {
  value = aws_api_gateway_rest_api.banking_api.id
}
