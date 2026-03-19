# ─────────────────────────────────────────────
# Module: storage
# Owner: Member 3
# Creates: S3 buckets for KYC docs, statements
# ─────────────────────────────────────────────

resource "aws_s3_bucket" "kyc_documents" {
  bucket = var.kyc_bucket_name

  tags = merge(var.tags, {
    Name    = var.kyc_bucket_name
    Purpose = "KYC identity documents — encrypted at rest"
  })
}

resource "aws_s3_bucket_versioning" "kyc_versioning" {
  bucket = aws_s3_bucket.kyc_documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kyc_encryption" {
  bucket = aws_s3_bucket.kyc_documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "kyc_block_public" {
  bucket                  = aws_s3_bucket.kyc_documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "statements" {
  bucket = var.statements_bucket_name

  tags = merge(var.tags, {
    Name    = var.statements_bucket_name
    Purpose = "Monthly account statements PDF"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "statements_lifecycle" {
  bucket = aws_s3_bucket.statements.id

  rule {
    id     = "archive-old-statements"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }
  }
}
