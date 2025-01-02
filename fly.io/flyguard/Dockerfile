ARG ADGUARD_VERSION=v0.107.55
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

# Pull adguard image
FROM adguard/adguardhome:${ADGUARD_VERSION}

# install required dependencies
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables tmux jq bash curl

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy tailscale binary
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy Overmind binary
COPY --from=overmind /usr/local/bin/overmind /usr/local/bin/overmind

# Copy files to docker
COPY config/start.sh /start.sh
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh

# Chmod the scripts
RUN chmod +x /start.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK \
	--interval=30s \
	--timeout=10s \
	--retries=3 \
	CMD [ "/opt/adguardhome/scripts/healthcheck.sh" ]

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start" ,"-f", "/Procfile"]
