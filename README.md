# Base Images Repository

Scalable, multi-image monorepo containing production-ready, security-hardened base images for application compilation, tooling, and DevOps pipelines.

## Directory Structure

```text
.
├── .github/
│   └── workflows/
│       └── build-and-validate.yml  # Matrix CI build, caching, and validation
├── scripts/
│   ├── generate-matrix.sh          # Dynamic matrix generator for GitHub Actions
│   └── build.sh                    # Local build and validation CLI
└── images/
    ├── terraform/                  # Terraform v1.16 base image with bundled TFLint & Checkov
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

## Adding a New Image

To add a new base image (e.g., `images/python` or `images/rust`):

1. Create a directory `images/<name>/`.
2. Add a `Dockerfile` utilizing BuildKit caching (`--mount=type=cache`).
3. Add `image.json` specifying targets and validation arguments:
   ```json
   {
     "name": "my-image",
     "description": "My custom base image",
     "targets": [
       {
         "name": "my-image-builder",
         "target": "builder",
         "validation_arg": "builder",
         "default": true
       }
     ]
   }
   ```
4. Add `tests/validate.sh` and make it executable (`chmod +x`).
5. (Optional) Provide test fixtures under `tests/fixtures/`.

GitHub Actions will automatically detect changes in `images/<name>/` and build/validate only the modified images.

## Local Development & Testing

Use the unified helper script:

```bash
# Build and test Terraform base image
./scripts/build.sh terraform --test

# Build and test Go builder
./scripts/build.sh golang --test

# Build and test Node.js builder
./scripts/build.sh nodejs --test
```

## Caching Strategy

- **GitHub Actions (`type=gha,mode=max`)**: Scoped per target (`scope=${image_name}-${target}`) to maximize cache hits and prevent cache pollution.
- **BuildKit Native Mounts**: Package managers (`apt`, `pip`, `go build`, `npm`) use cache mounts (`--mount=type=cache`) during compilation to ensure instant rebuilds.
- **Path-Filtered Builds**: CI only builds images that contain changes, saving runner minutes and cache quotas.
