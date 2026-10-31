#!/usr/bin/env bash
set -euo pipefail

# Helper to build and test images locally
# Usage: ./scripts/build.sh <image_dir_name> [--target <target>] [--test]

IMAGE_NAME="${1:-}"
shift || true

if [[ -z "$IMAGE_NAME" ]]; then
  echo "Usage: $0 <image_name> [--target <target_name>] [--test]"
  echo "Available images:"
  ls -1 images/
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="${REPO_ROOT}/images/${IMAGE_NAME}"

if [[ ! -d "$IMAGE_DIR" ]]; then
  echo "Error: Image directory '${IMAGE_DIR}' not found."
  exit 1
fi

TARGET=""
RUN_TEST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --test)
      RUN_TEST=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

TAG="${IMAGE_NAME}:test"
BUILD_ARGS=()

if [[ -n "$TARGET" ]]; then
  BUILD_ARGS+=(--target "$TARGET")
  TAG="${TARGET}:test"
fi

echo "==> Building ${IMAGE_NAME} (tag: ${TAG})..."
DOCKER_BUILDKIT=1 docker build \
  -f "${IMAGE_DIR}/Dockerfile" \
  "${BUILD_ARGS[@]}" \
  -t "${TAG}" \
  "${IMAGE_DIR}"

if [[ "$RUN_TEST" == true ]]; then
  if [[ -f "${IMAGE_DIR}/tests/validate.sh" ]]; then
    echo "==> Running validation tests for ${TAG}..."
    "${IMAGE_DIR}/tests/validate.sh" "${TAG}" "${TARGET}"
  else
    echo "Warning: No validation script found at ${IMAGE_DIR}/tests/validate.sh"
  fi
fi
