#!/usr/bin/env bash

# Test script for Wiz CLI integration
# Tests wiz.sh entrypoint and wizscan wrapper with mock wizcli

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZ_SH="$SCRIPT_DIR/../scripts/wiz.sh"
WIZSCAN_SH="$SCRIPT_DIR/../scripts/wizscan"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_TEMP_DIR=""
MOCK_WIZCLI_LOG=""

setup_mock_wizcli() {
    TEST_TEMP_DIR=$(mktemp -d)
    MOCK_WIZCLI_LOG="$TEST_TEMP_DIR/wizcli-log.txt"
    
    cat > "$TEST_TEMP_DIR/wizcli" <<MOCK_EOF
#!/usr/bin/env bash
echo "wizcli \$*" >> "$MOCK_WIZCLI_LOG"

case "\$1" in
    auth)
        if [[ "\${MOCK_AUTH_FAIL:-0}" == "1" ]]; then
            echo "Error: Authentication failed" >&2
            exit 3
        fi
        echo "Authenticated successfully"
        mkdir -p "\${WIZ_DIR:-/tmp/wiz}"
        echo '{"token":"mock-token"}' > "\${WIZ_DIR:-/tmp/wiz}/auth.json"
        exit 0
        ;;
    iac)
        if [[ "\$2" == "scan" ]]; then
            exit_code="\${MOCK_SCAN_EXIT_CODE:-0}"
            case "\$exit_code" in
                0)
                    echo '{}'
                    exit 0
                    ;;
                3)
                    echo "Error: Authentication required" >&2
                    exit 3
                    ;;
                4)
                    echo '{"findings":[{"severity":"HIGH","title":"S3 bucket is publicly accessible","file":"main.tf","line":"12"}]}'
                    exit 4
                    ;;
                1|2)
                    echo "Error: Infrastructure error" >&2
                    exit "\$exit_code"
                    ;;
                *)
                    echo "Error: Unknown scan error" >&2
                    exit "\$exit_code"
                    ;;
            esac
        fi
        ;;
    --help)
        echo "Mock wizcli help"
        exit 0
        ;;
esac

echo "Error: Unknown command" >&2
exit 1
MOCK_EOF

    chmod +x "$TEST_TEMP_DIR/wizcli"
    
    cat > "$TEST_TEMP_DIR/chown" <<'CHOWN_MOCK'
#!/usr/bin/env bash
exit 0
CHOWN_MOCK
    chmod +x "$TEST_TEMP_DIR/chown"

    # Mock aws CLI for SSM/Secrets Manager resolution tests
    cat > "$TEST_TEMP_DIR/aws" <<'AWS_MOCK'
#!/usr/bin/env bash
# Mock AWS CLI for testing resolve_secret()
if [[ "${MOCK_AWS_FAIL:-0}" == "1" ]]; then
    echo "An error occurred (AccessDeniedException)" >&2
    exit 1
fi

case "$1" in
    ssm)
        if [[ "$2" == "get-parameter" ]]; then
            echo "${MOCK_SSM_VALUE-resolved-ssm-secret}"
            exit 0
        fi
        ;;
    secretsmanager)
        if [[ "$2" == "get-secret-value" ]]; then
            echo "${MOCK_SM_VALUE-resolved-sm-secret}"
            exit 0
        fi
        ;;
esac
echo "Error: Unknown aws command: $*" >&2
exit 1
AWS_MOCK
    chmod +x "$TEST_TEMP_DIR/aws"
    
    export PATH="$TEST_TEMP_DIR:$PATH"
    export MOCK_WIZCLI_LOG
}

cleanup_mock_wizcli() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

trap cleanup_mock_wizcli EXIT

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n${GREEN}Running:${NC} $test_name"
    
    : > "$MOCK_WIZCLI_LOG"
    unset MOCK_AUTH_FAIL MOCK_SCAN_EXIT_CODE
    
    if $test_func; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ FAIL${NC}: $test_name"
    fi
}

