# Terraform Without Apply: Infrastructure Testing Lab



A production-ready starter repository that catches infrastructure mistakes before any cloud resource exists. All validation runs offline—no AWS credentials, no IAM roles, no cloud API calls.

**Repository:** https://github.com/manishpcp/terraform-offline-testing

**Blog Post:** [Terraform Without Apply: Build an Infrastructure Testing Lab on EC2](https://builder.aws.com/content/3KRqA1JGQ2tk8gLwggDr9Wrtw3t/terraform-testing-without-aws-build-an-offline-infrastructure-validation-pipeline)

## Quick Start

```bash
# Clone and run the full validation suite
git clone https://github.com/manishpcp/terraform-offline-testing.git
cd terraform-offline-testing
make check
```

### Common Commands

```bash
make check        # Full suite: fmt, validate, tflint, checkov, terraform test, offline plan + plan scan
make test         # Only terraform test (mock provider, no credentials)
make demo-fail    # Watch Checkov fail on an intentionally insecure fixture
make clean        # Remove .terraform directories and generated plans
```

## Architecture

```
terraform-offline-testing/
├── modules/
│   └── secure-bucket/       # Reusable S3 module with:
│       ├── main.tf          #   - Versioning, encryption, lifecycle, public access block, TLS-only policy
│       ├── variables.tf     #   - Typed variables with validation (incl. cross-variable rules for prod)
│       ├── outputs.tf       #   - Documented outputs
│       ├── versions.tf      #   - Pinned Terraform >=1.9, AWS provider 6.x
│       ├── .terraform.lock.hcl
│       └── tests/
│           ├── valid_inputs.tftest.hcl    # 3 test runs: secure defaults, prod KMS, TLS policy
│           └── invalid_inputs.tftest.hcl  # 10 negative tests for every validation rule
├── envs/
│   └── dev/                 # Example root module with:
│       ├── main.tf          #   - AWS provider with `offline` switch (no credentials needed)
│       ├── variables.tf     #   - Region, project, environment, offline, emulator_endpoint
│       ├── outputs.tf
│       ├── versions.tf
│       └── .terraform.lock.hcl
├── fixtures/
│   └── insecure-bucket/     # Deliberately bad config for scanner demos
├── .github/
│   └── workflows/
│       └── ci.yml           # PR checks: static, unit-tests, plan, gate (pinned by SHA)
├── scripts/
│   └── bootstrap-ec2.sh     # Installs pinned Terraform 1.12.2, TFLint v0.58.0, Checkov 3.2.443 on Ubuntu 24.04
├── .tflint.hcl              # TFLint config (terraform + aws rulesets, v0.44.0)
├── .checkov.yaml            # Checkov config (terraform + terraform_plan frameworks)
├── Makefile                 # One-command validation suite
└── .gitignore               # Excludes .terraform/, state, plans; KEEPS lock files
```

## Validation Layers (Rungs of the Ladder)

| Rung | Check | Needs AWS Credentials? | Needs AWS Network? | Typical Time |
|------|-------|------------------------|--------------------|--------------|
| 1 | `terraform fmt` | No | No | < 1s |
| 2 | `terraform validate` | No | No (after `init`) | seconds |
| 3 | TFLint, Checkov (code scan) | No | No | seconds |
| 4 | `terraform test` (mock provider) | No | No | seconds |
| 5 | `terraform plan` (offline mode) | No (dummy) | No | seconds |
| 6 | `terraform plan` (real account) | Read access | Yes | tens of seconds |
| 7 | `terraform apply` (sandbox) | Write access | Yes | minutes |

**This lab covers rungs 1–5 completely.** Rungs 6–7 require a real AWS account.

## What Each Layer Catches

| Mistake | First Layer That Catches It |
|---------|----------------------------|
| Inconsistent formatting | `terraform fmt -check` |
| Typo in resource attribute, undeclared variable | `terraform validate` |
| Uppercase/reserved bucket name | Variable validation → negative test |
| Unused variable, undocumented variable | TFLint |
| Public ACL, missing encryption, open SSH | Checkov |
| Missing TLS-only bucket policy | `terraform test` (mock apply) |
| Plan would destroy/replace resources | Plan JSON guard (`jq`) |
| Bucket name already taken globally | Real `apply` only |
| Missing IAM permission / SCP denial | Real plan or apply only |

## Key Features

### 1. Offline Provider Mode
The `envs/dev` root module uses an `offline` variable that sets:
```hcl
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
access_key = "offline"
secret_key = "offline"
```
This lets `terraform plan` run without any AWS credentials or network access to AWS.

### 2. Comprehensive Variable Validation
- S3 bucket naming: lowercase, hyphens, 3-63 chars, no reserved prefixes/suffixes
- Environment must be `dev`, `stage`, or `prod`
- **Prod requires** customer-managed KMS key (`kms_key_arn`), versioning enabled, `force_destroy = false`
- Tags must include `owner` and `cost-center`; no `aws:*` prefix

### 3. Mock Provider Tests
- `secure_defaults`: All 4 public access block settings true, versioning enabled, SSE-S3 default
- `prod_uses_customer_managed_key`: Supplying KMS key flips encryption to `aws:kms`
- `policy_denies_insecure_transport`: Mock `apply` makes computed values available to decode and assert on bucket policy

### 4. Negative Tests (Guardrails)
10 `expect_failures` runs ensure validation rules can't be silently weakened:
- Uppercase/underscores in name
- Reserved prefixes (`xn--`, `sthree-`, `sthreeconfig-`, `amazonaws-`, `aws-`)
- Reserved suffixes (`-s3alias`, `--ol-s3`, `-mrap`, `--x-s3`)
- Unknown environment
- KMS alias instead of key ARN
- Prod without KMS key / versioning / with force_destroy
- Zero-day retention
- Missing required tags / reserved `aws:` tag prefix

### 5. CI Pipeline (GitHub Actions)
- **static**: fmt → init/validate → TFLint → Checkov (code scan)
- **unit-tests**: `terraform test` with mock provider
- **plan**: Offline plan → Checkov (plan scan, with explicit CKV_AWS_145 skip for dev SSE-S3) → delete guard
- **gate**: Fails if any required job failed, was cancelled, or was skipped
- All actions pinned by full commit SHA
- Tool versions pinned: Terraform 1.12.2, TFLint v0.58.0, Checkov 3.2.443

### 6. Reproducibility
- Provider lock files (`.terraform.lock.hcl`) committed for both module and environment
- Exact tool versions in CI, bootstrap script, and documentation
- No floating version ranges

## Requirements

- **Terraform** ≥ 1.9.0 (cross-variable validation, mock providers)
- **AWS Provider** 6.x (tested with 6.68.0)
- **TFLint** v0.58.0 with `terraform` (recommended preset) and `aws` (v0.44.0) rulesets
- **Checkov** 3.2.443
- **make**, **jq**, **git**

## Bootstrap an EC2 Lab Machine

```bash
# On Ubuntu 24.04 (t3.small, no IAM role, IMDSv2 required)
chmod +x scripts/bootstrap-ec2.sh
./scripts/bootstrap-ec2.sh
source ~/.bashrc
```

The script installs pinned versions of Terraform, TFLint, and Checkov (in a venv), plus `make`, `jq`, `git`.

## What "Offline" Means Here

> **Terminology note.** "Offline" in this lab means *no AWS API calls and no AWS credentials required*. The toolchain still requires internet access to download the Terraform AWS provider, TFLint plugins, and Checkov unless they are already cached. In a fully air-gapped environment you would need to pre-download and vendor these dependencies.

## Security Exceptions

The secure-bucket module has four deliberate Checkov skips, each with a reason:

| Check | Skip Reason |
|-------|-------------|
| `CKV_AWS_18` | Access logging needs a central log bucket (out of scope) |
| `CKV_AWS_144` | Cross-region replication is a per-workload decision |
| `CKV2_AWS_62` | Event notifications are opt-in per workload |
| `CKV_AWS_145` | **SSE-S3 (AES256) is the default for dev/stage. Prod requires a customer-managed KMS key enforced by variable validation.** |

The plan scan in CI explicitly skips `CKV_AWS_145` for the `dev` environment (which correctly uses SSE-S3). For production, run the plan with `environment=prod` and `kms_key_arn` set—the plan will use SSE-KMS and pass CKV_AWS_145 without a skip.

## Pre-Deployment Checklist

### Automated (blocking in CI)
- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform init -backend=false` and `terraform validate` pass everywhere
- [ ] TFLint reports no findings
- [ ] Checkov passes with no unexplained skips
- [ ] `terraform test` passes (including all negative tests)
- [ ] Offline `terraform plan` succeeds and plan scan passes
- [ ] Plan contains no unexpected deletes or replacements
- [ ] `.terraform.lock.hcl` committed and unchanged unless intentionally upgraded

### Human Review
- [ ] Plan summary matches intent of the change
- [ ] Any new `#checkov:skip` has an accepted reason
- [ ] **For prod: plan uses a customer-managed KMS key (SSE-KMS), not SSE-S3**
- [ ] Naming, tags, ownership follow standards
- [ ] Anything marked `(known after apply)` has been considered

### Requires Real Environment
- [ ] Globally unique names are available
- [ ] Deploying role has permissions, not blocked by SCPs/boundaries
- [ ] Service quotas sufficient
- [ ] External resources (KMS keys, VPCs, hosted zones) exist, correct region, compatible policies
- [ ] Read-only plan against target account shows no drift
- [ ] Applied to sandbox first, with smoke test and successful destroy
- [ ] Rollback/recovery path exists for stateful resources

## Clean Up

1. Terminate the EC2 instance (no IAM role → nothing to revoke)
2. Delete key pair and security group if created for this lab
3. Review authorized apps in GitHub settings if `gh auth login` was used
4. No `terraform destroy` needed—nothing was created in AWS

## Next Steps

- Add more modules with their own `tests/` folders
- Add a read-only plan job using GitHub OIDC to a real AWS account
- Wire the `plan-guard` into an approval workflow
- Run a scheduled sandbox apply-and-destroy job to cover rungs 6–7