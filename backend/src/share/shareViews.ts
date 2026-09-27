import { escapeHtml } from './shareRenderer.js';

/**
 * Server-rendered HTML for public note share pages.
 *
 * Warm editorial "document reader" theme with light + dark support (defaults to
 * the visitor's OS preference, with a persisted manual toggle). Pages are
 * server-rendered and self-contained (inline CSS, self-hosted fonts, only a
 * small progressive-enhancement script). All dynamic values are HTML-escaped;
 * the note body HTML is pre-sanitized by shareRenderer.
 */

/** Public site origin, used for canonical + Open Graph URLs. */
const SITE = (process.env.PUBLIC_SHARE_BASE_URL || 'https://quietpaper.blackpiratex.com').replace(/\/+$/, '');

/** Self-hosted fonts served from /fonts/** (see vercel.json cache headers). */
const FONT_FACES = `
  @font-face { font-family:'Lora'; src:url('/fonts/Lora/Lora-Regular.ttf') format('truetype'); font-weight:400; font-style:normal; font-display:swap; }
  @font-face { font-family:'Lora'; src:url('/fonts/Lora/Lora-Bold.ttf') format('truetype'); font-weight:700; font-style:normal; font-display:swap; }
  @font-face { font-family:'Lora'; src:url('/fonts/Lora/Lora-Italic.ttf') format('truetype'); font-weight:400; font-style:italic; font-display:swap; }
  @font-face { font-family:'Inter'; src:url('/fonts/Inter/Inter-Regular.ttf') format('truetype'); font-weight:400; font-style:normal; font-display:swap; }
  @font-face { font-family:'Inter'; src:url('/fonts/Inter/Inter-Bold.ttf') format('truetype'); font-weight:700; font-style:normal; font-display:swap; }
  @font-face { font-family:'Inter'; src:url('/fonts/Inter/Inter-Italic.ttf') format('truetype'); font-weight:400; font-style:italic; font-display:swap; }
  @font-face { font-family:'iA Writer Quattro'; src:url('/fonts/iAWriterQuattro/iAWriterQuattro-Regular.ttf') format('truetype'); font-weight:400; font-style:normal; font-display:swap; }
  @font-face { font-family:'iA Writer Quattro'; src:url('/fonts/iAWriterQuattro/iAWriterQuattro-Bold.ttf') format('truetype'); font-weight:700; font-style:normal; font-display:swap; }
`;

const BASE_STYLES = `
  :root {
    --bg:#F7F6F2; --surface:#FFFFFF; --surface-2:#F0EEE7; --border:#E4E1D8;
    --border-strong:#D6D2C6; --text:#24221E; --text-muted:#6B665C; --text-dim:#948F83;
    --accent:#C2532F; --accent-soft:rgba(194,83,47,0.10); --amber:#B45309;
    --code-str:#4C8C4A; --code-fn:#7A6BC4;
    --shadow:0 1px 2px rgba(0,0,0,0.04), 0 8px 24px rgba(0,0,0,0.05);
    --font-serif:'Lora', Georgia, 'Times New Roman', serif;
    --font-sans:'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    --font-mono:'iA Writer Quattro', ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }
  @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
    --bg:#1D1C1A; --surface:#26241F; --surface-2:#221F1B; --border:#37342E;
    --border-strong:#47433B; --text:#F1EFE9; --text-muted:#A6A093; --text-dim:#746F64;
    --accent:#E07856; --accent-soft:rgba(224,120,86,0.14); --amber:#E0A458;
    --code-str:#83C583; --code-fn:#A99BE8; color-scheme:dark;
    --shadow:0 1px 2px rgba(0,0,0,0.3), 0 10px 30px rgba(0,0,0,0.35);
  } }
  :root[data-theme="dark"] {
    --bg:#1D1C1A; --surface:#26241F; --surface-2:#221F1B; --border:#37342E;
    --border-strong:#47433B; --text:#F1EFE9; --text-muted:#A6A093; --text-dim:#746F64;
    --accent:#E07856; --accent-soft:rgba(224,120,86,0.14); --amber:#E0A458;
    --code-str:#83C583; --code-fn:#A99BE8; color-scheme:dark;
    --shadow:0 1px 2px rgba(0,0,0,0.3), 0 10px 30px rgba(0,0,0,0.35);
  }
  * { box-sizing:border-box; margin:0; padding:0; }
  html { scroll-behavior:smooth; }
  body { background:var(--bg); color:var(--text); font-family:var(--font-sans);
    line-height:1.7; -webkit-font-smoothing:antialiased; min-height:100vh;
    transition:background 0.25s ease, color 0.25s ease; }
  #progress { position:fixed; top:0; left:0; height:3px; width:0; background:var(--accent); z-index:60; transition:width 0.1s linear; }
  .topbar { position:sticky; top:0; z-index:50; backdrop-filter:saturate(180%) blur(12px);
    background:color-mix(in srgb, var(--bg) 82%, transparent); border-bottom:1px solid var(--border);
    display:flex; align-items:center; justify-content:space-between; padding:12px max(24px, calc((100% - 1080px) / 2)); }
  .brand { display:flex; align-items:center; gap:9px; font-weight:600; font-size:14px; color:var(--text); text-decoration:none; }
  .brand-mark { width:24px; height:24px; border-radius:6px; background:var(--accent); color:#fff; font-weight:700; display:grid; place-items:center; font-size:14px; }
  .icon-btn { width:34px; height:34px; display:grid; place-items:center; border-radius:8px; border:1px solid var(--border); background:var(--surface); color:var(--text-muted); cursor:pointer; }
  .icon-btn:hover { color:var(--accent); border-color:var(--accent); }
`;

