#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-}"
EXPECTED_VERSION="${2:-1.16}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <image-tag> [expected_version (1.16|1.17)]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/terraform-test"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  exit 1
}

log_info "Starting validation for Terraform base image: ${IMAGE_TAG}"

# 1. Non-root user validation
log_info "Checking container user UID..."
USER_ID="$(docker run --rm "${IMAGE_TAG}" id -u)"
if [[ "$USER_ID" == "10001" ]]; then
  log_pass "Container runs as non-root user (UID: ${USER_ID})"
else
  log_fail "Expected UID 10001, got: ${USER_ID}"
fi

# 2. Workspace directory validation
log_info "Checking working directory..."
WORKDIR="$(docker run --rm "${IMAGE_TAG}" pwd)"
if [[ "$WORKDIR" == "/workspace" ]]; then
  log_pass "Working directory is /workspace"
else
  log_fail "Expected /workspace, got: ${WORKDIR}"
fi

# 3. Terraform binary and version check
log_info "Verifying Terraform version v${EXPECTED_VERSION}..."
TF_VERSION_OUTPUT="$(docker run --rm "${IMAGE_TAG}" terraform version)"
echo "$TF_VERSION_OUTPUT"
if echo "$TF_VERSION_OUTPUT" | grep -qE "Terraform v${EXPECTED_VERSION}\."; then
  log_pass "Terraform version ${EXPECTED_VERSION} verified"
else
  log_fail "Terraform version v${EXPECTED_VERSION} not detected in output"
fi

# 4. Terraform formatting and validation check
# Fixtures are mounted read-only and copied to a writable scratch dir so that
# terraform/tflint/checkov never write artifacts into the host checkout.
run_in_fixture() {
  docker run --rm -v "${FIXTURE_DIR}:/fixtures:ro" "${IMAGE_TAG}" \
    bash -euo pipefail -c 'mkdir -p /tmp/work && cp -r /fixtures/. /tmp/work/ && cd /tmp/work && eval "$1"' _ "$1"
}

log_info "Validating Terraform code in test fixture..."
run_in_fixture "terraform fmt -check" || log_fail "terraform fmt failed"
run_in_fixture "terraform init -backend=false && terraform validate" || log_fail "terraform init/validate failed"
log_pass "Terraform initialization and validation passed"

# 5. Bundled validators verification (TFLint and Checkov)
log_info "Verifying bundled TFLint validator..."
TFLINT_VERSION_OUTPUT="$(docker run --rm "${IMAGE_TAG}" tflint --version)"
echo "$TFLINT_VERSION_OUTPUT"
if echo "$TFLINT_VERSION_OUTPUT" | grep -qi "tflint"; then
  log_pass "TFLint binary detected"
else
  log_fail "TFLint verification failed"
fi

run_in_fixture "tflint" || log_fail "tflint execution failed"
log_pass "TFLint linting passed"

log_info "Verifying bundled Checkov validator..."
CHECKOV_VERSION_OUTPUT="$(docker run --rm "${IMAGE_TAG}" checkov --version)"
echo "Checkov version: ${CHECKOV_VERSION_OUTPUT}"
if [[ -n "${CHECKOV_VERSION_OUTPUT}" ]]; then
  log_pass "Checkov version detected: ${CHECKOV_VERSION_OUTPUT}"
else
  log_fail "Checkov version check failed"
fi

run_in_fixture "checkov --directory /tmp/work --framework terraform --quiet --compact" || log_fail "Checkov scan failed"
log_pass "Checkov security scan passed"

echo -e "\n${GREEN}===============================================${NC}"
echo -e "${GREEN}  All validation tests passed successfully!   ${NC}"
echo -e "${GREEN}===============================================${NC}"
