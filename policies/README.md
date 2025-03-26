# Null Resources Warning Policy

## Policy Name
null_resources_warning

## Policy Purpose
This policy ensures that no null resources are created in the infrastructure, preventing the use of temporary or placeholder resources that might bypass proper infrastructure management.

## Policy Situation
This policy is applied during Terraform plan evaluation with Atlantis in any environment where infrastructure changes are being proposed. It checks the planned resource changes before they are applied to prevent the creation of null resources.

## Policy Rules
1. The policy monitors all resource changes in the Terraform plan
2. It specifically tracks resources of type "null_resource"
3. If any null resources are scheduled for creation, the policy will raise a violation

## Policy Actions

> not in use

When a violation is detected:
- A denial message "null resources cannot be created" is generated
- The Terraform plan will fail, preventing the creation of null resources
- The user must modify their configuration to use proper resource types instead of null resources

# TFSec Issues Policy

## Policy Name
tfsec_issues

## Policy Purpose
This policy integrates TFSec security scanning into the infrastructure validation process, focusing on identifying and preventing high-severity security issues.

## Policy Situation
Applied during Terraform plan evaluation to scan for security vulnerabilities and best practice violations before infrastructure changes are applied.

## Policy Rules
1. Runs TFSec scanner on the current Terraform plan
2. Identifies security issues and their severity levels
3. Specifically flags high-severity security concerns

## Policy Actions
When a violation is detected:
- Generates detailed error messages including rule ID, description, and location
- Fails the Terraform plan for high-severity issues
- Requires security issues to be addressed before deployment

# Required Providers Policy

## Policy Name
required_providers

## Policy Purpose
This policy enforces the use of approved Terraform providers only, maintaining consistency and security across infrastructure deployments.

## Policy Situation
Evaluated during Terraform plan to ensure only allowed providers are used in the infrastructure configuration (would like to enforce the policy before plan on init with the lock file in the future).

## Policy Rules
1. Maintains a list of allowed providers (AWS, GitHub, Random, Time, Local, Kubernetes)
2. Validates all providers used in the configuration
3. Ensures providers are from approved sources

## Policy Actions
When a violation is detected:
- Generates an error message identifying the non-allowed provider
- Blocks the Terraform plan
- Requires using only approved providers from the allowed list

# Password Check Policy

## Policy Name
passwords_check

## Policy Purpose
This policy enforces secure password management practices by requiring the use of random password generation and minimum password lengths.

## Policy Situation
Applied when resources containing password fields are being created or modified, ensuring secure password practices.

## Policy Rules
1. Requires using random_password resource for password generation
2. Enforces minimum password length of 12 characters
3. Warns when passwords are under 16 characters
4. Monitors common password field names (password, master_password, admin_password, etc.)

## Policy Actions
When a violation is detected:
- Blocks hardcoded passwords, requiring random_password resource instead
- Fails if passwords are shorter than 12 characters
- Issues warnings for passwords between 12-16 characters
- Provides guidance on proper password configuration
