# WC-08: A failed image can be replaced by a different image with the same URL path

Status: **Open**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

The saved article can display incorrect illustrations under the original captions, silently changing article meaning.

## Reproduction

1. Use two distinct images at /image?id=one and /image?id=two.
2. Make id=one return HTTP 404 and id=two return a successful image response.
3. Clip with image downloading enabled and inspect the Markdown links.

**Expected:** The unavailable first image keeps its own reference or is reported missing; it must not acquire the second image content.

**Observed:** The One and Two Markdown images both point at the second image attachment UUID.

## Evidence and cause

The downloader registers a query-free URL alias for each successful image. When the first image lacks an exact map entry, _resolveAssetUri falls back to that alias and then scans entries while ignoring query strings. WC-08 exercises the real downloader and service with deterministic HTTP responses and the existing fake attachment vault; both output links use asset 00000000-0000-0000-0000-000000000001.

The corresponding `WC-08` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/web_image_downloader.dart:131`](../../../lib/core/web_clipper/web_image_downloader.dart#L131)
- [`lib/core/web_clipper/web_clipper_service.dart:261`](../../../lib/core/web_clipper/web_clipper_service.dart#L261)
