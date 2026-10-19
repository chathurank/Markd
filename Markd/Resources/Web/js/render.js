// Initialize markdown-it with plugins
const md = window.markdownit({
    html: true,
    linkify: true,
    typographer: true,
    highlight: function (str, lang) {
        // Skip mermaid blocks — let markdown-it preserve the language-mermaid class
        if (lang === 'mermaid') return '';
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
if (window.markdownitTaskLists) {
    md.use(window.markdownitTaskLists, { enabled: true, label: true });
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

// Hide YAML front matter (--- block at the top of the file)
if (window.markdownItFrontMatter) {
    md.use(window.markdownItFrontMatter, function () {});
}

// Heading attributes: "## Title {#custom-id .some-class}" (as in Pandoc and kramdown).
// Only #id and .class are recognised, and only on headings, so text like
// "GET /users/{id}" is left alone. Runs before the anchor plugin, which keeps an id that's set.
md.core.ruler.after('text_join', 'heading_attributes', function (state) {
    var tokens = state.tokens;
    for (var i = 0; i < tokens.length - 1; i++) {
        if (tokens[i].type !== 'heading_open') continue;
        var children = tokens[i + 1].children;
        var last = children && children[children.length - 1];
        if (!last || last.type !== 'text') continue;
        var match = last.content.match(/\s*\{\s*((?:[#.][\w-]+\s*)+)\}\s*$/);
        if (!match) continue;
        last.content = last.content.slice(0, match.index);
        match[1].trim().split(/\s+/).forEach(function (attr) {
            if (attr.charAt(0) === '#') tokens[i].attrSet('id', attr.slice(1));
            else tokens[i].attrJoin('class', attr.slice(1));
        });
    }
});

// Footnotes, numbered 1, 2, 3 instead of [1], [2], [3]
if (window.markdownitFootnote) {
    md.use(window.markdownitFootnote);
    md.renderer.rules.footnote_caption = function (tokens, idx) {
        var n = String(tokens[idx].meta.id + 1);
        if (tokens[idx].meta.subId > 0) n += ':' + tokens[idx].meta.subId;
        return n;
    };
}

// Definition lists, subscript (H~2~O) and superscript (x^2^)
if (window.markdownitDeflist) md.use(window.markdownitDeflist);
if (window.markdownitSub) md.use(window.markdownitSub);
if (window.markdownitSup) md.use(window.markdownitSup);

// GitHub alerts: > [!NOTE], [!TIP], [!IMPORTANT], [!WARNING], [!CAUTION]
if (window.markdownItGitHubAlerts) {
    md.use(window.markdownItGitHubAlerts);
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

    // 2. Sanitize and insert into DOM (DOMPurify strips dangerous tags/attributes)
    var clean = DOMPurify.sanitize(html, {
        ADD_TAGS: ['semantics', 'annotation'],
        ADD_ATTR: ['target', 'encoding'],
        FORBID_TAGS: ['style'],
        ALLOW_DATA_ATTR: true
    });
    contentEl.innerHTML = clean;

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

    // 5. Wrap mermaid diagrams in expandable containers with zoom/pan
    wrapMermaidDiagrams();

    // 6. Wrap tables in expandable containers
    wrapTables();

    // 7. Extract TOC and send to Swift
    extractAndSendTOC();

    // 8. Set up scroll spy
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

// ---- Expandable containers ----

function wrapMermaidDiagrams() {
    var diagrams = document.querySelectorAll('#content .mermaid');
    diagrams.forEach(function (diagram) {
        if (diagram.closest('.expandable-container')) return;

        // Keep the SVG at its natural size; fitting is handled by the zoom scale.
        var svg = diagram.querySelector('svg');
        var viewBox = svg && svg.viewBox.baseVal;
        if (viewBox && viewBox.width > 0 && viewBox.height > 0) {
            svg.setAttribute('width', viewBox.width);
            svg.setAttribute('height', viewBox.height);
            svg.style.width = viewBox.width + 'px';
            svg.style.height = viewBox.height + 'px';
            svg.style.maxWidth = 'none';
        }

        var container = document.createElement('div');
        container.className = 'expandable-container';

        // Toolbar with zoom controls + fullview
        var toolbar = document.createElement('div');
        toolbar.className = 'expandable-toolbar';
        toolbar.innerHTML =
            '<button class="zoom-out-btn" title="Zoom out">−</button>' +
            '<span class="zoom-label">100%</span>' +
            '<button class="zoom-in-btn" title="Zoom in">+</button>' +
            '<button class="zoom-reset-btn" title="Reset zoom">↺</button>' +
            '<button class="fullview-btn" title="Full view">⛶</button>';

        // Viewport for pan/zoom
        var viewport = document.createElement('div');
        viewport.className = 'mermaid-viewport';
        var inner = document.createElement('div');
        inner.className = 'mermaid-inner';

        diagram.parentNode.insertBefore(container, diagram);
        inner.appendChild(diagram);
        viewport.appendChild(inner);
        container.appendChild(toolbar);
        container.appendChild(viewport);

        setupDiagramZoomPan(container, viewport, inner);
    });
}

function wrapTables() {
    var tables = document.querySelectorAll('#content > table');
    tables.forEach(function (table) {
        if (table.parentElement.classList.contains('table-wrapper')) return;

        var wrapper = document.createElement('div');
        wrapper.className = 'table-wrapper';

        var btn = document.createElement('button');
        btn.className = 'table-expand-btn';
        btn.title = 'Full view';
        btn.textContent = '⛶';

        table.parentNode.insertBefore(wrapper, table);
        wrapper.appendChild(btn);
        wrapper.appendChild(table);

        btn.addEventListener('click', function () {
            openFullView(table.cloneNode(true), false);
        });
    });
}

// ---- Diagram zoom/pan ----

function setupDiagramZoomPan(container, viewport, inner) {
    var svg = inner.querySelector('svg');
    var naturalWidth = svg ? svg.getBoundingClientRect().width : inner.offsetWidth;
    var naturalHeight = svg ? svg.getBoundingClientRect().height : inner.offsetHeight;
    inner.style.width = naturalWidth + 'px';

    function getFitScale() {
        return naturalWidth > 0 && viewport.clientWidth > 0 ? Math.min(1, viewport.clientWidth / naturalWidth) : 1;
    }

    var fitScale = getFitScale();
    var scale = fitScale;
    var panX = 0;
    var panY = 0;
    var isPanning = false;
    var startX, startY, startPanX, startPanY;
    var label = container.querySelector('.zoom-label');

    function applyTransform(smooth) {
        var offsetX = Math.max(0, (viewport.clientWidth - naturalWidth * scale) / 2);
        inner.style.transition = smooth ? 'transform 0.15s ease-out' : 'none';
        inner.style.transform = 'translate(' + (offsetX + panX) + 'px,' + panY + 'px) scale(' + scale + ')';
        // Transforms do not change layout, so reserve only the scaled height.
        viewport.style.height = naturalHeight * scale + 'px';
        label.textContent = Math.round(scale * 100) + '%';
    }

    container.querySelector('.zoom-in-btn').addEventListener('click', function () {
        scale = Math.min(scale * 1.25, 5);
        applyTransform(true);
    });

    container.querySelector('.zoom-out-btn').addEventListener('click', function () {
        scale = Math.max(scale / 1.25, Math.min(0.2, fitScale));
        applyTransform(true);
    });

    container.querySelector('.zoom-reset-btn').addEventListener('click', function () {
        fitScale = getFitScale();
        scale = fitScale; panX = 0; panY = 0;
        applyTransform(true);
    });

    container.querySelector('.fullview-btn').addEventListener('click', function () {
        openFullView(inner.cloneNode(true), true);
    });

    // Mouse wheel zoom
    viewport.addEventListener('wheel', function (e) {
        e.preventDefault();
        var factor = e.deltaY < 0 ? 1.1 : 0.9;
        scale = Math.max(Math.min(0.2, fitScale), Math.min(5, scale * factor));
        applyTransform(false);
    }, { passive: false });

    // Pan with mouse drag
    viewport.addEventListener('mousedown', function (e) {
        isPanning = true;
        startX = e.clientX;
        startY = e.clientY;
        startPanX = panX;
        startPanY = panY;
        e.preventDefault();
    });

    document.addEventListener('mousemove', function (e) {
        if (!isPanning) return;
        panX = startPanX + (e.clientX - startX);
        panY = startPanY + (e.clientY - startY);
        applyTransform(false);
    });

    document.addEventListener('mouseup', function () {
        isPanning = false;
    });

    applyTransform(false);
}

// ---- Full-view overlay ----

function openFullView(contentNode, isDiagram) {
    // Remove any existing overlay
    var existing = document.querySelector('.fullview-overlay');
    if (existing) existing.remove();

    var overlay = document.createElement('div');
    overlay.className = 'fullview-overlay';

    var toolbar = document.createElement('div');
    toolbar.className = 'fullview-toolbar';

    if (isDiagram) {
        toolbar.innerHTML =
            '<button class="zoom-out-btn" title="Zoom out">−</button>' +
            '<span class="zoom-label" style="font-size:11px;color:var(--text-secondary);min-width:36px;text-align:center">100%</span>' +
            '<button class="zoom-in-btn" title="Zoom in">+</button>' +
            '<button class="zoom-reset-btn" title="Reset zoom">↺</button>' +
            '<span style="flex:1"></span>' +
            '<button class="close-btn">✕ Close</button>';
    } else {
        toolbar.innerHTML =
            '<span style="flex:1"></span>' +
            '<button class="close-btn">✕ Close</button>';
    }

    var body = document.createElement('div');
    body.className = 'fullview-body' + (isDiagram ? ' is-diagram' : '');

    var inner = document.createElement('div');
    inner.className = 'fullview-inner';
    if (isDiagram) {
        // The overlay owns its transform, independent of the page zoom and pan.
        contentNode.style.transform = 'none';
        contentNode.style.transition = 'none';
    }
    inner.appendChild(contentNode);
    body.appendChild(inner);

    overlay.appendChild(toolbar);
    overlay.appendChild(body);
    document.body.appendChild(overlay);

    // Animate in
    requestAnimationFrame(function () {
        overlay.classList.add('visible');
    });

    // Close handler
    function closeOverlay() {
        overlay.classList.remove('visible');
        setTimeout(function () { overlay.remove(); }, 200);
    }

    toolbar.querySelector('.close-btn').addEventListener('click', closeOverlay);

    // Escape key to close
    function onKeyDown(e) {
        if (e.key === 'Escape') {
            closeOverlay();
            document.removeEventListener('keydown', onKeyDown);
        }
    }
    document.addEventListener('keydown', onKeyDown);

    // Diagram zoom/pan in fullview
    if (isDiagram) {
        var fvSVG = contentNode.querySelector('svg');
        var fvNaturalWidth = fvSVG ? fvSVG.getBoundingClientRect().width : contentNode.offsetWidth;
        var fvNaturalHeight = fvSVG ? fvSVG.getBoundingClientRect().height : contentNode.offsetHeight;
        inner.style.width = fvNaturalWidth + 'px';
        var fvStyle = window.getComputedStyle(body);
        var fvWidth, fvHeight, fvFitScale;

        function fvGetFitScale() {
            fvWidth = body.clientWidth - parseFloat(fvStyle.paddingLeft) - parseFloat(fvStyle.paddingRight);
            fvHeight = body.clientHeight - parseFloat(fvStyle.paddingTop) - parseFloat(fvStyle.paddingBottom);
            return fvNaturalWidth > 0 && fvNaturalHeight > 0 && fvWidth > 0 && fvHeight > 0 ?
                Math.min(1, fvWidth / fvNaturalWidth, fvHeight / fvNaturalHeight) : 1;
        }

        fvFitScale = fvGetFitScale();
        var fvScale = fvFitScale, fvPanX = 0, fvPanY = 0;
        var fvIsPanning = false, fvStartX, fvStartY, fvStartPanX, fvStartPanY;
        var fvLabel = toolbar.querySelector('.zoom-label');

        function fvApply(smooth) {
            var fvOffsetX = Math.max(0, (fvWidth - fvNaturalWidth * fvScale) / 2);
            inner.style.transition = smooth ? 'transform 0.15s ease-out' : 'none';
            inner.style.transform = 'translate(' + (fvOffsetX + fvPanX) + 'px,' + fvPanY + 'px) scale(' + fvScale + ')';
            fvLabel.textContent = Math.round(fvScale * 100) + '%';
        }

        toolbar.querySelector('.zoom-in-btn').addEventListener('click', function () {
            fvScale = Math.min(fvScale * 1.25, 5); fvApply(true);
        });
        toolbar.querySelector('.zoom-out-btn').addEventListener('click', function () {
            fvScale = Math.max(fvScale / 1.25, Math.min(0.2, fvFitScale)); fvApply(true);
        });
        toolbar.querySelector('.zoom-reset-btn').addEventListener('click', function () {
            fvFitScale = fvGetFitScale();
            fvScale = fvFitScale; fvPanX = 0; fvPanY = 0; fvApply(true);
        });

        body.addEventListener('wheel', function (e) {
            e.preventDefault();
            var factor = e.deltaY < 0 ? 1.1 : 0.9;
            fvScale = Math.max(Math.min(0.2, fvFitScale), Math.min(5, fvScale * factor));
            fvApply(false);
        }, { passive: false });

        body.addEventListener('mousedown', function (e) {
            fvIsPanning = true;
            fvStartX = e.clientX; fvStartY = e.clientY;
            fvStartPanX = fvPanX; fvStartPanY = fvPanY;
            e.preventDefault();
        });
        document.addEventListener('mousemove', function handler(e) {
            if (!fvIsPanning) return;
            fvPanX = fvStartPanX + (e.clientX - fvStartX);
            fvPanY = fvStartPanY + (e.clientY - fvStartY);
            fvApply(false);
        });
        document.addEventListener('mouseup', function () {
            fvIsPanning = false;
        });

        fvApply(false);
    }
}

// ---- Find bar ----

var findBarVisible = false;
var findHighlights = [];
var findCurrentIndex = -1;

function showFindBar() {
    if (findBarVisible) {
        // Focus the input if already visible
        var input = document.getElementById('markd-find-input');
        if (input) { input.focus(); input.select(); }
        return;
    }
    findBarVisible = true;

    var bar = document.createElement('div');
    bar.id = 'markd-find-bar';
    bar.innerHTML =
        '<input id="markd-find-input" type="text" placeholder="Find…" autocomplete="off" spellcheck="false">' +
        '<span id="markd-find-count"></span>' +
        '<button id="markd-find-prev" title="Previous">▲</button>' +
        '<button id="markd-find-next" title="Next">▼</button>' +
        '<button id="markd-find-close" title="Close">✕</button>';
    document.body.appendChild(bar);

    var input = document.getElementById('markd-find-input');
    var countEl = document.getElementById('markd-find-count');

    var findDebounceTimer = null;
    input.addEventListener('input', function () {
        clearTimeout(findDebounceTimer);
        findDebounceTimer = setTimeout(function () {
            performFind(input.value, countEl);
        }, 150);
    });

    input.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') {
            if (e.shiftKey) findPrev(countEl);
            else findNext(countEl);
        }
        if (e.key === 'Escape') closeFindBar();
    });

    document.getElementById('markd-find-next').addEventListener('click', function () { findNext(countEl); });
    document.getElementById('markd-find-prev').addEventListener('click', function () { findPrev(countEl); });
    document.getElementById('markd-find-close').addEventListener('click', closeFindBar);

    input.focus();
}

function closeFindBar() {
    findBarVisible = false;
    var bar = document.getElementById('markd-find-bar');
    if (bar) bar.remove();
    clearHighlights();
}

function clearHighlights() {
    findHighlights.forEach(function (el) {
        var parent = el.parentNode;
        parent.replaceChild(document.createTextNode(el.textContent), el);
        parent.normalize();
    });
    findHighlights = [];
    findCurrentIndex = -1;
}

function performFind(query, countEl) {
    clearHighlights();
    if (!query) { countEl.textContent = ''; return; }

    var content = document.getElementById('content');
    var walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null);
    var textNodes = [];
    while (walker.nextNode()) textNodes.push(walker.currentNode);

    var lowerQuery = query.toLowerCase();
    textNodes.forEach(function (node) {
        var text = node.textContent;
        var lowerText = text.toLowerCase();
        var idx = lowerText.indexOf(lowerQuery);
        if (idx === -1) return;

        var frag = document.createDocumentFragment();
        var lastIdx = 0;
        while (idx !== -1) {
            frag.appendChild(document.createTextNode(text.substring(lastIdx, idx)));
            var mark = document.createElement('mark');
            mark.className = 'markd-find-highlight';
            mark.textContent = text.substring(idx, idx + query.length);
            frag.appendChild(mark);
            findHighlights.push(mark);
            lastIdx = idx + query.length;
            idx = lowerText.indexOf(lowerQuery, lastIdx);
        }
        frag.appendChild(document.createTextNode(text.substring(lastIdx)));
        node.parentNode.replaceChild(frag, node);
    });

    countEl.textContent = findHighlights.length + ' found';
    if (findHighlights.length > 0) {
        findCurrentIndex = 0;
        highlightCurrent(countEl);
    }
}

function findNext(countEl) {
    if (findHighlights.length === 0) return;
    findCurrentIndex = (findCurrentIndex + 1) % findHighlights.length;
    highlightCurrent(countEl);
}

function findPrev(countEl) {
    if (findHighlights.length === 0) return;
    findCurrentIndex = (findCurrentIndex - 1 + findHighlights.length) % findHighlights.length;
    highlightCurrent(countEl);
}

function highlightCurrent(countEl) {
    findHighlights.forEach(function (el, i) {
        el.classList.toggle('markd-find-active', i === findCurrentIndex);
    });
    if (findHighlights[findCurrentIndex]) {
        findHighlights[findCurrentIndex].scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    countEl.textContent = (findCurrentIndex + 1) + ' of ' + findHighlights.length;
}
