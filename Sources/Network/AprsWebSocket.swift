import Foundation
import Observation

@Observable
final class AprsWebSocket: NSObject {

    enum ConnState { case disconnected, connecting, connected, authed }
    var connState: ConnState = .disconnected

    var onPosition: ((String) -> Void)?
    var onPacket:   ((String) -> Void)?

    private var task:     URLSessionWebSocketTask?
    private lazy var session = URLSession(
        configuration: .default, delegate: self, delegateQueue: nil)
    private var callsign   = ""
    private var passcode   = ""
    private var shouldRun  = false
    private var retryCount = 0

    static let wsURL = URL(string: "wss://www.aprsnet.uk/ws")!

    func setCredentials(callsign: String, passcode: String) {
        self.callsign = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        self.passcode = passcode.trimmingCharacters(in: .whitespaces)
        if connState == .connected || connState == .authed { sendAuth() }
    }

    func connect() {
        shouldRun = true
        openSocket()
    }

    func disconnect() {
        shouldRun = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        DispatchQueue.main.async { self.connState = .disconnected }
    }

    private func openSocket() {
        DispatchQueue.main.async { self.connState = .connecting }
        task = session.webSocketTask(with: Self.wsURL)
        task?.resume()
        receive()
    }

    func sendRaw(_ json: String) {
        task?.send(.string(json)) { _ in }
    }

    func transmit(_ packet: String) {
        guard connState == .authed else { return }
        let escaped = packet
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"",  with: "\\\"")
        sendRaw("{\"type\":\"tx\",\"packet\":\"\(escaped)\"}")
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
                DispatchQueue.main.async { self.connState = .authed }
            }
        case "rx", "obj":
            if let packet = json["packet"] as? String, !packet.isEmpty {
                onPacket?(packet)
            }
            if let dataObj = json["data"],
               let dataBytes = try? JSONSerialization.data(withJSONObject: dataObj),
               let str = String(data: dataBytes, encoding: .utf8) {
                onPosition?(str)
            }
        default: break
        }
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        DispatchQueue.main.async { self.connState = .disconnected }
        retryCount += 1
        let delay = min(30.0, 1.0 * pow(1.5, Double(min(retryCount, 10))))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldRun else { return }
            self.openSocket()
        }
    }
}

extension AprsWebSocket: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        retryCount = 0
        DispatchQueue.main.async { self.connState = .connected }
        sendAuth()
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        scheduleReconnect()
    }
}
