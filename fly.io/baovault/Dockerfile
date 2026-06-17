ARG BAOVAULT_VERSION=2.5.5
ARG CLOUDFLARED_VERSION=2026.6.0

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

# vaultwarden build stage
FROM quay.io/openbao/openbao:${BAOVAULT_VERSION}

# Install runtime dependencies and set timezone
RUN apk add --no-cache tini curl bash tzdata && \
    ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo Asia/Kolkata > /etc/timezone

# Copy Cloudflared binary
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy configs files to docker
COPY config/entrypoint.sh /entrypoint.sh
COPY config/healthcheck.sh /healthcheck.sh

RUN chmod +x /entrypoint.sh /healthcheck.sh

ENTRYPOINT ["/sbin/tini", "-s", "--", "/entrypoint.sh"]
