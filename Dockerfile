FROM nginx:1.29-alpine

LABEL org.opencontainers.image.title="ServerDeck landing site"
LABEL org.opencontainers.image.description="The public ServerDeck landing page and install bootstrap"
LABEL org.opencontainers.image.source="https://github.com/onjoakimsmind/serverdeck"
LABEL org.opencontainers.image.url="https://serverdeck.black.ax"

COPY nginx.conf /etc/nginx/nginx.conf
COPY --chown=nginx:nginx public/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

USER nginx
