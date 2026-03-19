# ─────────────────────────────────────────────
# main.tf — Root module
# Calls each sub-module and wires them together
# ─────────────────────────────────────────────

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
    ManagedBy   = "terraform"
  }
}

# ── Networking ───────────────────────────────
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ── IAM ──────────────────────────────────────
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# ── Storage (S3) ─────────────────────────────
module "storage" {
  source                 = "./modules/storage"
  project_name           = var.project_name
  environment            = var.environment
  kyc_bucket_name        = var.kyc_bucket_name
  statements_bucket_name = var.statements_bucket_name
  tags                   = local.common_tags
}

# ── Database ─────────────────────────────────
module "database" {
  source            = "./modules/database"
  project_name      = var.project_name
  environment       = var.environment
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  subnet_ids        = module.networking.private_subnet_ids
  vpc_id            = module.networking.vpc_id
  tags              = local.common_tags
}

# ── Messaging ────────────────────────────────
module "messaging" {
  source                  = "./modules/messaging"
  project_name            = var.project_name
  environment             = var.environment
  transaction_queue_name  = var.transaction_queue_name
  notification_topic_name = var.notification_topic_name
  tags                    = local.common_tags
}

# ── Compute (Lambda) ─────────────────────────
module "compute" {
  source              = "./modules/compute"
  project_name        = var.project_name
  environment         = var.environment
  lambda_runtime      = var.lambda_runtime
  lambda_role_arn     = module.iam.lambda_role_arn
  transaction_queue   = module.messaging.transaction_queue_arn
  notification_topic  = module.messaging.notification_topic_arn
  db_endpoint         = module.database.rds_endpoint
  tags                = local.common_tags
}

# ── API Gateway ──────────────────────────────
module "api_gateway" {
  source              = "./modules/api_gateway"
  project_name        = var.project_name
  environment         = var.environment
  lambda_invoke_arns  = module.compute.lambda_invoke_arns
  tags                = local.common_tags
}

# ── Monitoring ───────────────────────────────
module "monitoring" {
  source       = "./modules/monitoring"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}
