import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightIndexer {
    static func index(fileURL: URL, content: String) {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.markdown)
        attrs.title = extractTitle(from: content) ?? fileURL.deletingPathExtension().lastPathComponent
        attrs.textContent = content
        attrs.contentDescription = String(
            content.replacingOccurrences(of: #"[#*_`~\[\]()>]"#, with: "", options: .regularExpression)
                .prefix(300)
        )
        attrs.contentURL = fileURL

        let item = CSSearchableItem(
            uniqueIdentifier: fileURL.path,
            domainIdentifier: "com.chathura.Markd.documents",
            attributeSet: attrs
        )
        item.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                print("[Markd] Spotlight indexing error: \(error.localizedDescription)")
            }
        }
    }

    private static func extractTitle(from markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
