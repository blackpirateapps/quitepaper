# WC-06: Direct HTTP clipping resolves assets against the pre-redirect URL

Status: **Open**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

Sharing or pasting a redirecting article link can produce broken relative images and hyperlinks, with incorrect source metadata and snapshot resource bases.

## Reproduction

1. Serve /start as an HTTP 302 redirect to /posts/article.
2. Serve an article at /posts/article containing src=photo.png.
3. Scan /start using the normal direct HTTP acquisition path.

**Expected:** The image resolves to /posts/photo.png, relative to the final document URL.

**Observed:** The scanner resolves and probes /photo.png using /start as its base. The local server confirms that /posts/article was reached through the real redirect before the wrong image path was requested.

## Evidence and cause

scanUrl passes targetUrl to extraction after receiving the successful response, regardless of redirects. WC-06 uses a real loopback HttpServer and IOClient, not a mocked redirect; the recorded port is ephemeral. The probe bypasses Flutter test HTTP overrides only for this local client.

The corresponding `WC-06` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/web_clipper_scanner.dart:165`](../../../lib/core/web_clipper/web_clipper_scanner.dart#L165)
- [`lib/core/web_clipper/web_clipper_scanner.dart:178`](../../../lib/core/web_clipper/web_clipper_scanner.dart#L178)
