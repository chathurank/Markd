import SwiftUI

@main
struct MarkdApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { config in
            ContentView(document: config.document)
        }
    }
}
