ARG GATUS_VERSION=v5.26.0
ARG TAILSCALE_VERSION=v1.88.3
ARG DNSPROXY_VERSION=v0.77.0
ARG CLOUDFLARED_VERSION=2025.9.1

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

# Fetch the latest dnsproxy package from it's official Docker image
FROM adguard/dnsproxy:${DNSPROXY_VERSION} as dnsproxy

# Gatus Kuma build stage
FROM twinproduction/gatus:${GATUS_VERSION} as gatus

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

FROM alpine as final

# install required dependencies
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables tmux jq curl bash tzdata

# Timezone settings
ENV TZ=Asia/Kolkata
RUN cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Copy tailscale binary
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy dnsproxy binary
COPY --from=dnsproxy /opt/dnsproxy/dnsproxy /usr/local/bin/dnsproxy

# Copy Cloudflared binary
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy Overmind binary
COPY --from=overmind /usr/local/bin/overmind /usr/local/bin/overmind

# Copy files to docker & change permission
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Gatus binary and configuration file
COPY --from=gatus /gatus /usr/local/bin/gatus
COPY --from=gatus /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY gatus /config

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-c", "tailscale", "-x", "dnsproxy", "-r", "all", "-s", "/overmind.gatus.sock"]
