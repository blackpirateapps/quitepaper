# WC-05: Browser capture uses the canonical URL as the asset base

Status: **Fixed**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

Clips from mirrored or republished pages can download wrong images and save wrong relative hyperlinks and snapshot resource URLs.

## Reproduction

1. Load https://mirror.example/posts/42 with a canonical link to https://publisher.example/articles/42.
2. Include an image with src=/photo.png and no overriding base element.
3. Capture the page from the in-app browser and scan its payload.

**Expected:** Relative assets resolve against the loaded document, so the image is https://mirror.example/photo.png.

**Observed:** The scanner resolves the image to https://publisher.example/photo.png instead. The source domain also becomes publisher.example.

## Evidence and cause

WebCapturePayload.effectiveUrl prioritizes canonicalUrl over finalUrl and is passed as sourceUrl to extraction. A canonical URL identifies preferred publication location; it does not change the loaded document base. WC-05 provides a captured DOM and observes the wrong image origin without network access.

The corresponding `WC-05` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/web_capture_payload.dart:58`](../../../lib/core/web_clipper/web_capture_payload.dart#L58)
- [`lib/core/web_clipper/web_clipper_scanner.dart:59`](../../../lib/core/web_clipper/web_clipper_scanner.dart#L59)
- [`lib/core/web_clipper/article_extractor.dart:36`](../../../lib/core/web_clipper/article_extractor.dart#L36)

## Resolution

Browser payloads resolve resources and source metadata against the final loaded document URL. Canonical publication URLs remain metadata and no longer redirect relative images or hyperlinks to another origin.

Validation: flutter analyze: clean; 16 scanner, browser controller and acquisition parity tests passed. No full suite ran.
