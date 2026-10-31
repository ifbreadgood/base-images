# syntax=docker/dockerfile:1.7

ARG PYTHON_VERSION=3.12-slim-bookworm
ARG TERRAFORM_VERSION=1.16.7

# ------------------------------------------------------------------------------
# Stage 1: Terraform Downloader (runs natively on build host for speed)
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:3.20 AS terraform-downloader

ARG TARGETARCH=amd64
ARG TERRAFORM_VERSION

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN apk add --no-cache curl unzip ca-certificates

WORKDIR /downloads

RUN ARCHIVE="terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
    && curl -fsSL -o "${ARCHIVE}" "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${ARCHIVE}" \
    && curl -fsSL -o tf_checksums "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && grep "${ARCHIVE}" tf_checksums | sha256sum -c - \
    && unzip "${ARCHIVE}" \
    && chmod 755 terraform \
    && rm -f "${ARCHIVE}" tf_checksums

# ------------------------------------------------------------------------------
# Stage 2: TFLint Downloader (runs natively on build host for speed)
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:3.20 AS tflint-downloader

ARG TARGETARCH=amd64
ARG TFLINT_VERSION=v0.65.0

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN apk add --no-cache curl unzip ca-certificates

WORKDIR /downloads

RUN ARCHIVE="tflint_linux_${TARGETARCH}.zip" \
    && curl -fsSL -o "${ARCHIVE}" "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/${ARCHIVE}" \
    && curl -fsSL -o tflint_checksums "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/checksums.txt" \
    && grep "${ARCHIVE}" tflint_checksums | sha256sum -c - \
    && unzip "${ARCHIVE}" \
    && chmod 755 tflint \
    && rm -f "${ARCHIVE}" tflint_checksums

# ------------------------------------------------------------------------------
# Stage 3: Checkov Python Builder
# ------------------------------------------------------------------------------
FROM python:${PYTHON_VERSION} AS checkov-builder

ARG CHECKOV_VERSION=3.4.0
ARG PIP_VERSION=25.0.1
ARG SETUPTOOLS_VERSION=75.8.2
ARG WHEEL_VERSION=0.45.1

# Install build dependencies with persistent apt cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libffi-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install checkov into isolated virtual environment with persistent pip cache
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv /opt/checkov-venv && \
    /opt/checkov-venv/bin/pip install "pip==${PIP_VERSION}" "setuptools==${SETUPTOOLS_VERSION}" "wheel==${WHEEL_VERSION}" && \
    /opt/checkov-venv/bin/pip install "checkov==${CHECKOV_VERSION}"

# ------------------------------------------------------------------------------
# Stage 4: Complete Terraform Base Image (includes TFLint & Checkov validators)
# ------------------------------------------------------------------------------
FROM python:${PYTHON_VERSION} AS terraform-base

ARG TERRAFORM_VERSION

LABEL maintainer="base-images" \
      org.opencontainers.image.title="Terraform Base Image" \
      org.opencontainers.image.description="Terraform v${TERRAFORM_VERSION} CI/CD base image with bundled TFLint and Checkov validators"

# hadolint ignore=DL3064
ARG USERNAME=terraform
ARG USER_UID=10001
ARG USER_GID=10001

# Install runtime utilities with persistent apt cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create unprivileged user
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && mkdir -p /workspace \
    && chown -R ${USERNAME}:${USERNAME} /workspace

# Install Terraform binary
COPY --from=terraform-downloader /downloads/terraform /usr/local/bin/terraform

# Install TFLint binary
COPY --from=tflint-downloader /downloads/tflint /usr/local/bin/tflint

# Install pre-built Checkov virtual environment
COPY --from=checkov-builder --chown=10001:10001 /opt/checkov-venv /opt/checkov-venv
RUN ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov

ENV PATH="/opt/checkov-venv/bin:${PATH}" \
    TF_IN_AUTOMATION=1 \
    TF_INPUT=0 \
    CHECK_TF_PLUGIN_CACHE_DIR=/workspace/.terraform.d/plugin-cache

WORKDIR /workspace
USER ${USERNAME}

CMD ["/bin/bash"]

# ------------------------------------------------------------------------------
# Stage 5: In-Build Smoke Test Target
# ------------------------------------------------------------------------------
FROM terraform-base AS test

USER 10001

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Execute verification checks inside container during BuildKit build
RUN terraform version | grep -E "Terraform v1\.(16|17)\." \
    && tflint --version \
    && checkov --version

# ------------------------------------------------------------------------------
# Stage 6: Default Final Stage
# Re-exposes terraform-base so a plain `docker build` produces the base image.
# Build `--target test` to run the in-build smoke test.
# ------------------------------------------------------------------------------
FROM terraform-base AS terraform
