# Atlantis
[![Docker Pulls](https://img.shields.io/badge/Docker%20Pulls-223-blue)](https://hub.docker.com/r/aliciousness/atlantis)
[![Latest Release](https://img.shields.io/badge/release-v2.0.3-brightgreen)](https://github.com/aliciousness/ACTION-latest-release-badge/releases)
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
| Tag | Description |
| :----: | --- |
| latest | Latest version of Atlantis with our custom configurations |
| version | Specific version for stable deployments |

# Environment Variables
Reference the following environment variables or config file [here](https://www.runatlantis.io/docs/server-configuration.html)

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

You can now edit the README.md file and replace its content with the above sections.