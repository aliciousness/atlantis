#!/bin/bash
# This script is used to set up Wiz CLI authentication for Atlantis
# It looks for the env variable WIZ_CONFIG (JSON) or individual env vars (WIZ_CLIENT_ID, WIZ_CLIENT_SECRET, WIZ_API_URL)
# and configures authentication, then pre-caches the auth token

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

# Check if Wiz is configured via WIZ_CONFIG or direct env vars
if [ -z "$WIZ_CONFIG" ] && [ -z "$WIZ_CLIENT_ID" ]; then
    info "Wiz not configured. Skipping."
    return 0
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
    
    # Extract auth fields
    WIZ_CLIENT_ID=$(echo "$cleaned_json" | jq -r '.auth.client_id // empty')
    WIZ_CLIENT_SECRET=$(echo "$cleaned_json" | jq -r '.auth.client_secret // empty')
    WIZ_API_URL=$(echo "$cleaned_json" | jq -r '.auth.api_url // empty')
    
    # Extract scan fields
    export WIZ_SCAN_PATH=$(echo "$cleaned_json" | jq -r '.scan.path // empty')
    export WIZ_POLICIES=$(echo "$cleaned_json" | jq -c '.scan.policies // empty')
    export WIZ_SCAN_TYPES=$(echo "$cleaned_json" | jq -r '.scan.types // empty')
    export WIZ_SEVERITY=$(echo "$cleaned_json" | jq -r '.scan.severity // empty')
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
