import SwiftUI

struct ZoomKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

extension FocusedValues {
    var zoom: Binding<Double>? {
        get { self[ZoomKey.self] }
        set { self[ZoomKey.self] = newValue }
    }
}

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    @State private var tocItems: [TOCItem] = []
    @State private var activeTOCId: String? = nil
    @State private var scrollToId: String? = nil
    @State private var markdown: String = ""
    @State private var fileWatcher: FileWatcher? = nil
    @AppStorage("pageZoom") private var zoomLevel: Double = 1.0

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
                markdown: markdown,
                scrollToId: $scrollToId,
                zoomLevel: zoomLevel,
                documentDirectory: fileURL?.deletingLastPathComponent(),
                onTOCUpdate: { items in tocItems = items },
                onActiveHeadingChange: { id in activeTOCId = id }
            )
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusedSceneValue(\.zoom, $zoomLevel)
        .onAppear {
            markdown = document.text
            startFileWatcher()
        }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
        }
    }

    private func startFileWatcher() {
        guard let url = fileURL else { return }
        fileWatcher = FileWatcher(url: url) {
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                markdown = text
            }
        }
    }
}
