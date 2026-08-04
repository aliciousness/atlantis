#!/bin/bash
# This script is used to set up Wiz CLI authentication for Atlantis
# It looks for the env variable WIZ_CONFIG (JSON) or individual env vars (WIZ_CLIENT_ID, WIZ_CLIENT_SECRET, WIZ_API_URL)
# and configures authentication, then pre-caches the auth token
#
# Credential resolution order:
#   1. WIZ_CONFIG JSON (inline or file path) → auth.client_id / auth.client_secret
#   2. Environment variables WIZ_CLIENT_ID / WIZ_CLIENT_SECRET (fallback if JSON fields empty)
#   3. If resolved value is an SSM Parameter ARN or Secrets Manager ARN, fetch at runtime

# Debug levels: 0=none, 1=info, 2=debug
DEBUG_LEVEL=${ENTRY_DEBUG_LEVEL:-1}

debug() {
    local level=$1
    shift
    if [ "$DEBUG_LEVEL" -ge "$level" ]; then
        if [ "$level" -eq 1 ]; then
            echo "[INFO] $*" >&2
        else
            echo "[DEBUG] $*" >&2
        fi
    fi
}

info() {
    debug 1 "$@"
}

# Helper function to mask secrets in debug output
mask_secret() {
    local secret="$1"
    if [ -n "$secret" ]; then
        echo "***"
    else
        echo ""
    fi
}

