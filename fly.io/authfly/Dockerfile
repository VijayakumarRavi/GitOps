ARG POCKETID_VERSION=v2.11.0
ARG CLOUDFLARED_VERSION=2026.8.3

# Builder for downloading dependencies
FROM alpine as builder
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.44
RUN apk add --no-cache wget && \
    wget -O /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" && \
    chmod +x /usr/local/bin/supercronic

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

FROM lldap/lldap:latest as lldap

# pocket id build stage
FROM ghcr.io/pocket-id/pocket-id:${POCKETID_VERSION}

# Install runtime dependencies and set timezone
RUN apk add --no-cache tini restic tzdata uuidgen curl su-exec && \
    ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo Asia/Kolkata > /etc/timezone

# Copy binaries
COPY  --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared
COPY  --from=builder /usr/local/bin/supercronic /usr/local/bin/supercronic
COPY  --from=lldap /app /app/lldap

# Copy config files
COPY config/restic.sh /restic.sh
COPY config/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /restic.sh

WORKDIR /app

EXPOSE 5000
ENV APP_ENV=production
ENV LDAP_PORT=3890
ENV HTTP_PORT=17170

ENTRYPOINT ["/sbin/tini", "-s", "--", "/entrypoint.sh"]
