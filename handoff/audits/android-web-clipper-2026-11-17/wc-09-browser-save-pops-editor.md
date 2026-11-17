# WC-09: Saving from the in-app browser immediately pops the newly opened editor

Status: **Fixed**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

After a successful clip the user stays in the browser instead of seeing the saved note. In the real controller path the browser can also retain its processing state because the success branch never resets it.

## Reproduction

1. Open the in-app acquisition browser and tap Clip.
2. In the preview, tap Clip to save successfully.
3. Observe the top route after the preview closes.

**Expected:** The saved article editor stays open and the browser completion flow closes the intended browser route.

**Observed:** The preview pops itself and pushes EditorScreen. The browser await then resumes and Navigator.pop removes that editor. The browser remains mounted. The observer records push:/browser, push:ModalBottomSheetRoute, pop:ModalBottomSheetRoute, push:MaterialPageRoute, pop:MaterialPageRoute.

## Evidence and cause

Both widgets own success navigation on the same Navigator. WC-09 uses the actual browser screen and preview with an Android theme, a fake successful capture/service and a route observer. It asserts the editor route pop and that WebClipBrowserScreen remains. Actual Android WebView rendering and editor interaction were not part of this widget probe; the processing consequence follows from the production capture state and success branch.

The corresponding `WC-09` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/features/web_clipper/presentation/web_clip_preview_sheet.dart:113`](../../../lib/features/web_clipper/presentation/web_clip_preview_sheet.dart#L113)
- [`lib/features/web_clipper/presentation/browser/web_clip_browser_screen.dart:98`](../../../lib/features/web_clipper/presentation/browser/web_clip_browser_screen.dart#L98)

## Physical-device confirmation

The USB follow-up reproduces this with the actual Android WebView and a live public article. After native Clip/Clip taps, the real controller remains processing with canClip=false; the observer records preview pop, editor push and editor pop, and the browser remains visible. Two synthetic notes exist: one direct-path save and one browser save. See [native evidence](usb-device-follow-up/evidence.md). No fix was made.

## Resolution

Browser previews return the saved note without opening an editor themselves. The browser resets processing state and replaces its own route with the saved editor in all three save paths. A route-observer regression verifies only the preview is popped and the replacement editor holds the saved note.

Validation: flutter analyze: clean; 5 navigation, browser and preview widget tests passed. No full suite ran.
