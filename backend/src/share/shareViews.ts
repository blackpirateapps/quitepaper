import { escapeHtml } from './shareRenderer.js';

/**
 * Server-rendered HTML for public note share pages.
 *
 * Warm editorial theme consistent with the Quiet Paper brand / admin console.
 * All dynamic values are HTML-escaped (note body HTML is pre-sanitized by
 * shareRenderer). Pages are self-contained (inline CSS) so they render without
 * any client bundle.
 */

const BASE_STYLES = `
  :root {
    --bg: #161513;
    --card-bg: #211F1C;
    --border: #33302B;
    --border-subtle: #282622;
    --accent: #D05A3F;
    --accent-hover: #B84D35;
    --amber: #D97706;
    --red: #EF4444;
    --text-main: #F4F2ED;
    --text-muted: #A39E93;
    --text-dim: #716C62;
    --font-serif: Georgia, 'Times New Roman', serif;
    --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    --font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background-color: var(--bg);
    color: var(--text-main);
    font-family: var(--font-sans);
    line-height: 1.65;
    min-height: 100vh;
  }
  .wrap { max-width: 720px; margin: 0 auto; padding: 48px 24px 96px; }
  .brand {
    display: flex; align-items: center; gap: 10px;
    font-weight: 600; font-size: 15px; color: var(--text-muted);
    margin-bottom: 32px;
  }
  .brand-icon {
    width: 26px; height: 26px; background: var(--accent); border-radius: 6px;
    display: flex; align-items: center; justify-content: center; color: #fff; font-weight: 700;
  }
  article { font-family: var(--font-serif); font-size: 18px; }
  article h1, article h2, article h3, article h4, article h5, article h6 {
    font-family: var(--font-sans); line-height: 1.3; margin: 1.6em 0 0.6em; letter-spacing: -0.3px;
  }
  .note-title { font-family: var(--font-sans); font-size: 32px; font-weight: 700; letter-spacing: -0.6px; margin-bottom: 8px; }
  article h1 { font-size: 26px; } article h2 { font-size: 22px; } article h3 { font-size: 19px; }
  article p { margin: 0 0 1.1em; }
  article ul, article ol { margin: 0 0 1.1em 1.4em; }
  article li { margin-bottom: 0.3em; }
  article a { color: var(--accent); }
  article img { max-width: 100%; height: auto; border-radius: 8px; margin: 0.6em 0; }
  article blockquote {
    border-left: 3px solid var(--accent); padding-left: 16px; margin: 0 0 1.1em;
    color: var(--text-muted); font-style: italic;
  }
  article pre {
    background: var(--card-bg); border: 1px solid var(--border); border-radius: 8px;
    padding: 14px 16px; overflow-x: auto; margin: 0 0 1.1em;
  }
  article code { font-family: var(--font-mono); font-size: 0.85em; }
  article pre code { font-size: 0.82em; }
  article :not(pre) > code {
    background: var(--card-bg); border: 1px solid var(--border-subtle);
    padding: 1px 5px; border-radius: 4px;
  }
  article hr { border: none; border-top: 1px solid var(--border); margin: 2em 0; }
  .meta { color: var(--text-dim); font-size: 13px; margin-bottom: 40px; padding-bottom: 24px; border-bottom: 1px solid var(--border); }
  .footer { margin-top: 64px; padding-top: 24px; border-top: 1px solid var(--border); color: var(--text-dim); font-size: 12px; text-align: center; line-height: 1.6; }
  .footer a { color: var(--text-muted); }
  .center-card {
    max-width: 420px; margin: 12vh auto 0; background: var(--card-bg);
    border: 1px solid var(--border); border-radius: 12px; padding: 32px;
  }
  .center-card h1 { font-size: 20px; font-weight: 700; margin-bottom: 8px; letter-spacing: -0.3px; }
  .center-card p { color: var(--text-muted); font-size: 14px; margin-bottom: 20px; }
  label { display: block; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-muted); margin-bottom: 6px; }
  input[type="password"] {
    width: 100%; background: var(--bg); border: 1px solid var(--border); color: var(--text-main);
    padding: 11px 13px; border-radius: 8px; font-size: 15px; outline: none;
  }
  input[type="password"]:focus { border-color: var(--accent); }
  .btn {
    display: inline-flex; align-items: center; justify-content: center; width: 100%;
    padding: 11px 16px; border-radius: 8px; font-size: 14px; font-weight: 600;
    background: var(--accent); color: #fff; border: none; cursor: pointer; margin-top: 16px;
  }
  .btn:hover { background: var(--accent-hover); }
  .error-banner {
    background: rgba(239,68,68,0.12); border: 1px solid rgba(239,68,68,0.3); color: #FECACA;
    padding: 10px 14px; border-radius: 8px; font-size: 13px; margin-bottom: 18px;
  }
  .lock-icon { font-size: 30px; margin-bottom: 12px; display: block; }
`;

