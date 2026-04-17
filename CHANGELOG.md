# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
