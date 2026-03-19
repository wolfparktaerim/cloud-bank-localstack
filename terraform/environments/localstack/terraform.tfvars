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

# Storage
kyc_bucket_name        = "cloud-bank-kyc-documents-local"
statements_bucket_name = "cloud-bank-statements-local"

# Messaging
transaction_queue_name  = "cloud-bank-transactions-local"
notification_topic_name = "cloud-bank-notifications-local"
