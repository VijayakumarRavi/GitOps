ARG VAULTWARDEN_VERSION=1.34.3
ARG LITESTREAM_VERSION=0.3.13
ARG CLOUDFLARED_VERSION=2025.8.0

# Builder for downloading dependencies
FROM alpine as builder

# renovate: datasource=github-releases depName=DarthSim/overmind
ARG OVERMIND_VERSION=v2.5.1
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.34
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

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

# vaultwarden build stage
FROM vaultwarden/server:${VAULTWARDEN_VERSION}

# Set timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && echo Asia/Kolkata > /etc/timezone

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y tmux restic tzdata uuid-runtime \
    && rm -rf /var/lib/apt/lists/*

# Copy Cloudflared binary 
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy Overmind binary
COPY --from=builder /usr/local/bin/overmind /usr/local/bin/overmind

# Copy Supercronic binary 
COPY --from=builder /usr/local/bin/supercronic /usr/local/bin/supercronic

# Copy configs files to docker
COPY config/Procfile /Procfile
COPY config/restic.sh /restic.sh
COPY config/entrypoint.sh /entrypoint.sh

# Chmod the entrypoint
RUN chmod +x /entrypoint.sh /restic.sh

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-r", "all", "-s", "/overmind.vault.sock"]
