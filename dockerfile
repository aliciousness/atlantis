FROM ghcr.io/runatlantis/atlantis:latest

# copy a terraform binary of the current version
USER root

# Install git
RUN apk add --no-cache git

COPY script.sh /docker-entrypoint.d/script.sh
COPY --chown=atlantis:atlantis atlantis.yaml /home/atlantis/atlantis.yaml
COPY --chown=atlantis:atlantis config.yaml /config.yaml
