import SwiftUI

struct ThreadScreen: View {
    @Environment(AprsViewModel.self) var vm
    let callsign: String
    @State private var text = ""

    private var thread: [APRSMessage] {
        vm.messages[callsign.uppercased()] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(thread) { msg in
                            MessageBubble(msg: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: thread.count) {
                    if let last = thread.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            Divider()
            HStack(spacing: 10) {
                TextField("Message (max 67 chars)", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) {
                        if text.count > 67 { text = String(text.prefix(67)) }
                    }
                Button {
                    let t = text.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    vm.send(to: callsign, text: t)
                    text = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty ||
                          vm.connState != .authed)
            }
            .padding()
        }
        .navigationTitle(callsign)
    }
}

struct MessageBubble: View {
    let msg: APRSMessage
    var body: some View {
        HStack {
            if msg.outgoing { Spacer(minLength: 60) }
            VStack(alignment: msg.outgoing ? .trailing : .leading, spacing: 2) {
                Text(msg.text)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(msg.outgoing ? (msg.acked ? Color.green.opacity(0.8) : Color.blue) : Color(.systemGray5)))
                    .foregroundStyle(msg.outgoing ? .white : .primary)
                HStack(spacing: 4) {
                    Text(msg.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    if msg.outgoing {
                        Image(systemName: msg.acked ? "checkmark.circle.fill" : "clock")
                            .font(.caption2)
                            .foregroundStyle(msg.acked ? .green : .secondary)
                    }
                }
            }
            if !msg.outgoing { Spacer(minLength: 60) }
        }
    }
}
