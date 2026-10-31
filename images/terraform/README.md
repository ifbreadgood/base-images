# Terraform Base Images

Multi-stage, BuildKit-optimized images for Terraform workflows.

## Variants

- **`terraform-runner`** (Default): Includes Terraform v1.17+, TFLint, Checkov, Git, Curl, JQ, and OpenSSH.
- **`terraform-base`**: Minimal image with Terraform v1.17+ and core CI tools.

## Build and Validate Locally

```bash
# Build runner image
docker build --target terraform-runner -t terraform-runner:test images/terraform

# Run validation tests
./images/terraform/tests/validate.sh terraform-runner:test runner
```
