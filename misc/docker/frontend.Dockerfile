FROM caddy:2.10.2-alpine

COPY front/dist/microcrm/browser/ /app/front/
COPY misc/docker/Caddyfile /etc/caddy/Caddyfile

WORKDIR /app

EXPOSE 80
EXPOSE 443
