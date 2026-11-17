# Image/scanner remediation verification — November 18, 2026

All **14/14 findings are fixed; 0 open**, on the original
`audit/images-scanner-2026-11-17` branch, with a separate commit per finding.
The audit report retains baseline descriptions and per-finding resolutions.

Final combined validation: **152 relevant tests passed**, serialized with
`--concurrency=1`; **Flutter analysis reports no issues**. No full suite ran.
Raw results: [analysis](flutter-analyze.txt), [tests](relevant-tests.txt).

```sh
flutter analyze
flutter test --no-pub --concurrency=1 \
  test/scanner test/image_processing \
  test/attachments/image_viewer_modal_test.dart \
  test/attachments/quiet_asset_image_view_test.dart \
  test/attachments/image_dimension_reader_test.dart \
  test/attachments/image_layout_calculator_test.dart \
  test/attachments/attachment_service_test.dart \
  test/attachments/generic_file_attachment_test.dart \
  test/attachments/attachment_viewer_cloud_only_test.dart \
  test/editor/editor_image_upload_compression_test.dart \
  test/editor/image_compression_dialog_test.dart
```

New permanent acceptance coverage:

- `test/image_processing/scanner_audit_regression_test.dart`: source-region
  selection through every rotation for rectangle and quad crops, both CPU tone
  paths versus the preview matrix, worker event-loop responsiveness and bounded
  representations, and forced/threshold animated-GIF preservation.
- `test/scanner/images_scanner_audit_test.dart`: cropped/dewarped review framing,
  real temporary-file writes/overwrites/cancel/failure, delayed detection after
  manual Full Page, locked remount, source-buffer reuse/200-source revisits,
  stale success/failure completion in both orders and variant changes, disposed
  picker results, preloaded viewer lifecycle and ORIGINAL press/release bytes.
- `test/scanner/pdf_aspect_ratio_test.dart`: actual MediaBox aspect ratios in
  both PDF generators for landscape, wide, portrait and square pages.
- `test/attachments/attachment_service_test.dart`: locked-cache denial in the
  real resolver and plaintext-cache purge through secure key lock.

Tests use synthetic images, controlled async services/pickers, and temporary
files. Existing camera/plugin fallbacks and invalid-input tests may log their
expected diagnostics; the repaired build/disposal reproductions assert their
absence. No native picker/camera automation, app build, new device replay,
release performance measurement, real-note change or cloud write was performed.
The original performance data and physical-device limits remain historical;
worker timer checks establish event-loop yielding without claiming device FPS.
Historical characterization probes assert the old bugs and must only be replayed
against the audited baseline, not used as acceptance checks on this branch.
