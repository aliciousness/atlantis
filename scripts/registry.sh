#!/bin/bash
# This script is used to set up private Terraform module registry for Atlantis
# It looks for the env variable REGISTRY_JSON and uses it to configure the credentials.tfrc.json file in the .terraform.d directory of the Atlantis user
# IMPORTANT: Because of the use other registry types, the REGISTRY_JSON env variable does not check for the format of the JSON string


set -e

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

echo "Setting up private Terraform module registry for Atlantis"

debug 2 "REGISTRY_JSON: $REGISTRY_JSON"

# Create the .terraform.d directory if it doesn't exist
if [ ! -d /home/atlantis/.terraform.d ]; then
  info "Creating /home/atlantis/.terraform.d directory"
  mkdir -p /home/atlantis/.terraform.d
fi

# Create the credentials.tfrc.json file
info "Creating /home/atlantis/.terraform.d/credentials.tfrc.json file"
echo "$REGISTRY_JSON" > /home/atlantis/.terraform.d/credentials.tfrc.json

# set the permissions on the credentials.tfrc.json file
info "Setting permissions on /home/atlantis/.terraform.d/credentials.tfrc.json file"
chown atlantis:root /home/atlantis/.terraform.d/credentials.tfrc.json
chmod 600 /home/atlantis/.terraform.d/credentials.tfrc.json

echo "Private Terraform module registry setup complete"