ARG BAOVAULT_VERSION=2.4.0-nightly1752150785
ARG CLOUDFLARED_VERSION=2025.8.1

# Builder for downloading dependencies
FROM alpine as builder

# renovate: datasource=github-releases depName=DarthSim/overmind
ARG OVERMIND_VERSION=v2.5.1

# install dependencies
RUN apk add --no-cache wget gzip

# Download and extract Overmind (latest release)
RUN wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

# vaultwarden build stage
FROM quay.io/openbao/openbao-nightly:${BAOVAULT_VERSION}

# Set timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && echo Asia/Kolkata > /etc/timezone

# Install runtime dependencies
RUN apk add --no-cache tmux curl bash tzdata

# Copy Cloudflared binary 
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy Overmind binary
COPY --from=builder /usr/local/bin/overmind /usr/local/bin/overmind

# Copy configs files to docker
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh
COPY config/healthcheck.sh /healthcheck.sh

# Chmod the entrypoint
RUN chmod +x /entrypoint.sh
RUN chmod +x /healthcheck.sh

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-r", "all", "-s", "/overmind.hcvault.sock"]
