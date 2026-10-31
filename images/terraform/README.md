# Terraform Base Image

Multi-stage, BuildKit-optimized base image for Terraform workflows.

## Features

- **Terraform v1.16+** (default `1.16.7`).
- **Pre-installed Validators**: Includes `tflint` and `checkov` inside the base image.
- **CI Tooling**: Bundled with `git`, `jq`, `curl`, and `openssh-client`.
- **Security Hardened**: Non-root user `terraform` (UID `10001`).

## Build and Validate Locally

```bash
# Build base image
docker build --target terraform-base -t terraform-base:test images/terraform

# Run validation tests
./images/terraform/tests/validate.sh terraform-base:test
```
