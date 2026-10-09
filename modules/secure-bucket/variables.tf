variable "name" {
  description = "Globally unique S3 bucket name (3-63 chars, lowercase letters, digits, hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "name must be 3-63 characters: lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }

  validation {
    condition = (
      !startswith(var.name, "xn--") &&
      !startswith(var.name, "sthree-") &&
      !startswith(var.name, "sthreeconfig-") &&
      !startswith(var.name, "amazonaws-") &&
      !startswith(var.name, "aws-") &&
      !endswith(var.name, "-s3alias") &&
      !endswith(var.name, "--ol-s3") &&
      !endswith(var.name, "-mrap") &&
      !endswith(var.name, "--x-s3")
    )
    error_message = "name must not use reserved S3 prefixes (xn--, sthree-, sthreeconfig-, amazonaws-, aws-) or suffixes (-s3alias, --ol-s3, -mrap, --x-s3)."
  }
}

variable "environment" {
  description = "Deployment environment. Drives which guardrails are mandatory."
  type        = string

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

variable "kms_key_arn" {
  description = "ARN of a customer-managed KMS key for default encryption. Null means SSE-S3 (AES256). Mandatory in prod."
  type        = string
  default     = null

  validation {
    condition = (
      var.kms_key_arn == null ||
      can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/(mrk-[a-f0-9]{32}|[a-f0-9-]{36})$", var.kms_key_arn))
    )
    error_message = "kms_key_arn must be a KMS key ARN (not an alias), for example arn:aws:kms:us-east-1:111122223333:key/<uuid>."
  }

  # Cross-variable validation requires Terraform 1.9 or newer.
  validation {
    condition     = var.environment != "prod" || var.kms_key_arn != null
    error_message = "kms_key_arn is required when environment is prod."
  }
}

variable "versioning_enabled" {
  description = "Whether S3 versioning is enabled. Must stay true in prod."
  type        = bool
  default     = true

  validation {
    condition     = var.environment != "prod" || var.versioning_enabled
    error_message = "versioning_enabled must be true when environment is prod."
  }
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket. Never allowed in prod."
  type        = bool
  default     = false

  validation {
    condition     = !(var.environment == "prod" && var.force_destroy)
    error_message = "force_destroy must be false when environment is prod."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent object versions expire (1-3650)."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1 && var.noncurrent_version_expiration_days <= 3650 && floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days
    error_message = "noncurrent_version_expiration_days must be a whole number between 1 and 3650."
  }
}

variable "tags" {
  description = "Resource tags. Must include 'owner' and 'cost-center'. Keys starting with 'aws:' are reserved."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["owner", "cost-center"] : contains(keys(var.tags), k)])
    error_message = "tags must include both 'owner' and 'cost-center'."
  }

  validation {
    condition     = alltrue([for k in keys(var.tags) : !startswith(lower(k), "aws:")])
    error_message = "tag keys must not start with 'aws:' (reserved prefix)."
  }
}
