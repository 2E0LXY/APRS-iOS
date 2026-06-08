import SwiftUI

struct StationsScreen: View {
    @Environment(AprsViewModel.self) var vm
    @State private var search = ""
    @State private var typeFilter: StationType? = nil

    private var filtered: [Station] {
        let base = vm.stationsFiltered()
        let byType = typeFilter == nil ? base : base.filter { $0.type == typeFilter }
        if search.isEmpty { return byType.sorted { $0.callsign < $1.callsign } }
        return byType.filter { $0.callsign.contains(search.uppercased()) }
                     .sorted { $0.callsign < $1.callsign }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TypeChip(label: "All", selected: typeFilter == nil) {
                            typeFilter = nil
                        }
                        ForEach(StationType.allCases, id: \.self) { t in
                            TypeChip(label: t.displayName, selected: typeFilter == t) {
                                typeFilter = typeFilter == t ? nil : t
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                Divider()
                List(filtered) { s in
                    HStack(spacing: 12) {
                        Image(systemName: s.type.symbolName)
                            .frame(width: 24)
                            .foregroundStyle(typeColor(s.type))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.callsign).font(.headline)
                            Text(s.comment.isEmpty ? s.type.displayName : s.comment)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(s.lastHeard, style: .relative)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .searchable(text: $search, prompt: "Search callsign")
            }
            .navigationTitle("Stations (\(filtered.count))")
        }
    }

    private func typeColor(_ t: StationType) -> Color {
        switch t {
        case .ham: return .blue; case .weather: return .green
        case .glider: return .orange; case .ship: return .teal
        case .lora: return .purple; case .mmdvm: return .red; case .object: return .gray
        }
    }
}

struct TypeChip: View {
    let label: String; let selected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(selected ? .bold : .regular))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(selected ? Color.blue : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
