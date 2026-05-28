ARG GOTIFY_VERSION=2.9.1
ARG IGOTIFY_VERSION=v1.5.1.3
ARG CLOUDFLARED_VERSION=2026.5.2

FROM ghcr.io/gotify/server:${GOTIFY_VERSION} AS gotify

FROM ghcr.io/androidseb25/igotify-notification-assist:${IGOTIFY_VERSION} AS igotify

# Cloudflared stage to fetch the latest cloudflared package
FROM cloudflare/cloudflared:${CLOUDFLARED_VERSION} as cloudflared

FROM mcr.microsoft.com/dotnet/aspnet:10.0

WORKDIR /data
RUN mkdir -p /data/gotify /data/igotify

RUN apt-get update && apt-get install -y \
  supervisor \
  curl \
  tzdata \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=gotify /app /app/gotify

COPY --from=igotify /app /app/igotify

COPY --from=cloudflared /usr/local/bin/cloudflared /usr/local/bin/cloudflared

COPY ./config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN useradd -r -s /usr/sbin/nologin appuser
RUN chown -R appuser:appuser /data /app

ENV GOTIFY_SERVER_PORT=8081
ENV GOTIFY_SERVER_TRUSTEDPROXIES=[127.0.0.1]
ENV GOTIFY_SERVER_LISTENADDR=127.0.0.1

EXPOSE 8080
EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl --fail http://localhost:8080/health || exit 1

CMD ["/usr/bin/supervisord", "-n"]