# ============================================================================
# wiz.sh Entrypoint Tests
# ============================================================================

test_wiz_sh_noop() {
    unset WIZ_CONFIG WIZ_CLIENT_ID WIZ_CLIENT_SECRET WIZ_API_URL
    local temp_script="$TEST_TEMP_DIR/test_wiz_noop.sh"
    
    cat > "$temp_script" <<EOF
#!/bin/bash
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" 2>&1 | grep -q "Wiz not configured"
exit \$?
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Expected no-op when not configured" >&2
        return 1
    fi
}

test_wiz_sh_valid_json() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_valid.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CONFIG='{
    "auth": {
        "client_id": "test-client-id",
        "client_secret": "test-secret",
        "api_url": "https://api.wiz.io"
    },
    "scan": {
        "path": "./terraform",
        "policies": "DefaultPolicy"
    },
    "advanced": {
        "wiz_dir": "$TEST_TEMP_DIR/wiz"
    }
}'
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ -n "\$WIZ_CLIENT_ID" ]] || exit 1
[[ -n "\$WIZ_CLIENT_SECRET" ]] || exit 1
[[ "\$WIZ_SCAN_PATH" == "./terraform" ]] || exit 1
[[ "\$WIZ_POLICIES" == '"DefaultPolicy"' ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Failed to parse valid JSON" >&2
        return 1
    fi
}

test_wiz_sh_invalid_json() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_invalid.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
export WIZ_CONFIG='{"auth": invalid json}'
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" 2>&1 | grep -q "Invalid JSON"
exit \$?
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Expected error on invalid JSON" >&2
        return 1
    fi
}

test_wiz_sh_env_fallback() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_env.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
unset WIZ_CONFIG
export WIZ_CLIENT_ID="env-client-id"
export WIZ_CLIENT_SECRET="env-secret"
export WIZ_API_URL="https://api.wiz.io"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "env-client-id" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "env-secret" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Failed env var fallback" >&2
        return 1
    fi
}

test_wiz_sh_precedence() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_precedence.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CONFIG='{
    "auth": {
        "client_id": "json-client-id",
        "client_secret": "json-secret"
    },
    "advanced": {
        "wiz_dir": "$TEST_TEMP_DIR/wiz"
    }
}'
export WIZ_CLIENT_ID="env-client-id"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "json-client-id" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Precedence test failed" >&2
        return 1
    fi
}

test_wiz_sh_secret_masking() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_mask.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CLIENT_ID="test-id"
export WIZ_CLIENT_SECRET="super-secret-value"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export ENTRY_DEBUG_LEVEL=2
export PATH="$TEST_TEMP_DIR:\$PATH"
output=\$(source "$WIZ_SH" 2>&1)
if echo "\$output" | grep -q "super-secret-value"; then
    echo "Secret not masked!" >&2
    exit 1
fi
if echo "\$output" | grep -q "\*\*\*"; then
    exit 0
fi
echo "Masking not working as expected" >&2
exit 1
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Secret masking failed" >&2
        return 1
    fi
}

test_wiz_sh_auth_failure() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_auth_fail.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
export WIZ_CLIENT_ID="test-id"
export WIZ_CLIENT_SECRET="test-secret"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
export MOCK_AUTH_FAIL=1
if source "$WIZ_SH" 2>&1 | grep -q "authentication failed"; then
    exit 0
fi
exit 1
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        return 0
    else
        echo "Auth failure test failed" >&2
        return 1
    fi
}

