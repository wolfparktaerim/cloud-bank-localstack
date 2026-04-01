# main.tf — Cloud Bank Full Production Architecture (LocalStack Pro)
# Region: ap-southeast-1  |  Multi-AZ  |  Sections 5.1 – 5.8

# ─── VARIABLES ────────────────────────────────────────────────────────────────
variable "MONGO_USER" {}
variable "MONGO_PASS" {}
variable "MONGO_HOST" {}
variable "DB_PASSWORD" { default = "BankRDS_P@ss2024!" }

# ─── DATA ─────────────────────────────────────────────────────────────────────
data "aws_caller_identity" "current" {}

# ─── PROVIDER ─────────────────────────────────────────────────────────────────
provider "aws" {
  region                      = "ap-southeast-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    acm            = "http://localhost:4566"
    apigateway     = "http://localhost:4566"
    backup         = "http://localhost:4566"
    cloudtrail     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    cognitoidp     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    guardduty      = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kms            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    route53        = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    wafv2          = "http://localhost:4566"
    xray           = "http://localhost:4566"
  }
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.1  GENERAL NETWORKING
# ══════════════════════════════════════════════════════════════════════════════

# ─── VPC ──────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "bank-vpc" }
}

# ─── SUBNETS (Availability Zone 1) ───────────────────────────────────────────
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "bank-public-az1", Tier = "Public" }
}

resource "aws_subnet" "private_lambda_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1a"
  tags              = { Name = "bank-private-lambda-az1", Tier = "PrivateLambda" }
}

resource "aws_subnet" "private_data_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1a"
  tags              = { Name = "bank-private-data-az1", Tier = "PrivateData" }
}

# ─── SUBNETS (Availability Zone 2 — reserved for HA) ─────────────────────────
resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "bank-public-az2", Tier = "Public" }
}

resource "aws_subnet" "private_lambda_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-southeast-1b"
  tags              = { Name = "bank-private-lambda-az2", Tier = "PrivateLambda" }
}

resource "aws_subnet" "private_data_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-southeast-1b"
  tags              = { Name = "bank-private-data-az2", Tier = "PrivateData" }
}

# ─── 5.1.8  INTERNET GATEWAY ─────────────────────────────────────────────────
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "bank-igw" }
}

# ─── 5.1.3  PUBLIC SUBNET — NAT GATEWAY ──────────────────────────────────────
resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az1.id
  tags          = { Name = "bank-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

# ─── 5.1.9  ROUTE TABLES ─────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "bank-rt-public" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "bank-rt-private" }
}

resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_lambda_az1" {
  subnet_id      = aws_subnet.private_lambda_az1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_lambda_az2" {
  subnet_id      = aws_subnet.private_lambda_az2.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_data_az1" {
  subnet_id      = aws_subnet.private_data_az1.id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "private_data_az2" {
  subnet_id      = aws_subnet.private_data_az2.id
  route_table_id = aws_route_table.private.id
}

# ─── 5.1.3.1 / 5.1.4.1 / 5.1.5.1  NACLs ────────────────────────────────────
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
  tags       = { Name = "bank-nacl-public" }

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
}

resource "aws_network_acl" "private_lambda" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_lambda_az1.id, aws_subnet.private_lambda_az2.id]
  tags       = { Name = "bank-nacl-private-lambda" }

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "10.0.0.0/16"
    action     = "allow"
  }
  egress {
    rule_no    = 100
    protocol   = "-1"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
}

resource "aws_network_acl" "private_data" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_data_az1.id, aws_subnet.private_data_az2.id]
  tags       = { Name = "bank-nacl-private-data" }

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    from_port  = 5432
    to_port    = 5432
    cidr_block = "10.0.2.0/24"
    action     = "allow"
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    from_port  = 5432
    to_port    = 5432
    cidr_block = "10.0.5.0/24"
    action     = "allow"
  }
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    from_port  = 27017
    to_port    = 27017
    cidr_block = "10.0.2.0/24"
    action     = "allow"
  }
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    from_port  = 6379
    to_port    = 6379
    cidr_block = "10.0.2.0/24"
    action     = "allow"
  }
  ingress {
    rule_no    = 140
    protocol   = "tcp"
    from_port  = 6379
    to_port    = 6379
    cidr_block = "10.0.5.0/24"
    action     = "allow"
  }
  egress {
    rule_no    = 100
    protocol   = "tcp"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "10.0.0.0/16"
    action     = "allow"
  }
}

