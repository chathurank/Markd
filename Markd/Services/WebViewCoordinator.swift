import WebKit

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    weak var webView: WKWebView?
    var currentMarkdown: String = ""
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
        if !currentMarkdown.isEmpty {
            injectMarkdown(currentMarkdown)
        }
    }

    func renderMarkdown(_ markdown: String) {
        currentMarkdown = markdown
        if pageLoaded {
            injectMarkdown(markdown)
        }
    }

    private func injectMarkdown(_ markdown: String) {
        guard let data = markdown.data(using: .utf8) else { return }
        let base64 = data.base64EncodedString()
        let js = "renderMarkdown(decodeURIComponent(escape(atob('\(base64)')))).catch(function(e){console.error('[Markd] render error:', e)})"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func scrollToHeading(_ id: String) {
        let safeId = id.replacingOccurrences(of: "'", with: "\\'")
        webView?.evaluateJavaScript("scrollToHeading('\(safeId)')")
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
