#!/usr/bin/env bash
# Run after ciwatcher.navel.uk cert renewal (certbot deploy hook / renewal-hooks).
set -euo pipefail

case "${RENEWED_DOMAINS:-ciwatcher.navel.uk}" in
  *ciwatcher.navel.uk*) ;;
  *) exit 0 ;;
esac

CONTENT_MAKER_SSL="/opt/content_maker/nginx/ssl/ciwatcher.navel.uk"
EDGE_NGINX_CONTAINER="${EDGE_NGINX_CONTAINER:-edge-nginx}"
LINEAGE="${RENEWED_LINEAGE:-/etc/letsencrypt/live/ciwatcher.navel.uk}"

if [[ ! -f "${LINEAGE}/fullchain.pem" ]]; then
  echo "ciwatcher certbot hook: missing ${LINEAGE}/fullchain.pem" >&2
  exit 1
fi

mkdir -p "$CONTENT_MAKER_SSL"
cp "${LINEAGE}/fullchain.pem" "${CONTENT_MAKER_SSL}/fullchain.pem"
cp "${LINEAGE}/privkey.pem" "${CONTENT_MAKER_SSL}/privkey.pem"
chmod 644 "${CONTENT_MAKER_SSL}/fullchain.pem"
chmod 600 "${CONTENT_MAKER_SSL}/privkey.pem"

if docker ps --format '{{.Names}}' | grep -qx "$EDGE_NGINX_CONTAINER"; then
  docker exec "$EDGE_NGINX_CONTAINER" nginx -t
  docker exec "$EDGE_NGINX_CONTAINER" nginx -s reload
fi

echo "ciwatcher SSL updated and edge-nginx reloaded"
