import SwiftUI
import UniformTypeIdentifiers

enum ViewMode: String, CaseIterable {
    case rendered
    case code
}

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
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @State private var tocItems: [TOCItem] = []
    @State private var activeTOCId: String? = nil
    @State private var scrollToId: String? = nil
    @State private var markdown: String = ""
    @State private var fileWatcher: FileWatcher? = nil
    @State private var isDropTargeted = false
    @State private var viewMode: ViewMode = .rendered
    @AppStorage("pageZoom") private var zoomLevel: Double = 1.0
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    private var documentTitle: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }

    private var documentSubtitle: String {
        fileURL?.deletingLastPathComponent().lastPathComponent ?? ""
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            TOCSidebar(
                items: tocItems,
                activeId: activeTOCId,
                onSelect: { id in
                    if viewMode == .code { viewMode = .rendered }
                    scrollToId = id
                }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
            .navigationTitle("Contents")
        } detail: {
            Group {
                if viewMode == .rendered {
                    MarkdownWebView(
                        markdown: markdown,
                        scrollToId: $scrollToId,
                        zoomLevel: zoomLevel,
                        documentDirectory: fileURL?.deletingLastPathComponent(),
                        onTOCUpdate: { items in tocItems = items },
                        onActiveHeadingChange: { id in activeTOCId = id }
                    )
                } else {
                    CodeEditorView(text: $document.text)
                }
            }
            .navigationTitle(documentTitle)
            .navigationSubtitle(documentSubtitle)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Picker("", selection: $viewMode) {
                        Image(systemName: "eye")
                            .tag(ViewMode.rendered)
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .tag(ViewMode.code)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .help(viewMode == .rendered ? "Rendered view" : "Code view")
                }

            }
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
            if let url = fileURL {
                SpotlightIndexer.index(fileURL: url, content: document.text)
            }
        }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
        }
        .onChange(of: viewMode) { _, newMode in
            if newMode == .rendered {
                // Sync edited text to rendered view
                markdown = document.text
                startFileWatcher()
            } else {
                // Pause file watcher during editing
                fileWatcher?.stop()
                fileWatcher = nil
            }
        }
    }

    private func startFileWatcher() {
        guard let url = fileURL else { return }
        fileWatcher?.stop()
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
