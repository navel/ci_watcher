# CIWatcher Backend API

Auth service for CIWatcher macOS app. Holds the GitHub App private key server-side and links each device to a single GitHub App installation.

Storage: **PostgreSQL** (persistent Docker volume; survives container restarts).

## Quick start (local)

1. Copy env file:

```bash
cp .env.example .env
```

2. Fill in `GITHUB_APP_ID` and `GITHUB_PRIVATE_KEY` in `.env`.

3. Start API + Postgres:

```bash
docker compose up --build
```

4. Health check:

```bash
curl http://localhost:8080/health
```

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | yes | Postgres connection string |
| `BASE_URL` | yes | Public API URL, no trailing slash |
| `GITHUB_APP_ID` | yes | GitHub App ID |
| `GITHUB_PRIVATE_KEY` | yes | PEM private key (`\n` escaped in env) |
| `GITHUB_APP_SLUG` | no | Default: `ciwatcher-native` |
| `GITHUB_CLIENT_ID` | no | Reserved for future OAuth use |
| `APP_URL_SCHEME` | no | Default: `ciwatcher` |
| `PORT` | no | Default: `8080` |

## Deploy to VPS (ciwatcher.navel.uk)

Production stack lives alongside existing `content_maker` services on the same host:

- **Postgres** — private Docker network only (no host port; does not conflict with content_maker Postgres on `:5432`)
- **API** — joins `content_maker` Docker network; proxied by existing nginx on `:443`
- **SSL** — Let's Encrypt cert for `ciwatcher.navel.uk`, served by content_maker nginx

### Automatic deploy (GitHub Actions)

On every push to `main` that changes `backend/**`, CI runs tests and then deploys to production.

**One-time:** add repository secrets:

| Secret | Example |
|--------|---------|
| `CIWATCHER_DEPLOY_HOST` | `root@91.98.47.222` |
| `CIWATCHER_DEPLOY_SSH_KEY` | private key with SSH access to the server |

Generate a deploy-only key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ciwatcher-deploy -N "" -C "ciwatcher-github-deploy"
ssh-copy-id -i ~/.ssh/ciwatcher-deploy.pub root@your-server
gh secret set CIWATCHER_DEPLOY_HOST --body "root@your-server"
gh secret set CIWATCHER_DEPLOY_SSH_KEY < ~/.ssh/ciwatcher-deploy
```

Manual deploy from GitHub: **Actions → Backend Deploy → Run workflow**.

### Manual deploy (local)

```bash
cd backend
./deploy/deploy.sh
```

First-time server bootstrap (nginx + SSL):

```bash
./deploy/deploy.sh --setup-nginx --issue-cert
```

### One-time server setup

1. **Cloudflare DNS**: `ciwatcher` A record → server IP

2. **Create env on server**:

```bash
ssh server
mkdir -p /opt/ciwatcher
cp /opt/ciwatcher/deploy/.env.prod.example /opt/ciwatcher/.env
# edit .env — set POSTGRES_PASSWORD, DATABASE_URL password, GitHub secrets
```

3. **GitHub App** — set Setup URL to:

`https://ciwatcher.navel.uk/v1/auth/callback`

4. **macOS app** — set `CIWATCHER_API_BASE_URL = https://ciwatcher.navel.uk`

### Data persistence

Postgres data is stored in the `postgres_data` Docker volume. Restarting or rebuilding the API container does **not** wipe the database. To destroy data intentionally: `docker volume rm ciwatcher_postgres_data`.

## API

### `POST /v1/auth/start`

Registers/updates a device and returns the GitHub install URL.

### `GET /v1/auth/callback`

GitHub Setup URL callback.

### `POST /v1/auth/token`

Returns a GitHub installation token for the linked device.

### `GET /v1/me/installation`

Returns connection status for the current device.

### `DELETE /v1/auth`

Unlinks the device from its GitHub installation.