const READER_STYLES = `
  .layout { max-width:1080px; margin:0 auto; padding:40px 24px 80px; display:grid;
    grid-template-columns:220px minmax(0, 720px); gap:48px; justify-content:center; }
  .layout.no-toc { grid-template-columns:minmax(0, 720px); }
  .toc { position:sticky; top:88px; align-self:start; font-size:13px; max-height:calc(100vh - 120px); overflow-y:auto; }
  .toc-title { text-transform:uppercase; letter-spacing:0.7px; font-size:11px; font-weight:600; color:var(--text-dim); margin-bottom:12px; }
  .toc a { display:block; color:var(--text-muted); text-decoration:none; padding:4px 0 4px 12px; border-left:2px solid var(--border); line-height:1.4; transition:color 0.15s, border-color 0.15s; }
  .toc a.sub { padding-left:24px; font-size:12px; }
  .toc a:hover { color:var(--text); }
  .toc a.active { color:var(--accent); border-left-color:var(--accent); font-weight:500; }
  .reader { min-width:0; }
  .note-title { font-family:var(--font-sans); font-size:38px; line-height:1.15; font-weight:700; letter-spacing:-0.8px; margin-bottom:16px; }
  .meta-row { display:flex; flex-wrap:wrap; align-items:center; gap:8px 14px; color:var(--text-dim); font-size:13px; padding-bottom:20px; margin-bottom:32px; border-bottom:1px solid var(--border); }
  .meta-row .dot { width:3px; height:3px; border-radius:50%; background:var(--text-dim); }
  .meta-row .expiry { color:var(--amber); }
  .actions { display:flex; gap:8px; margin-left:auto; }
  .pill { display:inline-flex; align-items:center; gap:6px; font:inherit; font-family:var(--font-sans); font-size:12px; font-weight:500; color:var(--text-muted); background:var(--surface); border:1px solid var(--border); padding:6px 11px; border-radius:999px; cursor:pointer; transition:color 0.15s, border-color 0.15s; }
  .pill:hover, .pill.done { color:var(--accent); border-color:var(--accent); }
  article { font-family:var(--font-serif); font-size:19px; }
  article > *:first-child { margin-top:0; }
  article h1, article h2, article h3, article h4 { font-family:var(--font-sans); line-height:1.25; letter-spacing:-0.4px; scroll-margin-top:90px; position:relative; }
  article h1 { font-size:28px; margin:1.7em 0 0.5em; font-weight:700; }
  article h2 { font-size:24px; margin:1.6em 0 0.5em; font-weight:700; }
  article h3 { font-size:20px; margin:1.5em 0 0.4em; font-weight:600; }
  article h4 { font-size:17px; margin:1.4em 0 0.3em; font-weight:600; }
  article p { margin:0 0 1.15em; }
  article a { color:var(--accent); text-underline-offset:3px; text-decoration-thickness:1px; }
  article ul, article ol { margin:0 0 1.15em 1.3em; }
  article li { margin-bottom:0.35em; }
  .anchor { position:absolute; left:-1.1em; opacity:0; text-decoration:none; color:var(--text-dim); font-family:var(--font-sans); cursor:pointer; }
  article h1:hover .anchor, article h2:hover .anchor, article h3:hover .anchor { opacity:1; }
  article blockquote { border-left:3px solid var(--accent); padding:2px 0 2px 20px; margin:0 0 1.15em; color:var(--text-muted); font-style:italic; }
  article pre { background:var(--surface); border:1px solid var(--border); border-radius:12px; padding:18px 20px; overflow-x:auto; margin:0 0 1.4em; font-size:14px; line-height:1.6; box-shadow:var(--shadow); }
  article pre code { font-family:var(--font-mono); font-size:1em; }
  article :not(pre) > code { font-family:var(--font-mono); font-size:0.85em; background:var(--surface-2); border:1px solid var(--border); padding:1px 6px; border-radius:5px; }
  .tok-key { color:var(--accent); } .tok-str { color:var(--code-str); } .tok-com { color:var(--text-dim); font-style:italic; }
  .tok-fn { color:var(--code-fn); } .tok-num { color:var(--amber); }
  article table { width:100%; border-collapse:collapse; margin:0 0 1.4em; font-family:var(--font-sans); font-size:15px; }
  article th, article td { border:1px solid var(--border); padding:9px 13px; text-align:left; }
  article th { background:var(--surface-2); font-weight:600; }
  article hr { border:none; border-top:1px solid var(--border); margin:2.2em 0; }
  article del { color:var(--text-dim); }
  article mark { background:var(--accent-soft); color:var(--text); padding:0 3px; border-radius:3px; }
  article .task-item { display:flex; align-items:flex-start; gap:9px; list-style:none; }
  article .task-item input { margin-top:0.5em; accent-color:var(--accent); }
  article img { max-width:100%; height:auto; border-radius:12px; border:1px solid var(--border); cursor:zoom-in; margin:0.4em 0; }
  .lightbox { position:fixed; inset:0; z-index:80; background:rgba(0,0,0,0.85); display:none; align-items:center; justify-content:center; padding:32px; cursor:zoom-out; }
  .lightbox.open { display:flex; }
  .lightbox img { max-width:100%; max-height:100%; border-radius:8px; border:none; }
`;

