# Node.js Application Builder Image

Base image for building, testing, and packaging Node.js applications in CI/CD pipelines.

## Features

- Node.js 22 (LTS) on Debian Bookworm Slim.
- Multi-package manager support out-of-the-box (`npm`, `yarn`, `pnpm` via Corepack).
- Git, OpenSSH, and JQ pre-installed.
- Non-root user `node` (UID `1000`).

## Local Build & Validation

```bash
docker build -t nodejs-builder:test images/nodejs
./images/nodejs/tests/validate.sh nodejs-builder:test
```
