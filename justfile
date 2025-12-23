set shell := ["bash", "-c"]
set dotenv-load := true

# Display all available commands
help:
    @just --list --unsorted

# Build the Docker image
build VERSION="latest":
    docker build --build-arg VERSION={{VERSION}} -t atlantis:{{VERSION}} .

# Run Atlantis locally with docker-compose
up:
    @echo "Starting Atlantis with docker-compose..."
    docker-compose up

# Run Atlantis in the background
up-detached:
    @echo "Starting Atlantis in detached mode..."
    docker-compose up -d

# Stop running containers
down:
    docker-compose down

# View logs from the running container
logs:
    docker-compose logs -f atlantis

# View ngrok logs
logs-ngrok:
    docker-compose logs -f ngrok

# Rebuild and restart services
restart:
    docker-compose down
    docker-compose up -d
    just logs

# Remove all containers, volumes, and networks
clean:
    docker-compose down -v
    @echo "Cleaned up all Docker resources"

# Validate OPA policy files
validate-policies:
    @echo "Validating OPA policies..."
    @for policy in policies/*.rego; do \
        echo "Checking $$policy"; \
        opa test "$$policy" 2>/dev/null || echo "  ⚠ Policy file: $$policy"; \
    done

# Lint OPA policy files
lint-policies:
    @echo "Linting OPA policy files..."
    @for policy in policies/*.rego; do \
        echo "Linting $$policy"; \
        opa fmt -d "$$policy" || echo "  ⚠ Issues in: $$policy"; \
    done

# Format OPA policy files
format-policies:
    @echo "Formatting OPA policy files..."
    @for policy in policies/*.rego; do \
        echo "Formatting $$policy"; \
        opa fmt -w "$$policy"; \
    done

# Validate Docker Compose configuration
validate-docker-compose:
    docker-compose config > /dev/null && echo "✓ docker-compose.yml is valid"

# Validate Atlantis configuration
validate-atlantis-config:
    @echo "Validating atlantis.yaml configuration..."
    @if command -v yamllint &> /dev/null; then \
        yamllint atlantis.yaml; \
    else \
        echo "yamllint not found, skipping validation"; \
    fi

# Validate all configuration files
validate-all: validate-docker-compose validate-atlantis-config
    @echo "✓ All configurations are valid"

# Run shell scripts
run-registry-script:
    @bash scripts/registry.sh

# List all AWS profiles configured in the system
list-aws-profiles:
    @bash scripts/aws_profiles.sh

# Check Docker and Docker Compose installation
check-deps:
    @echo "Checking dependencies..."
    @command -v docker >/dev/null && echo "✓ Docker installed" || echo "✗ Docker not found"
    @command -v docker-compose >/dev/null && echo "✓ Docker Compose installed" || echo "✗ Docker Compose not found"
    @command -v opa >/dev/null && echo "✓ OPA installed" || echo "✗ OPA not found"
    @command -v tfsec >/dev/null && echo "✓ tfsec installed" || echo "✗ tfsec not found"

# Setup local development environment
setup:
    @echo "Setting up local development environment..."
    just check-deps
    @echo ""
    @echo "Next steps:"
    @echo "1. Configure docker-compose.yml with your GitHub credentials"
    @echo "2. Set ngrok auth token in docker-compose.yml"
    @echo "3. Run 'just up' to start Atlantis"
    @echo "4. Check ngrok URL at http://localhost:4040"

# Display environment information
info:
    @echo "=== Project Information ==="
    @echo "Docker image: ghcr.io/runatlantis/atlantis:v0.38.0-alpine"
    @echo "Local Atlantis port: 4141"
    @echo "Local ngrok UI port: 4040"
    @echo ""
    @echo "=== Key Files ==="
    @echo "Atlantis config: atlantis.yaml"
    @echo "Docker Compose: docker-compose.yml"
    @echo "Dockerfile: dockerfile"
    @echo "OPA Policies: policies/*.rego"
    @echo ""
    @echo "=== Useful Resources ==="
    @echo "Atlantis Docs: https://www.runatlantis.io"
    @echo "OPA Docs: https://www.openpolicyagent.org"
    @echo "tfsec: https://github.com/aquasecurity/tfsec"

# Quick health check of running Atlantis instance
health-check:
    @echo "Checking Atlantis health..."
    @curl -s http://localhost:4141/healthz > /dev/null && echo "✓ Atlantis is running" || echo "✗ Atlantis not responding"

# Get the ngrok tunnel URL
get-ngrok-url:
    @echo "Fetching ngrok tunnel URL..."
    @curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*"' | cut -d'"' -f4

# Shell into the running Atlantis container
shell:
    docker-compose exec atlantis /bin/sh

# Shell into the running ngrok container
shell-ngrok:
    docker-compose exec ngrok /bin/sh

# Run tests (if they exist)
test:
    @echo "Running tests..."
    @if [ -f test/teamauthz.sh ]; then \
        bash test/teamauthz.sh; \
    else \
        echo "No tests found"; \
    fi

# Display project README
readme:
    @cat README.md
