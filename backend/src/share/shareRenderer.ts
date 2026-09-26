/**
 * Minimal, security-hardened Markdown → HTML renderer for server-rendered public
 * share pages.
 *
 * Threat model: the markdown is plaintext the sharing user published, rendered to
 * anonymous visitors. To prevent stored XSS we escape ALL HTML entities up front,
 * so any raw `<script>`/tags in the source become inert text, and only THEN apply
 * a small, fixed set of Markdown transforms on the already-escaped string. Links
 * and images are only emitted when their URL is an http(s) (or protocol-relative)
 * URL — everything else (javascript:, data:, etc.) renders as plain text.
 */

export function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/** Only http(s) and protocol-relative URLs are considered safe to emit as href/src. */
function isSafeUrl(url: string): boolean {
  const trimmed = url.trim();
  if (/^https?:\/\//i.test(trimmed)) return true;
  if (/^\/\//.test(trimmed)) return true;
  return false;
}

/**
 * Applies inline formatting (code, bold, italic, links, images) to a single line
 * of ALREADY-ESCAPED text. Order matters: inline code is extracted first so its
 * contents are not re-processed.
 */
function renderInline(escaped: string): string {
  const codeSpans: string[] = [];
  // Protect inline code spans from further transformation.
  let text = escaped.replace(/`([^`]+)`/g, (_m, code) => {
    codeSpans.push(`<code>${code}</code>`);
    return `\u0000CODE${codeSpans.length - 1}\u0000`;
  });

  // Images: ![alt](url)
  text = text.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, (full, alt, url) => {
    // The url here is HTML-escaped already; unescape &amp; for the safety check + attribute.
    const rawUrl = url.replace(/&amp;/g, '&');
    if (!isSafeUrl(rawUrl)) return full;
    return `<img src="${url}" alt="${alt}" loading="lazy">`;
  });

  // Links: [text](url)
  text = text.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (full, label, url) => {
    const rawUrl = url.replace(/&amp;/g, '&');
    if (!isSafeUrl(rawUrl)) return full;
    return `<a href="${url}" target="_blank" rel="noopener nofollow ugc">${label}</a>`;
  });

  // Bold then italic.
  text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/(^|[^*])\*([^*]+)\*/g, '$1<em>$2</em>');

  // Restore code spans.
  text = text.replace(/\u0000CODE(\d+)\u0000/g, (_m, i) => codeSpans[Number(i)]);
  return text;
}

/**
 * Renders a Markdown document (headings, lists, blockquotes, fenced code, images,
 * links, paragraphs, horizontal rules) to a safe HTML fragment.
 */
export function renderMarkdown(markdown: string): string {
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const html: string[] = [];

  let inCodeBlock = false;
  let codeBuffer: string[] = [];
  let listType: 'ul' | 'ol' | null = null;
  let paragraphBuffer: string[] = [];

  const flushParagraph = () => {
    if (paragraphBuffer.length > 0) {
      const joined = paragraphBuffer.map(l => renderInline(escapeHtml(l))).join('<br>');
      html.push(`<p>${joined}</p>`);
      paragraphBuffer = [];
    }
  };
  const closeList = () => {
    if (listType) {
      html.push(`</${listType}>`);
      listType = null;
    }
  };

  for (const rawLine of lines) {
    const line = rawLine;

    // Fenced code blocks (```). Contents are escaped, never formatted.
    const fenceMatch = line.match(/^\s*```/);
    if (fenceMatch) {
      if (inCodeBlock) {
        html.push(`<pre><code>${codeBuffer.map(escapeHtml).join('\n')}</code></pre>`);
        codeBuffer = [];
        inCodeBlock = false;
      } else {
        flushParagraph();
        closeList();
        inCodeBlock = true;
      }
      continue;
    }
    if (inCodeBlock) {
      codeBuffer.push(line);
      continue;
    }

    // Blank line: paragraph / list break.
    if (line.trim() === '') {
      flushParagraph();
      closeList();
      continue;
    }

    // Horizontal rule.
    if (/^\s*([-*_])\s*(\1\s*){2,}$/.test(line)) {
      flushParagraph();
      closeList();
      html.push('<hr>');
      continue;
    }

    // Headings (# .. ######).
    const heading = line.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      flushParagraph();
      closeList();
      const level = heading[1].length;
      html.push(`<h${level}>${renderInline(escapeHtml(heading[2].trim()))}</h${level}>`);
      continue;
    }

    // Blockquote.
    const quote = line.match(/^\s*>\s?(.*)$/);
    if (quote) {
      flushParagraph();
      closeList();
      html.push(`<blockquote>${renderInline(escapeHtml(quote[1]))}</blockquote>`);
      continue;
    }

    // Unordered list item.
    const ulItem = line.match(/^\s*[-*+]\s+(.*)$/);
    if (ulItem) {
      flushParagraph();
      if (listType !== 'ul') {
        closeList();
        html.push('<ul>');
        listType = 'ul';
      }
      html.push(`<li>${renderInline(escapeHtml(ulItem[1]))}</li>`);
      continue;
    }

    // Ordered list item.
    const olItem = line.match(/^\s*\d+\.\s+(.*)$/);
    if (olItem) {
      flushParagraph();
      if (listType !== 'ol') {
        closeList();
        html.push('<ol>');
        listType = 'ol';
      }
      html.push(`<li>${renderInline(escapeHtml(olItem[1]))}</li>`);
      continue;
    }

    // Otherwise accumulate into the current paragraph.
    closeList();
    paragraphBuffer.push(line);
  }

  // Flush any trailing state.
  if (inCodeBlock) {
    html.push(`<pre><code>${codeBuffer.map(escapeHtml).join('\n')}</code></pre>`);
  }
  flushParagraph();
  closeList();

  return html.join('\n');
}
