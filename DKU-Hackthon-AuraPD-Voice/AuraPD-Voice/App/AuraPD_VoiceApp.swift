import SwiftUI

@main
struct AuraPD_VoiceApp: App {
    @StateObject private var viewModel    = MainViewModel()
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(appViewModel)   // 全局跨 Tab 状态机
        }
    }
}
