// Initialize markdown-it with plugins
const md = window.markdownit({
    html: true,
    linkify: true,
    typographer: true,
    highlight: function (str, lang) {
        if (lang && hljs.getLanguage(lang)) {
            try {
                return '<pre class="hljs"><code>' +
                    hljs.highlight(str, { language: lang, ignoreIllegals: true }).value +
                    '</code></pre>';
            } catch (_) {}
        }
        return '<pre class="hljs"><code>' + md.utils.escapeHtml(str) + '</code></pre>';
    }
});

// Add anchor plugin for heading IDs
if (window.markdownItAnchor) {
    md.use(window.markdownItAnchor, {
        permalink: false,
        slugify: function (s) {
            return s.trim()
                .toLowerCase()
                .replace(/\s+/g, '-')
                .replace(/[^\w\u4e00-\u9fff-]/g, '')
                .replace(/--+/g, '-')
                .replace(/^-|-$/g, '');
        }
    });
}

// Add task list plugin
if (window.markdownItTaskLists) {
    md.use(window.markdownItTaskLists, { enabled: true, label: true });
}

// Add KaTeX math plugin
if (window.texmath) {
    md.use(window.texmath, {
        engine: window.katex,
        delimiters: 'dollars',
        katexOptions: {
            throwOnError: false,
            displayMode: false
        }
    });
}

// Initialize Mermaid
const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
mermaid.initialize({
    startOnLoad: false,
    theme: isDark ? 'dark' : 'default',
    securityLevel: 'strict',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif'
});

// Update mermaid theme on dark mode change
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    mermaid.initialize({
        startOnLoad: false,
        theme: e.matches ? 'dark' : 'default',
        securityLevel: 'strict',
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif'
    });
});

// ---- Main render function (called from Swift) ----

async function renderMarkdown(markdownText) {
    const contentEl = document.getElementById('content');

    // 1. Parse markdown to HTML
    var html = md.render(markdownText);

    // 2. Insert into DOM
    contentEl.innerHTML = html;

    // 3. Transform mermaid code blocks into renderable divs
    var mermaidBlocks = contentEl.querySelectorAll('pre > code.language-mermaid');
    for (var i = 0; i < mermaidBlocks.length; i++) {
        var pre = mermaidBlocks[i].parentElement;
        var div = document.createElement('div');
        div.className = 'mermaid';
        div.textContent = mermaidBlocks[i].textContent;
        pre.replaceWith(div);
    }

    // 4. Render mermaid diagrams
    var mermaidDivs = contentEl.querySelectorAll('.mermaid');
    if (mermaidDivs.length > 0) {
        try {
            await mermaid.run({ nodes: mermaidDivs });
        } catch (e) {
            console.error('Mermaid render error:', e);
        }
    }

    // 5. Extract TOC and send to Swift
    extractAndSendTOC();

    // 6. Set up scroll spy
    setupScrollSpy();

    // Scroll to top for new document
    window.scrollTo(0, 0);
}

// ---- TOC extraction ----

function extractAndSendTOC() {
    var headings = document.querySelectorAll('#content h1[id], #content h2[id], #content h3[id], #content h4[id]');
    var toc = [];
    headings.forEach(function (h) {
        toc.push({
            id: h.id,
            level: parseInt(h.tagName.charAt(1)),
            text: h.textContent.trim()
        });
    });

    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tocUpdate) {
        window.webkit.messageHandlers.tocUpdate.postMessage(JSON.stringify(toc));
    }
}

// ---- Scroll spy ----

var scrollSpyObserver = null;

function setupScrollSpy() {
    if (scrollSpyObserver) {
        scrollSpyObserver.disconnect();
    }

    var headings = document.querySelectorAll('#content h1[id], #content h2[id], #content h3[id], #content h4[id]');
    if (headings.length === 0) return;

    scrollSpyObserver = new IntersectionObserver(function (entries) {
        var topHeading = null;
        var topY = Infinity;

        entries.forEach(function (entry) {
            if (entry.isIntersecting && entry.boundingClientRect.top < topY) {
                topY = entry.boundingClientRect.top;
                topHeading = entry.target;
            }
        });

        if (topHeading && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.activeHeading) {
            window.webkit.messageHandlers.activeHeading.postMessage(topHeading.id);
        }
    }, {
        rootMargin: '0px 0px -70% 0px',
        threshold: 0
    });

    headings.forEach(function (h) {
        scrollSpyObserver.observe(h);
    });
}

// ---- Scroll to heading (called from Swift) ----

function scrollToHeading(id) {
    var el = document.getElementById(id);
    if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}
