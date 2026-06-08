# APRS Net iOS

Native SwiftUI client for [aprsnet.uk](https://www.aprsnet.uk) — iOS companion to the Android app.

## Features

- Live APRS station map (MapKit)
- Full messaging (send/receive, ACK tracking)
- Station list with type filters
- GPS beaconing (smart / manual / off)
- Direct aisstream.io AIS vessel feed
- TOCALL-based station classification (LoRa, MMDVM, OGN)
- Member account sync (passcode auto-fill, filter prefs)

## Requirements

- iOS 17+
- Xcode 15+ (build only)

## CI / Build

Builds run on GitHub Actions (`macos-latest`). CI produces a **simulator build** (no code signing).
Device/App Store deployment requires an Apple Developer certificate — add `APPLE_CERTIFICATE`,
`APPLE_PROVISIONING_PROFILE`, and `APPLE_TEAM_ID` as repository secrets and adapt the workflow.

## Structure

```
Sources/
  App/          Entry point, tab structure
  Network/      AprsWebSocket, AisWebSocket
  APRS/         PacketParser (position + message parsing, TOCALL classify)
  Model/        Station, Message, StationType
  Data/         SettingsStore (UserDefaults)
  ViewModel/    AprsViewModel (@Observable)
  UI/           MapScreen, MessagesScreen, StationsScreen, SettingsScreen, StatusScreen
```
