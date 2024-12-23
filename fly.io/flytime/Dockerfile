ARG TSVERSION=v1.78.3
ARG UPVERSION=1.23.16-alpine

# Tailscale stage to fetch the latest Tailscale package
FROM tailscale/tailscale:${TSVERSION} as tailscale

# Uptime Kuma build stage
FROM louislam/uptime-kuma:${UPVERSION}
RUN apk update && apk add bash ca-certificates iptables ip6tables iproute2 wget curl tar lsof openssl tmux procps neovim jq && rm -rf /var/cache/apk/*

WORKDIR /app

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy binary to production image
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy files to docker & change permission
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Download and extract Overmind (latest release)
RUN OVERMIND_VERSION=$(curl -s https://api.github.com/repos/DarthSim/overmind/releases/latest | jq -r '.tag_name') \
    && wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Delete downloaded archives
RUN rm -rf overmind.gz

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
