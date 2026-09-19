#!/bin/bash
# JFrog credentials helper entrypoint script
# This script copies JFrog terraform credentials and terraformrc configuration
# into the atlantis user's home directory after the EFS volume is mounted.
# Uses the same debug/info logging pattern as registry.sh

set -euo pipefail

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

info "Setting up JFrog credentials helper"

# Ensure .terraform.d/plugins directory exists
if [ ! -d /home/atlantis/.terraform.d/plugins ]; then
    debug 2 "Creating /home/atlantis/.terraform.d/plugins directory"
    mkdir -p /home/atlantis/.terraform.d/plugins
fi

# Copy terraform-credentials-jfrog to .terraform.d/plugins
SOURCE_CRED="/usr/local/share/atlantis/terraform-credentials-jfrog"
DEST_CRED="/home/atlantis/.terraform.d/plugins/terraform-credentials-jfrog"
if [ -f "$SOURCE_CRED" ]; then
    debug 2 "Copying $SOURCE_CRED to $DEST_CRED"
    cp "$SOURCE_CRED" "$DEST_CRED"
    chmod 0755 "$DEST_CRED"
    chown atlantis:root "$DEST_CRED"
    info "Copied terraform-credentials-jfrog helper"
else
    info "Warning: $SOURCE_CRED not found, skipping credentials helper setup"
    return 0
fi

# Copy terraformrc to home directory
SOURCE_RC="/usr/local/share/atlantis/terraformrc"
DEST_RC="/home/atlantis/.terraformrc"
if [ -f "$SOURCE_RC" ]; then
    debug 2 "Copying $SOURCE_RC to $DEST_RC"
    cp "$SOURCE_RC" "$DEST_RC"
    chmod 0600 "$DEST_RC"
    chown atlantis:root "$DEST_RC"
    info "Copied terraformrc configuration"
else
    info "Warning: $SOURCE_RC not found, skipping terraformrc setup"
    return 0
fi

info "JFrog credentials helper setup complete"
