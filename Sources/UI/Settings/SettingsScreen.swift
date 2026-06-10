import SwiftUI

struct SettingsScreen: View {
    @Environment(AprsViewModel.self) var vm

    var body: some View {
        NavigationStack {
            Form {
                AprsCredentialsSection(vm: vm)
                MemberAccountSection(vm: vm)
                BeaconingSection(vm: vm)
                FiltersSection(vm: vm)
                AisSection(vm: vm)
        GeoFenceAlertsSection(vm: vm)
                NotificationsSection(vm: vm)
            }
            .navigationTitle("Settings")
        }
    }
}

// ─ APRS Credentials ──────────────────────────────────────────────────────────
struct AprsCredentialsSection: View {
    let vm: AprsViewModel
    @State private var call = ""
    @State private var pass = ""
    @State private var ssid = 0
    @State private var saved = false

    var body: some View {
        Section("APRS Credentials") {
            TextField("Callsign", text: $call)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onAppear { call = vm.settings.callsign; pass = vm.settings.passcode; ssid = vm.settings.ssid }
            SecureField("APRS-IS Passcode", text: $pass)
                .keyboardType(.numberPad)
            Stepper("SSID: -\(ssid)", value: $ssid, in: 0...15)
            Button("Save credentials") {
                vm.settings.callsign = call; vm.settings.passcode = pass; vm.settings.ssid = ssid
                vm.applySettings(); saved = true
            }
            if saved { Text("Saved").foregroundStyle(.green).font(.caption) }
        }
    }
}

// ─ Member Account ────────────────────────────────────────────────────────────
struct MemberAccountSection: View {
    let vm: AprsViewModel
    @State private var user = ""; @State private var pass = ""
    @State private var status = ""; @State private var working = false

    var body: some View {
        Section("Website Member Account") {
            if vm.settings.memberSignedIn {
                Text("Signed in as \(vm.settings.memberName.isEmpty ? "(account)" : vm.settings.memberName)")
                    .foregroundStyle(.green)
                Button("Sign out", role: .destructive) { vm.settings.clearMember() }
            } else {
                TextField("Callsign", text: $user)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                SecureField("Password", text: $pass)
                Button(working ? "Signing in…" : "Sign in") {
                    working = true; status = ""
                    Task {
                        let err = await vm.loginMember(callsign: user, password: pass)
                        await MainActor.run {
                            working = false
                            status  = err ?? "Signed in — passcode loaded"
                        }
                    }
                }
                .disabled(working || user.isEmpty || pass.isEmpty)
                if !status.isEmpty {
                    Text(status).font(.caption)
                        .foregroundStyle(status.hasPrefix("Signed") ? .green : .red)
                }
            }
        }
    }
}

// ─ Beaconing ─────────────────────────────────────────────────────────────────
struct BeaconingSection: View {
    let vm: AprsViewModel
    @State private var mode:    String = "off"
    @State private var comment: String = "APRS Net iOS"
    @State private var saved   = false

    var body: some View {
        Section("Position / Beaconing") {
            Picker("Mode", selection: $mode) {
                Text("Off").tag("off")
                Text("GPS").tag("gps")
            }
            .pickerStyle(.segmented)
            .onAppear { mode = vm.settings.positionMode; comment = vm.settings.beaconComment }
            TextField("Beacon comment", text: $comment)
            Button("Save beaconing") {
                vm.settings.positionMode = mode; vm.settings.beaconComment = comment
                vm.applySettings(); saved = true
            }
            if saved { Text("Saved").foregroundStyle(.green).font(.caption) }
        }
    }
}

// ─ Filters ───────────────────────────────────────────────────────────────────
struct FiltersSection: View {
    let vm: AprsViewModel
    @State private var showHam = true; @State private var showWx  = true
    @State private var showOGN = true; @State private var showShip = true
    @State private var showLora = true; @State private var showMmdvm = true
    @State private var showOther = true

    var body: some View {
        Section("Map Filters") {
            Toggle("Ham (APRS)",         isOn: $showHam)   .onChange(of: showHam)    { vm.settings.showHam    = showHam;    vm.filterTick += 1 }
            Toggle("Weather (CWOP)",     isOn: $showWx)    .onChange(of: showWx)     { vm.settings.showWeather = showWx;   vm.filterTick += 1 }
            Toggle("Gliders (OGN)",      isOn: $showOGN)   .onChange(of: showOGN)   { vm.settings.showGlider = showOGN;   vm.filterTick += 1 }
            Toggle("Ships / AIS",        isOn: $showShip)  .onChange(of: showShip)  { vm.settings.showShip   = showShip;  vm.filterTick += 1 }
            Toggle("LoRa",               isOn: $showLora)  .onChange(of: showLora)  { vm.settings.showLora   = showLora;  vm.filterTick += 1 }
            Toggle("MMDVM / DMR",        isOn: $showMmdvm) .onChange(of: showMmdvm) { vm.settings.showMmdvm  = showMmdvm; vm.filterTick += 1 }
            Toggle("Objects / other",    isOn: $showOther) .onChange(of: showOther) { vm.settings.showOther  = showOther; vm.filterTick += 1 }
        }
        .onAppear {
            showHam = vm.settings.showHam;    showWx   = vm.settings.showWeather
            showOGN = vm.settings.showGlider; showShip = vm.settings.showShip
            showLora = vm.settings.showLora;  showMmdvm = vm.settings.showMmdvm
            showOther = vm.settings.showOther
        }
    }
}

// ─ AIS ───────────────────────────────────────────────────────────────────────
struct AisSection: View {
    let vm: AprsViewModel
    @State private var key = ""; @State private var keyVisible = false; @State private var saved = false

    var body: some View {
        Section {
            if keyVisible {
                TextField("aisstream.io API key", text: $key).autocorrectionDisabled()
            } else {
                SecureField("aisstream.io API key (optional)", text: $key)
            }
            Toggle("Show key", isOn: $keyVisible)
            Button("Save & connect") {
                vm.settings.aisApiKey = key; vm.restartAis(); saved = true
            }
            if saved {
                Text(key.isEmpty ? "Direct AIS disabled" : "Connecting to aisstream.io…")
                    .font(.caption).foregroundStyle(key.isEmpty ? Color.gray : Color.green)
            }
        } header: {
            Text("AIS / Ships (direct)")
        } footer: {
            Text("Optional. Free tier allows one connection per key — don't share it with the server.")
        }
        .onAppear { key = vm.settings.aisApiKey }
    }
}

// ─ Notifications ─────────────────────────────────────────────────────────────
struct NotificationsSection: View {
    let vm: AprsViewModel
    @State private var notifyMsg = true

    var body: some View {
        Section("Notifications") {
            Toggle("Incoming messages", isOn: $notifyMsg)
                .onChange(of: notifyMsg) { vm.settings.notifyMessages = notifyMsg }
                .onAppear { notifyMsg = vm.settings.notifyMessages }
        }
    }
}

// ─ Geo-fence alerts ───────────────────────────────────────────────────────────
struct GeoFenceAlertsSection: View {
    let vm: AprsViewModel
    var body: some View {
        Section {
            if vm.settings.memberSignedIn {
                NavigationLink(destination: GeoFenceScreen()) {
                    Label("Geo-fence Alerts", systemImage: "location.circle.fill")
                }
            } else {
                NavigationLink(destination: GeoFenceScreen()) {
                    Label("Geo-fence Alerts", systemImage: "location.circle.fill")
                }
                Text("Sign in to your aprsnet.uk account above to create alerts.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } footer: {
            Text("Get notified when a station enters or leaves a geographic area.")
        }
    }
}
