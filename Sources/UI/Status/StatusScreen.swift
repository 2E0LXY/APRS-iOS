import SwiftUI

struct StatusScreen: View {
    @Environment(AprsViewModel.self) var vm

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    LabeledContent("WebSocket") {
                        HStack(spacing: 6) {
                            Circle().fill(connColor).frame(width: 8, height: 8)
                            Text(connLabel).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Stations on map", value: "\(vm.stations.count)")
                }
                if let s = vm.serverStatus {
                    Section("Server (aprsnet.uk)") {
                        LabeledContent("Uptime",   value: s.uptime)
                        LabeledContent("Packets",  value: "\(s.packetsRx)")
                        LabeledContent("Stations", value: "\(s.stations)")
                        LabeledContent("Upstream") {
                            Text(s.upstreamConnected ? "Connected" : "Down")
                                .foregroundStyle(s.upstreamConnected ? .green : .red)
                        }
                    }
                }
                if let pos = vm.myPosition {
                    Section("My Position") {
                        LabeledContent("Lat", value: String(format: "%.5f°", pos.latitude))
                        LabeledContent("Lon", value: String(format: "%.5f°", pos.longitude))
                        LabeledContent("Mode", value: vm.settings.positionMode.capitalized)
                    }
                }
            }
            .navigationTitle("Status")
        }
    }

    private var connLabel: String {
        switch vm.connState {
        case .authed:       return "Authenticated"
        case .connected:    return "Connected"
        case .connecting:   return "Connecting…"
        case .disconnected: return "Disconnected"
        }
    }
    private var connColor: Color {
        switch vm.connState {
        case .authed:       return .green
        case .connected:    return .yellow
        case .connecting:   return .orange
        case .disconnected: return .red
        }
    }
}
