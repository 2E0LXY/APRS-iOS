import Foundation

struct AisShip {
    let mmsi: String; let name: String
    let lat: Double;  let lon: Double
    let sog: Double;  let cog: Double
}

final class AisWebSocket {
    var onShip: ((AisShip) -> Void)?

    private var task:      URLSessionWebSocketTask?
    private let session  = URLSession.shared
    private var shouldRun  = false
    private var retryCount = 0
    private let apiKey:    String

    static let wsURL = URL(string: "wss://stream.aisstream.io/v0/stream")!

    init(apiKey: String) { self.apiKey = apiKey }

    func connect() {
        guard !apiKey.isEmpty else { return }
        shouldRun = true; openSocket()
    }

    func disconnect() {
        shouldRun = false
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func openSocket() {
        task = session.webSocketTask(with: Self.wsURL)
        task?.resume()
        subscribe(); receive()
    }

    private func subscribe() {
        let sub = "{\"APIKey\":\"\"\(apiKey)\"\","  +
                  "\"BoundingBoxes\":[[[48.0,-12.0],[62.0,5.0]]]," +
                  "\"FilterMessageTypes\":[\"PositionReport\"]}"
        task?.send(.string(sub)) { _ in }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            if case .success(let msg) = result, case .string(let text) = msg {
                self.handle(text)
            }
            if case .failure = result { self.scheduleReconnect() }
            else { self.receive() }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["MessageType"] as? String == "PositionReport",
              let meta = json["MetaData"] as? [String: Any],
              let msg  = json["Message"]  as? [String: Any],
              let pr   = msg["PositionReport"] as? [String: Any]
        else { return }

        let lat = pr["Latitude"]  as? Double ?? 91
        let lon = pr["Longitude"] as? Double ?? 181
        guard abs(lat) <= 90, abs(lon) <= 180, !(lat == 0 && lon == 0) else { return }

        let mmsi = (meta["MMSI_String"] as? String).flatMap { $0.isEmpty ? nil : $0 }
               ?? (meta["MMSI"] as? Int).map(String.init)
               ?? ""
        guard !mmsi.isEmpty else { return }

        onShip?(AisShip(
            mmsi: mmsi,
            name: (meta["ShipName"] as? String ?? "").trimmingCharacters(in: .whitespaces),
            lat: lat, lon: lon,
            sog: pr["SpeedOverGround"]  as? Double ?? 0,
            cog: pr["CourseOverGround"] as? Double ?? 0
        ))
    }

    private func scheduleReconnect() {
        guard shouldRun else { return }
        retryCount += 1
        let delay = min(120.0, 5.0 * pow(2.0, Double(min(retryCount - 1, 5))))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldRun else { return }
            self.openSocket()
        }
    }
}
