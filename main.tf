variable "MONGO_USER" {}
variable "MONGO_PASS" {}
variable "MONGO_HOST" {}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
  
  endpoints {
    apigateway     = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    s3             = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
  }
}

# --- 1. DATA TIER: SECRETS & S3 ---
resource "aws_secretsmanager_secret" "db_creds" { name = "db/mongo" }
resource "aws_secretsmanager_secret_version" "v1" {
  secret_id     = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = var.MONGO_USER,
    password = var.MONGO_PASS,
    host     = var.MONGO_HOST
  })
}

resource "aws_s3_bucket" "audit_logs" {
  bucket = "bank-audit-logs"
}

# --- 2. RESILIENCE TIER: SQS DLQ ---
resource "aws_sqs_queue" "bank_dlq" {
  name = "bank-transaction-dlq"
}

# --- 3. IAM PERMISSIONS ---
resource "aws_iam_role" "lambda_role" {
  name = "bank_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "bank_lambda_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = "secretsmanager:GetSecretValue", Resource = "*", Effect = "Allow" },
      { Action = "s3:PutObject", Resource = "${aws_s3_bucket.audit_logs.arn}/*", Effect = "Allow" },
      { Action = "sqs:SendMessage", Resource = "${aws_sqs_queue.bank_dlq.arn}", Effect = "Allow" }
    ]
  })
}

# --- 4. APP TIER: LAMBDA ---
resource "aws_lambda_function" "app_tier" {
  filename      = "lambda.zip"
  function_name = "bank_logic"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"
  
  dead_letter_config {
    target_arn = aws_sqs_queue.bank_dlq.arn
  }

  environment {
    variables = { AUDIT_BUCKET = "bank-audit-logs" }
  }
}

# --- 5. PUBLIC TIER: API GATEWAY ---
resource "aws_api_gateway_rest_api" "api" { name = "BankAPI" }

resource "aws_api_gateway_resource" "res" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "transaction"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.res.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "link" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.res.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.app_tier.invoke_arn
}

resource "aws_api_gateway_method_response" "method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.res.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "method_integration_response" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.res.id
  http_method       = aws_api_gateway_method.method.http_method
  status_code       = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [aws_api_gateway_integration.link, aws_api_gateway_method_response.method_response_200]
}

# --- CORS PRE-FLIGHT ---
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.res.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_link" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.res.id
  http_method = aws_api_gateway_method.options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.res.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_res" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.res.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.options_200]
}

# --- DEPLOYMENT ---
resource "aws_api_gateway_deployment" "dev" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.res.id,
      aws_api_gateway_method.method.id,
      aws_api_gateway_integration.link.id,
      aws_api_gateway_method_response.method_response_200.id,
      aws_api_gateway_integration_response.method_integration_response.id,
      aws_api_gateway_method.options.id,
      aws_api_gateway_method_response.options_200.id,
      aws_api_gateway_integration_response.options_res.id
    ]))
  }
  lifecycle { create_before_destroy = true }
  depends_on = [aws_api_gateway_integration.link, aws_api_gateway_integration.options_link]
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_tier.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.dev.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}

output "api_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/${aws_api_gateway_stage.prod.stage_name}/_user_request_/transaction"
}