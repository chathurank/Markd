#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../Markd/Resources/Web/js" && pwd)"
mkdir -p "$DIR/fonts"

echo "Downloading JS dependencies to $DIR ..."

# markdown-it — GFM parsing
curl -sL -o "$DIR/markdown-it.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it@14/dist/markdown-it.min.js"
echo "  ✓ markdown-it"

# markdown-it-anchor — heading anchors
curl -sL -o "$DIR/markdownItAnchor.umd.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-anchor@9/dist/markdownItAnchor.umd.js"
echo "  ✓ markdown-it-anchor"

# markdown-it-task-lists — GFM task lists
curl -sL -o "$DIR/markdown-it-task-lists.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2/dist/markdown-it-task-lists.min.js"
echo "  ✓ markdown-it-task-lists"

# markdown-it-texmath — KaTeX bridge for $...$ and $$...$$ math
curl -sL -o "$DIR/texmath.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-texmath@1/texmath.min.js"
echo "  ✓ markdown-it-texmath"

# highlight.js — syntax highlighting (CDN assets bundle)
curl -sL -o "$DIR/highlight.min.js" \
  "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/highlight.min.js"
echo "  ✓ highlight.js"

# highlight.js themes (light + dark)
curl -sL -o "$DIR/github.min.css" \
  "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github.min.css"
curl -sL -o "$DIR/github-dark.min.css" \
  "https://cdn.jsdelivr.net/npm/@highlightjs/cdn-assets@11/styles/github-dark.min.css"
echo "  ✓ highlight.js themes"

# KaTeX — LaTeX math rendering
curl -sL -o "$DIR/katex.min.js" \
  "https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"
curl -sL -o "$DIR/katex.min.css" \
  "https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css"
echo "  ✓ katex"

# KaTeX fonts
KATEX_FONTS=(
  "KaTeX_AMS-Regular"
  "KaTeX_Main-Regular"
  "KaTeX_Main-Bold"
  "KaTeX_Main-Italic"
  "KaTeX_Main-BoldItalic"
  "KaTeX_Math-Italic"
  "KaTeX_Math-BoldItalic"
  "KaTeX_Size1-Regular"
  "KaTeX_Size2-Regular"
  "KaTeX_Size3-Regular"
  "KaTeX_Size4-Regular"
  "KaTeX_SansSerif-Regular"
  "KaTeX_SansSerif-Bold"
  "KaTeX_SansSerif-Italic"
  "KaTeX_Typewriter-Regular"
  "KaTeX_Caligraphic-Regular"
  "KaTeX_Caligraphic-Bold"
  "KaTeX_Fraktur-Regular"
  "KaTeX_Fraktur-Bold"
  "KaTeX_Script-Regular"
)
for font in "${KATEX_FONTS[@]}"; do
  curl -sL -o "$DIR/fonts/${font}.woff2" \
    "https://cdn.jsdelivr.net/npm/katex@0.16/dist/fonts/${font}.woff2"
done
echo "  ✓ katex fonts"

# Mermaid — diagram rendering
curl -sL -o "$DIR/mermaid.min.js" \
  "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"
echo "  ✓ mermaid"

echo ""
echo "All JS dependencies downloaded successfully."
