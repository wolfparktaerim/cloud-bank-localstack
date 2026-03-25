# ─────────────────────────────────────────────
# Module: api_gateway
# Owner: Member 2
# Creates: REST API with routes for all services
# ─────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "banking_api" {
  name        = "${var.project_name}-api"
  description = "NeoBank SG — Digital Banking REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.project_name}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# ── /accounts resource ────────────────────────
resource "aws_api_gateway_resource" "accounts" {
  rest_api_id = aws_api_gateway_rest_api.banking_api.id
  parent_id   = aws_api_gateway_rest_api.banking_api.root_resource_id
  path_part   = "accounts"
}

resource "aws_api_gateway_method" "accounts_get" {
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  resource_id   = aws_api_gateway_resource.accounts.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "accounts_post" {
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  resource_id   = aws_api_gateway_resource.accounts.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "accounts_get" {
  rest_api_id             = aws_api_gateway_rest_api.banking_api.id
  resource_id             = aws_api_gateway_resource.accounts.id
  http_method             = aws_api_gateway_method.accounts_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["accounts"]
}

resource "aws_api_gateway_integration" "accounts_post" {
  rest_api_id             = aws_api_gateway_rest_api.banking_api.id
  resource_id             = aws_api_gateway_resource.accounts.id
  http_method             = aws_api_gateway_method.accounts_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["accounts"]
}

# ── /transactions resource ────────────────────
resource "aws_api_gateway_resource" "transactions" {
  rest_api_id = aws_api_gateway_rest_api.banking_api.id
  parent_id   = aws_api_gateway_rest_api.banking_api.root_resource_id
  path_part   = "transactions"
}

resource "aws_api_gateway_method" "transactions_post" {
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  resource_id   = aws_api_gateway_resource.transactions.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "transactions_post" {
  rest_api_id             = aws_api_gateway_rest_api.banking_api.id
  resource_id             = aws_api_gateway_resource.transactions.id
  http_method             = aws_api_gateway_method.transactions_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["transactions"]
}

# ── /auth resource ────────────────────────────
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.banking_api.id
  parent_id   = aws_api_gateway_rest_api.banking_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_post" {
  rest_api_id             = aws_api_gateway_rest_api.banking_api.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.auth_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["auth"]
}

# ── /kyc resource ─────────────────────────────
resource "aws_api_gateway_resource" "kyc" {
  rest_api_id = aws_api_gateway_rest_api.banking_api.id
  parent_id   = aws_api_gateway_rest_api.banking_api.root_resource_id
  path_part   = "kyc"
}

resource "aws_api_gateway_method" "kyc_post" {
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  resource_id   = aws_api_gateway_resource.kyc.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "kyc_post" {
  rest_api_id             = aws_api_gateway_rest_api.banking_api.id
  resource_id             = aws_api_gateway_resource.kyc.id
  http_method             = aws_api_gateway_method.kyc_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arns["kyc"]
}

# ── Deploy the API ────────────────────────────
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.banking_api.id

  # Force redeploy when integrations change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_authorizer.cognito.id,
      aws_api_gateway_integration.accounts_get,
      aws_api_gateway_integration.accounts_post,
      aws_api_gateway_integration.transactions_post,
      aws_api_gateway_integration.auth_post,
      aws_api_gateway_integration.kyc_post,
      aws_api_gateway_method.accounts_get.authorization,
      aws_api_gateway_method.accounts_post.authorization,
      aws_api_gateway_method.transactions_post.authorization,
      aws_api_gateway_method.kyc_post.authorization,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.banking_api.id
  stage_name    = var.environment

  tags = var.tags
}
