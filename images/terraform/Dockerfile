# syntax=docker/dockerfile:1.7

ARG PYTHON_VERSION=3.12-slim-bookworm

# ------------------------------------------------------------------------------
# Stage 1: Terraform Downloader (runs natively on build host for speed)
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:3.20 AS terraform-downloader

ARG TARGETARCH
ARG TERRAFORM_VERSION=1.17.1

RUN apk add --no-cache curl unzip ca-certificates

WORKDIR /downloads

RUN curl -fsSL -o terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
    && curl -fsSL -o tf_checksums "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && grep "terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" tf_checksums | sha256sum -c - \
    && unzip terraform.zip \
    && chmod 755 terraform \
    && rm terraform.zip tf_checksums

# ------------------------------------------------------------------------------
# Stage 2: TFLint Downloader (runs natively on build host for speed)
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:3.20 AS tflint-downloader

ARG TARGETARCH
ARG TFLINT_VERSION=v0.65.0

RUN apk add --no-cache curl unzip ca-certificates

WORKDIR /downloads

RUN curl -fsSL -o tflint.zip "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_${TARGETARCH}.zip" \
    && curl -fsSL -o tflint_checksums "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/checksums.txt" \
    && grep "tflint_linux_${TARGETARCH}.zip" tflint_checksums | sha256sum -c - \
    && unzip tflint.zip \
    && chmod 755 tflint \
    && rm tflint.zip tflint_checksums

# ------------------------------------------------------------------------------
# Stage 3: Checkov Python Builder
# ------------------------------------------------------------------------------
FROM python:${PYTHON_VERSION} AS checkov-builder

ARG CHECKOV_VERSION=3.4.0

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
    /opt/checkov-venv/bin/pip install --upgrade pip setuptools wheel && \
    /opt/checkov-venv/bin/pip install "checkov==${CHECKOV_VERSION}"

# ------------------------------------------------------------------------------
# Stage 4: Minimal Terraform Base Image
# ------------------------------------------------------------------------------
FROM python:${PYTHON_VERSION} AS terraform-base

LABEL maintainer="base-images" \
      org.opencontainers.image.title="Terraform Base CI Image" \
      org.opencontainers.image.description="Minimal Terraform CI runner image with core utilities"

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

ENV TF_IN_AUTOMATION=1 \
    TF_INPUT=0

WORKDIR /workspace
USER ${USERNAME}

CMD ["/bin/bash"]

# ------------------------------------------------------------------------------
# Stage 5: Full Terraform Runner (Terraform v1.17 + TFLint + Checkov)
# ------------------------------------------------------------------------------
FROM terraform-base AS terraform-runner

LABEL org.opencontainers.image.title="Terraform Runner Image" \
      org.opencontainers.image.description="Terraform CI/CD runner containing Terraform v1.17, TFLint, and Checkov"

USER root

# Install TFLint binary
COPY --from=tflint-downloader /downloads/tflint /usr/local/bin/tflint

# Copy pre-built Checkov virtual environment with correct permissions
COPY --from=checkov-builder --chown=10001:10001 /opt/checkov-venv /opt/checkov-venv
RUN ln -s /opt/checkov-venv/bin/checkov /usr/local/bin/checkov

ENV PATH="/opt/checkov-venv/bin:${PATH}" \
    CHECK_TF_PLUGIN_CACHE_DIR=/workspace/.terraform.d/plugin-cache

USER 10001

CMD ["/bin/bash"]

# ------------------------------------------------------------------------------
# Stage 6: In-Build Smoke Test Target
# ------------------------------------------------------------------------------
FROM terraform-runner AS test

USER 10001

# Execute verification checks inside container during BuildKit build
RUN terraform version | grep -E "Terraform v1\.17\." \
    && tflint --version \
    && checkov --version
