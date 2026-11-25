# Notes list remediation verification

NL-08 reran the original isolated Linux profile harness after remediation, with
10,000 synthetic notes in memory and 1,000 loaded rows. The launcher checks the
actual desktop (1280 × 680) and phone-layout (390 × 680) render sizes. Sources and
replay commands remain in the parent audit report.

Repeated prewarm at 600/1,000 notes now takes at most 1 microsecond in these
samples, compared with original medians of 364/598 milliseconds. A full cache
returns without speculative parsing or eviction. The production list no longer
calls collection-wide metadata/thumbnail prewarming at all. Permanent tests check
cache-instance retention, lazy tile extraction and grouping reuse during refresh.

Desktop build p95 is 9.116ms and phone-layout build p95 is 7.608ms, below a 16.67ms
60Hz budget. Desktop has one 18.673ms build outlier; phone-layout has none over
budget. Raster p95 is 3.000ms/2.252ms. This is a shared-workstation sample, not a
hard frame-time guarantee. Both layouts mount 13 tiles at rest; Flutter reports
no runtime errors. Refresh retains all 1,000 loaded notes (also NL-04 acceptance).

These measurements use Linux's engine, programmatic scrolling and an in-memory
database. Physical mobile performance, native touch and disk latency remain
unverified. Initial whole-collection prewarm measurements are harness-only; the
application list uses lazy extraction. Raw metrics, window checks, build output
and isolated runtime output accompany this file. Restore the ordinary profile
entry point with `flutter build linux --profile --no-pub -t lib/main.dart` after
running the harness.

## Final remediation checks

- `flutter analyze`: no issues; [raw output](analysis.log.txt).
- `flutter test --no-pub --concurrency=1 test/notes test/features/notes`:
  **192 passed**; [raw output](notes-tests.log.txt). This covers only notes and
  notes gestures, not the full Flutter suite.
- Each of the ten findings has permanent acceptance coverage and its own fix
  commit/push. Historical defect-characterization probes are unchanged.
- Restored the normal profile entry point with
  `flutter build linux --profile --no-pub -t lib/main.dart` successfully;
  [build log](restore-build.log.txt).
