# Terraform Base Images

Multi-stage, BuildKit-optimized base images for Terraform workflows.

## Variants

- **`terraform-1.16`**: Bundles Terraform v1.16.7, TFLint, and Checkov.
- **`terraform-1.17`**: Bundles Terraform v1.17.1, TFLint, and Checkov.

## Features

- **Pre-installed Validators**: Includes `tflint` and `checkov` inside the base image.
- **CI Tooling**: Bundled with `git`, `jq`, `curl`, and `openssh-client`.
- **Security Hardened**: Non-root user `terraform` (UID `10001`).

## Build and Validate Locally

```bash
# Build and test Terraform 1.16
docker build --target terraform-base --build-arg TERRAFORM_VERSION=1.16.7 -t terraform-1.16:test images/terraform
./images/terraform/tests/validate.sh terraform-1.16:test 1.16

# Build and test Terraform 1.17
docker build --target terraform-base --build-arg TERRAFORM_VERSION=1.17.1 -t terraform-1.17:test images/terraform
./images/terraform/tests/validate.sh terraform-1.17:test 1.17
```

A plain `docker build images/terraform` now produces the base image (final stage `terraform` aliases `terraform-base`). Use `--target test` to run the in-build smoke test.
