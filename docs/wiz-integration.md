# Wiz CLI Integration

## Overview

This Atlantis Docker image includes integrated [Wiz CLI](https://www.wiz.io/) for Infrastructure as Code (IaC) security scanning during Terraform workflows. The integration provides:

- **Automated Security Scanning**: Scan Terraform code for security issues, misconfigurations, and compliance violations during `plan` and `apply` steps
- **Flexible Configuration**: Configure via JSON, YAML, or environment variables
- **Workflow Integration**: Seamlessly integrate into Atlantis workflow hooks
- **Configurable Enforcement**: Choose between warn-only mode (default) or blocking mode for policy violations
- **Apply Gate**: Use different policies for `plan` vs `apply` steps

The integration consists of two components:
- **`scripts/wiz.sh`**: Entrypoint script that sets up authentication and exports configuration
- **`scripts/wizscan`**: Wrapper script that runs `wizcli iac scan` with Atlantis-friendly markdown output

## Configuration

### JSON Configuration (WIZ_CONFIG)

The recommended configuration method is via the `WIZ_CONFIG` environment variable. You can provide the configuration in two ways:

**Option 1: Inline JSON string**
```yaml
environment:
  WIZ_CONFIG: '{
    "auth": {
      "client_id": "wiz-atlantis-prod",
      "client_secret": "secret-from-vault"
    }
  }'
```

**Option 2: File path**
```yaml
environment:
  WIZ_CONFIG: '/path/to/wiz-config.json'
```

The script automatically detects whether `WIZ_CONFIG` contains inline JSON or a file path.

**Full configuration example:**

```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault",
    "api_url": "https://api.us20.app.wiz.io"
  },
  "scan": {
    "path": "./",
    "policies": "TerraformBestPractices,ComplianceChecks",
    "types": "terraform",
    "severity": "MEDIUM",
    "output_format": "json",
    "output_file": ""
  },
  "behavior": {
    "block_on_failure": false,
    "apply_gate": true,
    "show_passed": false
  },
  "advanced": {
    "wiz_dir": "/home/atlantis/.wiz",
    "timeout": "300",
    "proxy": "",
    "extra_args": ""
  }
}
```

#### Configuration Schema

| Section | Field | Type | Required | Default | Description |
|---------|-------|------|----------|---------|-------------|
| **auth** | `client_id` | string | ✅ Yes | - | Wiz service account client ID |
| | `client_secret` | string | ✅ Yes | - | Wiz service account client secret |
| | `api_url` | string | ❌ No | `https://api.wiz.io` | Wiz API endpoint URL |
| **scan** | `path` | string | ❌ No | `./` | Path to scan (relative to repo root) |
| | `policies` | string | ❌ No | - | Comma-separated list of policy names |
| | `types` | string | ❌ No | `terraform` | IaC types to scan (terraform, cloudformation, etc.) |
| | `severity` | string | ❌ No | - | Minimum severity level (LOW, MEDIUM, HIGH, CRITICAL) |
| | `output_format` | string | ❌ No | `json` | Output format (json, sarif, etc.) |
| | `output_file` | string | ❌ No | - | Path to save scan results |
| **behavior** | `block_on_failure` | boolean | ❌ No | `false` | Block (exit 1) on policy violations |
| | `apply_gate` | boolean | ❌ No | `false` | Use stricter policies for apply vs plan |
| | `show_passed` | boolean | ❌ No | `false` | Show passed checks in output |
| **advanced** | `wiz_dir` | string | ❌ No | `/home/atlantis/.wiz` | Directory for Wiz CLI data |
| | `timeout` | string | ❌ No | - | Scan timeout in seconds |
| | `proxy` | string | ❌ No | - | HTTP proxy URL |
| | `extra_args` | string | ❌ No | - | Additional wizcli arguments |

### Environment Variables

Alternatively, configure using individual environment variables:

| Variable | Equivalent JSON Path | Description |
|----------|---------------------|-------------|
| `WIZ_CLIENT_ID` | `auth.client_id` | Wiz service account client ID |
| `WIZ_CLIENT_SECRET` | `auth.client_secret` | Wiz service account client secret |
| `WIZ_API_URL` | `auth.api_url` | Wiz API endpoint URL |
| `WIZ_SCAN_PATH` | `scan.path` | Path to scan |
| `WIZ_POLICIES` | `scan.policies` | Comma-separated policy names |
| `WIZ_SCAN_TYPES` | `scan.types` | IaC types to scan |
| `WIZ_SEVERITY` | `scan.severity` | Minimum severity level |
| `WIZ_OUTPUT_FORMAT` | `scan.output_format` | Output format |
| `WIZ_OUTPUT_FILE` | `scan.output_file` | Output file path |
| `WIZ_BLOCK_ON_FAILURE` | `behavior.block_on_failure` | Block on violations (true/false) |
| `WIZ_APPLY_GATE` | `behavior.apply_gate` | Use apply gate (true/false) |
| `WIZ_SHOW_PASSED` | `behavior.show_passed` | Show passed checks (true/false) |
| `WIZ_DIR` | `advanced.wiz_dir` | Wiz CLI data directory |
| `WIZ_TIMEOUT` | `advanced.timeout` | Scan timeout |
| `WIZ_PROXY` | `advanced.proxy` | HTTP proxy |
| `WIZ_EXTRA_ARGS` | `advanced.extra_args` | Additional arguments |

### Configuration Precedence

When multiple configuration sources are provided, the following precedence applies (highest to lowest):

1. **CLI Flags** (e.g., `wizscan --path /custom --block`)
2. **WIZ_CONFIG JSON** (parsed and exported as env vars)
3. **Individual Environment Variables** (e.g., `WIZ_CLIENT_ID`, `WIZ_SCAN_PATH`)

For auth credentials specifically (`client_id` / `client_secret`):
- If `WIZ_CONFIG` JSON is provided but `auth.client_id` or `auth.client_secret` are missing/empty, the script falls back to `WIZ_CLIENT_ID` / `WIZ_CLIENT_SECRET` environment variables.

**Example:** If you set `WIZ_SCAN_PATH=/env/path` and also provide `{"scan": {"path": "/json/path"}}` in `WIZ_CONFIG`, the JSON value (`/json/path`) takes precedence. If you then run `wizscan --path /cli/path`, the CLI flag value (`/cli/path`) wins.

### AWS Secret Resolution

After credentials are resolved (from JSON or env vars), the script checks if either `client_id` or `client_secret` is an AWS ARN. If so, it fetches the actual value at runtime using the AWS CLI.

Supported ARN formats:

| Service | ARN Pattern | AWS CLI Call |
|---------|-------------|--------------|
| SSM Parameter Store | `arn:aws:ssm:<region>:<account>:parameter/<name>` | `aws ssm get-parameter --with-decryption` |
| Secrets Manager | `arn:aws:secretsmanager:<region>:<account>:secret:<name>` | `aws secretsmanager get-secret-value` |

#### Examples

Store credentials in SSM Parameter Store:
```yaml
environment:
  WIZ_CLIENT_ID: "arn:aws:ssm:us-east-1:123456789012:parameter/atlantis/wiz-client-id"
  WIZ_CLIENT_SECRET: "arn:aws:ssm:us-east-1:123456789012:parameter/atlantis/wiz-client-secret"
```

Store credentials in Secrets Manager:
```yaml
environment:
  WIZ_CLIENT_ID: "wiz-atlantis-prod"
  WIZ_CLIENT_SECRET: "arn:aws:secretsmanager:us-east-1:123456789012:secret:atlantis/wiz-secret-AbCdEf"
```

Use ARNs inside `WIZ_CONFIG` JSON:
```yaml
environment:
  WIZ_CONFIG: '{
    "auth": {
      "client_id": "arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-id",
      "client_secret": "arn:aws:secretsmanager:us-east-1:123456789012:secret:wiz/secret-XyZ123"
    },
    "scan": { "path": "./" }
  }'
```

Mix ARNs with env var fallback (JSON omits auth, env vars provide ARNs):
```yaml
environment:
  WIZ_CONFIG: '{"scan": {"path": "./", "policies": "TerraformBestPractices"}}'
  WIZ_CLIENT_ID: "arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-id"
  WIZ_CLIENT_SECRET: "arn:aws:secretsmanager:us-east-1:123456789012:secret:wiz/secret-AbCdEf"
```

**Requirements:**
- The container must have AWS CLI available and configured (via IAM role, ECS task role, or `AWS_PROFILES`).
- The IAM identity must have `ssm:GetParameter` and/or `secretsmanager:GetSecretValue` permissions for the referenced resources.
- If resolution fails, the script exits with an error and Wiz setup is aborted.

## Workflow Integration

### atlantis.yaml Configuration

Integrate Wiz scanning into your Atlantis workflows using `workflow_hooks`:

#### Example 1: Scan on Plan (Warn Mode)

```yaml
version: 3
projects:
- dir: .
  workflow: terraform
  
workflows:
  terraform:
    plan:
      steps:
      - init
      - plan
      - run: wizscan --path $PLANFILE
        description: "Wiz IaC Security Scan"
    apply:
      steps:
      - apply
```

#### Example 2: Scan on Apply (Block Mode)

```yaml
version: 3
projects:
- dir: .
  workflow: terraform-strict
  
workflows:
  terraform-strict:
    plan:
      steps:
      - init
      - plan
      - run: wizscan --path ./
        description: "Wiz IaC Security Scan (Warn)"
    apply:
      steps:
      - run: wizscan --path ./ --block
        description: "Wiz IaC Security Scan (Block)"
      - apply
```

#### Example 3: Apply Gate (Different Policies)

```yaml
version: 3
projects:
- dir: environments/prod
  workflow: terraform-prod
  
workflows:
  terraform-prod:
    plan:
      steps:
      - init
      - plan
      - run: wizscan --path ./ --policies "TerraformBaseline"
        description: "Wiz Scan (Baseline)"
    apply:
      steps:
      - run: wizscan --path ./ --policies "TerraformStrict,ComplianceChecks" --block
        description: "Wiz Scan (Strict + Compliance)"
      - apply
```

### docker-compose.yml Configuration

Add `WIZ_CONFIG` to your docker-compose environment:

```yaml
version: "2.4"
services:
  atlantis:
    image: aliciousness/atlantis:latest
    ports:
      - 4141:4141
    environment:
      ATLANTIS_GH_USER: "your-github-user"
      ATLANTIS_GH_TOKEN: "your-github-token"
      ATLANTIS_GH_WEBHOOK_SECRET: "your-webhook-secret"
      
      # Optional: Wiz CLI IaC Scanning
      WIZ_CONFIG: '{
        "auth": {
          "client_id": "wiz-atlantis-prod",
          "client_secret": "${WIZ_SECRET}",
          "api_url": "https://api.us20.app.wiz.io"
        },
        "scan": {
          "path": "./",
          "policies": "TerraformBestPractices",
          "severity": "MEDIUM"
        },
        "behavior": {
          "block_on_failure": false,
          "apply_gate": true
        }
      }'
```

## Exit Codes

The `wizscan` wrapper script uses the following exit codes:

| Exit Code | Meaning | Behavior |
|-----------|---------|----------|
| **0** | Success | No violations found, or violations found in warn mode |
| **1** | Error | Infrastructure error, scan failure, or violations in block mode |
| **2** | Invalid Arguments | Bad command-line flags or missing required parameters |
| **3** | Authentication Failure | Wiz authentication failed (triggers re-auth retry) |
| **4** | Violations Found | Policy violations detected (wrapper decides to block or warn) |

### Exit Code 4: Violations Found (Special Handling)

**Exit code 4 is NOT an error** - it indicates that `wizcli iac scan` successfully completed and found policy violations. The `wizscan` wrapper script handles this specially:

- **Warn Mode (default)**: Violations are displayed in markdown format, but the wrapper exits with code **0** (success) to allow the workflow to continue
- **Block Mode**: Violations are displayed with a "BLOCKING" message, and the wrapper exits with code **1** (failure) to halt the workflow

**Enable block mode via:**
- CLI flag: `wizscan --block`
- Environment variable: `WIZ_BLOCK_ON_FAILURE=true`
- JSON config: `{"behavior": {"block_on_failure": true}}`

**Example output (warn mode):**
```markdown
## ⚠️ Wiz IaC Scan: Violations Found (warn mode)

Scanned path: `./`

| Severity | Title | File | Line |
|----------|-------|------|------|
| HIGH | S3 bucket is publicly accessible | main.tf | 12 |
| MEDIUM | IAM policy allows wildcard actions | iam.tf | 45 |

**Note:** This is warn mode. To block on these findings, set `WIZ_BLOCK_ON_FAILURE=true` or use `--block` flag.
```

**Example output (block mode):**
```markdown
## ❌ Wiz IaC Scan: BLOCKING on Violations

Scanned path: `./`

| Severity | Title | File | Line |
|----------|-------|------|------|
| HIGH | S3 bucket is publicly accessible | main.tf | 12 |

**BLOCKING:** Apply cannot proceed until violations are resolved.
```

### Re-Authentication Retry

When `wizcli iac scan` exits with code **3** (authentication failure), the `wizscan` wrapper automatically:

1. Runs `wizcli auth` to refresh the authentication token
2. Retries the scan command once
3. If the retry also fails, exits with code 1

This handles transient authentication issues (e.g., expired tokens) without manual intervention.

## Troubleshooting

### Common Issues

#### 1. "Wiz not configured. Skipping."

**Cause:** Neither `WIZ_CONFIG` nor `WIZ_CLIENT_ID`/`WIZ_CLIENT_SECRET` are set.

**Solution:** Set `WIZ_CONFIG` environment variable or individual `WIZ_CLIENT_ID` and `WIZ_CLIENT_SECRET` variables.

#### 2. "Error: Invalid JSON format in WIZ_CONFIG"

**Cause:** `WIZ_CONFIG` contains malformed JSON.

**Solution:** Validate your JSON using `echo "$WIZ_CONFIG" | jq .` before starting Atlantis.

#### 3. "Error: WIZ_CLIENT_ID and WIZ_CLIENT_SECRET are required"

**Cause:** Authentication credentials are missing.

**Solution:** Ensure `auth.client_id` and `auth.client_secret` are set in `WIZ_CONFIG` or via environment variables.

#### 4. "Authentication failed" (Exit Code 3)

**Cause:** Invalid credentials or network issues connecting to Wiz API.

**Solution:**
- Verify `client_id` and `client_secret` are correct
- Check `api_url` matches your Wiz tenant region
- Verify network connectivity to Wiz API
- Check proxy settings if behind a corporate firewall

#### 5. Scan Times Out

**Cause:** Large Terraform codebase or slow network.

**Solution:** Increase timeout via `advanced.timeout` in JSON config or `WIZ_TIMEOUT` environment variable:

```json
{
  "advanced": {
    "timeout": "600"
  }
}
```

#### 6. Violations Not Blocking Apply

**Cause:** `block_on_failure` is not enabled.

**Solution:** Set `behavior.block_on_failure: true` in JSON config, or use `--block` flag in workflow hook:

```yaml
- run: wizscan --path ./ --block
```

### Debug Logging

Enable debug logging to troubleshoot configuration and authentication issues:

```bash
# Level 1: Info messages
export DEBUG=1

# Level 2: Detailed debug output (includes config parsing, auth flow)
export ENTRY_DEBUG_LEVEL=2
```

**Note:** Debug output automatically masks `WIZ_CLIENT_SECRET` values (displays as `***`).

### Verify Installation

Check that Wiz CLI is installed and accessible:

```bash
docker run --rm aliciousness/atlantis:latest wizcli version
```

Expected output:
```
wizcli version X.Y.Z
```

## Examples

### Minimal Configuration (Auth Only)

```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault"
  }
}
```

Uses defaults:
- `api_url`: `https://api.wiz.io`
- `path`: `./`
- `block_on_failure`: `false` (warn mode)

### Configuration from File

Store your configuration in a JSON file and reference it:

**wiz-config.json:**
```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault",
    "api_url": "https://api.us20.app.wiz.io"
  },
  "scan": {
    "policies": "TerraformBestPractices"
  },
  "behavior": {
    "block_on_failure": false
  }
}
```

**docker-compose.yml:**
```yaml
environment:
  WIZ_CONFIG: '/etc/atlantis/wiz-config.json'
volumes:
  - ./wiz-config.json:/etc/atlantis/wiz-config.json:ro
```

This approach is useful for:
- Keeping secrets out of environment variables
- Sharing configuration across multiple containers
- Version controlling configuration separately

### Full Configuration (All Fields)

```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault",
    "api_url": "https://api.us20.app.wiz.io"
  },
  "scan": {
    "path": "./terraform",
    "policies": "TerraformBestPractices,ComplianceChecks,SecurityBaseline",
    "types": "terraform",
    "severity": "MEDIUM",
    "output_format": "json",
    "output_file": "/tmp/wiz-scan-results.json"
  },
  "behavior": {
    "block_on_failure": true,
    "apply_gate": true,
    "show_passed": false
  },
  "advanced": {
    "wiz_dir": "/home/atlantis/.wiz",
    "timeout": "600",
    "proxy": "http://proxy.example.com:8080",
    "extra_args": "--verbose"
  }
}
```

### Block Mode (Enforce Violations)

```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault"
  },
  "behavior": {
    "block_on_failure": true
  }
}
```

Or via CLI flag in `atlantis.yaml`:

```yaml
- run: wizscan --path ./ --block
```

### Custom Policies (Project-Specific)

```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault"
  },
  "scan": {
    "policies": "CustomPolicy-Team-A,ComplianceChecks"
  }
}
```

### Apply Gate (Different Policies for Plan vs Apply)

```json
{
  "auth": {
    "client_id": "wiz-atlantis-prod",
    "client_secret": "secret-from-vault"
  },
  "behavior": {
    "apply_gate": true
  }
}
```

Then in `atlantis.yaml`:

```yaml
workflows:
  terraform:
    plan:
      steps:
      - init
      - plan
      - run: wizscan --policies "TerraformBaseline"
    apply:
      steps:
      - run: wizscan --policies "TerraformStrict,ComplianceChecks" --block
      - apply
```

### Environment-Specific Configuration

```yaml
# atlantis.yaml
version: 3
projects:
- dir: environments/dev
  workflow: terraform-dev
- dir: environments/prod
  workflow: terraform-prod

workflows:
  terraform-dev:
    plan:
      steps:
      - init
      - plan
      - run: wizscan --policies "TerraformBaseline"
    apply:
      steps:
      - apply
  
  terraform-prod:
    plan:
      steps:
      - init
      - plan
      - run: wizscan --policies "TerraformStrict"
    apply:
      steps:
      - run: wizscan --policies "TerraformStrict,ComplianceChecks,SOC2" --block
      - apply
```

## Additional Resources

- [Wiz CLI Documentation](https://docs.wiz.io/wiz-docs/docs/wiz-cli)
- [Atlantis Workflow Hooks](https://www.runatlantis.io/docs/custom-workflows.html#custom-run-command)
- [Atlantis Server Configuration](https://www.runatlantis.io/docs/server-configuration.html)

## Support

For issues related to:
- **Wiz CLI functionality**: Contact Wiz support or consult [Wiz documentation](https://docs.wiz.io/)
- **Atlantis integration**: Open an issue in this repository
- **Docker image**: Open an issue in this repository
