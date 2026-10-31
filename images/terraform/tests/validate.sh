#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-}"
TARGET_TYPE="${2:-runner}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <image-tag> [runner|base]"
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

log_info "Starting validation for image: ${IMAGE_TAG} (target: ${TARGET_TYPE})"

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
log_info "Verifying Terraform version v1.17..."
TF_VERSION_OUTPUT="$(docker run --rm "${IMAGE_TAG}" terraform version)"
echo "$TF_VERSION_OUTPUT"
if echo "$TF_VERSION_OUTPUT" | grep -qE "Terraform v1\.17\."; then
  log_pass "Terraform version 1.17 verified"
else
  log_fail "Terraform version v1.17 not detected in output"
fi

# 4. Terraform formatting and validation check
log_info "Validating Terraform code in test fixture..."
docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" terraform fmt -check || log_fail "terraform fmt failed"
docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" terraform init -backend=false || log_fail "terraform init failed"
docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" terraform validate || log_fail "terraform validate failed"
log_pass "Terraform initialization and validation passed"

# 5. Runner-specific tools validation (TFLint and Checkov)
if [[ "${TARGET_TYPE}" == "runner" ]]; then
  log_info "Verifying TFLint version and execution..."
  TFLINT_VERSION_OUTPUT="$(docker run --rm "${IMAGE_TAG}" tflint --version)"
  echo "$TFLINT_VERSION_OUTPUT"
  if echo "$TFLINT_VERSION_OUTPUT" | grep -qi "tflint"; then
    log_pass "TFLint binary detected"
  else
    log_fail "TFLint verification failed"
  fi

  docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" tflint || log_fail "tflint execution failed"
  log_pass "TFLint linting passed"

  log_info "Verifying Checkov version and security scan execution..."
  CHECKOV_VERSION_OUTPUT="$(docker run --rm "${IMAGE_TAG}" checkov --version)"
  echo "Checkov version: ${CHECKOV_VERSION_OUTPUT}"
  if [[ -n "${CHECKOV_VERSION_OUTPUT}" ]]; then
    log_pass "Checkov version detected: ${CHECKOV_VERSION_OUTPUT}"
  else
    log_fail "Checkov version check failed"
  fi

  docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" checkov \
    --directory /workspace \
    --framework terraform \
    --quiet \
    --compact || log_fail "Checkov scan failed"
  log_pass "Checkov security scan passed"
fi

echo -e "\n${GREEN}===============================================${NC}"
echo -e "${GREEN}  All validation tests passed successfully!   ${NC}"
echo -e "${GREEN}===============================================${NC}"
