# iOS Distribution Guide

## Current release — Simulator build only

The CI currently produces a **simulator build** (`.app` inside a zip).
This cannot be installed on a real iPhone without further steps.

---

## Option A — TestFlight / App Store (recommended)

**Requires:** [Apple Developer Program](https://developer.apple.com/programs/) — £79/year

### One-time setup

1. **Create App ID** at [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles → Identifiers
   - Bundle ID: `uk.aprsnet.ios`
   - Enable: Push Notifications, Background Modes

2. **Create Distribution Certificate**
   - Certificates → + → Apple Distribution
   - Download, double-click to add to Keychain
   - Export as `.p12`: Keychain Access → My Certificates → right-click → Export
   ```
   openssl base64 -in Certificates.p12 | pbcopy
   ```
   → paste as GitHub secret `APPLE_CERTIFICATE`

3. **Create App Store Provisioning Profile**
   - Profiles → + → App Store Connect → select `uk.aprsnet.ios`
   - Download `APRSNet_AppStore.mobileprovision`
   ```
   base64 -i APRSNet_AppStore.mobileprovision | pbcopy
   ```
   → paste as GitHub secret `APPLE_PROVISIONING_PROFILE`

4. **Register app in App Store Connect**
   - [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → + → New App
   - Platform: iOS, Bundle ID: `uk.aprsnet.ios`, SKU: `aprsnet-ios`

5. **Create App Store Connect API Key** (for automated uploads)
   - App Store Connect → Users and Access → Integrations → App Store Connect API
   - Generate key with **Manager** role
   - Note the **Key ID** and **Issuer ID**
   - Download the `.p8` file
   ```
   base64 -i AuthKey_XXXXXXXX.p8 | pbcopy
   ```

6. **Add GitHub secrets** (Settings → Secrets → Actions → New):

   | Secret | Value |
   |--------|-------|
   | `APPLE_CERTIFICATE` | base64 encoded `.p12` |
   | `APPLE_CERTIFICATE_PASSWORD` | `.p12` export password |
   | `APPLE_PROVISIONING_PROFILE` | base64 encoded `.mobileprovision` |
   | `APPLE_TEAM_ID` | 10-char Team ID (e.g. `ABC12345DE`) — found at developer.apple.com |
   | `ASC_API_KEY_ID` | Key ID from App Store Connect |
   | `ASC_API_ISSUER_ID` | Issuer ID from App Store Connect |
   | `ASC_API_KEY_BASE64` | base64 encoded `.p8` private key |

7. **Push a version tag** — the `testflight` CI job runs automatically:
   ```
   git tag v1.2.0 && git push origin v1.2.0
   ```

Once uploaded, open **App Store Connect → TestFlight** and add yourself as an internal tester.
Share the **public TestFlight link** with up to 10,000 external testers.

---

## Option B — Sideload without Developer account

For personal/development use on a registered device only.

1. Clone the repo and open `APRSNet.xcodeproj` in Xcode
2. Connect your iPhone, select it as the build target
3. Sign with a free Apple ID: Xcode → Signing & Capabilities → Team → add your Apple ID
4. Build & Run (⌘R)

**Limitation:** Free account builds expire after 7 days and must be re-signed.
You can have a maximum of 3 apps on-device at a time with a free account.

---

## Option C — AltStore / Sideloadly

For distributing a signed IPA without the App Store.

1. Build an IPA using your developer certificate
2. Distribute via [Diawi](https://www.diawi.com) or host on a web server with an `.ipa` + manifest
3. Users install via [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io)

This approach requires users to re-sign the app every 7 days (free account) or annually (paid account).
