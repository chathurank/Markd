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

# markdown-it-footnote — footnotes ([^1])
curl -sL -o "$DIR/markdown-it-footnote.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-footnote@4/dist/markdown-it-footnote.min.js"
echo "  ✓ markdown-it-footnote"

# markdown-it-deflist — definition lists
curl -sL -o "$DIR/markdown-it-deflist.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-deflist@4/dist/markdown-it-deflist.min.js"
echo "  ✓ markdown-it-deflist"

# markdown-it-sub / markdown-it-sup — H~2~O and x^2^
curl -sL -o "$DIR/markdown-it-sub.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-sub@2/dist/markdown-it-sub.min.js"
curl -sL -o "$DIR/markdown-it-sup.min.js" \
  "https://cdn.jsdelivr.net/npm/markdown-it-sup@2/dist/markdown-it-sup.min.js"
echo "  ✓ markdown-it-sub / markdown-it-sup"

# markdown-it-front-matter — hides YAML front matter
# Published as CommonJS only, so wrap it to expose window.markdownItFrontMatter
FRONT_MATTER_SRC=$(curl -sfL "https://cdn.jsdelivr.net/npm/markdown-it-front-matter@0.2.4/index.js")
{
  echo "(function () { var module = { exports: {} };"
  printf '%s\n' "$FRONT_MATTER_SRC"
  echo "window.markdownItFrontMatter = module.exports; })();"
} > "$DIR/markdown-it-front-matter.js"
echo "  ✓ markdown-it-front-matter"

# markdown-it-github-alerts — > [!NOTE] / [!TIP] / [!IMPORTANT] / [!WARNING] / [!CAUTION]
# Published as an ES module only, so wrap it to expose window.markdownItGitHubAlerts
ALERTS_SRC=$(curl -sfL "https://cdn.jsdelivr.net/npm/markdown-it-github-alerts@1.0.1/dist/index.mjs")
ALERTS_EXPORT='export { MarkdownItGitHubAlerts as default };'
if ! grep -qxF "$ALERTS_EXPORT" <<< "$ALERTS_SRC"; then
  echo "markdown-it-github-alerts: unexpected export line, update the wrapper" >&2
  exit 1
fi
{
  echo "(function () {"
  grep -vxF "$ALERTS_EXPORT" <<< "$ALERTS_SRC"
  echo "window.markdownItGitHubAlerts = MarkdownItGitHubAlerts; })();"
} > "$DIR/markdown-it-github-alerts.js"
echo "  ✓ markdown-it-github-alerts"

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
