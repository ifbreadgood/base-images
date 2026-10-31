# Base Images Repository

Scalable, multi-image monorepo containing production-ready, security-hardened base images for application compilation, tooling, and DevOps pipelines.

## Directory Structure

```text
.
├── .github/
│   ├── dependabot.yml              # Automated Actions / Dockerfile base image updates
│   └── workflows/
│       └── build-and-validate.yml  # Matrix CI build, caching, scanning, and validation
├── .dockerignore
├── LICENSE
├── scripts/
│   ├── generate-matrix.sh          # Dynamic matrix generator for GitHub Actions
│   └── build.sh                    # Local build and validation CLI
└── images/
    ├── terraform/                  # Terraform v1.16 & v1.17 base images with bundled TFLint & Checkov
    │   ├── Dockerfile
    │   ├── image.json              # Image metadata and targets
    │   ├── README.md
    │   └── tests/
    │       ├── validate.sh         # Validation test suite
    │       └── fixtures/           # Terraform validation fixtures
    ├── golang/                     # Go application build image (GOCACHE mounts)
    │   ├── Dockerfile
    │   ├── image.json
    │   ├── README.md
    │   └── tests/
    │       ├── validate.sh
    │       └── fixtures/
    └── nodejs/                     # Node.js application build image (npm, yarn, pnpm)
        ├── Dockerfile
        ├── image.json
        ├── README.md
        └── tests/
            ├── validate.sh
            └── fixtures/
```

## Prerequisites

- `docker` with BuildKit / Buildx
- `bash` (any version; scripts are safe for macOS `/bin/bash` 3.2)
- `perl` with the core `JSON::PP` module (used by `scripts/generate-matrix.sh`)
- `git`

## Image Catalog

| Image | Variants (`image.json` targets) | Base OS | Bundled tools | User (UID/GID) |
| :--- | :--- | :--- | :--- | :--- |
| `terraform` | `terraform-1.16` (v1.16.7), `terraform-1.17` (v1.17.1) | Debian Bookworm (`python:3.12-slim`) | Terraform, TFLint, Checkov, `git`, `jq`, `curl`, `openssh-client` | `terraform` (10001/10001) |
| `golang` | `golang-builder` | Debian Bookworm (`golang:1.24`) | `golangci-lint`, `make`, `git`, `jq`, `curl`, `openssh-client` | `builder` (10001/10001) |
| `nodejs` | `nodejs-builder` | Debian Bookworm Slim (`node:22`) | npm, pnpm, Yarn (pinned via Corepack), `git`, `jq`, `curl`, `openssh-client` | `node` (10001/10001) |

Runtime environment variables: `terraform` sets `TF_IN_AUTOMATION=1`, `TF_INPUT=0`; `golang` sets `GOPATH`, `GOCACHE`, `GOMODCACHE`, `CGO_ENABLED=0`; `nodejs` sets `PNPM_HOME`, `COREPACK_DEFAULT_TO_LATEST=0`.

## Adding a New Image

To add a new base image (e.g., `images/python` or `images/rust`):

1. Create a directory `images/<name>/`.
2. Add a `Dockerfile` utilizing BuildKit caching (`--mount=type=cache`).
3. Add `image.json` specifying targets, optional build arguments, and validation arguments:
   ```json
   {
     "name": "my-image",
     "description": "My custom base image",
     "targets": [
       {
         "name": "my-image-builder",
         "target": "builder",
         "build_args": {
           "TOOL_VERSION": "1.2.3"
         },
         "validation_arg": "builder",
         "default": true
       }
     ]
   }
   ```
   `build_args` (optional) is an object of Docker `--build-arg` key/values; `validation_arg` (optional) is passed as the second argument to `tests/validate.sh`.
4. Add `tests/validate.sh` and make it executable (`chmod +x`).
5. (Optional) Provide test fixtures under `tests/fixtures/`.

GitHub Actions automatically detects changes in `images/<name>/` and builds/validates only the modified images. Changes to `scripts/` or `.github/workflows/` rebuild **all** images.

## Local Development & Testing

Use the unified helper script:

```bash
# Build and test Terraform 1.16 base image
./scripts/build.sh terraform --target terraform-base --build-arg TERRAFORM_VERSION=1.16.7 --validation-arg 1.16 --test

# Build and test Terraform 1.17 base image
./scripts/build.sh terraform --target terraform-base --build-arg TERRAFORM_VERSION=1.17.1 --validation-arg 1.17 --test

# Build and test Go builder
./scripts/build.sh golang --test

# Build and test Node.js builder
./scripts/build.sh nodejs --test
```

`--validation-arg` is forwarded to `tests/validate.sh` only when provided (the build target name is never used as a validation argument).

## CI/CD & Registry Consumption

On pushes to `main` (or `workflow_dispatch` with `push_images: true`), images are validated, scanned with Trivy (fails on fixable `CRITICAL`/`HIGH` CVEs), and pushed to GHCR with provenance and SBOM attestations:

```bash
docker pull ghcr.io/<owner>/<image_name>:latest
```

`<image_name>` is the target `name` from `image.json` (e.g. `terraform-1.16`, `golang-builder`, `nodejs-builder`).

| Tag | When |
| :--- | :--- |
| `latest` | Push from `main` |
| `sha-<short>` | Every pushed build |
| `<branch>` / `pr-<number>` | Branch / pull request refs |

`workflow_dispatch` inputs: `image` (image directory name or `all`) and `push_images` (boolean).

## Caching Strategy

- **GitHub Actions (`type=gha,mode=max`)**: Scoped per target (`scope=${image_name}-${target}`) to maximize cache hits and prevent cache pollution.
- **BuildKit Native Mounts**: `apt` and `pip` (Terraform image) use cache mounts (`--mount=type=cache`); the Go image pre-configures `GOCACHE`/`GOMODCACHE` directories for cache mounts in downstream builds. The Node.js image only caches `apt`.
- **Path-Filtered Builds**: CI only builds images that contain changes, saving runner minutes and cache quotas.
