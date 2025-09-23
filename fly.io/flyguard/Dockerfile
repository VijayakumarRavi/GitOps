ARG ADGUARD_VERSION=v0.107.66
ARG CLOUDFLARED_VERSION=2025.9.1

# Builder for Overmind download
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

RUN wget -O /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
  && chmod +x /usr/local/bin/supercronic

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

# Pull adguard image
FROM adguard/adguardhome:${ADGUARD_VERSION}

# install required dependencies
RUN apk add --no-cache ca-certificates iptables iproute2 ip6tables tmux jq bash curl tzdata restic uuidgen

# Timezone settings
ENV TZ=Asia/Kolkata
RUN cp /usr/share/zoneinfo/Asia/Kolkata /etc/localtime

# Copy Cloudflared binary 
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy Overmind binary
COPY --from=builder /usr/local/bin/overmind /usr/local/bin/overmind

# Copy Supercronic binary 
COPY --from=builder /usr/local/bin/supercronic /usr/local/bin/supercronic

# Copy files to docker
COPY config/ / 

# Chmod the scripts
RUN chmod +x -v /*.sh

# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-r", "all", "-s", "/overmind.AGH.sock"]
