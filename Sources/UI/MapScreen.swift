import SwiftUI
import MapKit

struct MapScreen: View {
    @Environment(AprsViewModel.self) var vm
    @State private var camera   = MapCameraPosition.automatic
    @State private var selected: Station?

    var body: some View {
        Map(position: $camera) {
            ForEach(vm.stationsFiltered()) { s in
                Annotation(s.callsign, coordinate: s.coordinate) {
                    StationPin(station: s)
                        .onTapGesture { selected = s }
                }
            }
            if let pos = vm.myPosition {
                Annotation("Me", coordinate: pos) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(.blue))
                        .shadow(radius: 3)
                }
            }
        }
        .mapStyle(.standard(elevation: .automatic))
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Button {
                    if let pos = vm.myPosition {
                        camera = .region(MKCoordinateRegion(
                            center: pos,
                            latitudinalMeters: 50_000,
                            longitudinalMeters: 50_000))
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                }
                Button {
                    vm.beaconNow()
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .padding(12)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                }
            }
            .padding()
        }
        .sheet(item: $selected) { s in
            StationDetailSheet(station: s, myCoord: vm.myPosition)
                .presentationDetents([.medium])
        }
        .navigationTitle("Map")
    }
}

struct StationPin: View {
    let station: Station
    var body: some View {
        Image(systemName: station.type.symbolName)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(5)
            .background(Circle().fill(pinColor))
            .shadow(radius: 2)
    }
    private var pinColor: Color {
        switch station.type {
        case .ham:     return .blue
        case .weather: return .green
        case .glider:  return .orange
        case .ship:    return .teal
        case .lora:    return .purple
        case .mmdvm:   return .red
        case .object:  return .gray
        }
    }
}

struct StationDetailSheet: View {
    let station: Station
    let myCoord: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Identity") {
                    LabeledContent("Callsign", value: station.callsign)
                    LabeledContent("Type",     value: station.type.displayName)
                }
                Section("Position") {
                    LabeledContent("Lat", value: String(format: "%.5f°", station.lat))
                    LabeledContent("Lon", value: String(format: "%.5f°", station.lon))
                    if let my = myCoord {
                        LabeledContent("Distance", value: distanceString(from: my, to: station.coordinate))
                    }
                }
                if !station.comment.isEmpty {
                    Section("Comment") {
                        Text(station.comment).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !station.path.isEmpty {
                    Section("Path") {
                        Text(station.path).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(station.callsign)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }}
        }
    }

    private func distanceString(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let f = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let t = CLLocation(latitude: to.latitude,   longitude: to.longitude)
        let m = f.distance(from: t)
        return m >= 1000 ? String(format: "%.1f km", m / 1000) : String(format: "%.0f m", m)
    }
}
