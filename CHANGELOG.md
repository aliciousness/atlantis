# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.48.2] - 2026-10-27
### Highlights
Emergency security release for the eMudhra intermediate CA key compromise. The private keys of eight eMudhra (emSign) intermediate certificates were compromised; some of those intermediates are cross-signed by a root that every trust store includes. We recommend all users upgrade.

- Go 1.27.3: Atlantis is now built with go1.27.3, whose crypto/x509 rejects any certificate chain containing the eight compromised keys (CVE-2026-111943). Go does not check revocation, so Atlantis v0.48.1 and earlier, built with go1.27.1, would accept a certificate issued with those keys for any host, including the VCS APIs Atlantis sends credentials to. go1.27.3 also includes the standard library fixes from go1.27.2.
- Trust store update in the images: ca-certificates is updated to Alpine 20261020-r0 and Debian 20250419+deb13u1. Both remove emSign ECC Root CA - G3, and Debian also removes the Comodo AAA Services root that cross-signed some of the affected intermediates. This covers the other TLS clients in the image (git, curl, Terraform/OpenTofu and conftest).
- Runtime image refresh: Debian curl 8.14.1-2+deb13u7 and openssl 3.5.7-1~deb13u3 security pins, Alpine 3.24.2, Terraform 1.16.5, conftest 0.70.1.
- Dependency security updates: golang.org/x/net v0.60.0 and vite v8.3.3.
If you build Atlantis yourself, rebuild with go1.27.3 or go1.26.10 or later. The terraform, tofu and conftest binaries are built by their own projects; update them when their releases with the Go fix are available.

### What's Changed
#### Security changes
- fix(deps): update Go to 1.27.3 to distrust compromised eMudhra intermediates (release-0.48) by @jamengual in #7000
- chore(deps): update module golang.org/x/net to v0.60.0 [security] (release-0.48) by @renovate[bot] in #6976
- chore(deps): update dependency vite to v8.3.3 [security] (release-0.48) by @renovate[bot] in #7002

## [0.47.1.2] - 2026-09-19

### Fixed

- `jfrog_credentials_helper.sh`'s `chown atlantis:root` calls no longer crash the container on boot. `/home/atlantis` is EFS-mounted through an access point that enforces a fixed POSIX uid/gid on everything under it, so `chown` to a different owner always fails there with "Operation not permitted" (`aws_profiles.sh` hits the identical error and just continues, since it has no strict mode). Our script's `set -euo pipefail` turned that harmless, pre-existing condition into a fatal crash mid-script — which, since `docker-entrypoint.sh` doesn't check each entrypoint script's exit code, silently killed the entire container boot before Atlantis ever started. `chown` is now non-fatal (`|| true`) since the access point already enforces correct ownership on anything created under the mount, making the explicit `chown` redundant anyway.

## [0.47.1.1] - 2026-09-19

### Fixed

- `scripts/` are now copied into `/docker-entrypoint.d/` with `COPY --chmod=0755`, forcing the executable bit at build time instead of inheriting it from the host filesystem. This fixes `jfrog_credentials_helper.sh` (and guards all future entrypoint scripts) from being silently skipped by Atlantis's `docker-entrypoint.sh`, which ignores any `.sh` file without the executable bit set (no error, no log beyond "Ignoring ..., not executable") — the seeded JFrog credentials helper was never being installed into `/home/atlantis/.terraform.d/plugins/`.

### Changed

- `.github/workflows/release.yml`: the release/image tag is now derived from `CHANGELOG.md`'s top `## [X.Y.Z]` entry instead of the Dockerfile's upstream `FROM` version, so patch releases of this repo (e.g. this entry) can ship independently of upstream Atlantis version bumps without colliding with an already-released upstream tag. The upstream `FROM` version is still extracted separately and used for the "upstream release notes" link/lookup, so that stays accurate.
- `.github/workflows/release.yml`: the gate that decides whether to build/release now only requires `CHANGELOG.md` to have changed in the push (previously required both `dockerfile` and `CHANGELOG.md` to change together). This lets a `CHANGELOG.md`-driven patch release land even when a prior commit already introduced the `dockerfile` change separately, while the existing "release tag already exists" check still prevents duplicate/accidental releases.

## [0.47.1] - 2026-09-18

### Added

- JFrog AWS IAM token-exchange credentials helper (`terraform-credentials-jfrog`) with runtime-seed entrypoint, replacing the stored `REGISTRY_JSON` token for `gcewebmkt.jfrog.io`.

## [0.46.0] - 2026-06-30

### Changed

