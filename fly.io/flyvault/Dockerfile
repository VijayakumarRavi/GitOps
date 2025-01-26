ARG VAULTWARDEN_VERSION=1.33.0
ARG TAILSCALE_VERSION=v1.78.3
ARG LITESTREAM_VERSION=0.3.13
ARG CLOUDFLARED_VERSION=2024.12.2

# Builder for downloading dependencies
FROM alpine as builder

# renovate: datasource=github-releases depName=DarthSim/overmind
ARG OVERMIND_VERSION=v2.5.1
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.33 
# renovate: datasource=github-releases depName=dani-garcia/bw_web_builds
ARG VAULT_VERSION=v2024.6.2c
# renovate: datasource=github-releases depName=caddyserver/caddy
ARG CADDY_VERSION=v2.9.1

# install dependencies
RUN apk add --no-cache wget gzip

# Download and extract Overmind (latest release)
RUN wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Download and install SuperCronic for linux-amd64 (latest release)
RUN wget -O /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
    && chmod +x /usr/local/bin/supercronic

# Download and extract Caddy (latest release)
RUN wget -O caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/${CADDY_VERSION}/caddy_${CADDY_VERSION#v}_linux_amd64.tar.gz"  \
    && tar -xzf caddy.tar.gz -C /usr/local/bin/ caddy

# Download and install Last Web-Vault (latest release)
RUN wget -O web-vault.tar.gz "https://github.com/dani-garcia/bw_web_builds/releases/download/${VAULT_VERSION}/bw_web_${VAULT_VERSION}.tar.gz" \
    && tar -xzf web-vault.tar.gz -C /

# Tailscale stage to fetch the latest Tailscale package
FROM tailscale/tailscale:${TAILSCALE_VERSION} as tailscale

# Litestream stage to fetch the latest Litestream package
FROM litestream/litestream:${LITESTREAM_VERSION} as litestream

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

# vaultwarden build stage
FROM vaultwarden/server:${VAULTWARDEN_VERSION}

VOLUME /

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y iptables iproute2 sqlite3 libnss3-tools libpq5 lsof jq gpg ca-certificates openssl tmux procps rclone \
    && rm -rf /var/lib/apt/lists/*

# Set timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && echo Asia/Kolkata > /etc/timezone

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy tailscale binary
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy Cloudflared binary 
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy litestream binary
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

# Copy Overmind binary
COPY --from=builder /usr/local/bin/overmind /usr/local/bin/overmind

# Copy Supercronic binary 
COPY --from=builder /usr/local/bin/supercronic /usr/local/bin/supercronic

# Copy Caddy binary 
COPY --from=builder /usr/local/bin/caddy /usr/local/bin/caddy

# Copy Web-Vault 
RUN rm -rfv /web-vault
COPY --from=builder /web-vault /web-vault

# Copy configs files to docker
COPY config/crontab /crontab
COPY config/Procfile /Procfile
COPY scripts/backup-rclone.sh /backup-rclone.sh
COPY scripts/cleanup-backups.sh /cleanup-backups.sh
COPY scripts/restore-data.sh /restore-data.sh
COPY config/Caddyfile /etc/caddy/Caddyfile
COPY config/litestream.yaml /etc/litestream.yaml
COPY entrypoint.sh /entrypoint.sh

# Chmod the scripts
RUN chmod +x /backup-rclone.sh
RUN chmod +x /cleanup-backups.sh
RUN chmod +x /restore-data.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start"]
