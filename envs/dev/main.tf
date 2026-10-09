provider "aws" {
  region = var.region

  # Offline mode: no STS call, no account lookup, no instance metadata lookup.
  skip_credentials_validation = var.offline
  skip_requesting_account_id  = var.offline
  skip_metadata_api_check     = var.offline
  access_key                  = (var.offline || var.emulator_endpoint != null) ? "offline" : null
  secret_key                  = (var.offline || var.emulator_endpoint != null) ? "offline" : null

  # Optional emulator (LocalStack and similar).
  s3_use_path_style = var.emulator_endpoint != null

  dynamic "endpoints" {
    for_each = var.emulator_endpoint == null ? [] : [var.emulator_endpoint]
    content {
      s3  = endpoints.value
      sts = endpoints.value
    }
  }
}

module "artifacts" {
  source = "../../modules/secure-bucket"

  name        = "${var.project}-${var.environment}-artifacts"
  environment = var.environment

  tags = {
    owner       = "platform-team"
    cost-center = "cc-1234"
  }
}
