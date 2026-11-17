# WC-02: Default save drops CSS already fetched during scanning

Status: **Open**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

Saved snapshots depend on live external stylesheets and lose their appearance offline. The preview storage estimate is computed from a different, CSS-inlined document.

## Reproduction

1. Scan a page with an external stylesheet that returns valid CSS.
2. Save the web snapshot using the normal provider-created WebClipperService.
3. Inspect the saved HTML and reopen it offline.

**Expected:** The saved snapshot retains the stylesheet content fetched while preparing the preview.

**Observed:** The probe observes a stylesheet request during scanPayload, but the persisted HTML contains only `<link rel="stylesheet" href="https://example.com/style.css">` and no stylesheet body.

## Evidence and cause

The scanner has an HTTP-enabled snapshot generator and computes an inlined preliminary snapshot, retaining only its byte estimate. The default service generator has no HTTP client, so commitment takes the branch that only absolutizes stylesheet links. The probe leaves the service generator at its production default; tests that inject an HTTP-enabled generator do not exercise this wiring.

The corresponding `WC-02` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/web_clipper_service.dart:32`](../../../lib/core/web_clipper/web_clipper_service.dart#L32)
- [`lib/core/web_clipper/web_clipper_scanner.dart:29`](../../../lib/core/web_clipper/web_clipper_scanner.dart#L29)
- [`lib/core/web_clipper/web_snapshot_generator.dart:80`](../../../lib/core/web_clipper/web_snapshot_generator.dart#L80)
- [`lib/core/web_clipper/web_clipper_provider.dart:12`](../../../lib/core/web_clipper/web_clipper_provider.dart#L12)
