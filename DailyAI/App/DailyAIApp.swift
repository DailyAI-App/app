import SwiftUI

@main
struct DailyAIApp: App {
    @StateObject private var settings = ConnectionSettings()
    @StateObject private var motion = HeadphoneMotionService()
    @StateObject private var focusTimer = FocusTimerService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(motion)
                .environmentObject(focusTimer)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
        #endif
    }
}
