# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.26-bookworm

# ------------------------------------------------------------------------------
# Stage 1: Tools Downloader
# ------------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:3.20 AS tools-downloader

ARG GOLANGCI_LINT_VERSION=v2.15.0
ARG TARGETARCH=amd64

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

RUN apk add --no-cache curl tar

WORKDIR /downloads

RUN ARCHIVE="golangci-lint-${GOLANGCI_LINT_VERSION#v}-linux-${TARGETARCH}.tar.gz" \
    && BASE_URL="https://github.com/golangci/golangci-lint/releases/download/${GOLANGCI_LINT_VERSION}" \
    && curl -fsSL -o "${ARCHIVE}" "${BASE_URL}/${ARCHIVE}" \
    && curl -fsSL -o checksums.txt "${BASE_URL}/golangci-lint-${GOLANGCI_LINT_VERSION#v}-checksums.txt" \
    && grep " ${ARCHIVE}\$" checksums.txt | sha256sum -c - \
    && tar -xz --strip-components=1 -f "${ARCHIVE}" \
    && chmod 755 golangci-lint \
    && rm -f "${ARCHIVE}" checksums.txt

# ------------------------------------------------------------------------------
# Stage 2: Go Application Builder Image
# ------------------------------------------------------------------------------
FROM golang:${GO_VERSION} AS builder

LABEL maintainer="base-images" \
      org.opencontainers.image.title="Go Application Builder Base Image" \
      org.opencontainers.image.description="Optimized base image for building Go applications in CI/CD"

ARG USERNAME=builder
ARG USER_UID=10001
ARG USER_GID=10001

# Apply pending Debian security updates (base image lags behind fixed packages), then
# install runtime utilities using persistent BuildKit apt cache
# hadolint ignore=DL3005
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install golangci-lint
COPY --from=tools-downloader /downloads/golangci-lint /usr/local/bin/golangci-lint

# Configure Go cache directories for BuildKit cache mounts
ENV GOPATH=/go \
    GOCACHE=/go/cache/build \
    GOMODCACHE=/go/cache/mod \
    CGO_ENABLED=0

# Create unprivileged user with access to go cache directories
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && mkdir -p /workspace /go/cache/build /go/cache/mod /go/bin /go/pkg \
    && chown -R ${USERNAME}:${USERNAME} /workspace /go

WORKDIR /workspace
USER ${USERNAME}

CMD ["go", "version"]
