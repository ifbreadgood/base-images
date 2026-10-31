# syntax=docker/dockerfile:1.7

ARG NODE_VERSION=22-bookworm-slim

FROM node:${NODE_VERSION} AS builder

LABEL maintainer="base-images" \
      org.opencontainers.image.title="Node.js Application Builder Base Image" \
      org.opencontainers.image.description="Optimized base image for building Node.js applications in CI/CD"

# hadolint ignore=DL3064
ARG USERNAME=node
ARG USER_UID=10001
ARG USER_GID=10001
ARG PNPM_VERSION=10.6.1
ARG YARN_VERSION=1.22.22

# Install essential build tools using BuildKit persistent apt cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Align the unprivileged user with the UID/GID used by the other images
RUN groupmod --gid ${USER_GID} ${USERNAME} \
    && usermod --uid ${USER_UID} --gid ${USER_GID} ${USERNAME}

# Enable Corepack for native Yarn and pnpm support
ENV COREPACK_DEFAULT_TO_LATEST=0 \
    PNPM_HOME="/home/node/.local/share/pnpm" \
    PATH="/home/node/.local/share/pnpm:${PATH}"

RUN corepack enable \
    && corepack prepare "pnpm@${PNPM_VERSION}" --activate \
    && corepack prepare "yarn@${YARN_VERSION}" --activate

# Prepare working directory
RUN mkdir -p /workspace /home/node/.npm /home/node/.cache \
    && chown -R ${USERNAME}:${USERNAME} /workspace /home/node

WORKDIR /workspace
USER ${USERNAME}

CMD ["node", "--version"]
