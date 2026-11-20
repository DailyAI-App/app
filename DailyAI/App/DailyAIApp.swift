import SwiftUI

@main
struct DailyAIApp: App {
    @StateObject private var settings = ConnectionSettings()
    @StateObject private var motion = HeadphoneMotionService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(motion)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        #endif
    }
}