const CHROME_STYLES = `
  .cta { margin-top:56px; background:var(--surface); border:1px solid var(--border); border-radius:16px; padding:28px; display:flex; align-items:center; gap:20px; box-shadow:var(--shadow); }
  .cta .mark { width:44px; height:44px; border-radius:11px; background:var(--accent); color:#fff; font-weight:700; font-size:22px; display:grid; place-items:center; flex-shrink:0; }
  .cta h3 { font-family:var(--font-sans); font-size:17px; margin-bottom:3px; }
  .cta p { font-family:var(--font-sans); font-size:13.5px; color:var(--text-muted); }
  .cta .btn { margin-left:auto; }
  .btn { display:inline-flex; align-items:center; justify-content:center; gap:8px; font:inherit; font-family:var(--font-sans); font-size:14px; font-weight:600; background:var(--accent); color:#fff; border:none; padding:11px 18px; border-radius:10px; cursor:pointer; text-decoration:none; white-space:nowrap; }
  .btn:hover { filter:brightness(1.06); }
  .about { margin-top:28px; font-family:var(--font-sans); font-size:12.5px; color:var(--text-dim); background:var(--surface-2); border:1px solid var(--border); border-radius:10px; padding:12px 16px; line-height:1.55; }
  .about strong { color:var(--text-muted); font-weight:600; }
  .footer { margin-top:40px; text-align:center; font-family:var(--font-sans); font-size:12px; color:var(--text-dim); }
  .footer a { color:var(--text-muted); }
  .center { min-height:calc(100vh - 58px); display:grid; place-items:center; padding:24px; }
  .card { width:100%; max-width:400px; background:var(--surface); border:1px solid var(--border); border-radius:16px; padding:34px; text-align:center; box-shadow:var(--shadow); }
  .card .glyph { width:52px; height:52px; border-radius:13px; background:var(--accent-soft); color:var(--accent); display:grid; place-items:center; margin:0 auto 16px; }
  .card h1 { font-family:var(--font-sans); font-size:21px; margin-bottom:8px; letter-spacing:-0.3px; }
  .card p { font-family:var(--font-sans); font-size:14px; color:var(--text-muted); margin-bottom:22px; }
  .card form { text-align:left; }
  .card label { display:block; font-family:var(--font-sans); font-size:11px; font-weight:600; text-transform:uppercase; letter-spacing:0.5px; color:var(--text-muted); margin-bottom:7px; }
  .card input { width:100%; background:var(--bg); border:1px solid var(--border-strong); color:var(--text); font:inherit; padding:11px 13px; border-radius:9px; outline:none; }
  .card input:focus { border-color:var(--accent); }
  .card .btn { width:100%; margin-top:16px; }
  .err { background:var(--accent-soft); border:1px solid var(--accent); color:var(--accent); font-family:var(--font-sans); font-size:13px; padding:9px 13px; border-radius:9px; margin-bottom:16px; text-align:left; }
  @media (max-width:860px) {
    .layout { grid-template-columns:minmax(0, 1fr); gap:0; padding:28px 20px 64px; }
    .toc { display:none; }
    .note-title { font-size:30px; }
    article { font-size:18px; }
    .cta { flex-direction:column; text-align:center; } .cta .btn { margin:4px 0 0; }
  }
`;

