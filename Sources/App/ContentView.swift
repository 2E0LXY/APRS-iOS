import SwiftUI

struct ContentView: View {
    @Environment(AprsViewModel.self) var vm

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map.fill") }
            ConversationListScreen()
                .tabItem { Label("Messages", systemImage: "message.fill") }
            StationsScreen()
                .tabItem { Label("Stations", systemImage: "antenna.radiowaves.left.and.right") }
            StatusScreen()
                .tabItem { Label("Status", systemImage: "chart.bar.fill") }
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(Color(red: 0.22, green: 0.74, blue: 0.97))
        .onAppear { vm.start() }
    }
}
