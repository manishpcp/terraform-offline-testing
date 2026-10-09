# Negative tests: each run must FAIL validation in exactly the way we expect.
# If a validation rule is deleted or loosened, its run here starts failing.
mock_provider "aws" {}

variables {
  name        = "lab-dev-artifacts"
  environment = "dev"
  tags = {
    owner       = "platform-team"
    cost-center = "cc-1234"
  }
}

run "rejects_uppercase_and_underscores_in_name" {
  command = plan

  variables {
    name = "Lab_Dev_Artifacts"
  }

  expect_failures = [var.name]
}

run "rejects_reserved_name_prefix" {
  command = plan

  variables {
    name = "xn--lab-dev-artifacts"
  }

  expect_failures = [var.name]
}

run "rejects_sthree_prefix" {
  command = plan

  variables {
    name = "sthree-lab-dev-artifacts"
  }

  expect_failures = [var.name]
}

run "rejects_sthreeconfig_prefix" {
  command = plan

  variables {
    name = "sthreeconfig-lab-dev-artifacts"
  }

  expect_failures = [var.name]
}

run "rejects_amazonaws_prefix" {
  command = plan

  variables {
    name = "amazonaws-lab-dev-artifacts"
  }

  expect_failures = [var.name]
}

run "rejects_aws_prefix" {
  command = plan

  variables {
    name = "aws-lab-dev-artifacts"
  }

  expect_failures = [var.name]
}

run "rejects_reserved_name_suffix_ol_s3" {
  command = plan

  variables {
    name = "lab-dev--ol-s3"
  }

  expect_failures = [var.name]
}

run "rejects_reserved_name_suffix_mrap" {
  command = plan

  variables {
    name = "lab-dev-mrap"
  }

  expect_failures = [var.name]
}

run "rejects_reserved_name_suffix_x_s3" {
  command = plan

  variables {
    name = "lab-dev--x-s3"
  }

  expect_failures = [var.name]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [var.environment]
}

run "rejects_alias_instead_of_key_arn" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:111122223333:alias/my-key"
  }

  expect_failures = [var.kms_key_arn]
}

run "prod_requires_kms_key" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [var.kms_key_arn]
}

run "prod_requires_versioning" {
  command = plan

  variables {
    environment        = "prod"
    kms_key_arn        = "arn:aws:kms:us-east-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    versioning_enabled = false
  }

  expect_failures = [var.versioning_enabled]
}

run "prod_forbids_force_destroy" {
  command = plan

  variables {
    environment   = "prod"
    kms_key_arn   = "arn:aws:kms:us-east-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    force_destroy = true
  }

  expect_failures = [var.force_destroy]
}

run "rejects_zero_day_retention" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 0
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}

run "requires_owner_and_cost_center_tags" {
  command = plan

  variables {
    tags = {
      owner = "platform-team"
    }
  }

  expect_failures = [var.tags]
}

run "rejects_reserved_aws_tag_prefix" {
  command = plan

  variables {
    tags = {
      owner       = "platform-team"
      cost-center = "cc-1234"
      "aws:team"  = "x"
    }
  }

  expect_failures = [var.tags]
}