# ─── 5.1.6  SECURITY GROUPS ──────────────────────────────────────────────────
resource "aws_security_group" "lambda_sg" {
  name        = "bank-lambda-sg"
  description = "Lambda functions — outbound only"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bank-lambda-sg" }
}

resource "aws_security_group" "data_sg" {
  name        = "bank-data-sg"
  description = "Data tier — allow inbound from Lambda SG only"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "PostgreSQL"
  }
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "MongoDB"
  }
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "Redis"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bank-data-sg" }
}

# ─── 5.1.7  VPC INTERFACE ENDPOINTS ──────────────────────────────────────────
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-southeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "bank-vpce-s3" }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.ap-southeast-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "bank-vpce-dynamodb" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_lambda_az1.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true
  tags                = { Name = "bank-vpce-secretsmanager" }
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.2  NETWORK & TRAFFIC MANAGEMENT — ROUTE 53
# ══════════════════════════════════════════════════════════════════════════════

resource "aws_route53_zone" "internal" {
  name = "cloudbank.internal"
  vpc { vpc_id = aws_vpc.main.id }
  tags = { Name = "bank-internal-zone" }
}

resource "aws_route53_record" "rds" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.cloudbank.internal"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.postgres.address]
}

resource "aws_route53_record" "cache" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "cache.cloudbank.internal"
  type    = "CNAME"
  ttl     = 300
  records = [aws_elasticache_cluster.redis.cache_nodes[0].address]
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.3  AUTHENTICATION & AUTHORIZATION — COGNITO
# ══════════════════════════════════════════════════════════════════════════════

# 5.3.1  User Pool
resource "aws_cognito_user_pool" "bank" {
  name = "bank-user-pool"

  # Feature 1 — MFA (OPTIONAL: users may enroll TOTP)
  mfa_configuration = "OPTIONAL"
  software_token_mfa_configuration { enabled = true }

  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }

  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = { Name = "bank-user-pool" }
}

# Feature 2 — App Client Integration
resource "aws_cognito_user_pool_client" "app" {
  name         = "bank-app-client"
  user_pool_id = aws_cognito_user_pool.bank.id

  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = ["http://localhost/callback"]
}

# Feature 3 — Secure Authorization (hosted UI domain)
resource "aws_cognito_user_pool_domain" "bank" {
  domain       = "cloudbank-auth"
  user_pool_id = aws_cognito_user_pool.bank.id
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.4  PRESENTATION LAYER — AMPLIFY
# ══════════════════════════════════════════════════════════════════════════════

# NOTE: aws_amplify_app is not supported by LocalStack (returns 403).
# In production AWS, uncomment and deploy:
#
# resource "aws_amplify_app" "frontend" {
#   name = "cloud-bank-frontend"
#   environment_variables = {
#     API_BASE_URL = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/prod/_user_request_"
#   }
# }

# ══════════════════════════════════════════════════════════════════════════════
# SHARED IAM — Lambda base role + policies
# ══════════════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Shared: CloudWatch Logs + VPC ENI (required for Lambda-in-VPC)
resource "aws_iam_policy" "lambda_base" {
  name = "bank-lambda-base"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.5  APPLICATION TIER — LAMBDA FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

locals {
  lambda_vpc = {
    subnet_ids         = [aws_subnet.private_lambda_az1.id, aws_subnet.private_lambda_az2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# ── AUTH LAMBDA ───────────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_auth" {
  name               = "bank-lambda-auth-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy_attachment" "auth_base" {
  role       = aws_iam_role.lambda_auth.name
  policy_arn = aws_iam_policy.lambda_base.arn
}
resource "aws_iam_role_policy" "auth_policy" {
  name = "auth-service-policy"
  role = aws_iam_role.lambda_auth.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["cognito-idp:AdminCreateUser", "cognito-idp:AdminSetUserPassword", "cognito-idp:AdminInitiateAuth", "cognito-idp:AdminGetUser"], Resource = aws_cognito_user_pool.bank.arn },
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"], Resource = aws_dynamodb_table.sessions.arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.bank.arn }
    ]
  })
}
resource "aws_lambda_function" "auth" {
  function_name = "lambda_auth"
  filename      = "lambda_auth.zip"
  handler       = "auth.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_auth.arn
  timeout       = 30
  tracing_config { mode = "Active" }
  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }
  environment {
    variables = {
      LOCALSTACK_ENDPOINT = "http://localstack:4566"
      USER_POOL_ID        = aws_cognito_user_pool.bank.id
      COGNITO_CLIENT_ID   = aws_cognito_user_pool_client.app.id
      SESSIONS_TABLE      = aws_dynamodb_table.sessions.name
      AWS_DEFAULT_REGION  = "ap-southeast-1"
    }
  }
}
resource "aws_cloudwatch_log_group" "auth" {
  name              = "/aws/lambda/${aws_lambda_function.auth.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.bank.arn
}

