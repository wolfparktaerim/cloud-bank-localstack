# KMS is not supported in LocalStack community.
# We output a placeholder ARN that has the correct
# format so other modules can reference it without
# breaking. In real AWS this would be the actual key ARN.
output "kms_key_arn" {
  value       = "arn:aws:kms:ap-southeast-1:000000000000:key/mock-kms-key-localstack"
  description = "Placeholder — real KMS key used in production AWS deployment"
}

output "kms_key_id" {
  value = "mock-kms-key-localstack"
}

output "secret_arns" {
  value = {
    db_password = aws_secretsmanager_secret.db_password.arn
    jwt_secret  = aws_secretsmanager_secret.jwt_secret.arn
    kyc_api_key = aws_secretsmanager_secret.kyc_api_key.arn
    abs_api_key = aws_secretsmanager_secret.abs_api_key.arn
  }
}

output "private_nacl_id" {
  value = aws_network_acl.private.id
}

output "public_nacl_id" {
  value = aws_network_acl.public.id
}
