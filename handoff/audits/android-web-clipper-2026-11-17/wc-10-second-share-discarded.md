# WC-10: A second shared URL is discarded while Quick Capture is open

Status: **Open**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

Android users sharing another article into an already open capture session lose that new capture request without an error or a queued entry.

## Reproduction

1. Share https://example.com/first into Quiet Paper and leave Quick Capture open.
2. Return to the external browser and share https://example.com/second into Quiet Paper.
3. Observe the capture screen and its payload.

**Expected:** The distinct new URL is delivered or retained for a later capture.

**Observed:** The coordinator logs Route already open; ignoring duplicate push and returns. The first URL remains, while the second URL is neither delivered nor queued.

## Evidence and cause

The route-open flag rejects all payloads, not just duplicate shares, and there is no active-session delivery or pending-share queue. WC-10 invokes the same coordinator method used by the share handler twice with distinct normalized share payloads. An Android-themed widget with an isolated in-memory database verifies only the first URL is visible. The OS intent transport was reviewed in code rather than replayed on a device.

The corresponding `WC-10` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/share_intent_handler.dart:76`](../../../lib/core/web_clipper/share_intent_handler.dart#L76)
- [`lib/features/quick_capture/application/quick_capture_coordinator.dart:79`](../../../lib/features/quick_capture/application/quick_capture_coordinator.dart#L79)
