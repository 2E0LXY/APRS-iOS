import SwiftUI

struct ConversationListScreen: View {
    @Environment(AprsViewModel.self) var vm
    @State private var newCall = ""
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.conversations, id: \.callsign) { conv in
                    NavigationLink(destination: ThreadScreen(callsign: conv.callsign)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(conv.callsign).font(.headline)
                                Text(conv.last.text)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(conv.last.timestamp, style: .time)
                                    .font(.caption).foregroundStyle(.secondary)
                                if conv.unread > 0 {
                                    Text("\(conv.unread)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(.blue))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showNew = true } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .alert("New message", isPresented: $showNew) {
                TextField("Callsign", text: $newCall)
                    .textInputAutocapitalization(.characters)
                Button("Open") { newCall = newCall.uppercased().trimmingCharacters(in: .whitespaces) }
                Button("Cancel", role: .cancel) { newCall = "" }
            }
        }
    }
}
