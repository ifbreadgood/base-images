# Go Application Builder Image

Base image optimized for compiling Go applications in CI/CD pipelines.

## Features

- Non-root user `builder` (UID `10001`).
- Pre-configured `GOCACHE` (`/go/cache/build`) and `GOMODCACHE` (`/go/cache/mod`) ready for BuildKit cache mounts.
- Bundled with `golangci-lint`, `make`, `git`, and `jq`.

## Local Build & Validation

```bash
docker build -t golang-builder:test images/golang
./images/golang/tests/validate.sh golang-builder:test
```
