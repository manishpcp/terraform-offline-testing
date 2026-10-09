locals {
  sse_algorithm = var.kms_key_arn == null ? "AES256" : "aws:kms"

  tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform"
  })
}

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_18:Access logging needs a central log bucket, which is out of scope for this lab module.
  #checkov:skip=CKV_AWS_144:Cross-region replication is a per-workload decision, not a module default.
  #checkov:skip=CKV2_AWS_62:Event notifications are opt-in per workload.
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is the default for dev/stage. Prod requires a customer-managed KMS key enforced by variable validation.

  bucket        = var.name
  force_destroy = var.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = var.kms_key_arn != null

    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "housekeeping"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  # Applying the public access block first avoids S3 conflict errors on the policy call.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
