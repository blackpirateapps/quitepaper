# WC-01: Saved snapshots contain Markdown in image src attributes

Status: **Fixed**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

Downloaded article images are broken in the saved HTML snapshot, even though the Markdown note can reference their local attachments.

## Reproduction

1. Clip an article containing an ordinary image with Save Web Snapshot and Download Images Locally enabled.
2. Open the saved snapshot, or inspect its persisted HTML bytes.

**Expected:** Each saved image has a source the snapshot viewer can load from the encrypted attachment vault.

**Observed:** The persisted HTML contains `<img src="![Photo](qp://asset/photo-id)">`. This is a Markdown snippet, not an image URL. The Android snapshot viewer simply calls `loadHtmlString` and also has no attachment resolution bridge for `qp://asset/` image requests.

## Evidence and cause

The downloader returns URL-to-Markdown-snippet entries. clipArticle passes that map as localImageSources; the generator copies each value verbatim into src. WC-01 inspects the bytes sent to document storage using a fixed downloader with the real downloader return contract. No Android rendering claim is needed to establish the malformed source.

The corresponding `WC-01` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/web_clipper_service.dart:125`](../../../lib/core/web_clipper/web_clipper_service.dart#L125)
- [`lib/core/web_clipper/web_snapshot_generator.dart:147`](../../../lib/core/web_clipper/web_snapshot_generator.dart#L147)
- [`lib/core/web_clipper/web_image_downloader.dart:23`](../../../lib/core/web_clipper/web_image_downloader.dart#L23)
- [`lib/features/web_clipper/presentation/web_snapshot_viewer_screen.dart:115`](../../../lib/features/web_clipper/presentation/web_snapshot_viewer_screen.dart#L115)

## Resolution

Saved snapshot image sources now contain vault URLs; the viewer decrypts and embeds image bytes in memory for offline rendering, removing competing srcset references.

Validation: flutter analyze: clean; 7 service, snapshot and image hydration tests passed. No full suite ran.
