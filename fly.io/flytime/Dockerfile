ARG UPTIME_VERSION=1.23.16-alpine
ARG TAILSCALE_VERSION=v1.78.3
ARG LITESTREAM_VERSION=0.3.13
ARG DNSPROXY_VERSION=v0.74.1
# Builder for Overmind download
FROM alpine as overmind

# renovate: datasource=github-releases depName=DarthSim/overmind
ARG OVERMIND_VERSION=v2.5.1

# install dependencies
RUN apk add --no-cache wget gzip

# Download and extract Overmind (latest release)
RUN wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Fetch the latest tailscale package from it's official Docker image
FROM tailscale/tailscale:${TAILSCALE_VERSION} as tailscale

# Fetch the latest litestream package from it's official Docker image
FROM litestream/litestream:${LITESTREAM_VERSION} as litestream

# Fetch the latest dnsproxy package from it's official Docker image
FROM adguard/dnsproxy:${DNSPROXY_VERSION} as dnsproxy

# Uptime Kuma build stage
FROM louislam/uptime-kuma:${UPTIME_VERSION}

# install required dependencies
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables tmux jq curl bash

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy tailscale binary
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy litestream binary
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

# Copy dnsproxy binary
COPY --from=dnsproxy /opt/dnsproxy/dnsproxy /usr/local/bin/dnsproxy

# Copy Overmind binary
COPY --from=overmind /usr/local/bin/overmind /usr/local/bin/overmind

# Copy files to docker & change permission
COPY config/litestream.yaml /etc/litestream.yaml
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose necessary port for the application
EXPOSE 3001

# Define health check commands for Uptime Kuma
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=5 CMD extra/healthcheck

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-c", "tailscale", "-x", "dnsproxy", "-r", "all", "-s", "/data/overmind.uptime.sock"]
