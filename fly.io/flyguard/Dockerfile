ARG TSVERSION=v1.78.1
ARG AGVERSION=v0.107.55

#
FROM tailscale/tailscale:${TSVERSION} as tailscale

# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
# https://github.com/AdguardTeam/AdGuardHome/blob/master/docker/Dockerfile
FROM adguard/adguardhome:${AGVERSION}
RUN apk update && apk add bash ca-certificates iptables ip6tables iproute2 wget curl tar lsof gpg openssl tmux procps neovim jq && rm -rf /var/cache/apk/*

# creating directories for tailscale
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/cache/tailscale
RUN mkdir -p /var/lib/tailscale

# Copy Tailscale bins from the Tailscale stage into the container
COPY --from=tailscale /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=tailscale /usr/local/bin/tailscale /usr/local/bin/tailscale

# Copy files to docker
COPY config/start.sh /start.sh
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh

# Chmod the scripts
RUN chmod +x /start.sh
RUN chmod +x /entrypoint.sh

# Download and extract Overmind (latest release)
RUN OVERMIND_VERSION=$(curl -s https://api.github.com/repos/DarthSim/overmind/releases/latest | jq -r '.tag_name') \
    && wget -O overmind.gz "https://github.com/DarthSim/overmind/releases/download/$OVERMIND_VERSION/overmind-${OVERMIND_VERSION}-linux-amd64.gz" \
    && gunzip overmind.gz \
    && chmod +x overmind \
    && mv overmind /usr/local/bin/

# Delete downloaded archives
RUN rm -rf overmind.gz

HEALTHCHECK \
	--interval=30s \
	--timeout=10s \
	--retries=3 \
	CMD [ "/opt/adguardhome/scripts/healthcheck.sh" ]

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start" ,"-f", "/Procfile"]