function layout(title: string, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(title)}</title>
  <style>${BASE_STYLES}</style>
</head>
<body>
${bodyHtml}
</body>
</html>`;
}

const BRAND_HEADER = `
  <div class="brand">
    <div class="brand-icon">Q</div>
    <span>Quiet Paper</span>
  </div>`;

function shareFooter(): string {
  return `
  <div class="footer">
    <p>Shared with <a href="/" target="_blank">Quiet Paper</a> — private, end-to-end encrypted notes.</p>
    <p>This page was published by its author. Content is not encrypted in transit to the app owner's server.</p>
  </div>`;
}

export interface RenderNoteOptions {
  title: string;
  contentHtml: string;
  createdAt?: string;
  expiresAt?: string;
}

function formatShareDate(isoStr?: string): string {
  if (!isoStr) return '';
  try {
    return new Date(isoStr).toLocaleDateString('en-US', {
      month: 'long',
      day: 'numeric',
      year: 'numeric',
    });
  } catch {
    return '';
  }
}

/** Renders the published note page (public / unlisted / unlocked password shares). */
export function renderSharePage(opts: RenderNoteOptions): string {
  const title = opts.title.trim() || 'Untitled note';
  const published = formatShareDate(opts.createdAt);
  const body = `
  <div class="wrap">
    ${BRAND_HEADER}
    <h1 class="note-title">${escapeHtml(title)}</h1>
    ${published ? `<div class="meta">Published ${escapeHtml(published)}</div>` : ''}
    <article>${opts.contentHtml}</article>
    ${shareFooter()}
  </div>`;
  return layout(title, body);
}

/** Renders the password prompt for a password-protected share. */
export function renderPasswordPage(slug: string, error?: string): string {
  const body = `
  <div class="wrap">
    <div class="center-card">
      <span class="lock-icon">🔒</span>
      <h1>Password required</h1>
      <p>This shared note is protected. Enter the password to view it.</p>
      ${error ? `<div class="error-banner">${escapeHtml(error)}</div>` : ''}
      <form method="POST" action="/note/${encodeURIComponent(slug)}">
        <label for="password">Password</label>
        <input type="password" id="password" name="password" autofocus required>
        <button type="submit" class="btn">Unlock note</button>
      </form>
    </div>
  </div>`;
  return layout('Password required — Quiet Paper', body);
}

/** Renders the not-found / expired page (used for 404 and 410 responses). */
export function renderNotFoundPage(expired: boolean = false): string {
  const heading = expired ? 'This share has expired' : 'Share not found';
  const detail = expired
    ? 'Shared notes stay available for 30 days. This link has passed its expiry date and is no longer viewable.'
    : 'This link is invalid, or the note it pointed to has been unshared or deleted.';
  const body = `
  <div class="wrap">
    <div class="center-card" style="text-align: center;">
      <span class="lock-icon">${expired ? '⏳' : '🔍'}</span>
      <h1>${escapeHtml(heading)}</h1>
      <p>${escapeHtml(detail)}</p>
      <a href="/" class="btn" style="text-decoration: none;">Learn about Quiet Paper</a>
    </div>
  </div>`;
  return layout(heading + ' — Quiet Paper', body);
}
