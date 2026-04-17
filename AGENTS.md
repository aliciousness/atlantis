# Atlantis - Custom Docker Image for Terraform PR Automation

**What it does:** Custom Docker image wrapping the official [runatlantis/atlantis](https://github.com/runatlantis/atlantis) with added tooling: tfsec, OPA policies, AWS profile configuration, private registry support, and team-based authorization.

**Stack:** Dockerfile (Alpine-based) • Shell scripts • OPA/Rego policies • Docker Compose • GitHub Actions CI/CD • Justfile

**Upstream:** Based on `ghcr.io/runatlantis/atlantis:v0.41.0-alpine`

## Project Structure

```
dockerfile              # Custom image based on official Atlantis Alpine
docker-compose.yml      # Local dev setup (Atlantis + ngrok)
config.yaml             # Atlantis server configuration
atlantis.yaml           # Atlantis repo-level configuration
justfile                # Developer commands (build, test, deploy)
scripts/
  teamauthz             # Team-based authorization script (copied to /usr/local/bin/)
  registry.sh           # Private Terraform registry config (entrypoint.d)
  aws_profiles.sh       # AWS profile setup from JSON env var (entrypoint.d)
policies/               # OPA/Rego policy files for policy checks
  *.rego                # Individual policy rules (tfsec, s3, passwords, etc.)
test/
  teamauthz.sh          # Test suite for teamauthz script
.github/workflows/
  release.yml           # Build & push Docker image on release
  pre-release.yml       # Build & push on pre-release
  badges.yml            # Update README badges
  anchore.yml           # Container security scanning
  autoassigning.yml     # PR auto-assignment
```

## Build & Test

**Build image:** `just build` or `just build 0.41.0` (passes VERSION build arg)

**Run locally:** `just up` (starts Atlantis + ngrok via docker-compose) • `just down` to stop

**Test:** `just test` (runs `test/teamauthz.sh`)

**Validate configs:** `just validate-all` (docker-compose + atlantis.yaml)

**OPA policies:** `just validate-policies` • `just lint-policies` • `just format-policies`

**Health check:** `just health-check` (checks `localhost:4141/healthz`)

**All commands:** `just help`

## CI/CD Workflows

**release.yml:** On GitHub release → builds Docker image with `docker/build-push-action@v5` → pushes to DockerHub → triggers badges workflow
**pre-release.yml:** Same as release but for pre-release tags
**anchore.yml:** Container vulnerability scanning with Anchore/Grype → uploads SARIF
**badges.yml:** Updates README badges (Docker pulls, latest release)

## Development Workflow

1. Edit `dockerfile`, `scripts/`, or `policies/` as needed
2. `just build` to build locally
3. `just test` to run tests
4. `just up` to test with docker-compose (configure GitHub creds in `docker-compose.yml`)
5. `just get-ngrok-url` to get the tunnel URL for webhook testing
6. `just shell` to exec into the running container

**Environment variables for docker-compose:**
- `ATLANTIS_GH_USER`, `ATLANTIS_GH_TOKEN`, `ATLANTIS_GH_WEBHOOK_SECRET` — GitHub auth
- `AWS_PROFILES` — JSON array of AWS role configs (see README)
- `REGISTRY_JSON` — Private Terraform registry credentials (see README)
- `NGROK_AUTH` — ngrok auth token

## Key Components

**teamauthz:** Shell script enforcing team-based access control for `apply`/`import` commands. Supports configurable production teams via args. See README for access rules.

**OPA policies:** Rego files in `policies/` for Atlantis policy checks (tfsec issues, required providers, S3 privacy, password checks, null resource warnings).

**Entrypoint scripts:** `scripts/registry.sh` and `scripts/aws_profiles.sh` run via `/docker-entrypoint.d/` on container start to configure AWS and Terraform registry credentials from env vars.

## Code Style

**Shell scripts:** Bash • Use `set -euo pipefail` • Support `DEBUG=1` for verbose logging
**Commits:** Conventional Commits (`fix:`, `feat:`, etc.)
**Policies:** OPA/Rego • Format with `opa fmt`
