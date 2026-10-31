#!/usr/bin/env bash
set -euo pipefail

# Helper to build and test images locally
# Usage: ./scripts/build.sh <image_dir_name> [--target <target>] [--build-arg KEY=VALUE]...
#                           [--validation-arg <arg>] [--test]

USAGE="Usage: $0 <image_name> [--target <target_name>] [--build-arg KEY=VALUE]... [--validation-arg <arg>] [--test]"

IMAGE_NAME="${1:-}"
shift || true

if [[ -z "$IMAGE_NAME" ]]; then
  echo "$USAGE"
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
VALIDATION_ARG=""
RUN_TEST=false
EXTRA_BUILD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:?--target requires a value}"
      shift 2
      ;;
    --build-arg)
      EXTRA_BUILD_ARGS+=(--build-arg "${2:?--build-arg requires a value}")
      shift 2
      ;;
    --validation-arg)
      VALIDATION_ARG="${2:?--validation-arg requires a value}"
      shift 2
      ;;
    --test)
      RUN_TEST=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "$USAGE"
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

# Empty-array-safe expansion (Bash < 4.4 raises "unbound variable" under set -u)
echo "==> Building ${IMAGE_NAME} (tag: ${TAG})..."
DOCKER_BUILDKIT=1 docker build \
  -f "${IMAGE_DIR}/Dockerfile" \
  ${EXTRA_BUILD_ARGS[@]+"${EXTRA_BUILD_ARGS[@]}"} \
  ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} \
  -t "${TAG}" \
  "${IMAGE_DIR}"

if [[ "$RUN_TEST" == true ]]; then
  if [[ -f "${IMAGE_DIR}/tests/validate.sh" ]]; then
    echo "==> Running validation tests for ${TAG}..."
    # Only pass the validation argument when explicitly provided; the build target
    # name is not a valid validation argument.
    "${IMAGE_DIR}/tests/validate.sh" "${TAG}" ${VALIDATION_ARG:+"${VALIDATION_ARG}"}
  else
    echo "Warning: No validation script found at ${IMAGE_DIR}/tests/validate.sh"
  fi
fi