# ── ACCOUNTS LAMBDA ───────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_accounts" {
  name               = "bank-lambda-accounts-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy_attachment" "accounts_base" {
  role       = aws_iam_role.lambda_accounts.name
  policy_arn = aws_iam_policy.lambda_base.arn
}
resource "aws_iam_role_policy" "accounts_policy" {
  name = "accounts-service-policy"
  role = aws_iam_role.lambda_accounts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan", "dynamodb:Query"], Resource = aws_dynamodb_table.accounts.arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.bank.arn }
    ]
  })
}
resource "aws_lambda_function" "accounts" {
  function_name = "lambda_accounts"
  filename      = "lambda_accounts.zip"
  handler       = "accounts.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_accounts.arn
  timeout       = 30
  tracing_config { mode = "Active" }
  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }
  environment {
    variables = {
      LOCALSTACK_ENDPOINT = "http://localstack:4566"
      ACCOUNTS_TABLE      = aws_dynamodb_table.accounts.name
      AWS_DEFAULT_REGION  = "ap-southeast-1"
    }
  }
}
resource "aws_cloudwatch_log_group" "accounts" {
  name              = "/aws/lambda/${aws_lambda_function.accounts.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.bank.arn
}

# ── TRANSACTIONS LAMBDA ───────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_transactions" {
  name               = "bank-lambda-transactions-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy_attachment" "transactions_base" {
  role       = aws_iam_role.lambda_transactions.name
  policy_arn = aws_iam_policy.lambda_base.arn
}
resource "aws_iam_role_policy" "transactions_policy" {
  name = "transactions-service-policy"
  role = aws_iam_role.lambda_transactions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = aws_secretsmanager_secret.db_mongo.arn },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.audit_logs.arn}/*" },
      { Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.bank_dlq.arn },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.transaction_events.arn },
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"], Resource = aws_dynamodb_table.audit_events.arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.bank.arn }
    ]
  })
}
resource "aws_lambda_function" "transactions" {
  function_name = "lambda_transactions"
  filename      = "lambda_transactions.zip"
  handler       = "transactions.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_transactions.arn
  timeout       = 30
  dead_letter_config { target_arn = aws_sqs_queue.bank_dlq.arn }
  tracing_config { mode = "Active" }
  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }
  environment {
    variables = {
      LOCALSTACK_ENDPOINT    = "http://localstack:4566"
      AUDIT_BUCKET           = aws_s3_bucket.audit_logs.bucket
      TRANSACTION_TABLE      = aws_dynamodb_table.audit_events.name
      NOTIFICATION_TOPIC_ARN = aws_sns_topic.transaction_events.arn
      AWS_DEFAULT_REGION     = "ap-southeast-1"
    }
  }
}
resource "aws_cloudwatch_log_group" "transactions" {
  name              = "/aws/lambda/${aws_lambda_function.transactions.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.bank.arn
}

# ── NOTIFICATIONS LAMBDA ──────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_notifications" {
  name               = "bank-lambda-notifications-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy_attachment" "notifications_base" {
  role       = aws_iam_role.lambda_notifications.name
  policy_arn = aws_iam_policy.lambda_base.arn
}
resource "aws_iam_role_policy" "notifications_policy" {
  name = "notifications-service-policy"
  role = aws_iam_role.lambda_notifications.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sns:Publish", "sns:Subscribe", "sns:ListSubscriptionsByTopic"], Resource = [aws_sns_topic.alerts.arn, aws_sns_topic.transaction_events.arn] },
      { Effect = "Allow", Action = ["ses:SendEmail", "ses:SendRawEmail"], Resource = "*" }
    ]
  })
}
resource "aws_lambda_function" "notifications" {
  function_name = "lambda_notifications"
  filename      = "lambda_notifications.zip"
  handler       = "notifications.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_notifications.arn
  timeout       = 30
  tracing_config { mode = "Active" }
  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }
  environment {
    variables = {
      LOCALSTACK_ENDPOINT   = "http://localstack:4566"
      ALERT_TOPIC_ARN       = aws_sns_topic.alerts.arn
      TRANSACTION_TOPIC_ARN = aws_sns_topic.transaction_events.arn
      AWS_DEFAULT_REGION    = "ap-southeast-1"
    }
  }
}
resource "aws_cloudwatch_log_group" "notifications" {
  name              = "/aws/lambda/${aws_lambda_function.notifications.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.bank.arn
}

# ── KYC LAMBDA ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_kyc" {
  name               = "bank-lambda-kyc-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}
resource "aws_iam_role_policy_attachment" "kyc_base" {
  role       = aws_iam_role.lambda_kyc.name
  policy_arn = aws_iam_policy.lambda_base.arn
}
resource "aws_iam_role_policy" "kyc_policy" {
  name = "kyc-service-policy"
  role = aws_iam_role.lambda_kyc.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.kyc_docs.arn}/*" },
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan"], Resource = aws_dynamodb_table.kyc_status.arn },
      { Effect = "Allow", Action = ["kms:Decrypt", "kms:GenerateDataKey"], Resource = aws_kms_key.bank.arn }
    ]
  })
}
resource "aws_lambda_function" "kyc" {
  function_name = "lambda_kyc"
  filename      = "lambda_kyc.zip"
  handler       = "kyc.handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_kyc.arn
  timeout       = 30
  tracing_config { mode = "Active" }
  vpc_config {
    subnet_ids         = local.lambda_vpc.subnet_ids
    security_group_ids = local.lambda_vpc.security_group_ids
  }
  environment {
    variables = {
      LOCALSTACK_ENDPOINT = "http://localstack:4566"
      KYC_BUCKET          = aws_s3_bucket.kyc_docs.bucket
      KYC_TABLE           = aws_dynamodb_table.kyc_status.name
      AWS_DEFAULT_REGION  = "ap-southeast-1"
    }
  }
}
resource "aws_cloudwatch_log_group" "kyc" {
  name              = "/aws/lambda/${aws_lambda_function.kyc.function_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.bank.arn
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.6  STORAGE TIER
# ══════════════════════════════════════════════════════════════════════════════

# ─── SECRETS MANAGER ─────────────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "db_mongo" { name = "db/mongo" }
resource "aws_secretsmanager_secret_version" "db_mongo" {
  secret_id     = aws_secretsmanager_secret.db_mongo.id
  secret_string = jsonencode({ username = var.MONGO_USER, password = var.MONGO_PASS, host = var.MONGO_HOST })
}

resource "aws_secretsmanager_secret" "db_rds" { name = "db/rds" }
resource "aws_secretsmanager_secret_version" "db_rds" {
  secret_id     = aws_secretsmanager_secret.db_rds.id
  secret_string = jsonencode({ username = "bankadmin", password = var.DB_PASSWORD, engine = "postgres" })
}

# ─── S3 BUCKETS ──────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "audit_logs" { bucket = "bank-audit-logs" }
resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bank.arn
    }
  }
}

resource "aws_s3_bucket" "kyc_docs" { bucket = "bank-kyc-documents" }
resource "aws_s3_bucket_server_side_encryption_configuration" "kyc" {
  bucket = aws_s3_bucket.kyc_docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bank.arn
    }
  }
}

resource "aws_s3_bucket" "monitoring_logs" { bucket = "bank-monitoring-logs" }

# ─── AWS RDS (PostgreSQL) ─────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "bank-db-subnet-group"
  subnet_ids = [aws_subnet.private_data_az1.id, aws_subnet.private_data_az2.id]
  tags       = { Name = "bank-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier             = "bank-rds"
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "bankdb"
  username               = "bankadmin"
  password               = var.DB_PASSWORD
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.data_sg.id]
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.bank.arn
  skip_final_snapshot    = true
  tags                   = { Name = "bank-rds" }
}

# ─── DYNAMODB TABLES ─────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "sessions" {
  name         = "bank-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  attribute {
    name = "session_id"
    type = "S"
  }
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.bank.arn
  }
  tags = { Name = "bank-sessions" }
}

resource "aws_dynamodb_table" "audit_events" {
  name         = "bank-audit-events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"
  range_key    = "timestamp"
  attribute {
    name = "event_id"
    type = "S"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.bank.arn
  }
  tags = { Name = "bank-audit-events" }
}

resource "aws_dynamodb_table" "accounts" {
  name         = "bank-accounts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "account_id"
  attribute {
    name = "account_id"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.bank.arn
  }
  tags = { Name = "bank-accounts" }
}

resource "aws_dynamodb_table" "kyc_status" {
  name         = "bank-kyc-status"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "kyc_id"
  attribute {
    name = "kyc_id"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.bank.arn
  }
  tags = { Name = "bank-kyc-status" }
}

# ─── ELASTICACHE REDIS ───────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "main" {
  name       = "bank-cache-subnet"
  subnet_ids = [aws_subnet.private_data_az1.id]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id         = "bank-cache"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.data_sg.id]
  tags               = { Name = "bank-redis" }
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.7  SECURITY
# ══════════════════════════════════════════════════════════════════════════════

# ─── 5.7.4  KMS ──────────────────────────────────────────────────────────────
resource "aws_kms_key" "bank" {
  description             = "Bank master encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "bank-kms-master" }
}
resource "aws_kms_alias" "bank" {
  name          = "alias/bank-master-key"
  target_key_id = aws_kms_key.bank.key_id
}

# ─── 5.7.2  WAF ──────────────────────────────────────────────────────────────
resource "aws_wafv2_web_acl" "bank" {
  name  = "bank-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRules"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BankWAFCommonRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedSQLRules"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BankWAFSQLRules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "BankWAF"
    sampled_requests_enabled   = true
  }

  tags = { Name = "bank-waf" }
}

# WAF ↔ API Gateway Stage association
resource "aws_wafv2_web_acl_association" "api_gw" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.bank.arn
  depends_on   = [aws_api_gateway_stage.prod]
}

# ─── 5.7.1  GUARDDUTY ────────────────────────────────────────────────────────
# NOTE: GuardDuty is not supported by LocalStack (returns 501 InternalFailure).
# In production AWS, uncomment:
#
# resource "aws_guardduty_detector" "main" {
#   enable = true
#   tags   = { Name = "bank-guardduty" }
# }

# ─── 5.7.3  ACM CERTIFICATE ──────────────────────────────────────────────────
resource "aws_acm_certificate" "bank" {
  domain_name       = "api.cloudbank.internal"
  validation_method = "DNS"
  tags              = { Name = "bank-api-cert" }
  lifecycle { create_before_destroy = true }
}

# ─── 6.7.6  IAM ROLES — defined per-Lambda above, backup role below ──────────

# ══════════════════════════════════════════════════════════════════════════════
# 5.8  RELIABILITY
# ══════════════════════════════════════════════════════════════════════════════

# ─── 5.8.2  SNS TOPICS ───────────────────────────────────────────────────────
resource "aws_sns_topic" "alerts" {
  name              = "bank-alerts"
  kms_master_key_id = aws_kms_key.bank.id
  tags              = { Name = "bank-alerts" }
}

resource "aws_sns_topic" "transaction_events" {
  name              = "bank-transaction-events"
  kms_master_key_id = aws_kms_key.bank.id
  tags              = { Name = "bank-transaction-events" }
}

# ─── SQS — DLQ + TRANSACTION QUEUE ──────────────────────────────────────────
resource "aws_sqs_queue" "bank_dlq" {
  name                      = "bank-transaction-dlq"
  kms_master_key_id         = aws_kms_key.bank.id
  message_retention_seconds = 1209600 # 14 days
  tags                      = { Name = "bank-dlq" }
}

resource "aws_sqs_queue" "transaction_queue" {
  name                       = "bank-transaction-queue"
  kms_master_key_id          = aws_kms_key.bank.id
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.bank_dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = "bank-transaction-queue" }
}

# Allow SNS to send to SQS
resource "aws_sqs_queue_policy" "transaction" {
  queue_url = aws_sqs_queue.transaction_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.transaction_queue.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.transaction_events.arn } }
    }]
  })
}

resource "aws_sns_topic_subscription" "sqs_transactions" {
  topic_arn = aws_sns_topic.transaction_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.transaction_queue.arn
}

# ─── 5.8.1  CLOUDWATCH ALARMS ────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "bank-lambda-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = { Name = "bank-lambda-errors-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "bank-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  dimensions          = { QueueName = aws_sqs_queue.bank_dlq.name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = { Name = "bank-dlq-depth-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "bank-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions          = { DBInstanceIdentifier = aws_db_instance.postgres.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = { Name = "bank-rds-cpu-alarm" }
}

# ─── 5.8.3  CLOUDTRAIL ───────────────────────────────────────────────────────
resource "aws_s3_bucket" "cloudtrail_logs" { bucket = "bank-cloudtrail-logs" }

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "bank-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.bucket
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.bank.arn
  tags                          = { Name = "bank-cloudtrail" }
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]
}

# ─── 5.8.4  BACKUP ───────────────────────────────────────────────────────────
resource "aws_iam_role" "backup" {
  name = "bank-backup-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "backup.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_vault" "main" {
  name        = "bank-backup-vault"
  kms_key_arn = aws_kms_key.bank.arn
  tags        = { Name = "bank-backup-vault" }
}

resource "aws_backup_plan" "main" {
  name = "bank-backup-plan"
  rule {
    rule_name         = "daily-backup-2am"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"
    lifecycle { delete_after = 30 }
  }
  tags = { Name = "bank-backup-plan" }
}

resource "aws_backup_selection" "main" {
  plan_id      = aws_backup_plan.main.id
  name         = "bank-resources"
  iam_role_arn = aws_iam_role.backup.arn
  resources = [
    aws_db_instance.postgres.arn,
    aws_dynamodb_table.accounts.arn,
    aws_dynamodb_table.audit_events.arn,
  ]
}

# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC TIER — API GATEWAY
# ══════════════════════════════════════════════════════════════════════════════

resource "aws_api_gateway_rest_api" "api" {
  name = "BankAPI"
  tags = { Name = "bank-api" }
}

# Cognito authorizer (set authorization = "COGNITO_USER_POOLS" per method to enable)
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "CognitoAuthorizer"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.bank.arn]
}

# ─── ROUTES (for_each) ───────────────────────────────────────────────────────
locals {
  api_routes = {
    auth          = aws_lambda_function.auth.invoke_arn
    accounts      = aws_lambda_function.accounts.invoke_arn
    transactions  = aws_lambda_function.transactions.invoke_arn
    notifications = aws_lambda_function.notifications.invoke_arn
    kyc           = aws_lambda_function.kyc.invoke_arn
  }
}

resource "aws_api_gateway_resource" "route" {
  for_each    = local.api_routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.key
}

# POST methods — authorization = "NONE" for local testing
# To enable Cognito auth: set authorization = "COGNITO_USER_POOLS" and authorizer_id = aws_api_gateway_authorizer.cognito.id
resource "aws_api_gateway_method" "post" {
  for_each      = local.api_routes
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.route[each.key].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post" {
  for_each                = local.api_routes
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.route[each.key].id
  http_method             = aws_api_gateway_method.post[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value
}

# OPTIONS (CORS pre-flight) for all routes
resource "aws_api_gateway_method" "options" {
  for_each      = local.api_routes
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.route[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each          = local.api_routes
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_resource.route[each.key].id
  http_method       = aws_api_gateway_method.options[each.key].http_method
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "options_200" {
  for_each    = local.api_routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.route[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each    = local.api_routes
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.route[each.key].id
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.options_200]
}

# Lambda permissions for API Gateway invocation
resource "aws_lambda_permission" "apigw" {
  for_each = {
    auth          = aws_lambda_function.auth.function_name
    accounts      = aws_lambda_function.accounts.function_name
    transactions  = aws_lambda_function.transactions.function_name
    notifications = aws_lambda_function.notifications.function_name
    kyc           = aws_lambda_function.kyc.function_name
  }
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.route,
      aws_api_gateway_method.post,
      aws_api_gateway_integration.post,
      aws_api_gateway_method.options,
    ]))
  }
  lifecycle { create_before_destroy = true }
  depends_on = [
    aws_api_gateway_integration.post,
    aws_api_gateway_integration.options,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"

  xray_tracing_enabled = true
  tags                 = { Name = "bank-api-prod" }
}

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUTS
# ══════════════════════════════════════════════════════════════════════════════

locals {
  api_base = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.api.id}/prod/_user_request_"
}

output "api_base_url" { value = local.api_base }
output "api_auth_url" { value = "${local.api_base}/auth" }
output "api_accounts_url" { value = "${local.api_base}/accounts" }
output "api_transactions_url" { value = "${local.api_base}/transactions" }
output "api_notifications_url" { value = "${local.api_base}/notifications" }
output "api_kyc_url" { value = "${local.api_base}/kyc" }
output "cognito_user_pool_id" { value = aws_cognito_user_pool.bank.id }
output "cognito_client_id" { value = aws_cognito_user_pool_client.app.id }
output "rds_endpoint" { value = aws_db_instance.postgres.endpoint }
output "redis_endpoint" { value = aws_elasticache_cluster.redis.cache_nodes[0].address }
