ARG ADGUARD_VERSION=v0.107.58
ARG TAILSCALE_VERSION=v1.80.3

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

# Tailscale stage to fetch the latest Tailscale package
FROM tailscale/tailscale:${TAILSCALE_VERSION} as tailscale

# Pull adguard image
FROM adguard/adguardhome:${ADGUARD_VERSION}

# install required dependencies
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables tmux jq bash curl py3-pip tzdata

# Timezone settings
ENV TZ=Asia/Kolkata
RUN cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

# install certbot dependencies
RUN pip install --upgrade --break-system-packages pip \
  && pip install --break-system-packages certbot certbot-dns-cloudflare

ENV CERTBOT_DOMAIN="" \
    CERTBOT_EMAIL="" \
    CERTBOT_KEY_TYPE="ecdsa" \
    CLOUDFLARE_API_TOKEN="" \
    RENEWAL_INTERVAL=43200

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
COPY config/certbot.sh /certbot.sh
COPY config/Procfile /Procfile
COPY config/entrypoint.sh /entrypoint.sh

# Chmod the scripts
RUN chmod +x /certbot.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK \
	--interval=30s \
	--timeout=10s \
	--retries=3 \
	CMD [ "/opt/adguardhome/scripts/healthcheck.sh" ]

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-c", "tailscale", "-r", "all", "-s", "/data/overmind.AGH.sock"]
