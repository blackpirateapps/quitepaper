/* Runs in the active tab's isolated extension world, only after a user action.
 * No fetch, XHR, external parser, cookie access, or page navigation. */
globalThis.quietPaperCapture = function captureLoadedPage({ mode = "article" } = {}) {
  if (!/^https?:$/.test(location.protocol)) {
    throw new Error("Open an HTTP or HTTPS webpage to clip it.");
  }
  if (!document.body) throw new Error("The page is still loading. Try again.");

  const blocked = "script, style, noscript, iframe, object, embed, form, input, textarea, select, button, svg, canvas, template, nav, dialog, [hidden], [aria-hidden='true']";
  // Keep these rules aligned with lib/core/web_clipper/article_content_rules.dart
  // so Android and the extension recognize the same publisher prose containers.
  const articleBodies = [
    ".articlebodycontent > .schemaDiv", '[itemprop~="articleBody"]',
    ".articlebodycontent", ".article-body", ".article__body", ".story-body",
    ".entry-content", ".post-content", ".article-content",
  ];
  const articleNoise = '.most-popular, #most-popular, .most_popular, #most_popular, ' +
    '.most-read, .popular-premium-tabs, .related-articles, .related-stories, ' +
    '.related-posts, .related-topics, .recommendations, .recommended-stories, ' +
    '[id^="taboola-"], [id^="outbrain"], .article-ad, .articleinlinead, ' +
    '.dfp-ad, [hidden], [aria-hidden="true"]';
  const meta = (name) => document.querySelector(`meta[property="${name}"], meta[name="${name}"]`)?.content?.trim() || "";
  // An inactive document prevents cloned image/srcset nodes from initiating
  // resource loads while the capture is prepared.
  const snapshotDocument = document.implementation.createHTMLDocument("");
  let root;
  let source;
  if (mode === "selection") {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || !selection.rangeCount) {
      throw new Error("Select some page text first, then open the clipper again.");
    }
    root = snapshotDocument.createElement("div");
    root.append(snapshotDocument.importNode(selection.getRangeAt(0).cloneContents(), true));
  } else {
    source = document.body;
    if (mode === "article") {
      // Prefer prose to broad wrappers. Never let a larger main/body beat an
      // identified article merely because it contains more recommendation text.
      for (const selector of [...articleBodies, "article", "main, [role='main']"]) {
        const candidate = [...document.querySelectorAll(selector)].find((node) =>
          node.getClientRects().length && node.innerText.trim().length >= 10 &&
          !node.closest(`aside, nav, footer, header, ${articleNoise}`));
        if (candidate) { source = candidate; break; }
      }
    }
    root = snapshotDocument.importNode(source, true);
    // Copy the actual selected image resource, and remove elements hidden by
    // styles before serializing. Never load lazy images or alternate srcsets.
    const originals = [source, ...source.querySelectorAll("*")];
    const clones = [root, ...root.querySelectorAll("*")];
    if (originals.length > 60000) throw new Error("This page is too large. Clip a selection instead.");
    originals.forEach((original, i) => {
      const clone = clones[i];
      const style = getComputedStyle(original);
      if (style.display === "none" || style.visibility === "hidden") {
        clone.remove();
      } else if (original.tagName === "IMG") {
        if (original.currentSrc) clone.setAttribute("src", original.currentSrc);
      }
    });
  }
  root.querySelectorAll(blocked).forEach((node) => node.remove());
  if (mode === "article") {
    root.querySelectorAll(`aside, footer, header, ${articleNoise}`).forEach((node) => node.remove());
  }
  root.querySelectorAll("source").forEach((node) => node.remove());
  for (const node of [root, ...root.querySelectorAll("*")]) {
    const saved = {};
    for (const name of ["href", "src", "alt", "title", "class"]) saved[name] = node.getAttribute(name);
    [...node.attributes].forEach((attribute) => node.removeAttribute(attribute.name));
    for (const name of ["href", "src"]) {
      if (!saved[name]) continue;
      try {
        const url = new URL(saved[name], document.baseURI);
        if ((/^https?:$/.test(url.protocol) && !url.username && !url.password) ||
            (name === "href" && url.protocol === "mailto:")) {
          node.setAttribute(name, url.href);
        }
      } catch { /* Omit invalid URLs. */ }
    }
    for (const name of ["alt", "title"]) {
      if (saved[name]) node.setAttribute(name, saved[name]);
    }
    if (/^(CODE|PRE)$/.test(node.tagName)) {
      const language = saved.class?.match(/\blanguage-[a-zA-Z0-9_-]+/);
      if (language) node.setAttribute("class", language[0]);
    }
  }
  if (!root.textContent.trim() && !root.querySelector("img")) {
    throw new Error("No readable page content was found. Try the whole page option.");
  }
  return {
    url: location.href,
    title: meta("og:title") || document.title || location.hostname,
    author: meta("author") || meta("article:author"),
    description: meta("description") || meta("og:description"),
    publishedAt: meta("article:published_time") || document.querySelector("time[datetime]")?.getAttribute("datetime") || "",
    html: root.outerHTML,
  };
};
