import SwiftUI

@main
struct APRSNetApp: App {
    @State private var vm = AprsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
        }
    }
}
