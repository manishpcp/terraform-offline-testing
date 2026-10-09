# Unit-style tests. The mock provider means no credentials and no network.
mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id                          = "lab-dev-artifacts"
      arn                         = "arn:aws:s3:::lab-dev-artifacts"
      bucket_regional_domain_name = "lab-dev-artifacts.s3.us-east-1.amazonaws.com"
    }
  }
}

variables {
  name        = "lab-dev-artifacts"
  environment = "dev"
  tags = {
    owner       = "platform-team"
    cost-center = "cc-1234"
  }
}

run "secure_defaults" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be true."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "Versioning must be enabled by default."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Without a KMS key the bucket must use SSE-S3 (AES256)."
  }

  assert {
    condition     = one(one(aws_s3_bucket_lifecycle_configuration.this.rule).noncurrent_version_expiration).noncurrent_days == 90
    error_message = "Noncurrent versions should expire after 90 days by default."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false."
  }

  assert {
    condition     = aws_s3_bucket.this.tags["managed-by"] == "terraform" && aws_s3_bucket.this.tags["environment"] == "dev"
    error_message = "The module must add managed-by and environment tags."
  }
}

run "prod_uses_customer_managed_key" {
  command = plan

  variables {
    environment = "prod"
    kms_key_arn = "arn:aws:kms:us-east-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "A KMS key must switch encryption to aws:kms."
  }

  assert {
    condition     = output.encryption.algorithm == "aws:kms" && output.encryption.kms_key_arn == var.kms_key_arn
    error_message = "The encryption output must reflect the KMS key."
  }
}

# command = apply against the mock provider "creates" resources in memory only.
# Computed values (arn, id) come from the mock defaults above, so the policy
# document can be inspected.
run "policy_denies_insecure_transport" {
  command = apply

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement[0].Effect == "Deny"
    error_message = "The bucket policy must deny requests that do not use TLS."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "The deny statement must be conditioned on aws:SecureTransport being false."
  }

  assert {
    condition     = contains(jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement[0].Resource, "${output.bucket_arn}/*")
    error_message = "The policy must cover objects as well as the bucket itself."
  }

  assert {
    condition     = output.bucket_arn == "arn:aws:s3:::lab-dev-artifacts"
    error_message = "bucket_arn output is not wired to the bucket resource."
  }
}
