# Atlantis
[![Docker Pulls](https://img.shields.io/badge/Docker%20Pulls-751-blue)](https://hub.docker.com/r/aliciousness/atlantis)
[![Latest Release](https://img.shields.io/badge/release-v0.36.0.1-brightgreen)](https://github.com/aliciousness/ACTION-latest-release-badge/releases)
[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/aliciousness)
<!-- [![Docker Image Size (tag)]() -->
<!-- ![Build Status](https://img.shields.io/github/actions/workflow/status/aliciousness/atlantis/release.yml?branch=main)]
[![GitHub last commit](https://img.shields.io/badge/Last%20Commit-2024-11-08-yellow)] -->

## Installation

To install the images, fork the repository:

```sh
git clone https://github.com/aliciousness/atlantis.git
```
**OR**
Use the public docker image found [here](https://hub.docker.com/r/aliciousness/atlantis)

Image is based on the official Atlantis image with additional configurations and tools.

# Tags
|   Tag   | Description                                               |
| :-----: | --------------------------------------------------------- |
| latest  | Latest version of Atlantis with our custom configurations |
| version | Specific version for stable deployments                   |

# Environment Variables
Reference the following environment variables or config file [here](https://www.runatlantis.io/docs/server-configuration.html)

## Optional Private Registry Configuration
The container includes a Terraform private registry configuration script. To use it, provide a JSON object through the `REGISTRY_JSON` environment variable:

```yaml
environment:
  REGISTRY_JSON: '{
    "credentials": {
      "your-registry.example.com": {
        "token": "your-registry-token"
      }
    }
  }'
```

This will create a `credentials.tfrc.json` file in `~/atlantis/.terraform.d/` that can be used to authenticate with private Terraform module registries.

To debug the registry script you can set the `ENTRY_DEBUG_LEVEL` to 1 or 2 to see the output of the script:

```yaml
environment:
  ENTRY_DEBUG_LEVEL: 1  # 1=info, 2=debug
```

## Optional AWS Configuration
The container includes an AWS profile configuration script that can set up multiple AWS role configurations. To use it, provide a JSON array through the `AWS_PROFILES` environment variable:

```yaml
environment:
  AWS_PROFILES: '[
    {"role_one":"arn:aws:iam::123456789012:role/role-name","region":"us-west-2"},
    {"role_two":"arn:aws:iam::123456789012:role/role-name","region":"us-east-1"}
  ]'
```

This will create AWS profiles in `/home/atlantis/.aws/config` that can be referenced in your Terraform configurations:

```ini
[profile role_one]
role_arn = arn:aws:iam::123456789012:role/role-name
region = us-west-2
credential_source = EcsContainer

[profile role_two]
role_arn = arn:aws:iam::123456789012:role/role-name
region = us-east-1
credential_source = EcsContainer
```

To debug the `AWS_PROFILE` script you can set the `AWS_PROFILES_DEBUG_LEVEL` to 1 or 2 to see the output of the script (default 0).

```yaml
environment:
  ENTRY_DEBUG_LEVEL: 1  # 1=info, 2=debug
```

## Team Authorization Script

The container includes a configurable team authorization script (`teamauthz`) that validates team membership for repository access control. This script enforces access policies based on GitHub team membership and supports both default and custom team configurations.

### Features

- ✅ **Configurable Production Teams**: Define which teams can apply to production via server config
- ✅ **Secure Defaults**: Built-in fallback teams if no configuration provided
- ✅ **Environment-Aware**: Different rules for `environments/prod`, `environments/dev`, etc.
- ✅ **Pattern Matching**: Flexible project and team name matching
- ✅ **Debug Support**: Detailed logging for troubleshooting

### Configuration

The script is automatically available at `/usr/local/bin/teamauthz` in the container. Configure it in your Atlantis server-side repo config:

#### Option 1: Custom Production Teams
```yaml
# server-atlantis.yaml or repos.yaml
team_authz:
  command: "teamauthz"
  args: ["myorg/platform-team,myorg/security-team,myorg/senior-devs"]
```

#### Option 2: Use Default Teams
```yaml
# server-atlantis.yaml or repos.yaml  
team_authz:
  command: "teamauthz"
  # No args = uses default teams: gce-digital-marketing-infrastructure/devops,gce-digital-marketing-infrastructure/tf_policy_approvers
```

### Access Rules

| Command  | Project Pattern | Default Teams                   | Configurable     |
| -------- | --------------- | ------------------------------- | ---------------- |
| `apply`  | `*prod*`        | `devops`, `tf_policy_approvers` | ✅ Via `args`     |
| `apply`  | `*dev*`         | `devops`, `Trainee`             | ❌ Hardcoded      |
| `plan`   | `*`             | Anyone                          | ❌ Always allowed |
| `import` | `*`             | `devops`                        | ❌ Hardcoded      |

### Project Matching Examples

- `environments/prod` ✅ matches `*prod*` (production rules)
- `environments/dev` ✅ matches `*dev*` (development rules)  
- `production-app` ✅ matches `*prod*` (production rules)
- `dev-environment` ✅ matches `*dev*` (development rules)

### Testing

Run the comprehensive test suite:

```bash
# Run all tests (21 test cases)
./scripts/test/teamauthz.sh

# Test with custom production teams
export PROJECT_NAME="environments/prod"
./teamauthz "myorg/custom-team" apply myorg/myrepo myorg/custom-team

# Test with defaults
export PROJECT_NAME="environments/prod"  
./teamauthz apply myorg/myrepo gce-digital-marketing-infrastructure/devops
```

### Debugging

Enable debug logging to see detailed authorization flow:

```bash
export DEBUG=1
./teamauthz apply myorg/myrepo myorg/team
```

For container-level debugging:

```yaml
environment:
  DEBUG: 1  # Enables detailed teamauthz logging
```

## Usage
Example docker-compose configuration:

```yaml
version: "2.4"
services:
  atlantis:
    image: aliciousness/atlantis:<latest/version>
    ports:
      - 4141:4141
    volumes:
      - ./config.yaml:/config.yaml  # Mount your custom config.yaml
    environment:
      ATLANTIS_GH_USER: "your-github-user"
      ATLANTIS_GH_TOKEN: "your-github-token"
      ATLANTIS_GH_WEBHOOK_SECRET: "your-webhook-secret"
```

### Server Configuration
You can customize the Atlantis server settings by providing your own `config.yaml`. Create a file named `config.yaml` with your desired configuration:

```yaml
# Example config.yaml
repo-allowlist: "github.com/your-org/*"
enable-policy-checks: true
enable-diff-markdown-format: true
web-basic-auth: true
repo-config: "/home/atlantis/atlantis.yaml"
```

For all available configuration options, refer to the [Atlantis Server Configuration Documentation](https://www.runatlantis.io/docs/server-configuration.html).

To set a new release of the image you will need to fork the repo set the GH variable/secrets DOCKERHUB_USERNAME and DOCKERHUB_TOKEN
and create a new GH release with a tagged version that will trigger the workflow

## Contribution
We welcome contributions! Here are some guidelines to get started:

Fork the repository.
Create a new branch for your feature or bugfix: git checkout -b my-feature-branch
Commit your changes: git commit -m 'Add new feature'
Push to the branch: git push origin my-feature-branch
Create a pull request.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
