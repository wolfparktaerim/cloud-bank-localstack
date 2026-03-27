# ─────────────────────────────────────────────
# Module: iam
# Owner: Member 1
# Layer: 1 (bootstrapped before security module)
# Creates: IAM roles and policies
# ─────────────────────────────────────────────

# ── Lambda Execution Role ─────────────────────
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Scoped policy for all Cloud Bank Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem","dynamodb:PutItem","dynamodb:UpdateItem",
          "dynamodb:DeleteItem","dynamodb:Query","dynamodb:Scan",
          "dynamodb:BatchGetItem","dynamodb:BatchWriteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project_name}-*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage","sqs:ReceiveMessage",
          "sqs:DeleteMessage","sqs:GetQueueAttributes","sqs:GetQueueUrl"
        ]
        Resource = "arn:aws:sqs:*:*:${var.project_name}-*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish","sns:ListTopics"]
        Resource = "arn:aws:sns:*:*:${var.project_name}-*"
      },
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}-*"
      },
      {
        Sid    = "KMSUsage"
        Effect = "Allow"
        Action = [
          "kms:Decrypt","kms:GenerateDataKey",
          "kms:DescribeKey","kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "kms:ViaService" = [
              "dynamodb.*.amazonaws.com",
              "s3.*.amazonaws.com",
              "sqs.*.amazonaws.com",
              "secretsmanager.*.amazonaws.com",
              "rds.*.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "VPCNetworkInterface"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface","ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ── API Gateway Role ──────────────────────────
resource "aws_iam_role" "api_gateway" {
  name = "${var.project_name}-apigateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# ── Deny policy — explicit deny for dangerous actions ──
# This applies even if someone accidentally attaches a broader policy
resource "aws_iam_policy" "lambda_deny" {
  name        = "${var.project_name}-lambda-deny"
  description = "Explicit deny for dangerous actions — defense in depth"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDeleteTables"
        Effect = "Deny"
        Action = [
          "dynamodb:DeleteTable",
          "rds:DeleteDBInstance",
          "s3:DeleteBucket",
          "kms:DeleteAlias",
          "kms:ScheduleKeyDeletion"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_deny_attach" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_deny.arn
}
