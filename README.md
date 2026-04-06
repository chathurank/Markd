# Markd

A native macOS markdown viewer built with SwiftUI and WKWebView.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-6.0-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

**Rendering**
- Full GitHub-flavored markdown (tables, task lists, strikethrough, autolinks)
- Mermaid diagrams with zoom/pan controls
- LaTeX math (inline `$...$` and display `$$...$$`) via KaTeX
- Code syntax highlighting (180+ languages)
- Relative image support

**Navigation**
- Auto-generated Table of Contents sidebar with scroll spy
- Find in document (Cmd+F) with match highlighting
- Internal anchor links
- Keyboard TOC navigation

**Viewer**
- Tabbed interface (multiple documents)
- Live reload (auto-refreshes when file changes on disk)
- Page zoom (Cmd+/Cmd-/Cmd+0)
- Dark mode (automatic, follows system)
- Word count and reading time status bar

**Platform Integration**
- File > Open, drag & drop, Finder double-click
- URL scheme: `markd://open?path=/path/to/file.md`
- Drag & drop .md files onto the window
- Spotlight indexing (files indexed when opened)
- Print (Cmd+P)
- Copy as HTML (Cmd+Shift+C)
- Export to HTML (Cmd+Shift+E)
- Custom CSS themes (`~/Library/Application Support/Markd/custom.css`)

## Install

Download `Markd.dmg`, open it, and drag **Markd.app** to **Applications**.

On first launch, right-click > Open to bypass Gatekeeper (the app is not notarized).

## Build from Source

Requires macOS 14+, Xcode 16+, and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
# Clone
git clone https://github.com/chathurank/Markd.git
cd Markd

# Download JS dependencies (one-time)
./Scripts/fetch-js-deps.sh

# Generate Xcode project and build
xcodegen generate
xcodebuild -scheme Markd -configuration Release build
```

## Set as Default Viewer

Right-click any `.md` file in Finder > Get Info > Open with > Markd > Change All.

## Custom Themes

Create a CSS file at `~/Library/Application Support/Markd/custom.css` to override the default styles. Changes take effect on next file open.

## Architecture

- **SwiftUI** app shell with `DocumentGroup` for file handling
- **WKWebView** for rendering via bundled JavaScript libraries
- **markdown-it** for GFM parsing
- **highlight.js** for syntax highlighting
- **mermaid.js** for diagrams
- **KaTeX** for LaTeX math
- **xcodegen** generates the Xcode project from `project.yml`

## License

MIT
