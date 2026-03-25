output "kms_key_arn" {
  value       = aws_kms_key.main.arn
  description = "Primary KMS key ARN"
}

output "kms_alias_name" {
  value       = aws_kms_alias.main.name
  description = "Primary KMS alias"
}

output "rds_secret_arn" {
  value       = aws_secretsmanager_secret.rds_credentials.arn
  description = "RDS credentials secret ARN"
}

output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "WAFv2 Web ACL ARN"
}

output "guardduty_detector_id" {
  value       = try(aws_guardduty_detector.main[0].id, null)
  description = "GuardDuty detector ID"
}

output "acm_certificate_arn" {
  value       = aws_acm_certificate.main.arn
  description = "ACM certificate ARN"
}
