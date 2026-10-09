# Terraform Without Apply: Infrastructure Testing Lab

A starter repository that catches infrastructure mistakes before any cloud resource exists.

```
make check      # fmt, validate, tflint, checkov, terraform test, offline plan + plan scan
make test       # only terraform test (mock provider)
make demo-fail  # watch Checkov fail on an intentionally insecure fixture
```

Layout:

- `modules/secure-bucket/` reusable S3 module with typed variables, validation, outputs, and `tests/`
- `envs/dev/` example root module with an `offline` switch so `terraform plan` needs no credentials
- `fixtures/insecure-bucket/` deliberately bad configuration for demonstrating scanners
- `.github/workflows/ci.yml` pull request checks, with a single `all checks passed` gate job
- `scripts/bootstrap-ec2.sh` installs the toolchain on Ubuntu 24.04

Requires Terraform 1.9 or newer (cross-variable validation, `terraform test` with mock providers).
