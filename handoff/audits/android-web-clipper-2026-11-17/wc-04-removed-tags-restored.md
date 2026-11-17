# WC-04: Removed default tags return when the article is saved

Status: **Open**. Priority: **P2**. Audited on `810704c40ce943d9b339279e5b83193001d32b01` (2026-11-17).

## Impact

The saved note disregards tag removals made in the preview.

## Reproduction

1. Open the clipping preview for example.com.
2. Remove the clipped and example.com chips; optionally add custom.
3. Save the clip and inspect the note tags.

**Expected:** The saved tags match the chips left in the preview.

**Observed:** Even when the supplied options contain only [custom], the saved note tags are [clipped, example.com, custom].

## Evidence and cause

The preview allows deleting every chip and passes the remaining list in options.tags. The service unconditionally reconstructs clipped and the source domain. WC-04 verifies the resulting saved Note with an in-memory repository.

The corresponding `WC-04` probe and its output are preserved in [evidence.md](evidence.md). Probe assertions characterize the existing defect; a passing probe does not mean the bug is fixed.

## Source locations

- [`lib/features/web_clipper/presentation/web_clip_preview_sheet.dart:61`](../../../lib/features/web_clipper/presentation/web_clip_preview_sheet.dart#L61)
- [`lib/features/web_clipper/presentation/web_clip_preview_sheet.dart:94`](../../../lib/features/web_clipper/presentation/web_clip_preview_sheet.dart#L94)
- [`lib/features/web_clipper/presentation/web_clip_preview_sheet.dart:156`](../../../lib/features/web_clipper/presentation/web_clip_preview_sheet.dart#L156)
- [`lib/core/web_clipper/web_clipper_service.dart:195`](../../../lib/core/web_clipper/web_clipper_service.dart#L195)
