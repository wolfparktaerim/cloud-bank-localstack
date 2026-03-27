# ─────────────────────────────────────────────
# main.tf — Root module
# Wires all modules together in dependency order
# ─────────────────────────────────────────────

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# ── LAYER 1: IAM (needed before security, security needs Lambda role ARN) ──
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ── LAYER 2a: Networking (needed before security — security needs subnet IDs) ──
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ── LAYER 1: Security (KMS, Secrets Manager, NACLs) ──
# Depends on: IAM (lambda_role_arn), Networking (vpc_id, subnet_ids)
module "security" {
  source              = "./modules/security"
  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  lambda_role_arn     = module.iam.lambda_role_arn
  db_password         = var.db_password
  jwt_secret          = var.jwt_secret
  tags                = local.common_tags
}

# ── LAYER 3: Storage (S3 — uses KMS key) ──
module "storage" {
  source                 = "./modules/storage"
  project_name           = var.project_name
  environment            = var.environment
  kyc_bucket_name        = var.kyc_bucket_name
  statements_bucket_name = var.statements_bucket_name
  tags                   = local.common_tags
}

# ── LAYER 3: Database (DynamoDB — uses KMS key) ──
module "database" {
  source       = "./modules/database"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ── LAYER 4: Messaging (SQS, SNS) ──
module "messaging" {
  source                  = "./modules/messaging"
  project_name            = var.project_name
  environment             = var.environment
  transaction_queue_name  = var.transaction_queue_name
  notification_topic_name = var.notification_topic_name
  tags                    = local.common_tags
}

# ── LAYER 5: Compute (Lambda — depends on everything above) ──
module "compute" {
  source             = "./modules/compute"
  project_name       = var.project_name
  environment        = var.environment
  lambda_runtime     = var.lambda_runtime
  lambda_role_arn    = module.iam.lambda_role_arn
  transaction_queue  = module.messaging.transaction_queue_arn
  notification_topic = module.messaging.notification_topic_arn
  db_endpoint        = module.database.rds_endpoint
  tags               = local.common_tags
}

# ── LAYER 6: API Gateway (depends on Lambda ARNs) ──
module "api_gateway" {
  source             = "./modules/api_gateway"
  project_name       = var.project_name
  environment        = var.environment
  lambda_invoke_arns = module.compute.lambda_invoke_arns
  tags               = local.common_tags
}

# ── LAYER 7: Monitoring ──
module "monitoring" {
  source       = "./modules/monitoring"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}
