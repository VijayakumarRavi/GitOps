ARG GATUS_VERSION=v5.36.0
ARG TAILSCALE_VERSION=v1.98.4
ARG DNSPROXY_VERSION=v0.81.3
ARG CLOUDFLARED_VERSION=2026.5.2

# Fetch the latest tailscale package from it's official Docker image
FROM tailscale/tailscale:${TAILSCALE_VERSION} as tailscale

# Fetch the latest dnsproxy package from it's official Docker image
FROM adguard/dnsproxy:${DNSPROXY_VERSION} as dnsproxy

# Gatus build stage
FROM twinproduction/gatus:${GATUS_VERSION} as gatus

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

FROM alpine as final

# install required dependencies and set timezone
ENV TZ=Asia/Kolkata
RUN apk add --no-cache tini ca-certificates iptables iproute2 ip6tables jq curl bash tzdata && \
    cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    mkdir -p /var/run/tailscale /var/cache/tailscale /var/lib/tailscale

# Copy binaries
COPY  --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY  --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale
COPY  --from=dnsproxy /opt/dnsproxy/dnsproxy /usr/local/bin/dnsproxy
COPY  --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy files to docker & change permission
COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Gatus binary and configuration file
COPY  --from=gatus /gatus /usr/local/bin/gatus
COPY  --from=gatus /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY gatus /config

ENTRYPOINT ["/sbin/tini", "-s", "--", "/entrypoint.sh"]
