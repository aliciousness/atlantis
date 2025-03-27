#!/bin/bash
# This script is used to set up private Terraform module registry for Atlantis
# It looks for the env variable REGISTRY_JSON and uses it to configure the credentials.tfrc.json file in the .terraform.d directory of the Atlantis user
# IMPORTANT: Because of the use other registry types, the REGISTRY_JSON env variable does not check for the format of the JSON string

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

# check to see if the REGISTRY_JSON env variable is set
if [ -z "$REGISTRY_JSON" ]; then
  echo "REGISTRY_JSON is not set. Exiting."
  return 0
fi

info "Setting up private Terraform module registry for Atlantis"

# Clean up JSON input to remove any newlines, tabs, or spaces
cleaned_json=$(echo "$REGISTRY_JSON" | jq '.')
if [ $? -ne 0 ]; then
    echo "Error: Invalid JSON format in REGISTRY_JSON"
    exit 1
fi

# Compact the JSON to remove unnecessary whitespace
cleaned_json=$(echo "$cleaned_json" | jq -c '.')

debug 2 "cleaned REGISTRY_JSON: $cleaned_json"

# Create the .terraform.d directory if it doesn't exist
if [ ! -d /home/atlantis/.terraform.d ]; then
    debug 2 "Creating /home/atlantis/.terraform.d directory"
    mkdir -p /home/atlantis/.terraform.d
fi

# Create the credentials.tfrc.json file with proper JSON formatting
debug 2 "Creating /home/atlantis/.terraform.d/credentials.tfrc.json file"
echo "$cleaned_json" | jq '.' > /home/atlantis/.terraform.d/credentials.tfrc.json

# set the permissions on the credentials.tfrc.json file
debug 2 "Setting permissions on /home/atlantis/.terraform.d/credentials.tfrc.json file"
chown atlantis:root /home/atlantis/.terraform.d/credentials.tfrc.json
chmod 600 /home/atlantis/.terraform.d/credentials.tfrc.json

info "Private Terraform module registry setup complete"