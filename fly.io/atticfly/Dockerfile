ARG ATTIC_VERSION=latest@sha256:18574aba70fc89d2b695273fbe2e7b2f8ad7e8e786b4cc535124fbe14bada1d0
# pocket id build stage
FROM ghcr.io/zhaofengli/attic:${ATTIC_VERSION}

COPY config/server.toml /server.toml

EXPOSE 8080

CMD ["-f", "/server.toml", "--mode", "monolithic"]
