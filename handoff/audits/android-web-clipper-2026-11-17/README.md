# Android web clipper bug audit — 2026-11-17

**10 confirmed open findings. No application changes or fixes.**

Branch: `audit/android-web-clipper-2026-11-17`

Audited source: `810704c40ce943d9b339279e5b83193001d32b01`

## Findings

P2 denotes incorrect clipping behavior or lost requested content. P3 denotes the lower-impact browser state contract defect. Every finding has reproduction steps, expected/observed results and source locations.

| Finding | Priority | Bug |
| --- | --- | --- |
| [WC-01](wc-01-snapshot-image-sources.md) | P2 | Saved snapshots contain Markdown in image src attributes |
| [WC-02](wc-02-snapshot-css-lost.md) | P2 | Default save drops CSS already fetched during scanning |
| [WC-03](wc-03-snapshot-save-failure-hidden.md) | P2 | Snapshot storage failures are reported as successful clips |
| [WC-04](wc-04-removed-tags-restored.md) | P2 | Removed default tags return when the article is saved |
| [WC-05](wc-05-canonical-url-asset-base.md) | P2 | Browser capture uses the canonical URL as the asset base |
| [WC-06](wc-06-redirect-asset-base.md) | P2 | Direct HTTP clipping resolves assets against the pre-redirect URL |
| [WC-07](wc-07-browser-message-clearing.md) | P3 | Browser state cannot clear previous error and status messages |
| [WC-08](wc-08-query-image-substitution.md) | P2 | A failed image can be replaced by a different image with the same URL path |
| [WC-09](wc-09-browser-save-pops-editor.md) | P2 | Saving from the in-app browser immediately pops the newly opened editor |
| [WC-10](wc-10-second-share-discarded.md) | P2 | A second shared URL is discarded while Quick Capture is open |

## Scope and limits

Reviewed Android manifest and activity integration, incoming share routing through Quick Capture, URL input, in-app acquisition browser, extraction and URL resolution, image downloads, preview options, note commitment, HTML snapshots and snapshot viewing. Shared core defects are included because they are used by the Android flow; they may also affect other platforms.

Evidence combines source tracing, deterministic HTTP/service probes, a real local HTTP redirect, and Android-themed widget tests of navigation and repeated shares. No Android device/emulator or adb was available, so native intents, real WebView lifecycle behavior, authenticated websites and device rendering were not tested. No live third-party site or private user data was used. This is a bounded audit, not a claim that all Android bugs have been found.

## Validation

- `flutter analyze`: no issues.
- `flutter test test/web_clipper`: **42 passed**, existing clipper tests only.
- `flutter test --no-pub test/quick_capture/quick_capture_normalizer_test.dart test/quick_capture/quick_capture_screen_test.dart --reporter expanded`: **15 passed**.
- Temporary focused audit probes: **10 passed**, asserting observed defects. Source and output are in [evidence.md](evidence.md).
- **No full test suite ran.** Temporary executable probes were removed after preserving them as Markdown; committed changes are Markdown only.

All findings remain open. Existing test success does not establish the absence of these bugs: those tests omit the failing state transitions, production wiring or artifact content examined here.