test_wiz_sh_config_file() {
    local config_file="$TEST_TEMP_DIR/wiz-config.json"
    cat > "$config_file" <<EOF
{
    "auth": {
        "client_id": "file-client-id",
        "client_secret": "file-secret",
        "api_url": "https://api.wiz.io"
    },
    "scan": {
        "path": "./terraform",
        "policies": "FilePolicy"
    },
    "advanced": {
        "wiz_dir": "$TEST_TEMP_DIR/wiz"
    }
}
EOF
    
    local temp_script="$TEST_TEMP_DIR/test_wiz_file.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CONFIG="$config_file"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "file-client-id" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "file-secret" ]] || exit 1
[[ "\$WIZ_SCAN_PATH" == "./terraform" ]] || exit 1
[[ "\$WIZ_POLICIES" == '"FilePolicy"' ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"
    
    if bash "$temp_script"; then
        rm -f "$config_file"
        return 0
    else
        echo "Config file test failed" >&2
        rm -f "$config_file"
        return 1
    fi
}

test_wiz_sh_json_missing_auth_env_fallback() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_json_env_fallback.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CONFIG='{
    "scan": {
        "path": "./infra"
    },
    "advanced": {
        "wiz_dir": "$TEST_TEMP_DIR/wiz"
    }
}'
export WIZ_CLIENT_ID="fallback-id"
export WIZ_CLIENT_SECRET="fallback-secret"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "fallback-id" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "fallback-secret" ]] || exit 1
[[ "\$WIZ_SCAN_PATH" == "./infra" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "JSON missing auth with env fallback test failed" >&2
        return 1
    fi
}

test_wiz_sh_json_partial_auth_env_fallback() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_partial_fallback.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CONFIG='{
    "auth": {
        "client_id": "json-id"
    },
    "advanced": {
        "wiz_dir": "$TEST_TEMP_DIR/wiz"
    }
}'
export WIZ_CLIENT_SECRET="env-secret"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "json-id" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "env-secret" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "Partial auth env fallback test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_ssm_parameter() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_ssm.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CLIENT_ID="arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-id"
export WIZ_CLIENT_SECRET="arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-secret"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export MOCK_SSM_VALUE="resolved-from-ssm"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "resolved-from-ssm" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "resolved-from-ssm" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "SSM parameter resolution test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_secrets_manager() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_sm.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CLIENT_ID="arn:aws:secretsmanager:us-east-1:123456789012:secret:wiz/client-id-AbCdEf"
export WIZ_CLIENT_SECRET="arn:aws:secretsmanager:us-east-1:123456789012:secret:wiz/client-secret-GhIjKl"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export MOCK_SM_VALUE="resolved-from-sm"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "resolved-from-sm" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "resolved-from-sm" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "Secrets Manager resolution test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_ssm_in_json() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_ssm_json.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CONFIG='{
    "auth": {
        "client_id": "arn:aws:ssm:us-west-2:111111111111:parameter/prod/wiz-id",
        "client_secret": "arn:aws:secretsmanager:us-west-2:111111111111:secret:prod/wiz-secret-XyZ123"
    },
    "advanced": {
        "wiz_dir": "$TEST_TEMP_DIR/wiz"
    }
}'
export MOCK_SSM_VALUE="ssm-resolved-id"
export MOCK_SM_VALUE="sm-resolved-secret"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "ssm-resolved-id" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "sm-resolved-secret" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "SSM/SM ARN in JSON test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_aws_failure() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_aws_fail.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
export WIZ_CLIENT_ID="arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-id"
export WIZ_CLIENT_SECRET="plain-secret"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export MOCK_AWS_FAIL=1
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
output=\$(source "$WIZ_SH" 2>&1)
exit_code=\$?
echo "\$output" | grep -q "Failed to resolve SSM parameter" || { echo "missing error message"; exit 1; }
echo "\$output" | grep -q "ARN:" || { echo "missing ARN in output"; exit 1; }
echo "\$output" | grep -q "ssm:GetParameter" || { echo "missing permission hint"; exit 1; }
echo "\$output" | grep -q "Wiz setup aborted" || { echo "missing abort message"; exit 1; }
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "AWS failure propagation test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_aws_failure_sm() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_sm_fail.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
export WIZ_CLIENT_ID="plain-id"
export WIZ_CLIENT_SECRET="arn:aws:secretsmanager:us-east-1:123456789012:secret:wiz/secret-AbCdEf"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export MOCK_AWS_FAIL=1
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
output=\$(source "$WIZ_SH" 2>&1)
echo "\$output" | grep -q "Failed to resolve Secrets Manager secret" || { echo "missing SM error"; exit 1; }
echo "\$output" | grep -q "ARN:" || { echo "missing ARN"; exit 1; }
echo "\$output" | grep -q "secretsmanager:GetSecretValue" || { echo "missing SM permission hint"; exit 1; }
echo "\$output" | grep -q "Wiz setup aborted" || { echo "missing abort message"; exit 1; }
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "Secrets Manager failure propagation test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_missing_aws_cli() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_no_aws.sh"
    local isolated_bin="$TEST_TEMP_DIR/no-aws-bin"
    mkdir -p "$isolated_bin"
    cp "$TEST_TEMP_DIR/wizcli" "$isolated_bin/wizcli"
    cp "$TEST_TEMP_DIR/chown" "$isolated_bin/chown"
    # Symlink only the system tools the script needs (explicitly excluding aws)
    for cmd in bash cat grep mkdir rm mktemp echo chmod; do
        local cmd_path
        cmd_path=$(command -v "$cmd" 2>/dev/null) && ln -sf "$cmd_path" "$isolated_bin/$cmd"
    done
    # jq may be in a brew or system path alongside aws — symlink it explicitly
    local jq_path
    jq_path=$(command -v jq 2>/dev/null) && ln -sf "$jq_path" "$isolated_bin/jq"

    cat > "$temp_script" <<EOF
