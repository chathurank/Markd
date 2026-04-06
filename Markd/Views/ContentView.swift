import SwiftUI
import UniformTypeIdentifiers

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
    @State private var isDropTargeted = false
    @AppStorage("pageZoom") private var zoomLevel: Double = 1.0
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    private var wordCount: Int {
        markdown.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var readingTime: String {
        let minutes = max(1, wordCount / 200)
        return "\(minutes) min read"
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $sidebarVisibility) {
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

            // Status bar
            HStack(spacing: 16) {
                Text("\(wordCount) words")
                Text(readingTime)
                Spacer()
                if zoomLevel != 1.0 {
                    Text("\(Int(zoomLevel * 100))%")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusedSceneValue(\.zoom, $zoomLevel)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            markdown = document.text
            startFileWatcher()
            // Index in Spotlight
            if let url = fileURL {
                SpotlightIndexer.index(fileURL: url, content: document.text)
            }
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

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let validExtensions = ["md", "markdown", "mdown", "mkd", "mdx"]
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      validExtensions.contains(url.pathExtension.lowercased())
                else { return }
                DispatchQueue.main.async {
                    NSDocumentController.shared.openDocument(
                        withContentsOf: url, display: true
                    ) { _, _, _ in }
                }
            }
        }
        return true
    }
}
