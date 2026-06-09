import Foundation

final class AprsWebSocket: NSObject {

    enum ConnState { case disconnected, connecting, connected, authed }

    /// Called on main thread whenever connection state changes.
    var onStateChange: ((ConnState) -> Void)?
    var onAlert:       ((String, String, String) -> Void)?
    var onPosition:    ((String) -> Void)?
    var onPacket:      ((String) -> Void)?

    private var session:   URLSession!
    private var task:      URLSessionWebSocketTask?
    private var callsign   = ""
    private var passcode   = ""
    private var shouldRun  = false
    private var retryCount = 0

    static let wsURL = URL(string: "wss://www.aprsnet.uk/ws")!

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func setCredentials(callsign: String, passcode: String) {
        self.callsign = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        self.passcode = passcode.trimmingCharacters(in: .whitespaces)
        // Re-auth if already connected
        let isUp = task?.state == .running
        if isUp { sendAuth() }
    }

    func connect() {
        shouldRun = true
        openSocket()
    }

    func disconnect() {
        shouldRun = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        notify(.disconnected)
    }

    func sendRaw(_ json: String) {
        task?.send(.string(json)) { _ in }
    }

    func transmit(_ packet: String) {
        let esc = packet
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"",  with: "\\\"")
        sendRaw("{\"type\":\"tx\",\"packet\":\"\(esc)\"}")
    }

    // ─ Private ───────────────────────────────────────────────────────────────

    private func openSocket() {
        notify(.connecting)
        task = session.webSocketTask(with: Self.wsURL)
        task?.resume()
        receive()
    }

    private func sendAuth() {
        guard !callsign.isEmpty, !passcode.isEmpty else { return }
        sendRaw("{\"type\":\"auth\",\"callsign\":\"\"\(callsign)\"\"," +
                "\"passcode\":\"\"\(passcode)\"\"," +
                "\"software\":\"APRSNetIOS 1.0\"}")
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                if case .string(let text) = msg { self.handleMessage(text) }
                self.receive()
            case .failure:
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        switch json["type"] as? String {
        case "auth_ack", "authok", "logresp":
            if (json["status"] as? String) != "error" {
                notify(.authed)
            }
        case "alert":
            let alertType = json["alert_type"] as? String ?? ""
            let call      = json["callsign"]   as? String ?? ""
            let msg       = json["message"]    as? String ?? ""
            if !alertType.isEmpty { onAlert?(alertType, call, msg) }
        case "rx", "obj":
            if let pkt = json["packet"] as? String, !pkt.isEmpty { onPacket?(pkt) }
            if let dataObj = json["data"],
               let bytes = try? JSONSerialization.data(withJSONObject: dataObj),
               let str   = String(data: bytes, encoding: .utf8) { onPosition?(str) }
        default: break
        }
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        notify(.disconnected)
        retryCount += 1
        let delay = min(30.0, 1.0 * pow(1.5, Double(min(retryCount, 10))))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldRun else { return }
            self.openSocket()
        }
    }

    private func notify(_ state: ConnState) {
        DispatchQueue.main.async { self.onStateChange?(state) }
    }
}

extension AprsWebSocket: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        retryCount = 0
        notify(.connected)
        sendAuth()
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        scheduleReconnect()
    }
}
