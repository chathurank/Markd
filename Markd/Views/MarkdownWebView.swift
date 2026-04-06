import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    @Binding var scrollToId: String?
    var zoomLevel: Double = 1.0
    var documentDirectory: URL? = nil
    let onTOCUpdate: ([TOCItem]) -> Void
    let onActiveHeadingChange: (String?) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "tocUpdate")
        userContentController.add(context.coordinator, name: "activeHeading")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.webView = webView
        context.coordinator.documentDirectory = documentDirectory
        WebViewCoordinator.active = context.coordinator

        if let webFolder = Bundle.main.resourceURL?.appendingPathComponent("Web") {
            let templateURL = webFolder.appendingPathComponent("template.html")
            webView.loadFileURL(templateURL, allowingReadAccessTo: webFolder)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        WebViewCoordinator.active = context.coordinator

        if context.coordinator.currentMarkdown != markdown {
            context.coordinator.renderMarkdown(markdown)
        }

        if webView.pageZoom != CGFloat(zoomLevel) {
            webView.pageZoom = CGFloat(zoomLevel)
        }

        if let id = scrollToId {
            context.coordinator.scrollToHeading(id)
            DispatchQueue.main.async { scrollToId = nil }
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(
            onTOCUpdate: onTOCUpdate,
            onActiveHeadingChange: onActiveHeadingChange
        )
    }
}
