# Android web clipper bug audit — 2026-11-17

**Remediation complete: 16/16 fixed; 0 open.**

Branch: `audit/android-web-clipper-2026-11-17`

Audited source: `810704c40ce943d9b339279e5b83193001d32b01`

## Findings

P2 denotes incorrect clipping behavior or lost requested content. P3 denotes the lower-impact browser state contract defect. Every finding has reproduction steps, expected/observed results and source locations.

| Finding | Priority | Bug |
| --- | --- | --- |
| **Fixed** [WC-01](wc-01-snapshot-image-sources.md) | P2 | Saved snapshots contain Markdown in image src attributes |
| **Fixed** [WC-02](wc-02-snapshot-css-lost.md) | P2 | Default save drops CSS already fetched during scanning |
| **Fixed** [WC-03](wc-03-snapshot-save-failure-hidden.md) | P2 | Snapshot storage failures are reported as successful clips |
| **Fixed** [WC-04](wc-04-removed-tags-restored.md) | P2 | Removed default tags return when the article is saved |
| **Fixed** [WC-05](wc-05-canonical-url-asset-base.md) | P2 | Browser capture uses the canonical URL as the asset base |
| **Fixed** [WC-06](wc-06-redirect-asset-base.md) | P2 | Direct HTTP clipping resolves assets against the pre-redirect URL |
| **Fixed** [WC-07](wc-07-browser-message-clearing.md) | P3 | Browser state cannot clear previous error and status messages |
| **Fixed** [WC-08](wc-08-query-image-substitution.md) | P2 | A failed image can be replaced by a different image with the same URL path |
| **Fixed** [WC-09](wc-09-browser-save-pops-editor.md) | P2 | Saving from the in-app browser immediately pops the newly opened editor |
| **Fixed** [WC-10](wc-10-second-share-discarded.md) | P2 | A second shared URL is discarded while Quick Capture is open |
| **Fixed** [WC-11](wc-11-url-dialog-loading-overflow.md) | P2 | Continue’s loading spinner overflows the URL dialog on a phone |
| **Fixed** [WC-12](wc-12-layout-table-article-triplication.md) | P2 | Direct clipping repeats article text from nested layout tables |
| **Fixed** [WC-13](wc-13-rfc-clipped-to-index.md) | P2 | A complete technical document is clipped down to its index appendix |
| **Fixed** [WC-14](wc-14-code-figures-disappear.md) | P2 | Code examples inside figure elements disappear from Markdown |
| **Fixed** [WC-15](wc-15-star-alt-removes-content-photo.md) | P2 | A meaningful photo is rejected when its alt text mentions a star |
| **Fixed** [WC-16](wc-16-failed-page-marked-ready.md) | P2 | An Android page-load failure becomes Ready to clip |

## USB device follow-up

The [physical-device audit](usb-device-follow-up/README.md) adds six findings, reproduces WC-09 and WC-07 on a Redmi K20 Pro, and exercises eight real public links. Five new findings have device/live-page evidence; WC-15 is a component-only reproduction. The final USB run passes 23 existing relevant tests plus four probes. That original device audit made no fixes and ran no full suite. Current resolutions are tracked above.

## Initial scope and limits

Reviewed Android manifest and activity integration, incoming share routing through Quick Capture, URL input, in-app acquisition browser, extraction and URL resolution, image downloads, preview options, note commitment, HTML snapshots and snapshot viewing. Shared core defects are included because they are used by the Android flow; they may also affect other platforms.

Evidence combines source tracing, deterministic HTTP/service probes, a real local HTTP redirect, and Android-themed widget tests of navigation and repeated shares. The initial pass did not exercise a device, native intents or real websites. The later USB follow-up exercises actual WebView and device rendering on public links; authenticated sites and OS share transport remain outside that follow-up. No private note data was used. This is a bounded audit, not a claim that all Android bugs have been found.

## Initial validation

- `flutter analyze`: no issues.
- `flutter test test/web_clipper`: **42 passed**, existing clipper tests only.
- `flutter test --no-pub test/quick_capture/quick_capture_normalizer_test.dart test/quick_capture/quick_capture_screen_test.dart --reporter expanded`: **15 passed**.
- Temporary focused audit probes: **10 passed**, asserting observed defects. Source and output are in [evidence.md](evidence.md).
- **No full test suite ran.** Temporary executable probes were removed after preserving them as Markdown; committed changes are Markdown only.

The original audit tests characterized defects. Per-finding resolution sections now track fixes and regression validation.


## Follow-up final static analysis

After archiving and removing temporary Dart instrumentation, `flutter analyze` reports no issues. See the [USB follow-up](usb-device-follow-up/README.md) for the focused test results, cleanup and native scope.

## Remediation validation

Each finding was fixed separately with regression tests, clean Flutter analysis, a HANDOFF update, and a commit pushed to the audit branch. WC-04 has an additional follow-up commit covering the converter’s independent YAML-tag insertion path.

The RFC 9110 local HTML replay retains all 154 h1/h2/h3 headings and all 161 pre blocks. Durable synthetic fixtures cover wrapped/unwrapped sections and technical section names. The temporary local-file replay was removed after verification.

Native lifecycle regression tests drive the real browser controller through the WebView platform callbacks, including main-frame errors, late progress/finish, in-flight JavaScript, internal error URLs, slow-load timers, subframe/cancellation errors and recovery. This remediation did not repeat a physical-device run or build an Android APK. Original device evidence remains historical.

No full test suite ran.

Final combined relevant validation: `flutter test --no-pub --concurrency=1 test/web_clipper test/quick_capture` — **92 passed**. `flutter analyze --no-pub` — **no issues**. Every WC-01 through WC-16 report is marked Fixed.
