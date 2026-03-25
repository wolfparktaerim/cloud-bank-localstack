# ─────────────────────────────────────────────
# main.tf — Root module
# ─────────────────────────────────────────────

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

module "storage" {
  source                 = "./modules/storage"
  project_name           = var.project_name
  environment            = var.environment
  kyc_bucket_name        = var.kyc_bucket_name
  statements_bucket_name = var.statements_bucket_name
  tags                   = local.common_tags
}

module "database" {
  source       = "./modules/database"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
  
  # Phase 1: Wire networking to database
  db_subnet_ids = module.networking.db_subnet_ids
  vpc_id        = module.networking.vpc_id
}

module "messaging" {
  source                  = "./modules/messaging"
  project_name            = var.project_name
  environment             = var.environment
  transaction_queue_name  = var.transaction_queue_name
  notification_topic_name = var.notification_topic_name
  tags                    = local.common_tags
}

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
  
  # Phase 1: Wire networking to compute
  lambda_subnet_ids         = module.networking.private_subnet_ids
  lambda_security_group_id  = module.networking.lambda_security_group_id
}

module "api_gateway" {
  source             = "./modules/api_gateway"
  project_name       = var.project_name
  environment        = var.environment
  lambda_invoke_arns = module.compute.lambda_invoke_arns
  tags               = local.common_tags
}

module "monitoring" {
  source       = "./modules/monitoring"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}
