import SwiftUI

@main
struct MarkdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { config in
            ContentView(document: config.document)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Force new documents to open as tabs instead of windows
        UserDefaults.standard.register(defaults: ["AppleWindowTabbingMode": "always"])
    }
}