const STYLES = BASE_STYLES + READER_STYLES + CHROME_STYLES;

/** Runs before first paint to apply the saved theme and avoid a flash. */
const THEME_INIT = `<script>try{var t=localStorage.getItem('qp-theme');if(t)document.documentElement.setAttribute('data-theme',t);}catch(e){}</script>`;

const THEME_TOGGLE = `
  <button class="icon-btn" id="theme-toggle" aria-label="Toggle light or dark theme" title="Toggle theme">
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"></circle><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"></path></svg>
  </button>`;

function topbar(): string {
  return `
  <header class="topbar">
    <a class="brand" href="${SITE}" target="_blank" rel="noopener"><span class="brand-mark">Q</span> Quiet Paper</a>
    <div class="topbar-actions">${THEME_TOGGLE}</div>
  </header>`;
}

interface LayoutOptions {
  title: string;
  description?: string;
  canonical?: string;
  body: string;
  script?: string;
}

function layout(opts: LayoutOptions): string {
  const title = escapeHtml(opts.title);
  const desc = escapeHtml(opts.description || 'A shared note from Quiet Paper — private, offline-first notes.');
  const canonicalTag = opts.canonical ? `\n  <link rel="canonical" href="${escapeHtml(opts.canonical)}">` : '';
  const ogUrlTag = opts.canonical ? `\n  <meta property="og:url" content="${escapeHtml(opts.canonical)}">` : '';
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <meta name="description" content="${desc}">${canonicalTag}
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="Quiet Paper">
  <meta property="og:title" content="${title}">
  <meta property="og:description" content="${desc}">
  <meta property="og:image" content="${SITE}/images/share-card.png">${ogUrlTag}
  <meta name="twitter:card" content="summary_large_image">
  <meta name="theme-color" content="#F7F6F2" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#1D1C1A" media="(prefers-color-scheme: dark)">
  <style>${FONT_FACES}${STYLES}</style>
  ${THEME_INIT}
</head>
<body>
${opts.body}${opts.script || ''}
</body>
</html>`;
}

const THEME_SCRIPT = `
  var root=document.documentElement;
  function themeNow(){ return root.getAttribute('data-theme') || (window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches ? 'dark':'light'); }
  var tt=document.getElementById('theme-toggle');
  if(tt) tt.addEventListener('click', function(){ var n=themeNow()==='dark'?'light':'dark'; root.setAttribute('data-theme',n); try{localStorage.setItem('qp-theme',n);}catch(e){} });`;

/** Progressive-enhancement script for the reader page (theme, TOC, copy, media). */
const READER_SCRIPT = `<script>(function(){${THEME_SCRIPT}
  var bar=document.getElementById('progress');
  function onScroll(){ var h=document.documentElement.scrollHeight-window.innerHeight; if(bar) bar.style.width=(h>0?(window.scrollY/h)*100:0)+'%'; }
  window.addEventListener('scroll',onScroll,{passive:true}); onScroll();
  var links=[].slice.call(document.querySelectorAll('.toc a'));
  var heads=links.map(function(a){return document.querySelector(a.getAttribute('href'));});
  if('IntersectionObserver' in window && heads[0]){
    var io=new IntersectionObserver(function(es){es.forEach(function(en){ if(!en.isIntersecting)return; links.forEach(function(l){ l.classList.toggle('active', l.getAttribute('href')==='#'+en.target.id); }); });},{rootMargin:'-80px 0px -70% 0px'});
    heads.forEach(function(h){ if(h) io.observe(h); });
  }
  var lb=document.getElementById('lightbox'), lbImg=lb?lb.querySelector('img'):null;
  document.querySelectorAll('#note-body img').forEach(function(img){ img.addEventListener('click',function(){ if(!lb)return; lbImg.src=img.src; lb.classList.add('open'); }); });
  if(lb) lb.addEventListener('click',function(){ lb.classList.remove('open'); });
  function flash(el,txt){ var s=el.querySelector('span'), o=s?s.textContent:''; if(s)s.textContent=txt; el.classList.add('done'); setTimeout(function(){ if(s)s.textContent=o; el.classList.remove('done'); },1600); }
  document.querySelectorAll('.pill[data-copy]').forEach(function(btn){ btn.addEventListener('click',function(){ var kind=btn.getAttribute('data-copy'); var body=document.getElementById('note-body'); var text=kind==='link'?location.href:((body&&body.innerText)||'').trim(); (navigator.clipboard?navigator.clipboard.writeText(text):Promise.reject()).then(function(){flash(btn,'Copied');},function(){flash(btn,'Failed');}); }); });
  document.querySelectorAll('.anchor').forEach(function(a){ a.addEventListener('click',function(e){ e.preventDefault(); var h=a.getAttribute('data-anchor'); if(navigator.clipboard) navigator.clipboard.writeText(location.href.split('#')[0]+h); location.hash=h; }); });
})();</script>`;

/** Minimal theme-only script for the password / not-found pages. */
const CHROME_SCRIPT = `<script>(function(){${THEME_SCRIPT}})();</script>`;

function slugify(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60);
}

/** Plain text from sanitized HTML, for word counts and the OG excerpt. */
function textFromHtml(html: string): string {
  return html.replace(/<[^>]+>/g, ' ').replace(/&[a-z#0-9]+;/gi, ' ').replace(/\s+/g, ' ').trim();
}

function formatShareDate(isoStr?: string): string {
  if (!isoStr) return '';
  try {
    return new Date(isoStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch {
    return '';
  }
}

/**
 * Adds stable ids + hover anchors to the article's h1–h3 and builds the matching
 * table of contents. Operates on the already-sanitized body HTML; heading text is
 * stripped of markup and re-escaped for the TOC. Returns an empty TOC (and the
 * page falls back to a single column) when there are fewer than two headings.
 */
function buildReadingArticle(contentHtml: string): { article: string; toc: string } {
  const headings: { level: number; id: string; text: string }[] = [];
  const used = new Set<string>();
  const article = contentHtml.replace(/<h([1-3])>([\s\S]*?)<\/h\1>/g, (_m, lvl: string, inner: string) => {
    const level = Number(lvl);
    const text = inner.replace(/<[^>]+>/g, '').trim();
    let id = slugify(text) || 'section';
    let n = 2;
    while (used.has(id)) id = `${slugify(text) || 'section'}-${n++}`;
    used.add(id);
    headings.push({ level, id, text });
    return `<h${level} id="${id}">${inner}<a class="anchor" data-anchor="#${id}" aria-hidden="true">#</a></h${level}>`;
  });
  if (headings.length < 2) return { article, toc: '' };
  const toc = headings
    .map(h => `<a href="#${h.id}"${h.level >= 3 ? ' class="sub"' : ''}>${escapeHtml(h.text)}</a>`)
    .join('\n      ');
  return { article, toc };
}

