# CIWatcher Backend API

Auth service for CIWatcher macOS app. Holds the GitHub App private key server-side and links each device to a single GitHub App installation.

Storage: **SQLite** (single file, no separate Postgres service).

## Quick start (local)

1. Copy env file:

```bash
cp .env.example .env
```

2. Fill in `GITHUB_APP_ID` and `GITHUB_PRIVATE_KEY` in `.env`.

3. Start API:

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
| `SQLITE_PATH` | no | SQLite file path. Default: `./data/ciwatcher.db` |
| `BASE_URL` | yes | Public API URL, no trailing slash |
| `GITHUB_APP_ID` | yes | GitHub App ID |
| `GITHUB_PRIVATE_KEY` | yes | PEM private key (`\n` escaped in env) |
| `GITHUB_APP_SLUG` | no | Default: `ciwatcher-native` |
| `GITHUB_CLIENT_ID` | no | Reserved for future OAuth use |
| `APP_URL_SCHEME` | no | Default: `ciwatcher` |
| `PORT` | no | Default: `8080` |

## Deploy to Fly.io

One-time volume setup:

```bash
cd backend
fly volumes create ciwatcher_data --size 1 --region fra
```

Deploy:

```bash
fly secrets set \
  BASE_URL=https://ciwatcher-api.fly.dev \
  GITHUB_APP_ID=... \
  GITHUB_PRIVATE_KEY='...'
fly deploy
```

`SQLITE_PATH=/data/ciwatcher.db` is already set in `fly.toml`. The database file lives on a Fly volume.

Then set GitHub App **Setup URL** to:

`https://ciwatcher-api.fly.dev/v1/auth/callback`

## API

See the previous sections in git history or `DEVELOPMENT.md` for endpoint docs.

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
