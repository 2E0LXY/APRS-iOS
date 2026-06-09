# APRS Net – iOS

Native SwiftUI client for [aprsnet.uk](https://www.aprsnet.uk) — feature-parity companion to the Android app, built for iPhone and iPad.

[![Release](https://img.shields.io/github/v/release/2E0LXY/APRS-iOS)](https://github.com/2E0LXY/APRS-iOS/releases)
[![Licence: GPL v3](https://img.shields.io/badge/Licence-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![APRS Net iOS](docs/screenshot-ios.svg)



---

## Also available on


![APRS Net — all platforms](docs/platforms.svg)

| Platform | Repository | Download |
|----------|------------|----------|
| **Android** | [2E0LXY/APRS-Android](https://github.com/2E0LXY/APRS-Android) | [APK](https://github.com/2E0LXY/APRS-Android/releases) |
| **Windows / Linux desktop** | [2E0LXY/APRS-Client](https://github.com/2E0LXY/APRS-Client) | [EXE / DEB](https://github.com/2E0LXY/APRS-Client/releases) |
| **Self-host the server** | [2E0LXY/Advanced-APRS-Go-server](https://github.com/2E0LXY/Advanced-APRS-Go-server) | [Install guide](https://github.com/2E0LXY/Advanced-APRS-Go-server#installation-debian-12) |

---

## Features

### Map
- Live MapKit map with real-time APRS station annotations
- **TOCALL-based station classification** — mirrors Android v2.5.6:
  - `APLRG*` / `APLG*` / `APLT*` / `APLO*` → LoRa
  - `APZDMR*` / `APDG*` → MMDVM/DMR
  - `APOG*` → OGN (glider network)
  - Callsign-string and symbol heuristics as fallback
- Colour-coded station pins: Ham (blue), Weather (green), Glider (orange), Ship (teal), LoRa (purple), MMDVM (red), Object (grey)
- Tap any pin to open station detail sheet (callsign, type, coordinates, distance, path)
- My location marker; tap locate button to zoom to current GPS fix
- Beacon Now button for instant position transmission

### AIS Ships
- **Server relay** — server subscribes to aisstream.io and relays vessel positions
- **Direct connection** — optional aisstream.io API key in Settings for an independent feed; configure separately from the server key to avoid free-tier conflicts

### Messaging
- Full send/receive APRS messaging with ACK tracking
- Conversation threads per callsign
- Outgoing bubbles turn green on ACK confirmation
- Incoming messages auto-ACKed per APRS spec
- 67-character message body limit enforced in the composer

### Beaconing
- GPS mode — continuous `watchPosition` via CoreLocation
- Manual mode — configured lat/lon in Settings
- Off — no position reporting
- Configurable beacon comment
- Smart APRS position format (DDMM.hhN/DDDMM.hhE)

### Stations
- Searchable list of all heard stations
- Type filter chips (All / Ham / Weather / Glider / Ship / LoRa / MMDVM / Object)
- Last-heard timestamp for each station

### Settings
- Callsign, APRS-IS passcode, SSID (0–15)
- **Member account** — sign in to aprsnet.uk member account; auto-fills passcode, syncs map filter preferences with web map and Android app
- Beaconing mode and comment
- Per-type map filters (7 toggles, persisted in UserDefaults)
- Direct aisstream.io API key (optional)
- Notification preferences

### Status
- WebSocket connection state indicator (connecting / connected / authenticated / disconnected)
- Server uptime, packet count, upstream connection state
- My current GPS position (if available)

---

## Quick Start

1. Download from [Releases](https://github.com/2E0LXY/APRS-iOS/releases) (simulator build — see note below)
2. Open the app → **Settings** tab
3. Enter callsign and APRS-IS passcode
4. Set beaconing mode to **GPS**
5. Tap **Save credentials** — live stations appear within seconds

---

## Requirements

- iOS 17+ / iPadOS 17+
- Xcode 15+ (to build from source)

---

## Build from Source

### Prerequisites
- macOS with Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Build

```bash
git clone https://github.com/2E0LXY/APRS-iOS
cd APRS-iOS
xcodegen generate --spec project.yml
open APRSNet.xcodeproj
```

Build and run on the iOS Simulator from Xcode, or use `xcodebuild`:

```bash
xcodebuild \
  -project APRSNet.xcodeproj \
  -scheme APRSNet \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Release \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  build
```

### CI / Releases
GitHub Actions runs on every push (`macos-latest`). Pushing a `v*` tag publishes a **simulator build** (`APRSNet-iOS-Simulator.zip`) to Releases.

> **Device / App Store deployment** requires an Apple Developer certificate. > Add `APPLE_CERTIFICATE`, `APPLE_PROVISIONING_PROFILE`, and `APPLE_TEAM_ID` > as repository secrets and update the workflow to use `xcodebuild archive` > with proper signing.

---

## Architecture

```
Sources/
  App/          APRSNetApp.swift, ContentView.swift (tab structure)
  Network/      AprsWebSocket.swift   — URLSessionWebSocketTask, auth, backoff
                AisWebSocket.swift    — direct aisstream.io connection
  APRS/         PacketParser.swift    — position + message parsing, TOCALL classify
  Model/        Models.swift          — Station, APRSMessage, StationType
  Data/         SettingsStore.swift   — UserDefaults persistence
  ViewModel/    AprsViewModel.swift   — @Observable, station map, messaging, GPS
                MemberLogin.swift     — /api/member/login, passcode calc, token
  UI/
    MapScreen.swift
    Messages/   ConversationListScreen.swift, ThreadScreen.swift
    Stations/   StationsScreen.swift
    Settings/   SettingsScreen.swift
    Status/     StatusScreen.swift
```

No external dependencies — `URLSessionWebSocketTask` for WebSocket, `MapKit` for maps, `CoreLocation` for GPS.

---

## Changelog

| Version | Changes |
|---------|---------|
| v1.0.0 | Initial release — map, messaging, beaconing, AIS, TOCALL classification, member login, all five screens |

---

## Licence

GNU General Public Licence v3 — © 2026 Daren Loxley 2E0LXY