export interface RenderNoteOptions {
  title: string;
  contentHtml: string;
  createdAt?: string;
  expiresAt?: string;
  slug?: string;
}

const ICON_COPY = `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/></svg>`;
const ICON_LINK = `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1"/></svg>`;

/** Renders the published note page (public / unlisted / unlocked password shares). */
export function renderSharePage(opts: RenderNoteOptions): string {
  const title = opts.title.trim() || 'Untitled note';
  const { article, toc } = buildReadingArticle(opts.contentHtml);
  const plain = textFromHtml(opts.contentHtml);
  const words = plain ? plain.split(/\s+/).filter(Boolean).length : 0;
  const readMin = Math.max(1, Math.round(words / 200));
  const published = formatShareDate(opts.createdAt);
  const expires = formatShareDate(opts.expiresAt);
  const canonical = opts.slug ? `${SITE}/note/${encodeURIComponent(opts.slug)}` : undefined;
  const description = plain ? `${plain.slice(0, 155)}${plain.length > 155 ? '…' : ''}` : undefined;

  const meta: string[] = [];
  if (published) meta.push(`<span>Published ${escapeHtml(published)}</span>`);
  meta.push(`<span>${readMin} min read</span>`);
  if (words > 0) meta.push(`<span>${words.toLocaleString('en-US')} words</span>`);
  if (expires) meta.push(`<span class="expiry">Available until ${escapeHtml(expires)}</span>`);

  const body = `
  ${topbar()}
  <div id="progress"></div>
  <main class="layout${toc ? '' : ' no-toc'}">
    ${toc ? `<nav class="toc" aria-label="Table of contents">
      <div class="toc-title">On this page</div>
      ${toc}
    </nav>` : ''}
    <div class="reader">
      <h1 class="note-title">${escapeHtml(title)}</h1>
      <div class="meta-row">
        ${meta.join('<span class="dot"></span>')}
        <div class="actions">
          <button class="pill" data-copy="text" type="button" aria-label="Copy note text">${ICON_COPY}<span>Copy</span></button>
          <button class="pill" data-copy="link" type="button" aria-label="Copy link">${ICON_LINK}<span>Link</span></button>
        </div>
      </div>
      <article id="note-body">${article}</article>

      <section class="cta">
        <div class="mark">Q</div>
        <div>
          <h3>Made with Quiet Paper</h3>
          <p>Private, offline-first notes with end-to-end encrypted sync.</p>
        </div>
        <a class="btn" href="${SITE}" target="_blank" rel="noopener">Get Quiet Paper</a>
      </section>

      <p class="about"><strong>About this page.</strong> This note was published as a link by its author. Unlike notes inside the app, shared pages are <strong>not end-to-end encrypted</strong> and are visible to anyone with the link${expires ? ` until ${escapeHtml(expires)}` : ''}.</p>

      <div class="footer">Shared with <a href="${SITE}" target="_blank" rel="noopener">Quiet Paper</a>${expires ? ` · Link expires ${escapeHtml(expires)}` : ''}</div>
    </div>
  </main>
  <div class="lightbox" id="lightbox"><img alt=""></div>`;

  return layout({ title, description, canonical, body, script: READER_SCRIPT });
}