- Upgraded base Atlantis Docker image from `v0.45.0-alpine` to `v0.46.0-alpine` (automated upstream tracking)
  - See [upstream release notes](https://github.com/runatlantis/atlantis/releases/tag/v0.46.0)

## [0.45.0] - 2026-06-28

### Changed

- Upgraded base Atlantis Docker image from `v0.44.1-alpine` to `v0.45.0-alpine` (automated upstream tracking)
  - See [upstream release notes](https://github.com/runatlantis/atlantis/releases/tag/v0.45.0)

## [0.44.1] - 2026-06-26

### Changed

- Upgraded base Atlantis Docker image from `v0.44.0-alpine` to `v0.44.1-alpine` (automated upstream tracking)
  - See [upstream release notes](https://github.com/runatlantis/atlantis/releases/tag/v0.44.1)

## [0.44.0] - 2026-06-10

### Changed

- Upgraded base Atlantis Docker image from `v0.43.0-alpine` to `v0.44.0-alpine` (automated upstream tracking)
  - See [upstream release notes](https://github.com/runatlantis/atlantis/releases/tag/v0.44.0)

## [0.43.0] - 2026-05-05

### Changed

- Upgraded base Atlantis Docker image from `v0.42.0-alpine` to `v0.43.0-alpine` (automated upstream tracking)
  - See [upstream release notes](https://github.com/runatlantis/atlantis/releases/tag/v0.43.0)

## [0.42.0] - 2026-04-21

### Changed

- Upgraded base Atlantis Docker image from `v0.41.0-alpine` to `v0.42.0-alpine` (automated upstream tracking)
  - See [upstream release notes](https://github.com/runatlantis/atlantis/releases/tag/v0.42.0)

## [0.41.0] - 2026-04-17

### Fixed

- Add conditional check for README updates in badges workflow
- Add permissions for `trigger-badges` job in release workflow

## [0.38.0.1] - 2025-12-23

### Added

- Justfile with developer-friendly commands for Docker builds, testing, policy validation, and local development workflows ([#10](https://github.com/aliciousness/atlantis/pull/10))

### Changed

- Migrated Docker build steps to `docker/build-push-action@v5` with labels and consistent version tag extraction ([#9](https://github.com/aliciousness/atlantis/pull/9))
- Updated badges workflow to use `workflow_call` with `secrets: inherit` ([#9](https://github.com/aliciousness/atlantis/pull/9))
- Updated Anchore action version in security scanning workflow ([#9](https://github.com/aliciousness/atlantis/pull/9))

### Fixed

- Typo in GitHub Action for uploading SARIF report ([#9](https://github.com/aliciousness/atlantis/pull/9))

## [0.38.0] - 2025-12-23

### Changed

- Upgraded base Atlantis Docker image from `v0.36.0-alpine` to `v0.38.0-alpine` ([#8](https://github.com/aliciousness/atlantis/pull/8))

## [0.36.0.1] - 2025-10-29

### Changed

- Configurable production team support for `teamauthz` via script arguments with fallback defaults ([#6](https://github.com/aliciousness/atlantis/pull/6))

## [0.36.0] - 2025-10-29

### Added

- Team-based authorization (`teamauthz`) script for Atlantis commands with pattern-based access control and GitHub team membership enforcement ([#5](https://github.com/aliciousness/atlantis/pull/5))
- Comprehensive test suite for `teamauthz` ([#5](https://github.com/aliciousness/atlantis/pull/5))

### Changed

- Upgraded base Atlantis Docker image from `v0.33.0-alpine` to `v0.36.0-alpine` ([#5](https://github.com/aliciousness/atlantis/pull/5))

## [0.3.5] - 2025-03-27

### Changed

- Refactored JSON input handling

## [0.3.4] - 2025-03-27

### Fixed

- Clean JSON before parsing

## [0.3.3] - 2025-03-26

### Changed

- Set up release triggers for `released` and `prereleased` events

## [0.3.2] - 2025-03-26

### Added

- Private module registry configuration support for Terraform (`credentials.tfrc.json`)

## [0.3.1] - 2025-03-26

### Fixed

- Fixes to AWS profiles script

### Changed

- Added policies to the policies directory

## [0.3.0] - 2025-03-25

### Added

- AWS profile configuration script that runs before execution to set up `~/.aws/config`

## [0.2.1] - 2025-03-18

### Added

- OPA policies and testing framework; added policies directory to Atlantis home

## [0.2.0] - 2025-03-17

### Fixed

- Dockerfile error; pinned base image to `v0.33.0`

## [0.1.2] - 2025-03-17

### Changed

- Removed unnecessary `git` and `curl` packages from Dockerfile (already included in base image)

## [0.1.1] - 2025-03-11

### Changed

- Switched to PAT for authentication
- Trigger badges workflow from release workflow

## [0.1.0] - 2025-03-11

### Added

- Initial Atlantis Docker image with custom configurations
- Dockerfile based on official Atlantis image
- CI/CD release workflow

[0.46.0]: https://github.com/aliciousness/atlantis/compare/v0.45.0...v0.46.0
[0.45.0]: https://github.com/aliciousness/atlantis/compare/v0.44.1...v0.45.0
[0.44.1]: https://github.com/aliciousness/atlantis/compare/v0.44.0...v0.44.1
[0.44.0]: https://github.com/aliciousness/atlantis/compare/v0.43.0...v0.44.0
[0.43.0]: https://github.com/aliciousness/atlantis/compare/v0.42.0...v0.43.0
[0.42.0]: https://github.com/aliciousness/atlantis/compare/v0.41.0...v0.42.0
[0.41.0]: https://github.com/aliciousness/atlantis/compare/v0.38.0.1...v0.41.0
[0.38.0.1]: https://github.com/aliciousness/atlantis/compare/v0.38.0...v0.38.0.1
[0.38.0]: https://github.com/aliciousness/atlantis/compare/v0.36.0.1...v0.38.0
[0.36.0.1]: https://github.com/aliciousness/atlantis/compare/v0.36.0...v0.36.0.1
[0.36.0]: https://github.com/aliciousness/atlantis/compare/v0.3.5...v0.36.0
[0.3.5]: https://github.com/aliciousness/atlantis/compare/v0.3.4...v0.3.5
[0.3.4]: https://github.com/aliciousness/atlantis/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/aliciousness/atlantis/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/aliciousness/atlantis/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/aliciousness/atlantis/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/aliciousness/atlantis/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/aliciousness/atlantis/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/aliciousness/atlantis/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/aliciousness/atlantis/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/aliciousness/atlantis/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/aliciousness/atlantis/releases/tag/v0.1.0

