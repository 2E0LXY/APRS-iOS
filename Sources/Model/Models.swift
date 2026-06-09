import Foundation
import CoreLocation

enum StationType: String, Codable, CaseIterable {
    case ham, weather, glider, ship, lora, mmdvm, object

    var displayName: String {
        switch self {
        case .ham:     return "Ham"
        case .weather: return "Weather (CWOP)"
        case .glider:  return "Glider / OGN"
        case .ship:    return "Ship / AIS"
        case .lora:    return "LoRa"
        case .mmdvm:   return "MMDVM / DMR"
        case .object:  return "Object"
        }
    }

    var symbolName: String {
        switch self {
        case .ham:     return "antenna.radiowaves.left.and.right"
        case .weather: return "cloud.rain.fill"
        case .glider:  return "airplane"
        case .ship:    return "ferry.fill"
        case .lora:    return "wifi"
        case .mmdvm:   return "dot.radiowaves.left.and.right"
        case .object:  return "mappin.circle.fill"
        }
    }
}

struct Station: Identifiable, Equatable {
    var id: String { callsign }
    let callsign: String
    let lat: Double
    let lon: Double
    let symbolTable: Character
    let symbolCode:  Character
    let comment:     String
    let path:        String
    let raw:         String
    let lastHeard:   Date
    let type:        StationType

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct APRSMessage: Identifiable, Equatable {
    let id:        UUID
    let from:      String
    let to:        String
    let text:      String
    let timestamp: Date
    var acked:     Bool
    var outgoing:  Bool
}

/// A server-side geo-fence alert rule owned by the current member.
struct AlertRule: Identifiable, Codable, Equatable {
    var id:            Int64  = 0
    var type:          String = "geofence_enter"   // "geofence_enter" | "geofence_exit"
    var watchCallsign: String = "*"
    var lat:           Double = 0
    var lon:           Double = 0
    var radiusMi:      Double = 10
    var name:          String = ""

    enum CodingKeys: String, CodingKey {
        case id, type, lat, lon, name
        case watchCallsign = "watch_callsign"
        case radiusMi      = "radius_mi"
    }
}
