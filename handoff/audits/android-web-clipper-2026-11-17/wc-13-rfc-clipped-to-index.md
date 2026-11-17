# WC-13: A complete technical document is clipped down to its index appendix

Status: **Fixed**. Priority: **P2**. Added during the physical-device follow-up on 2026-11-17. Application source remains `810704c40ce943d9b339279e5b83193001d32b01`.

## Impact

Most of an article can disappear even though scanning succeeds and labels the result an identified article.

## Reproduction

Clip https://www.rfc-editor.org/rfc/rfc9110.html, either through direct HTTP or the in-app browser.

**Expected:** The editable article includes the substantive specification sections, not just its alphabetic index.

**Observed:** Both real acquisition paths select section#appendix-D, the index. Of 154 h1/h2/h3 headings in the source, only one remains; 161 pre blocks in the direct source become zero. Only 55,036 cleaned text characters remain from roughly 556,600 source body characters. isPageContentFallback is false, so the loss is not exposed as a fallback.

## Evidence and cause

Without an explicit article/main wrapper, extraction scores individual div and section nodes and returns the highest-scoring single node. It does not preserve sibling document sections; this index wins because of its many linked entries and text.

Direct scan and actual Android WebView DOM capture agree on appendix-D. The focused sibling-section fixture confirms that the other sections are discarded while isArticleRootFound remains true.

See [USB follow-up evidence](usb-device-follow-up/evidence.md) for numeric observations, device setup, limitations and the exact executed harness. No fix was made.

## Source locations

- [`lib/core/web_clipper/article_extractor.dart:199`](../../../lib/core/web_clipper/article_extractor.dart#L199)
- [`lib/core/web_clipper/article_extractor.dart:211`](../../../lib/core/web_clipper/article_extractor.dart#L211)
- [`lib/core/web_clipper/web_clipper_scanner.dart:186`](../../../lib/core/web_clipper/web_clipper_scanner.dart#L186)

## Resolution

Scored sections expand to a shared multi-section document container instead of discarding sibling chapters. Whole-body extraction is marked as fallback, and semantic sections/headings survive noise names such as Comments and Header Fields. A local replay of RFC 9110 retains all 154 h1/h2/h3 headings and all 161 pre blocks (previously 1 and 0).

Validation: flutter analyze: clean; 15 permanent extraction/scanner/parity tests and one temporary RFC replay passed; temporary local-file probe removed. No full suite ran.
