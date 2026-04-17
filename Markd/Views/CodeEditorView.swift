import SwiftUI
import AppKit

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Text view setup
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        // Font
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        // Line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes[.paragraphStyle] = paragraphStyle

        // Layout
        textView.textContainerInset = NSSize(width: 32, height: 20)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Set initial text
        textView.string = text
        textView.delegate = context.coordinator

        // Apply theme + highlighting
        let isDark = colorScheme == .dark
        applyTheme(textView: textView, scrollView: scrollView, isDark: isDark)
        context.coordinator.applyHighlighting(textView, isDark: isDark)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let isDark = colorScheme == .dark
        let appearanceChanged = context.coordinator.currentIsDark != isDark

        applyTheme(textView: textView, scrollView: scrollView, isDark: isDark)
        context.coordinator.currentIsDark = isDark

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            context.coordinator.applyHighlighting(textView, isDark: isDark)
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        } else if appearanceChanged {
            context.coordinator.applyHighlighting(textView, isDark: isDark)
        }
    }

    private func applyTheme(textView: NSTextView, scrollView: NSScrollView, isDark: Bool) {
        let bgColor = isDark
            ? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            : NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        let cursorColor = isDark
            ? NSColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1.0)
            : NSColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
        let selectionColor = isDark
            ? NSColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 1.0)
            : NSColor(red: 0.7, green: 0.84, blue: 1.0, alpha: 1.0)

        textView.backgroundColor = bgColor
        textView.insertionPointColor = cursorColor
        textView.selectedTextAttributes = [
            .backgroundColor: selectionColor,
            .foregroundColor: NSColor.textColor
        ]
        scrollView.backgroundColor = bgColor
        scrollView.drawsBackground = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var currentIsDark: Bool = true

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            applyHighlighting(textView, isDark: currentIsDark)
        }

        func applyHighlighting(_ textView: NSTextView, isDark: Bool) {
            let string = textView.string
            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            let storage = textView.textStorage!

            // Theme-aware colors
            let defaultColor = isDark
                ? NSColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1.0)
                : NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            let headingColor = isDark
                ? NSColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 1.0)
                : NSColor(red: 0.0, green: 0.3, blue: 0.7, alpha: 1.0)
            let boldColor = isDark
                ? NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
                : NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
            let codeColor = isDark
                ? NSColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1.0)
                : NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
            let linkColor = isDark
                ? NSColor(red: 0.45, green: 0.7, blue: 1.0, alpha: 1.0)
                : NSColor(red: 0.0, green: 0.35, blue: 0.75, alpha: 1.0)
            let commentColor = isDark
                ? NSColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1.0)
                : NSColor(red: 0.45, green: 0.45, blue: 0.48, alpha: 1.0)
            let listColor = isDark
                ? NSColor(red: 0.9, green: 0.65, blue: 0.4, alpha: 1.0)
                : NSColor(red: 0.65, green: 0.35, blue: 0.0, alpha: 1.0)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 5

            storage.beginEditing()
            storage.addAttribute(.foregroundColor, value: defaultColor, range: fullRange)
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), range: fullRange)
            storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

            let patterns: [(String, NSColor, NSFont?)] = [
                (#"^#{1,6}\s.*$"#, headingColor, NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)),
                (#"\*\*[^*]+\*\*"#, boldColor, NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)),
                (#"(?<!\w)_[^_]+_(?!\w)"#, defaultColor, NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)),
                (#"`[^`\n]+`"#, codeColor, nil),
                (#"^```.*$"#, commentColor, nil),
                (#"\[([^\]]*)\]\([^\)]*\)"#, linkColor, nil),
                (#"https?://\S+"#, linkColor, nil),
                (#"^[\s]*[-*+]\s"#, listColor, nil),
                (#"^[\s]*\d+\.\s"#, listColor, nil),
                (#"^>\s.*$"#, commentColor, nil),
                (#"<[^>]+>"#, commentColor, nil),
            ]

            for (pattern, color, font) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { continue }
                let matches = regex.matches(in: string, range: fullRange)
                for match in matches {
                    storage.addAttribute(.foregroundColor, value: color, range: match.range)
                    if let font {
                        storage.addAttribute(.font, value: font, range: match.range)
                    }
                }
            }

            storage.endEditing()
        }
    }
}
