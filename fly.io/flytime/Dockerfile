ARG UPTIME_VERSION=1.23.16-alpine
ARG TAILSCALE_VERSION=v1.78.3
ARG LITESTREAM_VERSION=0.3.13

# Builder for Overmind download
FROM alpine as overmind

# renovate: datasource=github-releases depName=DarthSim/overmind
ARG OVERMIND_VERSION=v2.4.0

# install dependencies
RUN apk add --no-cache wget gzip

# Download and extract Overmind (latest release)
RUN wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Tailscale stage to fetch the latest Tailscale package
FROM tailscale/tailscale:${TAILSCALE_VERSION} as tailscale

# Litestream stage to fetch the latest Litestream package
FROM litestream/litestream:${LITESTREAM_VERSION} as litestream

# Uptime Kuma build stage
FROM louislam/uptime-kuma:${UPTIME_VERSION}

# install required dependencies
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables tmux jq bash

WORKDIR /app

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy tailscale binary
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy litestream binary
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

# Copy Overmind binary
COPY --from=overmind /usr/local/bin/overmind /usr/local/bin/overmind

# Copy files to docker & change permission
COPY config/litestream.yaml /etc/litestream.yaml
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose necessary port for the application
EXPOSE 3001

# Define volume for persistent data
VOLUME ["/app/data"]

# Define health check commands for Uptime Kuma
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 CMD extra/healthcheck

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start" ,"-f", "/Procfile"]
