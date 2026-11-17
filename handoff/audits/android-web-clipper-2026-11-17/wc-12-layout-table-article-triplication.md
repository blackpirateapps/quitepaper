# WC-12: Direct clipping repeats article text from nested layout tables

Status: **Fixed**. Priority: **P2**. Added during the physical-device follow-up on 2026-11-17. Application source remains `810704c40ce943d9b339279e5b83193001d32b01`.

## Impact

The editable note contains multiple copies of the same prose and inflated storage. Nested page layout tables become Markdown data tables containing duplicated content.

## Reproduction

Directly clip https://www.paulgraham.com/ds.html using Continue, rather than the in-app browser.

**Expected:** Each paragraph appears once in the clipped article.

**Observed:** The selected root is a table containing five descendant tables. Five independent 50-character samples each occur once in the raw page and cleaned text, but three times in the converted Markdown. The scan yields 82,089 Markdown characters from 25,110 cleaned text characters; saving through the phone UI creates an 82,137-character note.

## Evidence and cause

The table converter enumerates every descendant tr, then every descendant th/td for each row. Nested cells are included again while converting their parent cell, and the inner rows are subsequently emitted again.

Real direct HTTP on the phone, native dialog/save, occurrence-count diagnostics and a focused one-sentence nested-table fixture that produces exactly three copies. The real mobile WebView received a different, main-based page and produced a much smaller 26,071-character Markdown scan; this finding is specifically the direct-fetch path.

See [USB follow-up evidence](usb-device-follow-up/evidence.md) for numeric observations, device setup, limitations and the exact executed harness. No fix was made.

## Source locations

- [`lib/core/web_clipper/html_to_markdown_converter.dart:267`](../../../lib/core/web_clipper/html_to_markdown_converter.dart#L267)
- [`lib/core/web_clipper/html_to_markdown_converter.dart:273`](../../../lib/core/web_clipper/html_to_markdown_converter.dart#L273)

## Resolution

Nested and presentation/layout tables convert as document flow, preserving paragraphs, headings and fenced code once. Flat tables enumerate only direct row cells, preventing descendant-cell duplication while retaining ordinary data-table Markdown.

Validation: flutter analyze: clean; 17 converter, scanner and service tests passed. No full suite ran.
