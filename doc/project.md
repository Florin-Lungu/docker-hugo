# Project guide

## What this project does

This repository builds and publishes Docker images for [Hugo](https://gohugo.io/), the static site generator. The images package Hugo with small wrapper scripts and, depending on the selected variant, a Linux distribution, build tools, document converters, or CI/on-build behavior.

The published image is `floryn90/hugo` on Docker Hub. The Hugo version configured for the current release is `0.169.0` in [`src/project.yaml`](../src/project.yaml). The root [`README.md`](../README.md) is the user-facing reference for current tags, commands, environment variables, and image behavior. This guide describes how the repository is organized and how its build and release machinery fits together.

## Image variants

The image catalog is declared in the YAML files in [`src/config/`](../src/config/). Each entry maps a public image name to a Dockerfile target, one or more aliases, supported platforms, and smoke tests.

| Family | Variants | Purpose |
| --- | --- | --- |
| BusyBox | standard, `ci`, `onbuild` | Small default image; the standard image backs the `latest` and unqualified Hugo-version tags. |
| Alpine | standard, `ci`, `onbuild` | Hugo on Alpine Linux. |
| Debian | standard, `ci`, `onbuild` | Hugo on Debian stable-slim. The extended Debian image also backs the `ext` aliases. |
| Ubuntu | standard, `ci`, `onbuild` | Hugo on Ubuntu. |
| Alpine with Asciidoctor | standard, `ci`, `onbuild` | Alpine Hugo image with Asciidoctor available. |
| Alpine with Pandoc | standard, `ci`, `onbuild` | Alpine Hugo image with Pandoc available. |
| Extended editions | Alpine, Debian, Ubuntu; each with `ci` and `onbuild` variants | Hugo Extended plus the additional site-building tools described below. |

The modifiers have consistent intent across families:

- **Standard** runs Hugo with the image's normal entrypoint and development-oriented defaults.
- **Extended** uses Hugo Extended and includes tools such as Go, Node.js, Yarn via Corepack, Sass, Git, and PostCSS. Debian and Ubuntu extended images also include Asciidoctor and Pandoc; the Alpine extended family exposes Asciidoctor and Pandoc as separate variants.
- **CI** sets `HUGO_ENV=production` and uses an entrypoint wrapper that configures Git's safe directory when `CI_PROJECT_DIR` is set.
- **Onbuild** copies the downstream build context into the image and invokes Hugo during the downstream Docker build. Its build arguments are documented in the root README.

The configuration files specify the supported architectures per image. The standard BusyBox, Alpine, Debian, and Ubuntu families target `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Extended and Pandoc variants generally target amd64 and arm64; consult the specific config because support can differ by image.

Tags follow the configured Hugo version, with aliases declared beside each image. For example, the BusyBox standard image has the current version-specific tag, a `busybox` alias, and the `latest` alias. CI and on-build images likewise have versioned and rolling aliases. The authoritative, release-specific inventory is generated in the README and [`doc/tags.md`](tags.md); historical release notes are kept in [`doc/changelog/`](changelog/).

## Repository layout

| Path | Responsibility |
| --- | --- |
| [`src/project.yaml`](../src/project.yaml) | Docker image name, current Hugo version, and project-wide platform defaults. |
| [`src/config/`](../src/config/) | Public image catalog: target mappings, tags, platforms, and image smoke-test definitions. |
| [`src/docker/Dockerfile`](../src/docker/Dockerfile) | Top-level Dockerfile that imports the shared and distribution-specific build definitions. |
| [`src/docker/_base/`](../src/docker/_base/) | Shared image, Hugo acquisition, tool, certificate, and file-staging stages. |
| [`src/docker/_imports/`](../src/docker/_imports/) | Reusable Dockerfile fragments, including CI, on-build, version-argument, and default-user setup. |
| [`src/docker/alpine/`](../src/docker/alpine/) | Alpine standard image targets. |
| [`src/docker/alpine-ext/`](../src/docker/alpine-ext/) | Alpine extended and optional Asciidoctor/Pandoc targets. |
| [`src/docker/busybox/`](../src/docker/busybox/) | BusyBox image definition. |
| [`src/docker/debian/`](../src/docker/debian/) and [`src/docker/ubuntu/`](../src/docker/ubuntu/) | Debian and Ubuntu image targets. |
| [`src/files/`](../src/files/) | Files assembled into images, including Hugo/Pandoc wrappers, profile setup, and build-time acquisition scripts. |
| [`src/bin/`](../src/bin/) | Project helper scripts and the locally downloaded Buildx executable. |
| [`.github/workflows/`](../.github/workflows/) | Image build, release, version-bump, and SonarCloud workflows. |
| [`doc/changelog/`](changelog/) | Release-by-release Hugo updates and image tag lists. |
| [`doc/template/`](template/) | Templates used to generate the README and next changelog during a version bump. |
| [`doc/tags.md`](tags.md) | Historical and current tag reference generated as part of releases. |

## Build design

The Dockerfile sources are written using the Docker Project `IMPORT` syntax and are prepared into a conventional Docker build bundle. The top-level Dockerfile imports shared stages and then the BusyBox, Alpine, Debian, and Ubuntu definitions. Those definitions reuse the common Hugo and utility stages rather than independently installing Hugo into every image.

Hugo binaries are downloaded for the target architecture in [`src/docker/_base/hugo.df`](../src/docker/_base/hugo.df). The standard and extended editions use separate scripts in [`src/files/_script/`](../src/files/_script/); both verify Hugo's release checksum, stage the binary and shell completion into the image, and record the bundled version. Other helper scripts fetch or stage tools including Node.js, Go, Sass, and Pandoc.

The resulting images use a non-root `hugo` user with UID/GID `1234`, work in `/src`, expose port `1313`, and provide `/src`, `/target`, and `/builds` as volumes. The base image entrypoint is `hugo`. The `hugo` wrapper applies container-friendly defaults: it binds Hugo's server to `HUGO_BIND` (default `0.0.0.0`), honors destination configuration, disables file timestamp updates when running unprivileged, and provides a `shell` command in the distributions that include Bash. `hugo-official` is available to bypass the wrapper.

### Image behavior and configuration

Common environment variables are:

| Variable | Default | Effect |
| --- | --- | --- |
| `HUGO_BIND` | `0.0.0.0` | Bind address used for `hugo server` / `hugo serve`. |
| `HUGO_CACHEDIR` | `/tmp` | Hugo module cache directory. |
| `HUGO_DESTINATION` | `public` | Build output destination. |
| `HUGO_ENV` | `DEV` | Hugo environment; CI images set it to `production`. |
| `HUGO_PANDOC` | `pandoc-default` | Command used by the Pandoc wrapper in Pandoc images. |
| `HUGO_VERSION` | Bundled Hugo version | Version configured for the image build. |
| `HUGO_VERSION_OVERRIDE` | unset | Optional Hugo version override for images that support it (Hugo 0.71.1 and later). |

The image exposes TCP port `1313`. See the README for usage examples and the on-build arguments.

## Build and test locally

Requirements include Docker with Buildx support, `make`, and the utilities used by the Makefile (`curl`, `jq`, and Git). Multi-platform builds use QEMU emulation; the GitHub Actions workflows set up QEMU and Buildx for CI.

The Makefile targets are:

| Command | Purpose |
| --- | --- |
| `make prepare` | Downloads/configures Buildx as needed and runs `klakegg/docker-project-prepare:edge` to generate `target/bundle`. |
| `make build` | Builds the prepared image bundle. On failure it prints the end of the generated build log. |
| `make build-debug` | Builds the prepared bundle with debug output. |
| `make test` | Runs the Docsy and DocuAPI integration builds. |
| `make test-docsy` | Clones the latest Docsy release into `target/test/docsy`, installs its npm dependencies in the extended Alpine image, and builds it. |
| `make test-docuapi` | Clones the latest DocuAPI release into `target/test/docuapi`, installs its npm dependencies in the extended Alpine image, and builds it. |
| `make push-edge` | Pushes edge image tags using the generated bundle's Makefile. |
| `make push-release` | Pushes stable/release image tags using the generated bundle's Makefile. |
| `make bump version=X.Y.Z` | Updates the configured version and regenerates release-facing documentation. |

Typical local build sequence:

```sh
make prepare
make build
```

The build and integration-test targets require a running Docker daemon and may download binaries, source repositories, or build tools. `make test` removes and recreates its `target/test` directories. `make prepare` generates files under `target/bundle`; `make clean` removes `target`.

The image configs include smoke tests for Hugo and the relevant optional tools, and verify that the default user has UID `1234`. The CI build workflow prepares and builds the bundle, uploads `target` as an artifact, and pushes edge tags for its non-tag builds.

## Release and version updates

Hugo version updates are automated by [`.github/workflows/version_bump.yaml`](../.github/workflows/version_bump.yaml), which runs daily or by manual dispatch. When the latest Hugo release differs from the repository release, the workflow creates a `release/<version>` branch, runs the `bump` script, opens and merges a pull request, and creates a GitHub release.

The bump script updates `src/project.yaml`, regenerates `README.md` from `doc/template/README.md`, updates the tag inventory, creates a versioned changelog from `doc/changelog/NEXT.md`, and initializes the next changelog from its template. **Because the README is generated during a version bump, durable project and maintainer documentation belongs under `doc/`, not only in the README.**

The image build workflow runs for pull requests to `master`, pushes to `release/*`, and manual dispatch. It prepares and builds the images, uploads build output, and pushes edge tags for non-tag builds. The release workflow runs on a published GitHub release or manual dispatch and builds/pushes stable tags. Docker Hub credentials and GitHub/SonarCloud tokens referenced by workflows are configured as repository secrets; they are not needed for reading this guide.

## Making changes

When adding or changing an image:

1. Update the appropriate `src/config/*.yaml` entry with its Docker target, aliases, platforms, and smoke tests.
2. Add or adjust the Docker target and shared imports under `src/docker/`; place staged files or scripts under `src/files/` when needed.
3. Keep the standard, CI, and on-build variants consistent where the image family supports them.
4. Update the README template or release documentation only when the change affects generated user-facing content. For a version bump, edit the changelog templates and configuration rather than hand-editing generated release data.
5. Run the relevant local build and smoke/integration tests when Docker is available.

For general usage, current tags, and example commands, start with the [README](../README.md). For individual Hugo releases, see the [changelog](changelog/).
