# WC-07: Browser state cannot clear previous error and status messages

Status: **Fixed**. Priority: **P3**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

Reset and navigation transitions retain stale transient state instead of fulfilling their message-clearing contract. This is a confirmed state defect; an independent visible UI failure was not established.

## Reproduction

1. Create a WebClipBrowserState containing an errorMessage and statusMessage.
2. Call copyWith(errorMessage: null, statusMessage: null), as resetToReady and navigation handlers do.
3. Read the resulting state.

**Expected:** Both nullable message fields are cleared.

**Observed:** The old error and status strings remain. The probe records error=Old error and status=Old status after the clearing call.

## Evidence and cause

copyWith uses newValue ?? oldValue for nullable messages, making explicit clearing indistinguishable from omission. WC-07 isolates the real immutable state operation. The existing reset test only resets a state whose messages were already null, so it passes without testing the failing transition.

The corresponding `WC-07` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/features/web_clipper/presentation/browser/web_clip_browser_controller.dart:68`](../../../lib/features/web_clipper/presentation/browser/web_clip_browser_controller.dart#L68)
- [`lib/features/web_clipper/presentation/browser/web_clip_browser_controller.dart:568`](../../../lib/features/web_clipper/presentation/browser/web_clip_browser_controller.dart#L568)

## Physical-device confirmation

After a real Android main-frame cleartext failure, navigation and DOM capture of the HTTPS Hexo and RFC pages succeed while errorMessage still contains the previous net::ERR_CLEARTEXT_NOT_PERMITTED. The actual captured pages and stale controller state are recorded in [native evidence](usb-device-follow-up/evidence.md). This confirms the state defect without claiming an additional independent visible failure.

## Resolution

Browser state copyWith now distinguishes omitted transient messages from explicit null. Navigation and reset calls can clear old error/status messages while unrelated copies preserve them.

Validation: flutter analyze: clean; 11 browser controller and screen tests passed. No full suite ran.
