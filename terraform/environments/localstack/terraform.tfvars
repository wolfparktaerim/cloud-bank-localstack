# environments/localstack/terraform.tfvars
# Used when running: terraform apply -var-file="environments/localstack/terraform.tfvars"

aws_region   = "ap-southeast-1"
environment  = "localstack"
project_name = "cloud-bank"

# Compute
lambda_runtime = "python3.11"

# Database — lightweight for local dev
db_instance_class = "db.t3.micro"
db_name           = "cloudbank"
db_username       = "admin"
db_password       = "LocalDev123!"
enable_rds_instance = true

# Storage
kyc_bucket_name        = "cloud-bank-kyc-documents-local"
statements_bucket_name = "cloud-bank-statements-local"

# Messaging
transaction_queue_name  = "cloud-bank-transactions-local"
notification_topic_name = "cloud-bank-notifications-local"

# Cognito
cognito_callback_urls = ["http://localhost:3000/callback"]
cognito_logout_urls   = ["http://localhost:3000/logout"]
cognito_domain_prefix = "cloud-bank-local-auth"
enable_cognito_hosted_ui_domain = false

# Phase 3: Edge services
route53_zone_name   = "cloud-bank.local"
route53_record_name = "api.cloud-bank.local"

# Phase 4B: Data platform
enable_elasticache     = true
enable_glue            = true
elasticache_cluster_id = "cloud-bank-redis"
glue_database_name     = "cloud_bank_analytics"
glue_table_name        = "transactions_raw"
glue_s3_target_path    = "s3://cloud-bank-statements-local/glue"

# Phase 5: Security
acm_domain_name = "cloud-bank.local"
enable_guardduty = false

# Phase 6: Observability
cloudtrail_s3_bucket_name = "cloud-bank-statements-local"
cloudtrail_trail_name     = "cloud-bank-audit-trail"
backup_vault_name         = "cloud-bank-backup-vault"
backup_plan_name          = "cloud-bank-backup-plan"
