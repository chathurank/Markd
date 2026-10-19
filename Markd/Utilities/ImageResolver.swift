import Foundation

enum ImageResolver {
    private static let imagePattern = try! NSRegularExpression(pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#)
    private static let maxImageBytes = 20 * 1024 * 1024

    /// Replace relative image paths in markdown with base64 data: URLs.
    /// Only resolves paths within the given directory (prevents path traversal).
    static func resolveImagePaths(in markdown: String, relativeTo directory: URL) -> String {
        var result = markdown
        let nsString = result as NSString
        let matches = imagePattern.matches(in: result, range: NSRange(location: 0, length: nsString.length))
        let directoryPath = directory.resolvingSymlinksInPath().path
        let directoryPrefix = directoryPath.hasSuffix("/") ? directoryPath : directoryPath + "/"

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

            // Prevent path traversal — only allow files within the document directory.
            // Resolve symlinks first: a repo can ship "logo.png" as a link to ~/.ssh/id_rsa.
            let resolvedURL = imageURL.resolvingSymlinksInPath()
            guard resolvedURL.path.hasPrefix(directoryPrefix) else { continue }

            // Only regular image files of a sane size, judged by the real file, not the link name
            guard let mimeType = mimeTypeForExtension(resolvedURL.pathExtension.lowercased()),
                  let values = try? resolvedURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize, size <= maxImageBytes,
                  let imageData = try? Data(contentsOf: resolvedURL) else { continue }
            let dataURL = "data:\(mimeType);base64,\(imageData.base64EncodedString())"

            result = (result as NSString).replacingCharacters(in: pathRange, with: dataURL)
        }

        return result
    }

    private static func mimeTypeForExtension(_ ext: String) -> String? {
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "tiff", "tif": return "image/tiff"
        case "ico": return "image/x-icon"
        default: return nil
        }
    }
}
