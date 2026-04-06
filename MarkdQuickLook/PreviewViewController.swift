import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        guard let markdownData = try? Data(contentsOf: url) else {
            handler(NSError(domain: "com.chathura.Markd.QuickLook", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Could not read file"]))
            return
        }

        // Try common encodings
        let encodings: [String.Encoding] = [.utf8, .isoLatin1, .macOSRoman, .ascii]
        var markdown: String?
        for enc in encodings {
            if let text = String(data: markdownData, encoding: enc) {
                markdown = text
                break
            }
        }
        guard let markdown else {
            handler(NSError(domain: "com.chathura.Markd.QuickLook", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Could not decode file"]))
            return
        }

        let documentDirectory = url.deletingLastPathComponent()
        let processedMarkdown = ImageResolver.resolveImagePaths(in: markdown, relativeTo: documentDirectory)

        guard let webFolder = Bundle(for: Self.self).resourceURL?.appendingPathComponent("Web") else {
            handler(NSError(domain: "com.chathura.Markd.QuickLook", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Could not find Web resources"]))
            return
        }

        let templateURL = webFolder.appendingPathComponent("template.html")
        webView.navigationDelegate = self
        webView.loadFileURL(templateURL, allowingReadAccessTo: webFolder)

        pendingMarkdown = processedMarkdown
        pendingHandler = handler
    }

    private var pendingMarkdown: String?
    private var pendingHandler: ((Error?) -> Void)?
}

extension PreviewViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let markdown = pendingMarkdown,
              let data = markdown.data(using: .utf8) else {
            pendingHandler?(nil)
            return
        }

        let base64 = data.base64EncodedString()
        let js = "renderMarkdown(decodeURIComponent(escape(atob('\(base64)')))).then(function(){return null}).catch(function(e){return null})"
        webView.evaluateJavaScript(js) { [weak self] _, _ in
            self?.pendingHandler?(nil)
            self?.pendingHandler = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        pendingHandler?(error)
        pendingHandler = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        pendingHandler?(error)
        pendingHandler = nil
    }
}
