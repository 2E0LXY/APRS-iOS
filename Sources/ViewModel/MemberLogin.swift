import Foundation

extension AprsViewModel {
    func loginMember(callsign: String, password: String) async -> String? {
        guard let url = URL(string: "https://www.aprsnet.uk/api/member/login") else {
            return "Invalid URL"
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "callsign": callsign.uppercased(),
            "password": password
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String, !token.isEmpty
        else { return "Login failed — check callsign and password" }

        let effectiveCall = (json["callsign"] as? String ?? callsign).uppercased()
        var effectivePass = json["passcode"] as? String ?? ""
        if let p = Int(effectivePass), p <= 0 { effectivePass = "" }
        if effectivePass.isEmpty {
            effectivePass = String(aprsPasscode(effectiveCall))
        }

        await MainActor.run {
            settings.callsign    = effectiveCall
            settings.passcode    = effectivePass
            settings.memberToken = token
            settings.memberName  = json["name"] as? String ?? ""
        }
        applySettings()
        return nil
    }

    // Deterministic APRS-IS passcode from callsign (standard algorithm)
    private func aprsPasscode(_ call: String) -> Int {
        let base = (call.components(separatedBy: "-").first ?? call).uppercased()
        var hash: Int = 0x73e2
        var idx  = base.startIndex
        while idx < base.endIndex {
            let c1 = Int(base[idx].asciiValue ?? 0)
            hash ^= c1 << 8
            let nxt = base.index(after: idx)
            if nxt < base.endIndex {
                hash ^= Int(base[nxt].asciiValue ?? 0)
                idx = base.index(after: nxt)
            } else { idx = nxt }
        }
        return hash & 0x7fff
    }
}

private extension Character {
    var asciiValue: UInt8? {
        guard let scalar = unicodeScalars.first, scalar.value < 128 else { return nil }
        return UInt8(scalar.value)
    }
}

// MARK: - Geo-fence alert rules

extension AprsViewModel {
    func loadAlertRules() async {
        guard !settings.memberToken.isEmpty,
              let url = URL(string: "https://www.aprsnet.uk/api/member/alert-rules")
        else { return }
        var req = URLRequest(url: url)
        req.setValue(settings.memberToken, forHTTPHeaderField: "X-Member-Token")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rules = try? JSONDecoder().decode([AlertRule].self, from: data)
        else { return }
        await MainActor.run { alertRules = rules }
    }

    func createAlertRule(_ rule: AlertRule) async {
        guard !settings.memberToken.isEmpty,
              let url = URL(string: "https://www.aprsnet.uk/api/member/alert-rules"),
              let body = try? JSONEncoder().encode(rule)
        else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        req.setValue(settings.memberToken,  forHTTPHeaderField: "X-Member-Token")
        req.httpBody = body
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 201,
              let created = try? JSONDecoder().decode(AlertRule.self, from: data)
        else { return }
        await MainActor.run { alertRules.append(created) }
    }

    func deleteAlertRule(id: Int64) async {
        guard !settings.memberToken.isEmpty,
              let url = URL(string: "https://www.aprsnet.uk/api/member/alert-rules/\(id)")
        else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(settings.memberToken, forHTTPHeaderField: "X-Member-Token")
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 204
        else { return }
        await MainActor.run { alertRules.removeAll { $0.id == id } }
    }
}
