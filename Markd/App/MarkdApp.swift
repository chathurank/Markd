import SwiftUI
import WebKit

@main
struct MarkdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusedBinding(\.zoom) private var zoomLevel

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { config in
            ContentView(document: config.document, fileURL: config.fileURL)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }

            // Zoom
            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    if let zoom = zoomLevel {
                        zoomLevel = min(zoom * 1.1, 3.0)
                    }
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    if let zoom = zoomLevel {
                        zoomLevel = max(zoom / 1.1, 0.5)
                    }
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    zoomLevel = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()
            }

            // Replace system Print with ours
            CommandGroup(replacing: .printItem) {
                Button("Print…") {
                    WebViewCoordinator.active?.printDocument()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(WebViewCoordinator.active == nil)
            }

            // Replace system Find with ours
            CommandGroup(replacing: .textEditing) {
                Button("Find…") {
                    WebViewCoordinator.active?.showFind()
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["AppleWindowTabbingMode": "always"])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable window frame autosave so size/position persists
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for window in NSApp.windows {
                if window.frameAutosaveName.isEmpty {
                    window.setFrameAutosaveName("MarkdMainWindow")
                }
            }
        }
    }
}
