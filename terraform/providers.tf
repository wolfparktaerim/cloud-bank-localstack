terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    rds            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    logs           = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    cognitoidentityprovider = "http://localhost:4566"
    route53        = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    wafv2          = "http://localhost:4566"
    acm            = "http://localhost:4566"
    kms            = "http://localhost:4566"
    cloudtrail     = "http://localhost:4566"
    glue           = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    backup         = "http://localhost:4566"
    guardduty      = "http://localhost:4566"
  }

  # Critical for LocalStack on Windows — forces path-style S3 URLs
  # Without this, S3 uses virtual-hosted style which Windows DNS cannot resolve
  s3_use_path_style = true
}
