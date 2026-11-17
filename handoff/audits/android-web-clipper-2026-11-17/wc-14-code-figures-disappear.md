# WC-14: Code examples inside figure elements disappear from Markdown

Status: **Fixed**. Priority: **P2**. Added during the physical-device follow-up on 2026-11-17. Application source remains `810704c40ce943d9b339279e5b83193001d32b01`.

## Impact

Technical notes lose executable examples while keeping their surrounding explanation. The HTML snapshot and editable note can therefore disagree materially.

## Reproduction

Clip https://hexo.io/docs/writing.html and inspect the converted Markdown, including the examples for publishing drafts and creating a photo post.

**Expected:** Non-image figures retain their code and text content.

**Observed:** Direct and Android WebView captures each contain three pre blocks inside figures. Two complete example strings, 31 and 29 characters long, are absent from the resulting Markdown even though the cleaned DOM still contains them. The first 27-character string also appears elsewhere in the result; its presence does not establish that its figure was converted correctly.

## Evidence and cause

The figure conversion branch handles only the first img and an optional figcaption. A figure containing pre/code, with no image or caption, converts to an empty string.

Real Hexo documentation was fetched and captured on the phone. Both acquisition paths have identical missing-example diagnostics. A focused figure fixture preserves its caption but loses its protocol code, isolating conversion from extraction.

See [USB follow-up evidence](usb-device-follow-up/evidence.md) for numeric observations, device setup, limitations and the exact executed harness. No fix was made.

## Source locations

- [`lib/core/web_clipper/html_to_markdown_converter.dart:226`](../../../lib/core/web_clipper/html_to_markdown_converter.dart#L226)

## Resolution

Figure conversion preserves every child instead of selecting only the first image. Code-only and mixed-content figures retain fenced examples, explanatory text, all illustrations and italic captions exactly once.

Validation: flutter analyze: clean; 12 converter, picture extraction and service tests passed. No full suite ran.
