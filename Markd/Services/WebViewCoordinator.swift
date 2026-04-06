import WebKit

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    @MainActor static var active: WebViewCoordinator?

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
