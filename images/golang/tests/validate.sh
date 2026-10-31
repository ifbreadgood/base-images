#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-}"

if [[ -z "$IMAGE_TAG" ]]; then
  echo "Usage: $0 <image-tag>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

log_info "Starting validation for Go builder image: ${IMAGE_TAG}"

# 1. Non-root user validation
USER_ID="$(docker run --rm "${IMAGE_TAG}" id -u)"
[[ "$USER_ID" == "10001" ]] || log_fail "Expected UID 10001, got ${USER_ID}"
log_pass "Container runs as non-root user (UID 10001)"

# 2. Go binary check
GO_VERSION="$(docker run --rm "${IMAGE_TAG}" go version)"
log_pass "Go runtime available: ${GO_VERSION}"

# 3. Linter check
LINT_VERSION="$(docker run --rm "${IMAGE_TAG}" golangci-lint --version)"
log_pass "golangci-lint available: ${LINT_VERSION}"

# 4. Compilation test
log_info "Testing application build in fixture directory..."
docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" go build -o /tmp/app main.go || log_fail "Go build failed"
log_pass "Go build succeeded"

echo -e "\n${GREEN}All Go builder validation checks passed!${NC}"