#!/bin/bash
export WIZ_CLIENT_ID="arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-id"
export WIZ_CLIENT_SECRET="plain-secret"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export ENTRY_DEBUG_LEVEL=0
export PATH="$isolated_bin"
output=\$(source "$WIZ_SH" 2>&1)
echo "\$output" | grep -q "AWS CLI is required" || { echo "missing CLI-not-found error"; exit 1; }
echo "\$output" | grep -q "provide the credential value directly" || { echo "missing hint"; exit 1; }
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "Missing AWS CLI test failed" >&2
        return 1
    fi
}

test_wiz_sh_resolve_empty_value() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_empty_resolve.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
export WIZ_CLIENT_ID="arn:aws:ssm:us-east-1:123456789012:parameter/wiz/client-id"
export WIZ_CLIENT_SECRET="plain-secret"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export MOCK_SSM_VALUE=""
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
output=\$(source "$WIZ_SH" 2>&1)
echo "\$output" | grep -q "resolved to an empty value" || { echo "missing empty-value error"; exit 1; }
echo "\$output" | grep -q "contains a non-empty value" || { echo "missing hint"; exit 1; }
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "Empty resolved value test failed" >&2
        return 1
    fi
}

test_wiz_sh_plain_values_no_resolution() {
    local temp_script="$TEST_TEMP_DIR/test_wiz_plain.sh"
    cat > "$temp_script" <<EOF
#!/bin/bash
set -e
export WIZ_CLIENT_ID="plain-client-id"
export WIZ_CLIENT_SECRET="plain-client-secret"
export WIZ_DIR="$TEST_TEMP_DIR/wiz"
export ENTRY_DEBUG_LEVEL=0
export PATH="$TEST_TEMP_DIR:\$PATH"
source "$WIZ_SH" >/dev/null 2>&1
[[ "\$WIZ_CLIENT_ID" == "plain-client-id" ]] || exit 1
[[ "\$WIZ_CLIENT_SECRET" == "plain-client-secret" ]] || exit 1
exit 0
EOF
    chmod +x "$temp_script"

    if bash "$temp_script"; then
        return 0
    else
        echo "Plain values should pass through unchanged" >&2
        return 1
    fi
}

# ============================================================================
# wizscan Wrapper Tests
# ============================================================================

