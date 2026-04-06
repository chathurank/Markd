import SwiftUI

struct ContentView: View {
    let document: MarkdownDocument
    @State private var tocItems: [TOCItem] = []
    @State private var activeTOCId: String? = nil
    @State private var scrollToId: String? = nil

    var body: some View {
        NavigationSplitView {
            TOCSidebar(
                items: tocItems,
                activeId: activeTOCId,
                onSelect: { id in scrollToId = id }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
            .navigationTitle("Contents")
        } detail: {
            MarkdownWebView(
                markdown: document.text,
                scrollToId: $scrollToId,
                onTOCUpdate: { items in tocItems = items },
                onActiveHeadingChange: { id in activeTOCId = id }
            )
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
