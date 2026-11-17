# WC-03: Snapshot storage failures are reported as successful clips

Status: **Open**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

A user can believe an offline snapshot was saved when the note contains no snapshot at all.

## Reproduction

1. Keep Save Web Snapshot enabled.
2. Have createWebSnapshotDocument fail, for example because vault storage cannot be written.
3. Observe the result and completion progress.

**Expected:** The user is told that the requested snapshot failed to save.

**Observed:** clipArticle resolves successfully with snapshotDocument=null, persists the text note without a snapshot link, and emits WebClipProgressStep.complete. The preview presents the ordinary Article clipped success notification.

## Evidence and cause

The snapshot try/catch logs the failure with debugPrint and continues. The probe injects a document service throwing StateError("vault write failed") and verifies the successful return, absent snapshot link and complete progress. This is an explicitly induced storage failure, not an unexplained runtime exception.

The corresponding `WC-03` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/core/web_clipper/web_clipper_service.dart:124`](../../../lib/core/web_clipper/web_clipper_service.dart#L124)
- [`lib/core/web_clipper/web_clipper_service.dart:225`](../../../lib/core/web_clipper/web_clipper_service.dart#L225)
- [`lib/features/web_clipper/presentation/web_clip_preview_sheet.dart:113`](../../../lib/features/web_clipper/presentation/web_clip_preview_sheet.dart#L113)
