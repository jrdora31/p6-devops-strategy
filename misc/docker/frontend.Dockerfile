FROM caddy:2.11.4-alpine@sha256:5f5c8640aae01df9654968d946d8f1a56c497f1dd5c5cda4cf95ab7c14d58648

COPY front/dist/microcrm/browser/ /app/front/
COPY misc/docker/Caddyfile /etc/caddy/Caddyfile

WORKDIR /app

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --output-document=- http://127.0.0.1/ >/dev/null || exit 1
