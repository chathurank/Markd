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
        // Read the markdown file
        guard let markdownData = try? Data(contentsOf: url),
              let markdown = String(data: markdownData, encoding: .utf8) else {
            handler(NSError(domain: "com.chathura.Markd.QuickLook", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Could not read file"]))
            return
        }

        // Resolve relative images
        let documentDirectory = url.deletingLastPathComponent()
        let processedMarkdown = resolveImagePaths(in: markdown, relativeTo: documentDirectory)

        // Load the template from the extension's bundle
        guard let webFolder = Bundle(for: Self.self).resourceURL?.appendingPathComponent("Web") else {
            handler(NSError(domain: "com.chathura.Markd.QuickLook", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Could not find Web resources"]))
            return
        }

        let templateURL = webFolder.appendingPathComponent("template.html")
        webView.navigationDelegate = self
        webView.loadFileURL(templateURL, allowingReadAccessTo: webFolder)

        // Store markdown and handler for use in didFinish
        pendingMarkdown = processedMarkdown
        pendingHandler = handler
    }

    private var pendingMarkdown: String?
    private var pendingHandler: ((Error?) -> Void)?

    // Image resolution (simplified version of WebViewCoordinator's logic)
    private func resolveImagePaths(in markdown: String, relativeTo directory: URL) -> String {
        var result = markdown
        let pattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }

        let nsString = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let pathRange = match.range(at: 2)
            let path = nsString.substring(with: pathRange)

            if path.hasPrefix("http://") || path.hasPrefix("https://") || path.hasPrefix("data:") {
                continue
            }

            let imageURL: URL
            if path.hasPrefix("/") {
                imageURL = URL(fileURLWithPath: path).standardized
            } else {
                imageURL = directory.appendingPathComponent(path).standardized
            }

            guard let imageData = try? Data(contentsOf: imageURL) else { continue }
            let ext = (path as NSString).pathExtension.lowercased()
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "jpg", "jpeg": mime = "image/jpeg"
            case "gif": mime = "image/gif"
            case "svg": mime = "image/svg+xml"
            case "webp": mime = "image/webp"
            default: mime = "image/png"
            }
            let dataURL = "data:\(mime);base64,\(imageData.base64EncodedString())"
            result = (result as NSString).replacingCharacters(in: pathRange, with: dataURL)
        }
        return result
    }
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
