#!/bin/bash

# Debug levels: 0=none, 1=info, 2=debug
DEBUG_LEVEL=${AWS_PROFILE_DEBUG_LEVEL:-1}

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

# Check if AWS_PROFILES environment variable exists
if [ -z "${AWS_PROFILES}" ]; then
    echo "Not setting up AWS profiles config file"
    return 0
fi

debug 2 "AWS_PROFILES: ${AWS_PROFILES}"
echo "Setting up AWS profiles config file"

# Create .aws directory if it doesn't exist
debug 2 "Creating /home/atlantis/.aws directory"
mkdir -p /home/atlantis/.aws
debug 2 "Setting permissions on /home/atlantis/.aws"
chown -R atlantis:root /home/atlantis/.aws

# Create or truncate the config file
CONFIG_FILE="/home/atlantis/.aws/config"
> "${CONFIG_FILE}"

profiles_json="${AWS_PROFILES}"
info "Setting up AWS profiles config file"
debug 2 "Received profiles:"
debug 2 "${profiles_json}"
# while loop to use a temporary file instead
echo "${profiles_json}" | jq -c '.[]' > /tmp/profiles.json
while read -r profile; do
    debug 2 "Processing profile: ${profile}"
    # Get the first key that isn't "region"
    profile_name=$(echo "${profile}" | jq -r 'keys | map(select(. != "region"))[0]')
    debug 2 "Profile name: ${profile_name}"
    role_arn=$(echo "${profile}" | jq -r ".[\"${profile_name}\"]")
    debug 2 "Role ARN: ${role_arn}"
    region=$(echo "${profile}" | jq -r '.region')
    debug 2 "Region: ${region}"

    # No need for region check anymore since we're explicitly excluding it
    debug 2 "About to write to ${CONFIG_FILE}"
    cat >> "${CONFIG_FILE}" << EOF
[profile ${profile_name}]
role_arn = ${role_arn}
region = ${region}
credential_source = EcsContainer

EOF
    debug 2 "Wrote profile ${profile_name}"
done < /tmp/profiles.json
debug 2 "removing /tmp/profiles.json"
rm /tmp/profiles.json

# Set proper permissions
debug 2 "Setting permissions on ${CONFIG_FILE}"
chmod 644 "${CONFIG_FILE}"
debug 2 "Changing ownership of ${CONFIG_FILE}"
chown atlantis:root "${CONFIG_FILE}"

echo "AWS config file has been created at ${CONFIG_FILE}"