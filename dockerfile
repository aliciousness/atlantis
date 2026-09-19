FROM ghcr.io/runatlantis/atlantis:v0.47.1-alpine
LABEL maintainer="Richard Craddock craddock9richard@gmail.com"
LABEL version=$VERSION
ARG VERSION
ENV VERSION=${VERSION}
USER root
RUN apk add --no-cache jq python3 py3-botocore \
  && curl -L "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64" -o /usr/local/bin/tfsec \
  && chmod +x /usr/local/bin/tfsec \
  && mkdir -p /home/atlantis/policies /usr/local/share/atlantis \
  && chown -R atlantis:root /home/atlantis/policies /usr/local/share/atlantis
COPY --chmod=0755 scripts/ /docker-entrypoint.d/
COPY --chmod=0755 credentials/terraform-credentials-jfrog /usr/local/share/atlantis/terraform-credentials-jfrog
COPY --chmod=0644 credentials/terraformrc /usr/local/share/atlantis/terraformrc
RUN mv /docker-entrypoint.d/teamauthz /usr/local/bin/teamauthz \
  && chmod +x /usr/local/bin/teamauthz \
  && chown atlantis:root /usr/local/share/atlantis/terraform-credentials-jfrog /usr/local/share/atlantis/terraformrc
USER atlantis
