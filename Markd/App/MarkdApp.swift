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

            // Print
            CommandGroup(replacing: .printItem) {
                Button("Print…") {
                    WebViewCoordinator.active?.printDocument()
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            // Find
            CommandGroup(replacing: .textEditing) {
                Button("Find…") {
                    WebViewCoordinator.active?.showFind()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Copy as HTML in Edit menu
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Copy as HTML") {
                    WebViewCoordinator.active?.copyHTML()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }

            // Export to HTML in File menu
            CommandGroup(after: .saveItem) {
                Button("Export to HTML…") {
                    WebViewCoordinator.active?.exportHTML()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["AppleWindowTabbingMode": "always"])
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for window in NSApp.windows {
                if window.frameAutosaveName.isEmpty {
                    window.setFrameAutosaveName("MarkdMainWindow")
                }
            }
        }

        // Keyboard monitor for Cmd+P and Cmd+F (bypasses SwiftUI menu conflicts)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            switch event.charactersIgnoringModifiers {
            case "p" where !event.modifierFlags.contains(.shift):
                WebViewCoordinator.active?.printDocument()
                return nil
            case "f" where !event.modifierFlags.contains(.shift):
                WebViewCoordinator.active?.showFind()
                return nil
            default:
                return event
            }
        }
    }

    // Handle markd:// URL scheme
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "markd", url.host == "open" else { continue }
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let path = components.queryItems?.first(where: { $0.name == "path" })?.value
            else { continue }

            let fileURL = URL(fileURLWithPath: path)
            let validExts = ["md", "markdown", "mdown", "mkd", "mdx"]
            guard validExts.contains(fileURL.pathExtension.lowercased()),
                  FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            NSDocumentController.shared.openDocument(
                withContentsOf: fileURL, display: true
            ) { _, _, _ in }
        }
    }
}
