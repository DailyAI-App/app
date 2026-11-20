import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class ConnectionSettings: ObservableObject {
    @AppStorage("dailyai.baseURL") var baseURL: String = "http://localhost:3000"
    @AppStorage("dailyai.apiKey") var apiKey: String = ""

    var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    init() {
        if !apiKey.trimmingCharacters(in: .whitespaces).isEmpty { return }
        #if os(macOS)
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        #else
        let clipboard = UIPasteboard.general.string ?? ""
        #endif
        importFromText(clipboard)
    }

    func importFromClipboard() -> Bool {
        #if os(macOS)
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        #else
        let text = UIPasteboard.general.string ?? ""
        #endif
        return importFromText(text)
    }

    @discardableResult
    func importFromText(_ text: String) -> Bool {
        let keyPattern = #"(?<![A-Za-z0-9])pk_[A-Za-z0-9_-]+"#
        guard let range = text.range(of: keyPattern, options: .regularExpression) else { return false }
        apiKey = String(text[range])
        return true
    }
}
