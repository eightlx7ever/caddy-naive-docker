FROM caddy:2.11.7-alpine

COPY caddy /usr/bin/caddy

RUN chmod 755 /usr/bin/caddy
