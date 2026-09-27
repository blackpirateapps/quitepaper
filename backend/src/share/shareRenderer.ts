/**
 * Security-hardened Markdown → HTML renderer for server-rendered public share
 * pages.
 *
 * Threat model: the markdown is plaintext the sharing user published, rendered to
 * anonymous visitors. To prevent stored XSS we escape ALL HTML entities up front,
 * so any raw `<script>`/tags in the source become inert text, and only THEN apply
 * a small, fixed set of Markdown transforms on the already-escaped string. Links
 * and images are only emitted when their URL is an http(s) (or protocol-relative)
 * URL — everything else (javascript:, data:, etc.) renders as plain text.
 *
 * Supported: ATX headings, ordered/unordered/nested lists, task lists (`- [ ]`),
 * blockquotes, fenced code blocks, GFM pipe tables, horizontal rules, images,
 * links, bare-URL autolinks, and inline bold/italic/strikethrough/highlight/code.
 */

export function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/** Only http(s) and protocol-relative URLs are safe to emit as an image src. */
function isSafeUrl(url: string): boolean {
  const trimmed = url.trim();
  if (/^https?:\/\//i.test(trimmed)) return true;
  if (/^\/\//.test(trimmed)) return true;
  return false;
}

/** Link hrefs additionally allow mailto: (still never javascript:/data:). */
function isSafeLinkUrl(url: string): boolean {
  if (isSafeUrl(url)) return true;
  if (/^mailto:[^\s]+@[^\s]+$/i.test(url.trim())) return true;
  return false;
}

const PLACEHOLDER = /\u0000F(\d+)\u0000/g;

/**
 * Applies inline formatting to a single line of ALREADY-ESCAPED text. Code spans,
 * links and images are first swapped out for placeholders so their contents are
 * never re-processed by the emphasis/autolink passes, then restored at the end.
 */
function renderInline(escaped: string): string {
  const frags: string[] = [];
  const stash = (html: string): string => {
    frags.push(html);
    return `\u0000F${frags.length - 1}\u0000`;
  };

  let text = escaped;

  // Inline code — protected first so nothing inside is transformed.
  text = text.replace(/`([^`]+)`/g, (_m, code) => stash(`<code>${code}</code>`));

  // Images: ![alt](url). `url` is HTML-escaped already; unescape &amp; for checks.
  text = text.replace(/!\[([^\]]*)\]\(([^)\s]+)\)/g, (full, alt, url) => {
    const rawUrl = String(url).replace(/&amp;/g, '&');
    if (!isSafeUrl(rawUrl)) return full;
    return stash(`<img src="${url}" alt="${alt}" loading="lazy">`);
  });

  // Links: [label](url).
  text = text.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (full, label, url) => {
    const rawUrl = String(url).replace(/&amp;/g, '&');
    if (!isSafeLinkUrl(rawUrl)) return full;
    return stash(`<a href="${url}" target="_blank" rel="noopener nofollow ugc">${label}</a>`);
  });

  // Bare-URL autolinks (http/https only). Trailing sentence punctuation is left
  // outside the link. Runs after explicit links so their hrefs are already stashed.
  text = text.replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, (_m, pre, url) => {
    let trailing = '';
    let clean = String(url);
    const m = clean.match(/([)\].,;:!?'"]+)$/);
    if (m) {
      trailing = m[1];
      clean = clean.slice(0, clean.length - trailing.length);
    }
    const rawUrl = clean.replace(/&amp;/g, '&');
    if (!isSafeUrl(rawUrl)) return `${pre}${url}`;
    return `${pre}${stash(`<a href="${clean}" target="_blank" rel="noopener nofollow ugc">${clean}</a>`)}${trailing}`;
  });

  // Emphasis. Bold before italic; multi-char markers before single-char ones.
  text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/__([^_]+)__/g, '<strong>$1</strong>');
  text = text.replace(/~~([^~]+)~~/g, '<del>$1</del>');
  text = text.replace(/==([^=]+)==/g, '<mark>$1</mark>');
  text = text.replace(/(^|[^*])\*([^*\s][^*]*?)\*/g, '$1<em>$2</em>');
  // Underscore italic only at word boundaries, so snake_case survives intact.
  text = text.replace(/(^|[^\w_])_([^_\s][^_]*?)_(?![\w_])/g, '$1<em>$2</em>');

  // Restore protected fragments.
  text = text.replace(PLACEHOLDER, (_m, i) => frags[Number(i)]);
  return text;
}

interface ListItem {
  indent: number;
  type: 'ul' | 'ol';
  content: string;
}

/** Renders a single list item's content, handling `- [ ]` / `- [x]` task items. */
function renderListItem(content: string): string {
  const task = content.match(/^\[([ xX])\]\s+(.*)$/);
  if (task) {
    const checked = task[1].toLowerCase() === 'x';
    return `<label class="task-item"><input type="checkbox" disabled${checked ? ' checked' : ''}>${renderInline(escapeHtml(task[2]))}</label>`;
  }
  return renderInline(escapeHtml(content));
}

/** Renders a contiguous run of list-item lines into (possibly nested) <ul>/<ol>. */
function renderList(items: ListItem[]): string {
  let html = '';
  const stack: { type: 'ul' | 'ol'; indent: number }[] = [];

  for (const it of items) {
    if (stack.length === 0) {
      stack.push({ type: it.type, indent: it.indent });
      html += `<${it.type}><li>${renderListItem(it.content)}`;
      continue;
    }
    const top = stack[stack.length - 1];
    if (it.indent > top.indent) {
      // Deeper: open a nested list inside the currently open <li>.
      stack.push({ type: it.type, indent: it.indent });
      html += `<${it.type}><li>${renderListItem(it.content)}`;
    } else if (it.indent < top.indent) {
      // Shallower: close nested lists back to this indent level.
      while (stack.length > 1 && stack[stack.length - 1].indent > it.indent) {
        html += `</li></${stack.pop()!.type}>`;
      }
      html += '</li>';
      if (stack[stack.length - 1].type !== it.type) {
        html += `</${stack.pop()!.type}>`;
        stack.push({ type: it.type, indent: it.indent });
        html += `<${it.type}>`;
      }
      html += `<li>${renderListItem(it.content)}`;
    } else {
      // Same level: close the current item, switching list type if needed.
      html += '</li>';
      if (top.type !== it.type) {
        html += `</${stack.pop()!.type}>`;
        stack.push({ type: it.type, indent: it.indent });
        html += `<${it.type}>`;
      }
      html += `<li>${renderListItem(it.content)}`;
    }
  }
  while (stack.length) {
    html += `</li></${stack.pop()!.type}>`;
  }
  return html;
}

/** Renders a GFM pipe table (header row + separator + body rows) to <table>. */
function renderTable(header: string, separator: string, rows: string[]): string {
  const splitRow = (line: string): string[] => {
    let s = line.trim();
    if (s.startsWith('|')) s = s.slice(1);
    if (s.endsWith('|')) s = s.slice(0, -1);
    return s.split('|').map(c => c.trim());
  };
  const aligns = splitRow(separator).map(spec => {
    const left = spec.startsWith(':');
    const right = spec.endsWith(':');
    if (left && right) return 'center';
    if (right) return 'right';
    if (left) return 'left';
    return '';
  });
  const cell = (tag: string, value: string, i: number): string => {
    const align = aligns[i] ? ` style="text-align:${aligns[i]}"` : '';
    return `<${tag}${align}>${renderInline(escapeHtml(value))}</${tag}>`;
  };
  const headCells = splitRow(header).map((c, i) => cell('th', c, i)).join('');
  const bodyRows = rows
    .map(r => `<tr>${splitRow(r).map((c, i) => cell('td', c, i)).join('')}</tr>`)
    .join('');
  return `<table><thead><tr>${headCells}</tr></thead><tbody>${bodyRows}</tbody></table>`;
}

const LIST_ITEM_RE = /^(\s*)([-*+]|\d+\.)\s+(.*)$/;
const TABLE_SEP_RE = /^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)+\|?\s*$/;

/**
 * Renders a Markdown document to a safe HTML fragment. All text is HTML-escaped
 * before any Markdown transform is applied (see file header).
 */
export function renderMarkdown(markdown: string): string {
  const lines = markdown.replace(/\r\n?/g, '\n').split('\n');
  const html: string[] = [];

  let paragraphBuffer: string[] = [];
  const flushParagraph = () => {
    if (paragraphBuffer.length > 0) {
      const joined = paragraphBuffer.map(l => renderInline(escapeHtml(l))).join('<br>');
      html.push(`<p>${joined}</p>`);
      paragraphBuffer = [];
    }
  };

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    // Fenced code blocks (```lang). Contents are escaped, never formatted.
    const fence = line.match(/^\s*```(.*)$/);
    if (fence) {
      flushParagraph();
      const lang = fence[1].trim().replace(/[^A-Za-z0-9+#._-]/g, '');
      const buffer: string[] = [];
      i++;
      while (i < lines.length && !/^\s*```/.test(lines[i])) {
        buffer.push(lines[i]);
        i++;
      }
      const cls = lang ? ` class="language-${lang}"` : '';
      html.push(`<pre><code${cls}>${buffer.map(escapeHtml).join('\n')}</code></pre>`);
      continue;
    }

    // Blank line: paragraph break.
    if (line.trim() === '') {
      flushParagraph();
      continue;
    }

    // Horizontal rule.
    if (/^\s*([-*_])\s*(\1\s*){2,}$/.test(line)) {
      flushParagraph();
      html.push('<hr>');
      continue;
    }

    // GFM table: a header line with a pipe followed by a separator row.
    if (line.includes('|') && i + 1 < lines.length && TABLE_SEP_RE.test(lines[i + 1])) {
      flushParagraph();
      const header = line;
      const separator = lines[i + 1];
      const rows: string[] = [];
      let j = i + 2;
      while (j < lines.length && lines[j].trim() !== '' && lines[j].includes('|')) {
        rows.push(lines[j]);
        j++;
      }
      html.push(renderTable(header, separator, rows));
      i = j - 1;
      continue;
    }

    // Headings (# .. ######).
    const heading = line.match(/^(#{1,6})\s+(.*)$/);
    if (heading) {
      flushParagraph();
      const level = heading[1].length;
      html.push(`<h${level}>${renderInline(escapeHtml(heading[2].trim()))}</h${level}>`);
      continue;
    }

    // Blockquote (consecutive `>` lines merged into one quote).
    if (/^\s*>\s?/.test(line)) {
      flushParagraph();
      const quoteLines: string[] = [];
      let j = i;
      while (j < lines.length && /^\s*>\s?/.test(lines[j])) {
        quoteLines.push(lines[j].replace(/^\s*>\s?/, ''));
        j++;
      }
      const inner = quoteLines.map(l => renderInline(escapeHtml(l))).join('<br>');
      html.push(`<blockquote>${inner}</blockquote>`);
      i = j - 1;
      continue;
    }

    // Lists (ordered/unordered/task, with nesting by indentation).
    if (LIST_ITEM_RE.test(line)) {
      flushParagraph();
      const items: ListItem[] = [];
      let j = i;
      while (j < lines.length) {
        const m = lines[j].match(LIST_ITEM_RE);
        if (!m) break;
        const indent = m[1].replace(/\t/g, '  ').length;
        const type: 'ul' | 'ol' = /^\d+\./.test(m[2]) ? 'ol' : 'ul';
        items.push({ indent, type, content: m[3] });
        j++;
      }
      html.push(renderList(items));
      i = j - 1;
      continue;
    }

    // Otherwise accumulate into the current paragraph.
    paragraphBuffer.push(line);
  }

  flushParagraph();
  return html.join('\n');
}
