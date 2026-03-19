output "kyc_bucket_name" {
  value = aws_s3_bucket.kyc_documents.bucket
}

output "kyc_bucket_arn" {
  value = aws_s3_bucket.kyc_documents.arn
}

output "statements_bucket_name" {
  value = aws_s3_bucket.statements.bucket
}
