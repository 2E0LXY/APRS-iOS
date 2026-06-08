import Foundation

enum ParseResult {
    case position(Station)
    case message(ParsedMessage)
    case ack(to: String, msgId: String)
    case none
}

struct ParsedMessage {
    let from:  String
    let to:    String
    let text:  String
    let msgId: String?
}

struct PacketParser {

    // TOCALL-based + symbol classification (mirrors Android v2.5.6)
    static func classify(call: String, path: String,
                         table: Character, code: Character) -> StationType {
        let up     = call.uppercased()
        let tocall = path.components(separatedBy: ",").first?.uppercased() ?? ""

        if tocall.hasPrefix("APLR") || tocall.hasPrefix("APLG") ||
           tocall.hasPrefix("APLT") || tocall.hasPrefix("APLO") ||
           (tocall.hasPrefix("APL") && tocall.count >= 5) { return .lora }

        if tocall.hasPrefix("APZDMR") || tocall.hasPrefix("APDG") { return .mmdvm }
        if tocall.hasPrefix("APOG")                               { return .glider }

        if up.contains("MMDVM") || up.contains("PISTAR") ||
           (table == "\\" && code == "M")                       { return .mmdvm }
        if code == "_" || (code == "W" && table == "\\")        { return .weather }
        if code == "'" || code == "g" || code == "^" ||
           up.hasPrefix("OGN")                                     { return .glider }
        if code == "s" || code == "Y" || code == "C" ||
           (table == "\\" && code == "s") ||
           up.range(of: "^[0-9]{6,9}", options: .regularExpression) != nil { return .ship }
        if up.contains("LORA") || up.contains("MESH")             { return .lora }
        if code == "r" || code == "#" || code == "&" ||
           code == "I"                                             { return .object }
        return .ham
    }

    static func parse(_ raw: String) -> ParseResult {
        guard let arrowIdx = raw.firstIndex(of: ">") else { return .none }
        guard let colonIdx = raw[arrowIdx...].firstIndex(of: ":") else { return .none }
        guard arrowIdx < colonIdx else { return .none }

        let call    = String(raw[raw.startIndex..<arrowIdx])
        let pathStr = String(raw[raw.index(after: arrowIdx)..<colonIdx])
        let payload = String(raw[raw.index(after: colonIdx)...])
        guard !payload.isEmpty else { return .none }

        if payload.first == ":" {
            return parseMessage(from: call, payload: payload, raw: raw)
        }

        if let s = parsePosition(call: call, path: pathStr, payload: payload, raw: raw) {
            return .position(s)
        }
        return .none
    }

    // ─ Position ───────────────────────────────────────────────────────────────
    private static let posPattern = try! NSRegularExpression(
        pattern: #"[!=/@](\d{4}\.\d{2}[NS])(.)(\d{5}\.\d{2}[EW])(.)(.*)"#
    )

    private static func parsePosition(call: String, path: String,
                                      payload: String, raw: String) -> Station? {
        let ns  = NSRange(payload.startIndex..., in: payload)
        guard let m = posPattern.firstMatch(in: payload, range: ns),
              m.numberOfRanges >= 6 else { return nil }

        func sub(_ i: Int) -> String {
            guard let r = Range(m.range(at: i), in: payload) else { return "" }
            return String(payload[r])
        }

        let latStr = sub(1); let lonStr = sub(3)
        let symT   = sub(2).first ?? "/"
        let symC   = sub(4).first ?? ">"
        let comment = sub(5).trimmingCharacters(in: .whitespaces)

        var lat = parseDM(latStr)
        var lon = parseDM(lonStr)
        if latStr.last == "S" { lat = -lat }
        if lonStr.last == "W" { lon = -lon }
        if lat == 0 && lon == 0 { return nil }

        return Station(
            callsign: call, lat: lat, lon: lon,
            symbolTable: symT, symbolCode: symC,
            comment: comment, path: path, raw: raw,
            lastHeard: Date(),
            type: classify(call: call, path: path, table: symT, code: symC)
        )
    }

    private static func parseDM(_ s: String) -> Double {
        guard let dotIdx = s.firstIndex(of: "."),
              s.distance(from: s.startIndex, to: dotIdx) >= 2 else { return 0 }
        let minStart = s.index(dotIdx, offsetBy: -2)
        let minEnd   = s.index(before: s.endIndex)
        let degStr   = String(s[s.startIndex..<minStart])
        let minStr   = String(s[minStart..<minEnd])
        guard let deg = Double(degStr), let min = Double(minStr) else { return 0 }
        return deg + min / 60.0
    }

    // ─ Message ────────────────────────────────────────────────────────────────
    private static func parseMessage(from: String, payload: String, raw: String) -> ParseResult {
        // :CALLSSSS :text{id  (addressee is chars 1-9, separator at index 10)
        guard payload.count > 11 else { return .none }
        let s1  = payload.index(after: payload.startIndex)  // skip leading ':'
        let s10 = payload.index(s1, offsetBy: 9)
        let to  = String(payload[s1..<s10]).trimmingCharacters(in: .whitespaces)
        guard payload[s10] == ":" else { return .none }
        let rest = String(payload[payload.index(after: s10)...])

        if rest.hasPrefix("ack") {
            return .ack(to: from, msgId: String(rest.dropFirst(3)))
        }

        var text  = rest
        var msgId: String? = nil
        if let bi = rest.lastIndex(of: "{") {
            msgId = String(rest[rest.index(after: bi)...])
            text  = String(rest[..<bi])
        }
        return .message(ParsedMessage(from: from, to: to,
                                      text: text.trimmingCharacters(in: .whitespaces),
                                      msgId: msgId))
    }
}
