FROM ghcr.io/runatlantis/atlantis:v0.33.0-alpine
LABEL maintainer="Richard Craddock craddock9richard@gmail.com"
LABEL version=$VERSION
ARG VERSION
ENV VERSION=${VERSION}
USER root
RUN apk update \
  && apk upgrade \
  && apk add --no-cache jq \
  && curl -L "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64" -o /usr/local/bin/tfsec \
  && chmod +x /usr/local/bin/tfsec \
  && mkdir -p /home/atlantis/policies \
  && chown -R atlantis:root /home/atlantis/policies
COPY scripts/ /docker-entrypoint.d/
USER atlantis