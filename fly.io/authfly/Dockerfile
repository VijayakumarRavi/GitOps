ARG POCKETID_VERSION=v1.9.1
ARG CLOUDFLARED_VERSION=2025.8.1

# Builder for downloading dependencies
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

# Download and install SuperCronic for linux-amd64 (latest release)
RUN wget -O /usr/local/bin/supercronic "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
    && chmod +x /usr/local/bin/supercronic

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

FROM lldap/lldap:latest as lldap

# pocket id build stage
FROM ghcr.io/pocket-id/pocket-id:${POCKETID_VERSION}

# Set timezone
RUN ln -snf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && echo Asia/Kolkata > /etc/timezone

# Install runtime dependencies
RUN apk add --no-cache tmux restic tzdata uuidgen curl su-exec 

# Copy Cloudflared binary 
COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Copy Overmind binary
COPY --from=builder /usr/local/bin/overmind /usr/local/bin/overmind

# Copy Supercronic binary 
COPY --from=builder /usr/local/bin/supercronic /usr/local/bin/supercronic

# Copy lldap data and binaries
COPY --from=lldap /app /app/lldap

# Copy configs files to docker
COPY config/Procfile /Procfile
COPY config/restic.sh /restic.sh
COPY config/entrypoint.sh /entrypoint.sh

# Chmod the entrypoint
RUN chmod +x /entrypoint.sh /restic.sh

WORKDIR /app

EXPOSE 5000
ENV APP_ENV=production
ENV LDAP_PORT=3890
ENV HTTP_PORT=17170
# Set the entrypoint script as the entrypoint for the container
ENTRYPOINT ["/entrypoint.sh"]

# Start Overmind
CMD ["overmind", "start","-f", "/Procfile", "-r", "all", "-s", "/overmind.vault.sock"]