test_wizscan_help() {
    if bash "$WIZSCAN_SH" --help 2>&1 | grep -q "Usage: wizscan"; then
        return 0
    else
        echo "Help output missing" >&2
        return 1
    fi
}

test_wizscan_clean_scan() {
    export MOCK_SCAN_EXIT_CODE=0
    export WIZ_CLIENT_ID="test-id"
    export WIZ_CLIENT_SECRET="test-secret"
    
    local output
    output=$(bash "$WIZSCAN_SH" --path /tmp 2>&1)
    
    if echo "$output" | grep -q "No security issues found"; then
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 0
    else
        echo "Clean scan failed: $output" >&2
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 1
    fi
}

test_wizscan_violations_warn() {
    export MOCK_SCAN_EXIT_CODE=4
    export WIZ_BLOCK_ON_FAILURE=false
    export WIZ_CLIENT_ID="test-id"
    export WIZ_CLIENT_SECRET="test-secret"
    
    local output exit_code
    set +e
    output=$(bash "$WIZSCAN_SH" --path /tmp 2>&1)
    exit_code=$?
    set -e
    
    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "warn mode"; then
        unset MOCK_SCAN_EXIT_CODE WIZ_BLOCK_ON_FAILURE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 0
    else
        echo "Warn mode failed: exit=$exit_code" >&2
        unset MOCK_SCAN_EXIT_CODE WIZ_BLOCK_ON_FAILURE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 1
    fi
}

test_wizscan_violations_block() {
    export MOCK_SCAN_EXIT_CODE=4
    export WIZ_CLIENT_ID="test-id"
    export WIZ_CLIENT_SECRET="test-secret"
    
    local output exit_code
    set +e
    output=$(bash "$WIZSCAN_SH" --path /tmp --block 2>&1)
    exit_code=$?
    set -e
    
    if [[ $exit_code -eq 1 ]] && echo "$output" | grep -q "BLOCKING"; then
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 0
    else
        echo "Block mode failed: exit=$exit_code" >&2
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 1
    fi
}

test_wizscan_auth_failure_retry() {
    export MOCK_SCAN_EXIT_CODE=3
    export WIZ_CLIENT_ID="test-id"
    export WIZ_CLIENT_SECRET="test-secret"
    
    local output exit_code
    set +e
    output=$(bash "$WIZSCAN_SH" --path /tmp 2>&1)
    exit_code=$?
    set -e
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q "Authentication failed"; then
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 0
    else
        echo "Auth retry test failed" >&2
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 1
    fi
}

test_wizscan_infra_error() {
    export MOCK_SCAN_EXIT_CODE=1
    export WIZ_CLIENT_ID="test-id"
    export WIZ_CLIENT_SECRET="test-secret"
    
    local output exit_code
    set +e
    output=$(bash "$WIZSCAN_SH" --path /tmp 2>&1)
    exit_code=$?
    set -e
    
    if [[ $exit_code -eq 1 ]] && echo "$output" | grep -q "Scan failed"; then
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 0
    else
        echo "Infra error test failed" >&2
        unset MOCK_SCAN_EXIT_CODE WIZ_CLIENT_ID WIZ_CLIENT_SECRET
        return 1
    fi
}

test_wizscan_flag_precedence() {
    export WIZ_SCAN_PATH="/env/path"
    export WIZ_CLIENT_ID="test-id"
    export WIZ_CLIENT_SECRET="test-secret"
    export MOCK_SCAN_EXIT_CODE=0
    
    bash "$WIZSCAN_SH" --path /cli/path >/dev/null 2>&1
    
    if grep -q "/cli/path" "$MOCK_WIZCLI_LOG"; then
        unset WIZ_SCAN_PATH WIZ_CLIENT_ID WIZ_CLIENT_SECRET MOCK_SCAN_EXIT_CODE
        return 0
    else
        echo "CLI flag did not take precedence" >&2
        unset WIZ_SCAN_PATH WIZ_CLIENT_ID WIZ_CLIENT_SECRET MOCK_SCAN_EXIT_CODE
        return 1
    fi
}

