# CIWatcher — Release Guide

## Distribution Channels

| Channel | Method | Updates |
|---------|--------|---------|
| **GitHub Releases** | DMG + ZIP | Sparkle auto-update |
| **Mac App Store** | Manual workflow | App Store |

## GitHub Releases (Primary)

### One-Time Setup

#### 1. Apple Certificates

Export your **Developer ID Application** certificate as a `.p12` file from Keychain Access.

#### 2. Sparkle EdDSA Keys

Download [Sparkle](https://github.com/sparkle-project/Sparkle/releases) and generate keys:

```bash
./bin/generate_keys
```

This creates:
- `eddsa_private_key` → export with `./generate_keys -x eddsa_private_key`, then base64-encode for GitHub Secret `SPARKLE_PRIVATE_ED_KEY`
- Public key string → GitHub Secret `SPARKLE_PUBLIC_ED_KEY` and local `Secrets.xcconfig`

Encode private key for GitHub Secret:

```bash
cd ~/Downloads/Sparkle-for-Swift-Package-Manager/bin
./generate_keys -x eddsa_private_key
base64 -i eddsa_private_key | tr -d '\n' | pbcopy
```

Paste into `SPARKLE_PRIVATE_ED_KEY` (single line, base64).

#### 3. GitHub Repository Secrets

Add these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `APPLE_TEAM_ID` | Your Apple Team ID (e.g. `6YATHLR4YS`) |
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded `.p12` Developer ID certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Password for the `.p12` file |
| `KEYCHAIN_PASSWORD` | Temporary keychain password for CI |
| `NOTARY_APPLE_ID` | Apple ID email for notarization |
| `NOTARY_PASSWORD` | App-specific password |
| `CIWATCHER_APP_ID` | GitHub App ID |
| `CIWATCHER_CLIENT_ID` | GitHub App Client ID |
| `CIWATCHER_CLIENT_SECRET` | GitHub App Client Secret (optional) |
| `CIWATCHER_PRIVATE_KEY_BASE64` | Base64-encoded PEM private key |
| `SPARKLE_PUBLIC_ED_KEY` | Sparkle EdDSA public key |
| `SPARKLE_PRIVATE_ED_KEY` | Sparkle EdDSA private key (for appcast signing) |

Encode certificate:

```bash
base64 -i certificate.p12 | pbcopy
```

Encode private key:

```bash
base64 -i private-key.pem | pbcopy
```

### Creating a Release

Push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The [Release workflow](.github/workflows/release.yml) will:

1. Build universal macOS binary
2. Sign with Developer ID
3. Notarize with Apple
4. Create DMG and ZIP
5. Generate Sparkle `appcast.xml`
6. Publish GitHub Release with assets

Users download the DMG, drag to Applications, and get automatic updates via Sparkle.

### Local Release Build

```bash
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export NOTARY_APPLE_ID="your@email.com"
export NOTARY_PASSWORD="app-specific-password"
export GITHUB_APP_ID="..."
export GITHUB_CLIENT_ID="..."
export GITHUB_PRIVATE_KEY_BASE64="..."

./scripts/ci/build-direct-release.sh
```

## Mac App Store

### One-Time Setup

1. Create the app in [App Store Connect](https://appstoreconnect.apple.com)
2. Create an [App Store Connect API key](https://appstoreconnect.apple.com/access/api)
3. Add GitHub Secrets:

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | Contents of the `.p8` file |

### Uploading

Go to **Actions → App Store → Run workflow**, enter the version tag (e.g. `v1.0.0`).

The workflow builds with App Store entitlements (sandbox, no Sparkle), packages a `.pkg`, and uploads to App Store Connect.

After upload, submit for review in App Store Connect.

### App Store Notes

- Menu bar apps are supported on the Mac App Store
- Sparkle framework is stripped from App Store builds
- Sandbox is enabled — network client entitlement is included
- You may need to add App Store screenshots and description in App Store Connect

## Versioning

- **Marketing version** (`MARKETING_VERSION`): set by git tag (`v1.0.0` → `1.0.0`)
- **Build number** (`CURRENT_PROJECT_VERSION`): GitHub Actions run number

## Troubleshooting

### Notarization fails

- Verify `NOTARY_PASSWORD` is an app-specific password, not your Apple ID password
- Check certificate is **Developer ID Application**, not **Apple Development**

### Sparkle updates not working

- Verify `SPARKLE_PUBLIC_ED_KEY` is in the built app's `Info.plist`
- Verify `appcast.xml` is uploaded to the GitHub Release
- Check `SUFeedURL` points to the correct release asset URL

### Code signing in CI

- Ensure the `.p12` includes the private key
- The workflow creates a temporary keychain — certificate must be trusted for codesigning
