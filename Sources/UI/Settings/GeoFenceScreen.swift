import SwiftUI
import CoreLocation

/// Screen for managing server-side geo-fence alert rules.
/// Rules are stored on the aprsnet.uk server and evaluated on every
/// incoming position packet — a push notification is delivered to all
/// sessions belonging to the owning member.
struct GeoFenceScreen: View {
    @Environment(AprsViewModel.self) var vm
    @State private var showAdd = false
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Group {
                if !vm.settings.memberSignedIn {
                    ContentUnavailableView(
                        "Sign in required",
                        systemImage: "lock.circle",
                        description: Text("Sign in to your aprsnet.uk account to use geo-fence alerts.")
                    )
                } else if vm.alertRules.isEmpty {
                    ContentUnavailableView(
                        "No geo-fence rules",
                        systemImage: "location.circle",
                        description: Text("Tap + to watch a callsign entering or leaving an area.")
                    )
                } else {
                    List {
                        ForEach(vm.alertRules) { rule in
                            GeoFenceRuleRow(rule: rule)
                        }
                        .onDelete { idx in
                            for i in idx {
                                Task { await vm.deleteAlertRule(id: vm.alertRules[i].id) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Geo-fence Alerts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .disabled(!vm.settings.memberSignedIn)
                }
            }
            .task { await vm.loadAlertRules() }
        }
        .sheet(isPresented: $showAdd) {
            AddGeoFenceSheet(onAdd: { rule in
                Task { await vm.createAlertRule(rule) }
            })
        }
    }
}

struct GeoFenceRuleRow: View {
    let rule: AlertRule
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rule.name.isEmpty
                 ? (rule.type == "geofence_enter" ? "Enters zone" : "Leaves zone")
                 : rule.name)
                .font(.headline)
            let callLabel = rule.watchCallsign == "*" ? "Any station" : rule.watchCallsign
            let verb      = rule.type == "geofence_enter" ? "enters" : "leaves"
            Text("\(callLabel) \(verb) a \(Int(rule.radiusMi)) mi radius")
                .font(.subheadline).foregroundStyle(.secondary)
            Text(String(format: "%.4f°, %.4f°", rule.lat, rule.lon))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddGeoFenceSheet: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (AlertRule) -> Void

    @State private var name      = ""
    @State private var callsign  = "*"
    @State private var latStr    = ""
    @State private var lonStr    = ""
    @State private var radiusStr = "10"
    @State private var ruleType  = "geofence_enter"
    @State private var useMyLoc  = false
    @Environment(AprsViewModel.self) var vm

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone") {
                    TextField("Name (optional)", text: $name)
                    TextField("Lat", text: $latStr).keyboardType(.decimalPad)
                    TextField("Lon", text: $lonStr).keyboardType(.decimalPad)
                    TextField("Radius (miles)", text: $radiusStr).keyboardType(.decimalPad)
                    if let pos = vm.myPosition {
                        Button("Use my current location") {
                            latStr = String(format: "%.5f", pos.latitude)
                            lonStr = String(format: "%.5f", pos.longitude)
                        }
                    }
                }
                Section("Watch") {
                    TextField("Callsign (* = any)", text: $callsign)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Picker("Alert when", selection: $ruleType) {
                        Text("Station enters zone").tag("geofence_enter")
                        Text("Station leaves zone").tag("geofence_exit")
                    }
                }
            }
            .navigationTitle("Add Geo-fence Rule")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let lat = Double(latStr), let lon = Double(lonStr) else { return }
                        let radius = Double(radiusStr) ?? 10
                        onAdd(AlertRule(type: ruleType,
                                        watchCallsign: callsign.isEmpty ? "*" : callsign.uppercased(),
                                        lat: lat, lon: lon, radiusMi: radius, name: name))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
