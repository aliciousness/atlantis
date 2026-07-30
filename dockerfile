FROM alpine:latest AS wizcli
ARG TARGETARCH
RUN apk add --no-cache curl \
  && curl -fsSL "https://downloads.wiz.io/v1/wizcli/latest/wizcli-linux-${TARGETARCH}" \
       -o /usr/local/bin/wizcli \
  && chmod +x /usr/local/bin/wizcli

FROM ghcr.io/runatlantis/atlantis:v0.46.0-alpine
LABEL maintainer="Richard Craddock craddock9richard@gmail.com"
LABEL version=$VERSION
ARG VERSION
ARG TARGETARCH
ENV VERSION=${VERSION}
USER root
COPY --from=wizcli /usr/local/bin/wizcli /usr/local/bin/wizcli
RUN apk add --no-cache jq gcompat libstdc++ libgcc ca-certificates \
  && ARCH=$(case ${TARGETARCH} in amd64) echo "amd64" ;; arm64) echo "arm64" ;; *) echo "amd64" ;; esac) \
  && curl -L "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-linux-${ARCH}" -o /usr/local/bin/tfsec \
  && chmod +x /usr/local/bin/tfsec \
  && mkdir -p /home/atlantis/policies \
  && chown -R atlantis:root /home/atlantis/policies
RUN wizcli version
COPY scripts/ /docker-entrypoint.d/
RUN mv /docker-entrypoint.d/teamauthz /usr/local/bin/teamauthz \
  && mv /docker-entrypoint.d/wizscan /usr/local/bin/wizscan \
  && chmod +x /usr/local/bin/teamauthz \
  && chmod +x /usr/local/bin/wizscan \
  && chmod +x /docker-entrypoint.d/wiz.sh
USER atlantis
