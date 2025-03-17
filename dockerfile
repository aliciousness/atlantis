FROM ghcr.io/runatlantis/atlantis:v0.33.0-alpine
LABEL maintainer="Richard Craddock craddock9richard@gmail.com"
LABEL version=$VERSION
ARG VERSION
ENV VERSION=${VERSION}
USER root
# Install git
RUN curl -L "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-amd64" -o /usr/local/bin/tfsec && \
  chmod +x /usr/local/bin/tfsec
COPY script.sh /docker-entrypoint.d/script.sh
USER atlantis