import SwiftUI

@main
struct AuraPD_VoiceApp: App {
    @StateObject private var viewModel    = MainViewModel()
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appViewModel)
        }
    }
}

