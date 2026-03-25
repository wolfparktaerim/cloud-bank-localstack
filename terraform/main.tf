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
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  enable_rds_instance = var.enable_rds_instance
  
  # Phase 1: Wire networking to database
  db_subnet_ids         = module.networking.db_subnet_ids
  vpc_id                = module.networking.vpc_id
  rds_security_group_id = module.networking.rds_security_group_id
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

module "cognito" {
  source                = "./modules/cognito"
  project_name          = var.project_name
  environment           = var.environment
  cognito_callback_urls = var.cognito_callback_urls
  cognito_logout_urls   = var.cognito_logout_urls
  cognito_domain_prefix = var.cognito_domain_prefix
  enable_hosted_ui_domain = var.enable_cognito_hosted_ui_domain
  tags                  = local.common_tags
}

module "api_gateway" {
  source             = "./modules/api_gateway"
  project_name       = var.project_name
  environment        = var.environment
  lambda_invoke_arns = module.compute.lambda_invoke_arns
  cognito_user_pool_arn = module.cognito.user_pool_arn
  tags               = local.common_tags
}

module "edge" {
  source = "./modules/edge"

  project_name                = var.project_name
  environment                 = var.environment
  tags                        = local.common_tags
  vpc_id                      = module.networking.vpc_id
  public_subnet_ids           = module.networking.public_subnet_ids
  lambda_target_function_name = module.compute.lambda_function_names["accounts"]
  lambda_target_function_arn  = module.compute.lambda_function_arns["accounts"]
  route53_zone_name           = var.route53_zone_name
  route53_record_name         = var.route53_record_name
}

module "monitoring" {
  source       = "./modules/monitoring"
  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}
