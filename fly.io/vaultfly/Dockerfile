ARG VAULTWARDEN_VERSION=1.36.0
ARG CLOUDFLARED_VERSION=2026.6.0

# Builder for downloading dependencies
FROM alpine as builder
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.44
RUN apk add --no-cache wget && \
    wget -O /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" && \
    chmod +x /usr/local/bin/supercronic

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

# vaultwarden build stage
FROM ghcr.io/dani-garcia/vaultwarden:${VAULTWARDEN_VERSION}

# Install runtime dependencies and set timezone
RUN apt-get update && \
    apt-get install -y --no-install-recommends tini restic tzdata uuid-runtime gosu curl && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo Asia/Kolkata > /etc/timezone

# Copy binaries
COPY  --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY  --from=builder /usr/local/bin/supercronic /usr/local/bin/supercronic

# Copy configs files to docker
COPY config/restic.sh /restic.sh
COPY config/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /restic.sh

ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/entrypoint.sh"]
