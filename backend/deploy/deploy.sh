#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${ROOT_DIR}/deploy"
REMOTE_DIR="/opt/ciwatcher"
CONTENT_MAKER_NGINX="/opt/content_maker/nginx/nginx.conf"
CONTENT_MAKER_SSL="/opt/content_maker/nginx/ssl/ciwatcher.navel.uk"
BEGIN_MARKER="# BEGIN CIWATCHER API"
END_MARKER="# END CIWATCHER API"
HEALTH_URL="${CIWATCHER_DEPLOY_HEALTH_URL:-https://ciwatcher.navel.uk/health}"

usage() {
  cat <<'EOF'
Usage: deploy/deploy.sh [--host user@server] [--setup-nginx] [--issue-cert] [--skip-health]

Deploy CIWatcher API to the VPS.

Environment:
  CIWATCHER_DEPLOY_HOST          SSH target (same as --host)
  CIWATCHER_DEPLOY_HEALTH_URL    Post-deploy health check URL

Options:
  --host HOST         SSH target (default: CIWATCHER_DEPLOY_HOST, then `tocontent`)
  --setup-nginx       Inject nginx vhost into content_maker nginx.conf (one-time)
  --issue-cert        Issue Let's Encrypt cert for ciwatcher.navel.uk (one-time)
  --skip-health       Skip public HTTPS health check

Requires /opt/ciwatcher/.env on the server (see deploy/.env.prod.example).
EOF
}

SSH_HOST="${CIWATCHER_DEPLOY_HOST:-}"
SETUP_NGINX=false
ISSUE_CERT=false
SKIP_HEALTH=false
SSH_IDENTITY_FILE="${CIWATCHER_DEPLOY_SSH_KEY_FILE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) SSH_HOST="$2"; shift 2 ;;
    --setup-nginx) SETUP_NGINX=true; shift ;;
    --issue-cert) ISSUE_CERT=true; shift ;;
    --skip-health) SKIP_HEALTH=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

ssh_cmd() {
  local -a args=(-o BatchMode=yes)
  if [[ -n "$SSH_IDENTITY_FILE" ]]; then
    args+=(-i "$SSH_IDENTITY_FILE")
  fi
  ssh "${args[@]}" "$@"
}

if [[ -n "$SSH_HOST" ]]; then
  run_remote() { ssh_cmd "$SSH_HOST" "$@"; }
  run_remote_stdin() { ssh_cmd "$SSH_HOST" "$@"; }
elif command -v tocontent >/dev/null 2>&1; then
  run_remote() { tocontent "$@"; }
  run_remote_stdin() { tocontent "$@"; }
else
  echo "Error: pass --host or set CIWATCHER_DEPLOY_HOST" >&2
  exit 1
fi

echo "==> Syncing backend to ${REMOTE_DIR}"
run_remote "mkdir -p ${REMOTE_DIR}/deploy/nginx"
COPYFILE_DISABLE=1 tar -C "$ROOT_DIR" -czf - \
  Dockerfile go.mod go.sum cmd internal | run_remote_stdin "tar -xzf - -C ${REMOTE_DIR}"
COPYFILE_DISABLE=1 tar -C "$DEPLOY_DIR" -czf - \
  docker-compose.prod.yml nginx .env.prod.example deploy.sh | run_remote_stdin "tar -xzf - -C ${REMOTE_DIR}/deploy"

echo "==> Building and starting containers"
run_remote "test -f ${REMOTE_DIR}/.env" || {
  echo "Missing ${REMOTE_DIR}/.env — copy deploy/.env.prod.example and fill secrets first." >&2
  exit 1
}
run_remote "cd ${REMOTE_DIR} && docker compose -f deploy/docker-compose.prod.yml --env-file .env up -d --build --remove-orphans"

if $SETUP_NGINX; then
  echo "==> Installing nginx vhost into content_maker"
  run_remote "mkdir -p ${CONTENT_MAKER_SSL}"
  if ! run_remote "test -f ${CONTENT_MAKER_SSL}/fullchain.pem"; then
    run_remote "openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
      -keyout ${CONTENT_MAKER_SSL}/privkey.pem \
      -out ${CONTENT_MAKER_SSL}/fullchain.pem \
      -subj '/CN=ciwatcher.navel.uk'"
  fi
  run_remote "python3 - <<'PY'
from pathlib import Path

main = Path('${CONTENT_MAKER_NGINX}')
snippet = Path('${REMOTE_DIR}/deploy/nginx/ciwatcher.navel.uk.conf')
text = main.read_text()
block = '${BEGIN_MARKER}\\n' + snippet.read_text().rstrip() + '\\n${END_MARKER}\\n'
if '${BEGIN_MARKER}' in text:
    start = text.index('${BEGIN_MARKER}')
    end = text.index('${END_MARKER}') + len('${END_MARKER}')
    text = text[:start] + block.rstrip() + text[end:]
else:
    close = text.rfind('}\\n')
    if close == -1:
        raise SystemExit('could not find http block closing brace')
    text = text[:close] + '\\n' + block.rstrip() + '\\n' + text[close:]
main.write_text(text)
PY"
  run_remote "docker exec content_maker-nginx-1 nginx -t"
  run_remote "docker exec content_maker-nginx-1 nginx -s reload"
fi

if $ISSUE_CERT; then
  echo "==> Issuing Let's Encrypt certificate for ciwatcher.navel.uk"
  run_remote "mkdir -p /var/www/certbot ${CONTENT_MAKER_SSL}"
  run_remote "certbot certonly --webroot -w /var/www/certbot -d ciwatcher.navel.uk --non-interactive --agree-tos --register-unsafely-without-email || certbot certonly --webroot -w /var/www/certbot -d ciwatcher.navel.uk --non-interactive --agree-tos -m admin@navel.uk"
  run_remote "cp /etc/letsencrypt/live/ciwatcher.navel.uk/fullchain.pem ${CONTENT_MAKER_SSL}/fullchain.pem"
  run_remote "cp /etc/letsencrypt/live/ciwatcher.navel.uk/privkey.pem ${CONTENT_MAKER_SSL}/privkey.pem"
  run_remote "docker exec content_maker-nginx-1 nginx -s reload"
fi

echo "==> Container status"
run_remote "docker ps --filter name=ciwatcher --format 'table {{.Names}}\t{{.Status}}'"

if ! $SKIP_HEALTH; then
  echo "==> Health check: ${HEALTH_URL}"
  for attempt in 1 2 3 4 5; do
    if curl -fsS "$HEALTH_URL" >/dev/null; then
      curl -fsS "$HEALTH_URL"
      echo
      echo "Deploy complete."
      exit 0
    fi
    sleep 3
  done
  echo "Health check failed: ${HEALTH_URL}" >&2
  exit 1
fi

echo "Deploy complete."
