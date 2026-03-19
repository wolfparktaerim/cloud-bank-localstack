output "lambda_invoke_arns" {
  value = {
    for k, fn in aws_lambda_function.service :
    k => fn.invoke_arn
  }
}

output "lambda_function_names" {
  value = {
    for k, fn in aws_lambda_function.service :
    k => fn.function_name
  }
}
