ARG TSVERSION=v1.78.3
ARG VWVERSION=1.32.7

# Tailscale stage to fetch the latest Tailscale package
FROM tailscale/tailscale:${TSVERSION} as tailscale

# vaultwarden build stage
FROM vaultwarden/server:${VWVERSION}

ARG DOMAIN

# Set Env
ENV TZ="Asia/Kolkata" \
    ROCKET_PROFILE="release" \
    ROCKET_ADDRESS=0.0.0.0 \
    ROCKET_PORT=8080 \
    ROCKET_WORKERS=50 \
    SSL_CERT_DIR=/etc/ssl/certs \
    EMERGENCY_ACCESS_ALLOWED=true \
    EXTENDED_LOGGING=true \
    LOG_FILE=/data/vaultwarden.log \
    LOG_LEVEL=info \
    IP_HEADER=X-Forwarded-For \
    ORG_CREATION_USERS=all \
    ORG_EVENTS_ENABLED=false \
    ORG_GROUPS_ENABLED=false \
    PUSH_ENABLED=true \
    RELOAD_TEMPLATES=false \
    SENDS_ALLOWED=true \
    SHOW_PASSWORD_HINT=true \
    SIGNUPS_ALLOWED=false \
    SIGNUPS_VERIFY=true \
    SIGNUPS_DOMAINS_WHITELIST=vijayakumar.xyz \
    SIGNUPS_VERIFY_RESEND_TIME=3600 \
    SIGNUPS_VERIFY_RESEND_LIMIT=3600 \
    INVITATIONS_ALLOWED=true \
    USE_SYSLOG=false \
    WEBSOCKET_ENABLED=true \
    WEB_VAULT_ENABLED=true \
    DATABASE_MAX_CONNS=10 \
    DB_CONNECTION_RETRIES=15 \
    ICON_SERVICE=bitwarden \
    ICON_DOWNLOAD_TIMEOUT=20 \
    ICON_BLACKLIST_NON_GLOBAL_IPS=true \
    EMAIL_CHANGE_ALLOWED=true \
    EMAIL_ATTEMPTS_LIMIT=3 \
    EMAIL_TOKEN_SIZE=6 \
    PASSWORD_HINTS_ALLOWED=true \
    LOGIN_RATELIMIT_MAX_BURST=5 \
    LOGIN_RATELIMIT_SECONDS=60 \
    ADMIN_SESSION_LIFETIME=3 \
    DOMAIN=https://${DOMAIN} \
    DOMAIN_NAME=${DOMAIN} \
    SMTP_FROM=no-reply@vijayakumar.xyz \
    SMTP_FROM_NAME=Vaultwarden \
    SMTP_PORT=587 \
    SMTP_TIMEOUT=15 \
    SMTP_AUTH_MECHANISM=login \
    REQUIRE_DEVICE_EMAIL=true \
    EXPERIMENTAL_CLIENT_FEATURE_FLAGS=fido2-vault-credentials,ssh-agent,ssh-key-vault-item,autofill-v2,autofill-overlay

VOLUME /
# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y  iptables ip6tables iproute2 sqlite3 libnss3-tools libpq5 wget curl tar lsof jq gpg ca-certificates openssl tmux procps neovim rclone \
    && rm -rf /var/lib/apt/lists/*

# Set the timezone to Riga at runtime
RUN ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && echo Asia/Kolkata > /etc/timezone

# Download and extract Overmind (latest release)
RUN OVERMIND_VERSION=$(curl -s https://api.github.com/repos/DarthSim/overmind/releases/latest | jq -r '.tag_name') \
    && wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Download and install SuperCronic for linux-amd64 (latest release)
RUN SUPERCRONIC_VERSION=$(curl -s https://api.github.com/repos/aptible/supercronic/releases/latest | jq -r '.tag_name') \
    && wget -O /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
    && chmod +x /usr/local/bin/supercronic

# Download and install Last Web-Vault (latest release)
RUN VAULT_VERSION=$(curl -s https://api.github.com/repos/dani-garcia/bw_web_builds/releases/latest | jq -r '.tag_name') \
    && rm -rf /web-vault \
    && wget -O web-vault.tar.gz "https://github.com/dani-garcia/bw_web_builds/releases/download/${VAULT_VERSION}/bw_web_v${VAULT_VERSION#v}.tar.gz" \
    && tar -xzf web-vault.tar.gz -C /

# Download and extract Caddy (latest release)
RUN CADDY_VERSION=$(curl -s https://api.github.com/repos/caddyserver/caddy/releases/latest | jq -r '.tag_name') \
    && wget -O caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/$CADDY_VERSION/caddy_${CADDY_VERSION#v}_linux_amd64.tar.gz" \
    && tar -xzf caddy.tar.gz -C /usr/local/bin/ caddy

# Install cloudflared tunnel (latest release)
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \
    && dpkg -i cloudflared.deb

# Delete downloaded archives
RUN rm -rf overmind.gz web-vault.tar.gz cloudflared.deb caddy.tar.gz

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy binary to production image
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy files to docker
COPY config/crontab /crontab
COPY config/Procfile /Procfile
COPY scripts/backup-rclone.sh /backup-rclone.sh
COPY scripts/cleanup-backups.sh /cleanup-backups.sh
COPY scripts/backup-data-github.sh /backup-data-github.sh
COPY scripts/restore-data.sh /restore-data.sh
COPY scripts/restore-data-github.sh /restore-data-github.sh
COPY config/Caddyfile /etc/caddy/Caddyfile
COPY entrypoint.sh /entrypoint.sh

# Chmod the scripts
RUN chmod +x /backup-rclone.sh
RUN chmod +x /cleanup-backups.sh
RUN chmod +x /backup-data-github.sh
RUN chmod +x /restore-data.sh
RUN chmod +x /restore-data-github.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start"]
