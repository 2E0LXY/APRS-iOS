import Foundation
import UserNotifications
import CoreLocation
import Observation

@Observable
final class AprsViewModel {

    var stations:   [String: Station]           = [:]
    var messages:   [String: [APRSMessage]]      = [:]
    var connState:  AprsWebSocket.ConnState      = .disconnected
    var myPosition: CLLocationCoordinate2D?
    var filterTick  = 0
    var alertRules: [AlertRule] = []
    var serverStatus: ServerStatus?

    let settings   = SettingsStore()
    let ws         = AprsWebSocket()
    private var aisWs: AisWebSocket?

    private let locHelper = LocationHelper()
    private let locMgr    = CLLocationManager()
    private var statusTimer: Timer?

    struct ServerStatus: Codable {
        let uptime: String; let packetsRx: Int
        let upstreamConnected: Bool; let stations: Int
        enum CodingKeys: String, CodingKey {
            case uptime, packetsRx = "packets_rx",
                 upstreamConnected = "upstream_connected", stations
        }
    }

    init() {
        locHelper.onFix = { [weak self] coord in
            self?.myPosition = coord
        }
        locMgr.delegate = locHelper
        locMgr.desiredAccuracy = kCLLocationAccuracyBest

        ws.onStateChange = { [weak self] state in self?.connState = state }
        ws.onPosition = { [weak self] json in self?.handlePositionJson(json) }
        ws.onAlert    = { [weak self] type, call, msg in self?.handleWsAlert(type, call, msg) }
        ws.onPacket   = { [weak self] raw  in self?.handleRawPacket(raw)   }
    }

    func start() {
        if !settings.callsign.isEmpty {
            ws.setCredentials(callsign: settings.callsign, passcode: settings.passcode)
        }
        ws.connect()
        startBeaconing()
        startAis()
        startStatusPoll()
    }

    func applySettings() {
        if !settings.callsign.isEmpty {
            ws.setCredentials(callsign: settings.callsign, passcode: settings.passcode)
        }
        startBeaconing()
        restartAis()
        filterTick += 1
    }

    // ─ AIS ───────────────────────────────────────────────────────────────────
    private func startAis() {
        let key = settings.aisApiKey
        guard !key.isEmpty else { return }
        let ais = AisWebSocket(apiKey: key)
        aisWs = ais
        ais.onShip = { [weak self] ship in
            guard let self else { return }
            let s = Station(callsign: ship.mmsi, lat: ship.lat, lon: ship.lon,
                            symbolTable: "/", symbolCode: "s",
                            comment: ship.name, path: "AIS",
                            raw: "\(ship.mmsi)>AIS:!AIS \(ship.name)",
                            lastHeard: Date(), type: .ship)
            DispatchQueue.main.async { self.stations[ship.mmsi] = s }
        }
        ais.connect()
    }

    func restartAis() { aisWs?.disconnect(); aisWs = nil; startAis() }

    // ─ Packet handling ────────────────────────────────────────────────────────
    private func handlePositionJson(_ json: String) {
        guard let data = json.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let call = obj["call"] as? String, !call.isEmpty,
              let lat  = obj["lat"]  as? Double,
              let lon  = obj["lon"]  as? Double else { return }

        let sym  = obj["sym"]  as? String ?? ""
        let path = obj["path"] as? String ?? ""
        let raw  = obj["raw"]  as? String ?? ""
        let symT: Character = sym.first        ?? "/"
        let symC: Character = sym.dropFirst().first ?? ">"
        let type = PacketParser.classify(call: call, path: path, table: symT, code: symC)

        let s = Station(callsign: call, lat: lat, lon: lon,
                        symbolTable: symT, symbolCode: symC,
                        comment: raw, path: path, raw: raw,
                        lastHeard: Date(), type: type)
        DispatchQueue.main.async { self.stations[call] = s }
    }

