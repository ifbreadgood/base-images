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

log_info "Starting validation for Node.js builder image: ${IMAGE_TAG}"

# 1. Non-root user validation
USER_NAME="$(docker run --rm "${IMAGE_TAG}" whoami)"
[[ "$USER_NAME" == "node" ]] || log_fail "Expected user 'node', got ${USER_NAME}"
log_pass "Container runs as non-root user (node)"

# 2. Runtimes and package managers
NODE_VER="$(docker run --rm "${IMAGE_TAG}" node --version)"
NPM_VER="$(docker run --rm "${IMAGE_TAG}" npm --version)"
PNPM_VER="$(docker run --rm "${IMAGE_TAG}" pnpm --version)"
YARN_VER="$(docker run --rm "${IMAGE_TAG}" yarn --version)"

log_pass "Node runtime: ${NODE_VER}"
log_pass "npm: ${NPM_VER}"
log_pass "pnpm: ${PNPM_VER}"
log_pass "yarn: ${YARN_VER}"

# 3. Execution test
log_info "Running test script in fixture directory..."
docker run --rm -v "${FIXTURE_DIR}:/workspace" -w /workspace "${IMAGE_TAG}" npm test || log_fail "npm test failed"
log_pass "npm test execution passed"

echo -e "\n${GREEN}All Node.js builder validation checks passed!${NC}"