# Resolve a secret value that may be an SSM Parameter ARN or Secrets Manager ARN.
# If the value is a plain string (not an ARN), it is returned unchanged.
# Supported ARN formats:
#   arn:aws:ssm:<region>:<account>:parameter/<name>
#   arn:aws:secretsmanager:<region>:<account>:secret:<name>
resolve_secret() {
    local value="$1"
    local field_name="${2:-secret}"

    if [ -z "$value" ]; then
        echo ""
        return 0
    fi

    # SSM Parameter ARN
    if [[ "$value" == arn:aws:ssm:*:parameter/* ]]; then
        debug 2 "Resolving $field_name from SSM Parameter: $value"
        if ! command -v aws &>/dev/null; then
            echo "Error: AWS CLI is required to resolve SSM parameter ARN for $field_name but 'aws' was not found in PATH" >&2
            echo "Hint: Install the AWS CLI or provide the credential value directly instead of an ARN" >&2
            return 1
        fi
        local resolved aws_stderr
        aws_stderr=$(mktemp)
        if ! resolved=$(aws ssm get-parameter --name "$value" --with-decryption --query 'Parameter.Value' --output text 2>"$aws_stderr"); then
            echo "Error: Failed to resolve SSM parameter for $field_name" >&2
            echo "  ARN: $value" >&2
            echo "  AWS error: $(cat "$aws_stderr")" >&2
            echo "  Hint: Verify the ARN is correct and that the container's IAM role has ssm:GetParameter permission" >&2
            rm -f "$aws_stderr"
            return 1
        fi
        rm -f "$aws_stderr"
        if [ -z "$resolved" ] || [ "$resolved" = "None" ]; then
            echo "Error: SSM parameter resolved to an empty value for $field_name" >&2
            echo "  ARN: $value" >&2
            echo "  Hint: Check that the SSM parameter exists and contains a non-empty value" >&2
            return 1
        fi
        echo "$resolved"
        return 0
    fi

    # Secrets Manager ARN
    if [[ "$value" == arn:aws:secretsmanager:*:secret:* ]]; then
        debug 2 "Resolving $field_name from Secrets Manager: $value"
        if ! command -v aws &>/dev/null; then
            echo "Error: AWS CLI is required to resolve Secrets Manager ARN for $field_name but 'aws' was not found in PATH" >&2
            echo "Hint: Install the AWS CLI or provide the credential value directly instead of an ARN" >&2
            return 1
        fi
        local resolved aws_stderr
        aws_stderr=$(mktemp)
        if ! resolved=$(aws secretsmanager get-secret-value --secret-id "$value" --query 'SecretString' --output text 2>"$aws_stderr"); then
            echo "Error: Failed to resolve Secrets Manager secret for $field_name" >&2
            echo "  ARN: $value" >&2
            echo "  AWS error: $(cat "$aws_stderr")" >&2
            echo "  Hint: Verify the ARN is correct and that the container's IAM role has secretsmanager:GetSecretValue permission" >&2
            rm -f "$aws_stderr"
            return 1
        fi
        rm -f "$aws_stderr"
        if [ -z "$resolved" ] || [ "$resolved" = "None" ]; then
            echo "Error: Secrets Manager secret resolved to an empty value for $field_name" >&2
            echo "  ARN: $value" >&2
            echo "  Hint: Check that the secret exists and contains a non-empty SecretString" >&2
            return 1
        fi
        echo "$resolved"
        return 0
    fi

    # Plain value — return as-is
    echo "$value"
    return 0
}

# Check if Wiz is configured via WIZ_CONFIG or direct env vars
if [ -z "$WIZ_CONFIG" ] && [ -z "$WIZ_CLIENT_ID" ]; then
    info "Wiz not configured. Skipping."
    exit 0
fi

info "Setting up Wiz CLI authentication for Atlantis"

# Handle WIZ_CONFIG JSON or file path if provided
if [ -n "$WIZ_CONFIG" ]; then
    # Check if WIZ_CONFIG is a file path
    if [ -f "$WIZ_CONFIG" ]; then
        debug 2 "WIZ_CONFIG is a file path, reading from $WIZ_CONFIG"
        config_content=$(cat "$WIZ_CONFIG")
    else
        debug 2 "WIZ_CONFIG is inline JSON"
        config_content="$WIZ_CONFIG"
    fi
    
    # Validate JSON format
    if ! cleaned_json=$(echo "$config_content" | jq '.'); then
        echo "Error: Invalid JSON format in WIZ_CONFIG" >&2
        exit 1
    fi
    
    # Extract auth fields from JSON
    json_client_id=$(echo "$cleaned_json" | jq -r '.auth.client_id // empty')
    json_client_secret=$(echo "$cleaned_json" | jq -r '.auth.client_secret // empty')
    json_api_url=$(echo "$cleaned_json" | jq -r '.auth.api_url // empty')

    # Use JSON values if present, otherwise fall back to env vars
    WIZ_CLIENT_ID="${json_client_id:-$WIZ_CLIENT_ID}"
    WIZ_CLIENT_SECRET="${json_client_secret:-$WIZ_CLIENT_SECRET}"
    WIZ_API_URL="${json_api_url:-$WIZ_API_URL}"

    if [ -z "$json_client_id" ] && [ -n "$WIZ_CLIENT_ID" ]; then
        debug 2 "auth.client_id not in JSON, using WIZ_CLIENT_ID env var"
    fi
    if [ -z "$json_client_secret" ] && [ -n "$WIZ_CLIENT_SECRET" ]; then
        debug 2 "auth.client_secret not in JSON, using WIZ_CLIENT_SECRET env var"
    fi
    
    # Extract scan fields
    export WIZ_SCAN_PATH=$(echo "$cleaned_json" | jq -r '.scan.path // empty')
    export WIZ_POLICIES=$(echo "$cleaned_json" | jq -c '.scan.policies // empty')
    export WIZ_SCAN_TYPES=$(echo "$cleaned_json" | jq -r '.scan.types // empty')
    export WIZ_OUTPUT_FORMAT=$(echo "$cleaned_json" | jq -r '.scan.output_format // empty')
    export WIZ_OUTPUT_FILE=$(echo "$cleaned_json" | jq -r '.scan.output_file // empty')
    
    # Extract behavior fields
    export WIZ_BLOCK_ON_FAILURE=$(echo "$cleaned_json" | jq -r '.behavior.block_on_failure // empty')
    export WIZ_APPLY_GATE=$(echo "$cleaned_json" | jq -r '.behavior.apply_gate // empty')
    export WIZ_SHOW_PASSED=$(echo "$cleaned_json" | jq -r '.behavior.show_passed // empty')
    
    # Extract advanced fields
    export WIZ_DIR=$(echo "$cleaned_json" | jq -r '.advanced.wiz_dir // empty')
    export WIZ_TIMEOUT=$(echo "$cleaned_json" | jq -r '.advanced.timeout // empty')
    export WIZ_PROXY=$(echo "$cleaned_json" | jq -r '.advanced.proxy // empty')
    export WIZ_EXTRA_ARGS=$(echo "$cleaned_json" | jq -r '.advanced.extra_args // empty')
    
    debug 2 "Extracted configuration from WIZ_CONFIG JSON"
else
    debug 2 "Using direct environment variables (WIZ_CLIENT_ID, WIZ_CLIENT_SECRET, WIZ_API_URL)"
fi

# Validate required auth fields
if [ -z "$WIZ_CLIENT_ID" ] || [ -z "$WIZ_CLIENT_SECRET" ]; then
    echo "Error: WIZ_CLIENT_ID and WIZ_CLIENT_SECRET are required" >&2
    exit 1
fi

# Resolve credentials from SSM Parameter Store or Secrets Manager if values are ARNs
if ! WIZ_CLIENT_ID=$(resolve_secret "$WIZ_CLIENT_ID" "WIZ_CLIENT_ID"); then
    echo "Error: Wiz setup aborted — could not resolve WIZ_CLIENT_ID. See above for details." >&2
    exit 1
fi
if ! WIZ_CLIENT_SECRET=$(resolve_secret "$WIZ_CLIENT_SECRET" "WIZ_CLIENT_SECRET"); then
    echo "Error: Wiz setup aborted — could not resolve WIZ_CLIENT_SECRET. See above for details." >&2
    exit 1
fi

# Export auth environment variables
export WIZ_CLIENT_ID
export WIZ_CLIENT_SECRET
export WIZ_API_URL

# Debug output with secret masking
debug 2 "WIZ_CLIENT_ID: ${WIZ_CLIENT_ID}"
debug 2 "WIZ_CLIENT_SECRET: $(mask_secret "$WIZ_CLIENT_SECRET")"
debug 2 "WIZ_API_URL: ${WIZ_API_URL}"

# Set default Wiz directory if not specified
if [ -z "$WIZ_DIR" ]; then
    WIZ_DIR="/home/atlantis/.wiz"
    export WIZ_DIR
fi

# Create Wiz directory and set permissions
debug 2 "Creating ${WIZ_DIR} directory"
mkdir -p "${WIZ_DIR}"
chown -R atlantis:root "${WIZ_DIR}"
debug 2 "Set permissions on ${WIZ_DIR}"

# Pre-cache Wiz authentication token
info "Authenticating with Wiz CLI to pre-cache token"
debug 2 "Running: wizcli auth --id ${WIZ_CLIENT_ID} --secret [MASKED]"

if wizcli auth --id "$WIZ_CLIENT_ID" --secret "$WIZ_CLIENT_SECRET"; then
    info "Wiz CLI authentication successful, token cached to ${WIZ_DIR}/auth.json"
else
    echo "Error: Wiz CLI authentication failed" >&2
    exit 1
fi

debug 2 "Wiz CLI setup complete"