    private func handleRawPacket(_ raw: String) {
        let myCall = settings.fullCallsign.uppercased()
        switch PacketParser.parse(raw) {
        case .position(let s):
            DispatchQueue.main.async { self.stations[s.callsign] = s }
        case .message(let m) where m.to.uppercased() == myCall:
            let msg = APRSMessage(id: UUID(), from: m.from, to: m.to,
                                  text: m.text, timestamp: Date(),
                                  acked: false, outgoing: false)
            DispatchQueue.main.async {
                self.messages[m.from.uppercased(), default: []].append(msg)
                if let mid = m.msgId {
                    self.ws.transmit("\(myCall)>APRS,TCPIP*::\(m.from.padding(toLength:9,withPad:" ",startingAt:0)):ack\(mid)")
                }
            }
        case .ack(let to, _):
            DispatchQueue.main.async {
                let k = to.uppercased()
                guard var conv = self.messages[k],
                      let idx  = conv.lastIndex(where: { $0.outgoing && !$0.acked })
                else { return }
                let old = conv[idx]
                conv[idx] = APRSMessage(id: old.id, from: old.from, to: old.to,
                                        text: old.text, timestamp: old.timestamp,
                                        acked: true, outgoing: true)
                self.messages[k] = conv
            }
        default: break
        }
    }

    // ─ Beaconing ─────────────────────────────────────────────────────────────
    func startBeaconing() {
        guard settings.positionMode != "off" else { return }
        locMgr.requestWhenInUseAuthorization()
        locMgr.startUpdatingLocation()
    }

    func beaconNow() {
        guard let pos = myPosition else { return }
        let call    = settings.fullCallsign
        let comment = settings.beaconComment
        let latStr  = formatLat(pos.latitude)
        let lonStr  = formatLon(pos.longitude)
        ws.transmit("\(call)>APRS,TCPIP*:!\(latStr)/\(lonStr)>\(comment)")
    }

    private func formatLat(_ d: Double) -> String {
        let a = abs(d); let dd = Int(a); let mm = (a - Double(dd)) * 60
        return String(format: "%02d%05.2f%@", dd, mm, d >= 0 ? "N" : "S")
    }
    private func formatLon(_ d: Double) -> String {
        let a = abs(d); let dd = Int(a); let mm = (a - Double(dd)) * 60
        return String(format: "%03d%05.2f%@", dd, mm, d >= 0 ? "E" : "W")
    }

    // ─ Messaging ─────────────────────────────────────────────────────────────
    func send(to: String, text: String) {
        let myCall  = settings.fullCallsign
        let msgId   = Int.random(in: 1000...9999)
        let padded  = to.padding(toLength: 9, withPad: " ", startingAt: 0)
        ws.transmit("\(myCall)>APRS,TCPIP*::\(padded):\(text){\(msgId)")
        let msg = APRSMessage(id: UUID(), from: myCall, to: to.uppercased(),
                              text: text, timestamp: Date(), acked: false, outgoing: true)
        messages[to.uppercased(), default: []].append(msg)
    }

    var conversations: [(callsign: String, last: APRSMessage, unread: Int)] {
        messages.compactMap { k, msgs in
            guard let last = msgs.last else { return nil }
            let unread = msgs.filter { !$0.outgoing }.count
            return (k, last, unread)
        }.sorted { $0.last.timestamp > $1.last.timestamp }
    }

    func stationsFiltered() -> [Station] {
        let s = settings
        return stations.values.filter { st in
            switch st.type {
            case .ham:     return s.showHam
            case .weather: return s.showWeather
            case .glider:  return s.showGlider
            case .ship:    return s.showShip
            case .lora:    return s.showLora
            case .mmdvm:   return s.showMmdvm
            case .object:  return s.showOther
            }
        }
    }

    // ─ Status poll ───────────────────────────────────────────────────────────
    private func startStatusPoll() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.fetchStatus() }
        }
        Task { @MainActor in await fetchStatus() }
    }

    @MainActor
    private func fetchStatus() async {
        guard let url = URL(string: "https://www.aprsnet.uk/api/status") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        serverStatus = try? JSONDecoder().decode(ServerStatus.self, from: data)
    }

    private func handleWsAlert(_ alertType: String, _ callsign: String, _ message: String) {
        guard settings.notifyMessages else { return }
        let content = UNMutableNotificationContent()
        content.title = "\u{1F4CD} Geo-fence: \(callsign)"
        content.body  = message
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "geofence-\(callsign)-\(Date().timeIntervalSince1970)",
            content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    deinit {
        statusTimer?.invalidate()
        ws.disconnect()
        aisWs?.disconnect()
    }
}

// Private helper: CLLocationManager delegate (NSObject subclass)
private final class LocationHelper: NSObject, CLLocationManagerDelegate {
    var onFix: ((CLLocationCoordinate2D) -> Void)?
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        locs.last.map { onFix?($0.coordinate) }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
