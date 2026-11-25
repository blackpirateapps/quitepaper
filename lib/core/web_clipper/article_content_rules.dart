/// Keep these selectors aligned with extensions/browser/shared/capture.js.
/// Prefer a publisher's prose container over page-wide semantic wrappers.
const articleBodySelectors = [
  '.articlebodycontent > .schemaDiv', // The Hindu's article prose.
  '[itemprop~="articleBody"]',
  '.articlebodycontent',
  '.article-body',
  '.article__body',
  '.story-body',
  '.entry-content',
  '.post-content',
  '.article-content',
];

/// Explicit non-article modules must be removed even when their names also
/// contain positive scoring hints such as "article" or "content".
const articleNoiseSelector =
    '.most-popular, #most-popular, .most_popular, #most_popular, '
    '.most-read, .popular-premium-tabs, .related-articles, .related-stories, '
    '.related-posts, .related-topics, .recommendations, .recommended-stories, '
    '[id^="taboola-"], [id^="outbrain"], .article-ad, .articleinlinead, '
    '.dfp-ad, [hidden], [aria-hidden="true"]';