test_wizscan_invalid_flag() {
    local output exit_code
    set +e
    output=$(bash "$WIZSCAN_SH" --invalid-flag 2>&1)
    exit_code=$?
    set -e
    
    if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q "Unknown option"; then
        return 0
    else
        echo "Invalid flag test failed" >&2
        return 1
    fi
}

# ============================================================================
# Main Test Execution
# ============================================================================

echo "=== Testing Wiz CLI Integration ==="
echo "Scripts: $WIZ_SH, $WIZSCAN_SH"

if [[ ! -f "$WIZ_SH" ]]; then
    echo -e "${RED}Error: wiz.sh not found at $WIZ_SH${NC}"
    exit 1
fi

if [[ ! -f "$WIZSCAN_SH" ]]; then
    echo -e "${RED}Error: wizscan not found at $WIZSCAN_SH${NC}"
    exit 1
fi

setup_mock_wizcli

echo -e "\n${GREEN}=== wiz.sh Entrypoint Tests ===${NC}"
run_test "wiz.sh - no-op when not configured" test_wiz_sh_noop
run_test "wiz.sh - valid JSON parsing" test_wiz_sh_valid_json
run_test "wiz.sh - invalid JSON fails" test_wiz_sh_invalid_json
run_test "wiz.sh - env var fallback" test_wiz_sh_env_fallback
run_test "wiz.sh - WIZ_CONFIG takes precedence" test_wiz_sh_precedence
run_test "wiz.sh - secret masking in debug" test_wiz_sh_secret_masking
run_test "wiz.sh - auth failure propagates" test_wiz_sh_auth_failure
run_test "wiz.sh - config file path support" test_wiz_sh_config_file
run_test "wiz.sh - JSON missing auth falls back to env vars" test_wiz_sh_json_missing_auth_env_fallback
run_test "wiz.sh - JSON partial auth falls back to env for missing field" test_wiz_sh_json_partial_auth_env_fallback
run_test "wiz.sh - resolves SSM Parameter ARN" test_wiz_sh_resolve_ssm_parameter
run_test "wiz.sh - resolves Secrets Manager ARN" test_wiz_sh_resolve_secrets_manager
run_test "wiz.sh - resolves ARNs from JSON config" test_wiz_sh_resolve_ssm_in_json
run_test "wiz.sh - AWS SSM resolution failure shows ARN, error, and hint" test_wiz_sh_resolve_aws_failure
run_test "wiz.sh - AWS SM resolution failure shows ARN, error, and hint" test_wiz_sh_resolve_aws_failure_sm
run_test "wiz.sh - missing aws CLI gives clear error" test_wiz_sh_resolve_missing_aws_cli
run_test "wiz.sh - empty resolved value gives clear error" test_wiz_sh_resolve_empty_value
run_test "wiz.sh - plain values pass through without resolution" test_wiz_sh_plain_values_no_resolution

echo -e "\n${GREEN}=== wizscan Wrapper Tests ===${NC}"
run_test "wizscan - --help prints usage" test_wizscan_help
run_test "wizscan - clean scan (exit 0)" test_wizscan_clean_scan
run_test "wizscan - violations warn mode (exit 4 + no block)" test_wizscan_violations_warn
run_test "wizscan - violations block mode (exit 4 + --block)" test_wizscan_violations_block
run_test "wizscan - auth failure retry (exit 3)" test_wizscan_auth_failure_retry
run_test "wizscan - infrastructure error (exit 1)" test_wizscan_infra_error
run_test "wizscan - CLI flag precedence" test_wizscan_flag_precedence
run_test "wizscan - invalid flag error" test_wizscan_invalid_flag

echo -e "\n═══════════════════════════════════════"
echo -e "Test Summary:"
echo -e "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "  Failed: 0"
    exit 0
fi
