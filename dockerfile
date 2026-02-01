FROM ghcr.io/runatlantis/atlantis:v0.40.0-alpine
LABEL maintainer="Richard Craddock craddock9richard@gmail.com"
LABEL version=$VERSION
ARG VERSION
ENV VERSION=${VERSION}
USER root
RUN apk add --no-cache jq \
  && curl -L "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64" -o /usr/local/bin/tfsec \
  && chmod +x /usr/local/bin/tfsec \
  && mkdir -p /home/atlantis/policies \
  && chown -R atlantis:root /home/atlantis/policies
COPY scripts/ /docker-entrypoint.d/
RUN mv /docker-entrypoint.d/teamauthz /usr/local/bin/teamauthz \
  && chmod +x /usr/local/bin/teamauthz
USER atlantis