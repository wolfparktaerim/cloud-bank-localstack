# ─────────────────────────────────────────────
# Module: storage
# Owner: Member 3
# Creates: S3 buckets for KYC docs and statements
# ─────────────────────────────────────────────

# ── KYC Documents Bucket ─────────────────────
resource "aws_s3_bucket" "kyc_documents" {
  bucket = var.kyc_bucket_name
  # Note: tags omitted — LocalStack community rejects
  # certain tag value characters (e.g. colons in timestamps)
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

# ── Statements Bucket ─────────────────────────
resource "aws_s3_bucket" "statements" {
  bucket = var.statements_bucket_name
  # Note: tags omitted — LocalStack community tag limitation
}

resource "aws_s3_bucket_versioning" "statements_versioning" {
  bucket = aws_s3_bucket.statements.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "statements_block_public" {
  bucket                  = aws_s3_bucket.statements.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
