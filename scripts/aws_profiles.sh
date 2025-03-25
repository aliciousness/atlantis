#!/bin/sh
# Check if AWS_PROFILES environment variable exists
if [ -z "${AWS_PROFILES}" ]; then
    echo "Not setting up AWS profiles config file"
    return 0
fi

echo "Setting up AWS profiles config file"

# Create .aws directory if it doesn't exist
mkdir -p /home/atlantis/.aws
chown -R atlantis:root /home/atlantis/.aws

# Create or truncate the config file
CONFIG_FILE="/home/atlantis/.aws/config"
> "${CONFIG_FILE}"

# Parse JSON and create config entries
echo "${AWS_PROFILES}" | jq -c '.[]' | while read -r profile; do
    profile_name=$(echo "${profile}" | jq -r 'keys[0]')
    role_arn=$(echo "${profile}" | jq -r ".[\"${profile_name}\"]")
    region=$(echo "${profile}" | jq -r '.region')

    # Skip if profile_name is "region"
    if [ "${profile_name}" = "region" ]; then
        continue
    fi

    # Write profile configuration to file
    cat >> "${CONFIG_FILE}" << EOF
[profile ${profile_name}]
role_arn = ${role_arn}
region = ${region}
credential_source = EcsContainer

EOF
done

# Set proper permissions
chmod 644 "${CONFIG_FILE}"
chown atlantis:root "${CONFIG_FILE}"

echo "AWS config file has been created at ${CONFIG_FILE}"