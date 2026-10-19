import WebKit

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    @MainActor static var active: WebViewCoordinator?

    weak var webView: WKWebView?
    var currentMarkdown: String = ""
    var documentDirectory: URL? = nil
    /// The bundled template.html — the only page this web view may show or receive markdown.
    var templateURL: URL? = nil
    private var pageLoaded = false
    private let onTOCUpdate: ([TOCItem]) -> Void
    private let onActiveHeadingChange: (String?) -> Void

    init(
        onTOCUpdate: @escaping ([TOCItem]) -> Void,
        onActiveHeadingChange: @escaping (String?) -> Void
    ) {
        self.onTOCUpdate = onTOCUpdate
        self.onActiveHeadingChange = onActiveHeadingChange
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Never hand the document (with its inlined images) to any page but our own
        guard let url = webView.url, isTemplate(url) else { return }
        pageLoaded = true
        injectCustomCSS()
        if !currentMarkdown.isEmpty {
            injectMarkdown(currentMarkdown)
        }
    }

    private func injectCustomCSS() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let cssURL = appSupport?.appendingPathComponent("Markd/custom.css"),
              let css = try? String(contentsOf: cssURL, encoding: .utf8),
              let cssData = try? JSONEncoder().encode(css),
              let cssJSON = String(data: cssData, encoding: .utf8) else { return }
        let js = """
        (function(){
            var s = document.getElementById('markd-custom-css');
            if (!s) { s = document.createElement('style'); s.id = 'markd-custom-css'; document.head.appendChild(s); }
            s.textContent = \(cssJSON);
        })()
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func renderMarkdown(_ markdown: String) {
        currentMarkdown = markdown
        if pageLoaded {
            injectMarkdown(markdown)
        }
    }

    private func injectMarkdown(_ markdown: String) {
        var processedMarkdown = markdown
        if let dir = documentDirectory {
            processedMarkdown = ImageResolver.resolveImagePaths(in: markdown, relativeTo: dir)
        }

        guard let data = processedMarkdown.data(using: .utf8) else { return }
        let base64 = data.base64EncodedString()
        let js = "renderMarkdown(decodeURIComponent(escape(atob('\(base64)')))).catch(function(e){console.error('[Markd] render error:', e)})"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func scrollToHeading(_ id: String) {
        guard let data = try? JSONEncoder().encode(id),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("scrollToHeading(\(json))")
    }

    func printDocument() {
        guard let webView else { return }
        let printInfo = NSPrintInfo.shared
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = false
        let op = webView.printOperation(with: printInfo)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.run()
    }

    func showFind() {
        webView?.evaluateJavaScript("showFindBar()", completionHandler: nil)
    }

    func copyHTML() {
        webView?.evaluateJavaScript("document.getElementById('content').innerHTML") { result, _ in
            guard let html = result as? String else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(html, forType: .html)
            pasteboard.setString(html, forType: .string)
        }
    }

    func exportHTML() {
        webView?.evaluateJavaScript("document.getElementById('content').innerHTML") { result, _ in
            guard let bodyHTML = result as? String else { return }

            let cssString: String
            if let cssURL = Bundle.main.resourceURL?
                .appendingPathComponent("Web/css/style.css"),
               let css = try? String(contentsOf: cssURL, encoding: .utf8) {
                cssString = css
            } else {
                cssString = ""
            }

            let fullHTML = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(cssString)</style>
            </head>
            <body><article>\(bodyHTML)</article></body>
            </html>
            """

            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.html]
                panel.nameFieldStringValue = "document.html"
                if panel.runModal() == .OK, let url = panel.url {
                    do {
                        try fullHTML.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        let alert = NSAlert(error: error)
                        alert.runModal()
                    }
                }
            }
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "tocUpdate":
            if let jsonString = message.body as? String,
               let data = jsonString.data(using: .utf8),
               let items = try? JSONDecoder().decode([TOCItem].self, from: data) {
                onTOCUpdate(items)
            }
        case "activeHeading":
            let id = message.body as? String
            onActiveHeadingChange(id)
        default:
            break
        }
    }

    // Allowlist: this web view only ever shows the bundled template (including in-page
    // #anchor jumps). Everything else — links, form submissions, redirects — is cancelled,
    // and links the user clicked are handed to the right app instead.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if isTemplate(url) {
            decisionHandler(.allow)
            return
        }
        if navigationAction.navigationType == .linkActivated {
            openExternally(url)
        }
        decisionHandler(.cancel)
    }

    private func isTemplate(_ url: URL) -> Bool {
        guard let templateURL, url.isFileURL, url.query == nil else { return false }
        return url.resolvingSymlinksInPath().path == templateURL.resolvingSymlinksInPath().path
    }

    private static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdx"]

    private func openExternally(_ url: URL) {
        switch url.scheme?.lowercased() {
        case "http", "https", "mailto":
            NSWorkspace.shared.open(url)
        case "file":
            // Relative links to other Markdown files open as a new document; never hand
            // other local files to NSWorkspace, which would launch apps and scripts.
            let resolved = url.resolvingSymlinksInPath()
            let isRegularFile = (try? resolved.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
            guard isRegularFile, Self.markdownExtensions.contains(resolved.pathExtension.lowercased()) else { return }
            NSDocumentController.shared.openDocument(withContentsOf: resolved, display: true) { _, _, _ in }
        default:
            break
        }
    }
}