/** Renders the password prompt for a password-protected share. */
export function renderPasswordPage(slug: string, error?: string): string {
  const body = `
  ${topbar()}
  <div class="center">
    <div class="card">
      <div class="glyph"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg></div>
      <h1>Password required</h1>
      <p>This shared note is protected. Enter the password to read it.</p>
      ${error ? `<div class="err">${escapeHtml(error)}</div>` : ''}
      <form method="POST" action="/note/${encodeURIComponent(slug)}">
        <label for="password">Password</label>
        <input type="password" id="password" name="password" autofocus required>
        <button type="submit" class="btn">Unlock note</button>
      </form>
    </div>
  </div>`;
  return layout({ title: 'Password required — Quiet Paper', body, script: CHROME_SCRIPT });
}

/** Renders the not-found / expired page (used for 404 and 410 responses). */
export function renderNotFoundPage(expired: boolean = false): string {
  const heading = expired ? 'This share has expired' : 'Share not found';
  const detail = expired
    ? 'Shared notes stay live for 30 days. This link has passed its expiry date — but you can make your own.'
    : 'This link is invalid, or the note it pointed to has been unshared or deleted.';
  const glyph = expired
    ? `<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>`
    : `<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>`;
  const body = `
  ${topbar()}
  <div class="center">
    <div class="card">
      <div class="glyph"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">${glyph}</svg></div>
      <h1>${escapeHtml(heading)}</h1>
      <p>${escapeHtml(detail)}</p>
      <a class="btn" href="${SITE}" target="_blank" rel="noopener">Learn about Quiet Paper</a>
    </div>
  </div>`;
  return layout({ title: `${heading} — Quiet Paper`, body, script: CHROME_SCRIPT });
}






