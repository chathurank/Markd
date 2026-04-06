import WebKit

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    /// The most recently active coordinator (set when webView is created/updated)
    static var active: WebViewCoordinator?

    weak var webView: WKWebView?
    var currentMarkdown: String = ""
    var documentDirectory: URL? = nil
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
        pageLoaded = true
        injectCustomCSS()
        if !currentMarkdown.isEmpty {
            injectMarkdown(currentMarkdown)
        }
    }

    /// Inject user's custom CSS from ~/Library/Application Support/Markd/custom.css
    private func injectCustomCSS() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let cssURL = appSupport?.appendingPathComponent("Markd/custom.css"),
              let css = try? String(contentsOf: cssURL, encoding: .utf8) else { return }
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = """
        (function(){
            var s = document.getElementById('markd-custom-css');
            if (!s) { s = document.createElement('style'); s.id = 'markd-custom-css'; document.head.appendChild(s); }
            s.textContent = '\(escaped)';
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
        // Resolve relative image paths to data: URLs before sending to JS
        var processedMarkdown = markdown
        if let dir = documentDirectory {
            processedMarkdown = resolveImagePaths(in: markdown, relativeTo: dir)
        }

        guard let data = processedMarkdown.data(using: .utf8) else { return }
        let base64 = data.base64EncodedString()
        let js = "renderMarkdown(decodeURIComponent(escape(atob('\(base64)')))).catch(function(e){console.error('[Markd] render error:', e)})"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Replace relative image paths with data: URLs by reading files from disk
    private func resolveImagePaths(in markdown: String, relativeTo directory: URL) -> String {
        var result = markdown
        // Match markdown image syntax: ![alt](path)
        let pattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        let nsString = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

        // Process in reverse order to preserve string indices
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let pathRange = match.range(at: 2)
            let path = nsString.substring(with: pathRange)

            // Skip URLs and absolute paths
            if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("data:") {
                continue
            }

            // Resolve the path relative to the document directory
            let imageURL: URL
            if path.hasPrefix("/") {
                imageURL = URL(fileURLWithPath: path).standardized
            } else {
                imageURL = directory.appendingPathComponent(path).standardized
            }

            // Read the file and convert to data URL
            guard let imageData = try? Data(contentsOf: imageURL) else {
                continue
            }
            let mimeType = mimeTypeForPath(path)
            let dataURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"

            result = (result as NSString).replacingCharacters(in: pathRange, with: dataURL)
        }

        return result
    }

    private func mimeTypeForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "ico": return "image/x-icon"
        default: return "image/png"
        }
    }

    func scrollToHeading(_ id: String) {
        let safeId = id.replacingOccurrences(of: "'", with: "\\'")
        webView?.evaluateJavaScript("scrollToHeading('\(safeId)')")
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
        // Inject a find overlay into the web page
        let js = "showFindBar()"
        webView?.evaluateJavaScript(js, completionHandler: nil)
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

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url {
            if url.fragment != nil && url.scheme == "file" {
                decisionHandler(.allow)
            } else if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}
