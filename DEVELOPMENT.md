# CIWatcher — Development Guide

## Requirements

- macOS 14+
- Xcode 16+
- Swift 5.9+
- A configured [GitHub App](https://github.com/apps/ciwatcher-native) (for integration tests)

## Project Structure

```
CIWatcher.xcworkspace     # Open this in Xcode
├── CIWatcher-macOS/      # Menu bar macOS app
├── CIWatcher-iOS/        # iOS app (WIP)
├── SharedCore/           # Shared Swift package (API, auth, notifications)
└── backend/              # Go auth API (GitHub App private key stays server-side)
```

## First-Time Setup

1. Copy the secrets template:

   ```bash
   cp CIWatcher-macOS/CIWatcher-macOS/Secrets.xcconfig.example \
      CIWatcher-macOS/CIWatcher-macOS/Secrets.xcconfig
   ```

2. Fill in `Secrets.xcconfig` with your GitHub App credentials:

   | Key | Description |
   |-----|-------------|
   | `GITHUB_APP_ID` | GitHub App numeric ID |
   | `GITHUB_CLIENT_ID` | OAuth Client ID |
   | `GITHUB_CLIENT_SECRET` | Optional, for OAuth |
   | `GITHUB_PRIVATE_KEY` | PEM or base64-encoded PEM |
   | `SPARKLE_PUBLIC_ED_KEY` | Sparkle EdDSA public key (releases only) |

3. Open `CIWatcher.xcworkspace` and build the **CIWatcher-macOS** scheme.

`Secrets.xcconfig` is gitignored — never commit it.

### Private Key Formats

`GITHUB_PRIVATE_KEY` accepts:

- **PEM** with literal `\n` characters (xcconfig-friendly)
- **Base64-encoded PEM** (single line, recommended for CI)

Convert PEM to base64:

```bash
./scripts/convert_key_to_base64.sh path/to/private-key.pem
```

### Keychain Fallback (Development)

Instead of embedding the key in `Secrets.xcconfig`, you can store it in Keychain:

```swift
KeychainManager.storeGitHubAppPrivateKey(pemString)
```

The app checks `Info.plist` first, then Keychain.

## Running Tests

### Unit tests (no credentials needed)

```bash
cd SharedCore
swift test --filter 'GitHubAppAuthTests|GitHubAppConfigTests|SharedCoreTests'
```

### Integration tests (live GitHub API)

Requires valid credentials in `Secrets.xcconfig` or Keychain:

```bash
cd SharedCore
CIWATCHER_RUN_INTEGRATION_TESTS=1 swift test --filter Integration
```

## Architecture Notes

- **Auth (target)**: macOS app → backend API → GitHub App installation token → direct GitHub API calls from the app
- **Auth (current app code)**: GitHub App JWT in the client (being migrated to backend)
- **Updates**: Polling every 60 seconds (no webhook/server needed)
- **Notifications**: `UNUserNotificationCenter` (macOS + iOS ready)
- **Auto-updates**: [Sparkle](https://sparkle-project.org/) for GitHub Releases builds; disabled for App Store

## Backend API (local)

See [backend/README.md](backend/README.md) for full API docs and Fly.io deployment.

```bash
cd backend
cp .env.example .env
# fill GITHUB_APP_ID and GITHUB_PRIVATE_KEY
docker compose up --build
curl http://localhost:8080/health
```

GitHub App **Setup URL** for local testing (via tunnel) or production:

`https://<api-domain>/v1/auth/callback`

### Backend API URL in the macOS app

Set `CIWATCHER_API_BASE_URL` in `Secrets.xcconfig`.

**Important:** `.xcconfig` treats `//` as a comment, so URLs must use this syntax:

```text
# Production (Fly.io)
CIWATCHER_API_BASE_URL = https:/$()/ciwatcher-api.fly.dev

# Local backend (docker compose up in backend/)
CIWATCHER_API_BASE_URL = http:/$()/localhost:8080
```

After changing `Secrets.xcconfig`, do **Product → Clean Build Folder** and rebuild.

## Entitlements

| File | Use |
|------|-----|
| `CIWatcher_macOS.entitlements` | Default Xcode development |
| `CIWatcher_macOS_Direct.entitlements` | GitHub Releases (no sandbox, Sparkle) |
| `CIWatcher_macOS_AppStore.entitlements` | Mac App Store (sandbox, no Sparkle) |

## Useful Commands

```bash
# Build Release locally
xcodebuild -workspace CIWatcher.xcworkspace \
  -scheme CIWatcher-macOS -configuration Release build

# Generate Secrets.xcconfig from env vars
./scripts/ci/generate-secrets-xcconfig.sh
```

## GitHub App Setup

Users only need to click **Connect GitHub** in Settings — they do not create their own GitHub App.

For development, configure the shared `ciwatcher-native` app or your own test app with permissions:

- Actions: Read-only
- Metadata: Read-only

Webhook URL can be left empty.
