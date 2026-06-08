import Foundation

class SettingsStore {
    private let d = UserDefaults.standard

    private func bool(_ key: String, default def: Bool = true) -> Bool {
        d.object(forKey: key) == nil ? def : d.bool(forKey: key)
    }

    // APRS credentials
    var callsign: String {
        get { d.string(forKey: "callsign") ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespaces).uppercased(), forKey: "callsign") }
    }
    var passcode: String {
        get { d.string(forKey: "passcode") ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "passcode") }
    }
    var ssid: Int {
        get { min(15, max(0, d.integer(forKey: "ssid"))) }
        set { d.set(max(0, min(15, newValue)), forKey: "ssid") }
    }
    var fullCallsign: String { ssid == 0 ? callsign : "\(callsign)-\(ssid)" }

    // Member account
    var memberToken: String {
        get { d.string(forKey: "member_token") ?? "" }
        set { d.set(newValue, forKey: "member_token") }
    }
    var memberName: String {
        get { d.string(forKey: "member_name") ?? "" }
        set { d.set(newValue, forKey: "member_name") }
    }
    var memberSignedIn: Bool { !memberToken.isEmpty }
    func clearMember() {
        d.removeObject(forKey: "member_token")
        d.removeObject(forKey: "member_name")
    }

    // Position / beaconing
    var positionMode: String {
        get { d.string(forKey: "position_mode") ?? "off" }
        set { d.set(newValue, forKey: "position_mode") }
    }
    var beaconComment: String {
        get { d.string(forKey: "beacon_comment") ?? "APRS Net iOS" }
        set { d.set(newValue, forKey: "beacon_comment") }
    }

    // Map filters (default true)
    var showHam:     Bool { get { bool("filter_ham") }     set { d.set(newValue, forKey: "filter_ham") } }
    var showWeather: Bool { get { bool("filter_weather") } set { d.set(newValue, forKey: "filter_weather") } }
    var showGlider:  Bool { get { bool("filter_glider") }  set { d.set(newValue, forKey: "filter_glider") } }
    var showShip:    Bool { get { bool("filter_ship") }    set { d.set(newValue, forKey: "filter_ship") } }
    var showLora:    Bool { get { bool("filter_lora") }    set { d.set(newValue, forKey: "filter_lora") } }
    var showMmdvm:   Bool { get { bool("filter_mmdvm") }   set { d.set(newValue, forKey: "filter_mmdvm") } }
    var showOther:   Bool { get { bool("filter_other") }   set { d.set(newValue, forKey: "filter_other") } }

    // Drop preferences (synced from member account)
    var dropPistar: Bool {
        get { bool("drop_pistar", default: false) }
        set { d.set(newValue, forKey: "drop_pistar") }
    }

    // AIS direct
    var aisApiKey: String {
        get { d.string(forKey: "ais_api_key") ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "ais_api_key") }
    }

    // Notifications
    var notifyMessages: Bool {
        get { bool("notify_messages") }
        set { d.set(newValue, forKey: "notify_messages") }
    }
}
