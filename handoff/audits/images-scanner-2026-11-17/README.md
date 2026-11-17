# Images and document scanner audit — November 17, 2026

Branch: `audit/images-scanner-2026-11-17`. Baseline: `8724bf0` (includes the completed notes-list remediation). Audit only: application defects are recorded open; production behavior is unchanged. An unrelated pre-existing untracked prompt is excluded from the audit commit.

Read first: `HANDOFF.md`, `handoff/ocr-and-documents.md`, and scanner/image source and relevant existing tests. Scope: local image compression/viewer editing, scanner import/review/adjustments, corner detection/dewarp, PDF generation and processing performance. No full test suite. Findings below were entered as soon as confirmed; the final executable evidence and validation are linked below.

## Findings

**14 confirmed, 1 fixed, 13 open.** P1 = high priority for lost/incorrect exported content, misleading save success, privacy boundaries or UI stalls. P2 = ordinary functional correctness or memory-growth risk. Priority is triage guidance; timing and exposure limits are stated per finding.

| ID | Priority | Defect | Production source |
| --- | --- | --- | --- |
| IS-01 | P1 | Rotation crops/dewarps the wrong region | `image_processor.dart:274`, `scanner_preview_canvas.dart:159` |
| IS-02 | P2 | Applied crop absent from review | `scanner_preview_canvas.dart:175`, `document_scanner_screen.dart:923` |
| IS-03 | P1 | Preview and saved tone transforms disagree | `image_adjustments.dart:95`, `image_processor.dart:338` |
| IS-04 | P1 | Desktop Save Image succeeds without writing | `image_viewer_modal.dart:809` |
| IS-05 | P1 | Full-resolution preparation blocks UI isolate | `image_processor.dart:128`, `:215` |
| IS-06 | P1 | Late corner detection overwrites manual edit | `document_scanner_screen.dart:398` |
| IS-07 | P2 | Landscape PDF has incorrect page aspect | `pdf_generator.dart:39` |
| IS-08 | P1 | Compression drops GIF animation | `image_compression_service.dart:242` |
| IS-09 | P1 | Cached inline plaintext bypasses lock resolution | `quiet_asset_image_view.dart:86` |
| IS-10 | P2 | Unbounded inline image source cache | `quiet_asset_image_view.dart:67` |
| IS-11 | P1 | Stale load displays previous image under new identity | `quiet_asset_image_view.dart:98`, `:145` |
| IS-12 | P2 | Late gallery result mutates disposed scanner | `document_scanner_screen.dart:266`, `:299` |
| IS-13 | P2 | Preloaded viewer callback mutates parent during build | `image_viewer_modal.dart:437`, `:688` |
| IS-14 | P2 | ORIGINAL comparison retains baked scanner mode | `page_adjustment_sheet.dart:107`, `scanner_preview_canvas.dart:125` |

Source basenames refer to `lib/core/image_processing/`, `lib/core/attachments/presentation/`, `lib/core/pdf/`, or `lib/features/scanner/presentation/` (including `widgets/`) as appropriate. Line references are against baseline `8724bf0`.

### IS-01 — P1 — Rotation changes the crop/dewarp coordinate system (FIXED)

Confirmed in source: `ScannerPreviewCanvas` rotates the image and its crop/quad overlay together, so stored coordinates still refer to the unrotated image. `DartImageProcessor._executeHighResProcessing` instead rotates the bitmap first, then applies the unchanged normalized quad or rectangle. `ImageAdjustments.rotateRight/Left` does not transform those coordinates. A noncentral selected region therefore moves to a different physical region at export; dimensions can also change incorrectly. Affects both scanner perspective crop and ordinary image rectangular editing.

Reproduce: select the upper-left part of a four-color image, rotate right and export. Expected: the selected upper-left content, rotated. Actual: a different region from the rotated bitmap. Fix direction: apply geometry in source coordinates before rotation, or transform all saved geometry consistently. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.


Resolution: Rectangle crops and perspective quads now apply in oriented source coordinates before rotation in both processing paths. Four-rotation pixel regressions preserve the selected red region and output orientation.

Validation: 5 processor/dewarp tests passed. Flutter analysis clean. No full suite ran.

### IS-02 — P2 — Applied crops are absent from review previews (OPEN)

Confirmed in source: `ScannerPreviewCanvas` only reads `adjustments.crop` inside the interactive overlay when `isCropMode` is true; it never clips/renders the selected crop in review. `DocumentScannerScreen._buildActivePageCanvas` does not pass `page.documentQuad` at all. Applying either crop returns to the full uncropped photo, while final processing does apply the geometry. The scanner can also auto-select a quad without showing the resulting exported framing.

Reproduce: select a half-page crop, Apply, inspect review and save. Expected: review shows the saved framing. Actual: full original framing in review, cropped final image. Fix direction: maintain a bounded geometrically transformed preview and share its coordinate contract with crop editing. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-03 — P1 — Fine-tune preview and saved pixels use different color transforms (OPEN)

Confirmed in source: `ImageAdjustments.toColorMatrix` uses additive brightness (`brightness * 128`) and asymmetric contrast (up to 2.5x). Both CPU image-processing paths instead use multiplicative brightness (`1 + brightness * 0.6`) and package:image contrast at `100 + contrast * 70`. These operations are mathematically different, so the exported PDF/image cannot match the preview. Positive brightness on black pixels is a direct counterexample: preview lifts black; export multiplication leaves it black.

Reproduce: Original mode, brightness +1 on a dark image, Apply/save. Expected: the preview's pixel values. Actual: substantially darker saved image. Fix direction: use one specified color transform across GPU preview and CPU export. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-04 — P1 — Desktop Save Image reports success without writing the file (OPEN)

Confirmed in source: `ImageViewerModal`'s `handleSaveImage` passes bytes to `FilePicker.saveFile`, then shows success for any non-null path without writing bytes. The desktop file-picker API returns a destination path; the caller must write the image. This is the same contract already handled in the repository's PDF/ZIP export fixes. Affects Linux/macOS/Windows Save Image, including overwrites.

Reproduce: Save Image to a desktop destination. Expected: exact image bytes at that path. Actual: success UI with missing file or unchanged previous file. Fix direction: write and flush the returned desktop path, handle cancellation/empty paths and surface write failures; retain mobile picker ownership. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-05 — P1 — Scanner/image-edit preparation performs full-resolution work on the UI isolate (OPEN)

Confirmed in source: `DartImageProcessor.createPageRepresentations` is declared `async` but has no await or isolate dispatch. It synchronously decodes the full source, bakes orientation, resizes twice and JPEG-encodes twice before returning its Future. Both scanner import/capture and Edit Image call it on the UI isolate. The neutral `processHighResolution` fast path also decodes synchronously before deciding whether to launch compute, so large Original pages are decoded twice. An asynchronous signature alone does not make this background processing.

Reproduce: import a large camera photo or enter Edit Image while observing the event loop. Expected: interactive UI while preparing bounded previews. Actual: timer/frame callbacks cannot run until the synchronous work finishes. Fix direction: move preparation and fast-path decisions to a worker isolate, with bounded concurrency. Measured confirmation: `evidence/flutter-preparation.json` and `evidence/final-audit-probes.log`; do not interpret widget/JIT timings as release device FPS.

### IS-06 — P1 — Late automatic corner detection overwrites manual crop edits (OPEN)

Confirmed in source: `_processAndAddPage` launches `_detectQuad` without awaiting it. On completion `_detectQuad` locates the page by ID and unconditionally writes `result.quad`, even if the user has since opened adjustments and committed manually chosen corners or Use Full Page. The page ID check prevents edits to a deleted page but does not protect newer edits on the same page. A silent late replacement changes the saved framing.

Reproduce: delay initial detector, open adjustments, choose Use Full Page and Apply, then let the original detector finish. Expected: the user's later decision wins. Actual: detected corners replace it. Fix direction: track page geometry revisions or cancel/invalidate pending detection when the user edits. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-07 — P2 — Landscape scans export on the wrong page aspect ratio (OPEN)

Confirmed by real `DefaultPdfGenerator` output parsed with Syncfusion: a 240×160 scan (aspect 1.5) produces an 841.9×595.3 PDF page (aspect 1.4142857). All landscape inputs use fixed landscape A4, while portraits match source aspect. The image is contained, so content survives, but extra blank margins appear and exported page geometry violates the matching-aspect contract. `PdfBuilder` has the same branch, but the tested production path is `DefaultPdfGenerator`.

Reproduce: save a landscape photo/receipt, inspect PDF MediaBox. Fix direction: derive landscape page height/width from the actual image aspect as for portraits. Evidence: `probes/pixel_probe.dart`, `evidence/final-audit-probes.log`.

### IS-08 — P1 — Compression silently destroys animated GIFs (OPEN)

Confirmed with a two-frame GIF through the real compression isolate: input 1,999 bytes, output 1,009 bytes, `wasCompressed=true`, MIME `image/jpeg`, output frame count 1 instead of 2. `_compressImageInIsolate` decodes animation but routes every non-alpha-PNG input to single-frame JPEG. A second reproduction uses a four-frame >500KB GIF through normal threshold-based compression without force; it also emits one frame (see final log). GIF is an accepted editor image type.

Reproduce: choose Compress for an eligible animated GIF (or force compression in the service). Expected: preserve animation or explicitly offer flattening. Actual: silent static replacement. Fix direction: bypass unsupported animations or preserve their frames/timing. Evidence: `probes/pixel_probe.dart`, `evidence/final-audit-probes.log`.

### IS-09 — P1 — Inline plaintext image cache bypasses subsequent lock checks (OPEN)

Confirmed in source: `QuietAssetImageView` keeps decrypted bytes in private static `_globalBytesCache`; every hit in init/update/load renders immediately without consulting the attachment service/key manager. No cache clearing or lock/session scoping exists anywhere in this file. After a previously loaded image is unmounted and the vault is locked, a fresh widget can still display its cached plaintext instead of the service's locked state. This confirms a component-level lock bypass; full application lock-screen reachability is a separate question, not asserted here.

Reproduce: load an encrypted asset, unmount, lock/revoke access, remount the same asset. Expected: locked placeholder, no plaintext. Actual: bytes reused without a resolve call. Fix direction: session-scoped cache with explicit invalidation on lock/logout and access checks on cache hits. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-10 — P2 — Inline image byte cache has no memory bound or eviction (OPEN)

Confirmed in source: both static maps in `QuietAssetImageView` only grow; decoded widgets can unmount, but every visited source's original encoded byte buffer remains strongly retained for the process lifetime. There is no count/byte cap, LRU eviction, or clear method. This is outside Flutter's bounded ImageCache, so its normal eviction does not release these source buffers. A library of 1,000 visited 5MB photos retains about 5GB of encoded data alone (illustrative arithmetic, not a measured allocation).

Reproduce: sequentially mount/unmount many unique large image assets, revisit an early one after other widgets/cache entries are evicted. Expected: bounded retained data/reload of evicted entries. Actual: every old source is still served from the static map. Fix direction: account for source bytes in a bounded session cache; include retained-memory checks. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-11 — P1 — Late inline-image loads overwrite the current widget's source (OPEN)

Confirmed in source: `QuietAssetImageView.didUpdateWidget` starts `_loadImage` when its asset/URL changes. An older in-flight `_loadImage` checks only `mounted` after await; it does not compare source identity or request generation. When a widget is reused for B while A is pending, A can finish after B and install A's pixels/dimensions under B's current UI and actions. Affects async encrypted-asset resolution and network requests.

Reproduce: reuse one widget from A to B; complete B first, A second. Expected: B remains displayed. Actual: A replaces it. Fix direction: per-load generation tokens and source snapshots checked before state/cache updates. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.

### IS-12 — P2 — A gallery result after scanner disposal calls setState on a dead screen (OPEN)

Confirmed by delayed native-picker callback in the scanner widget: open import, remove the route, then complete the picker with a valid page. `_importPageFromGallery` enters `_processAndAddPage`, which calls `setState` before any `mounted` check. The enclosing gallery catch swallows the exception and logs `setState() called after dispose()`; it does not crash the process in this reproduction. Capture/read callbacks have the same missing pre-processing lifetime guard.

Expected: ignore the late result after cancellation. Actual: attempted mutation of disposed state and diagnostic error. Fix direction: check mounting after picker/camera/file awaits and cancel or invalidate session jobs on disposal. Evidence: `probes/widget_probe.dart`, `evidence/final-audit-probes.log`.

### IS-13 — P2 — Opening a preloaded network image triggers a build-phase setState error (OPEN)

Confirmed while executing Save Image probes with `ViewerImageItem(url: ..., initialBytes: ...)`: `_ViewerImagePageState.initState` synchronously calls `_loadImageAndOcr`; the preloaded network path has no await before `widget.onOcrStateChanged()`. The parent callback calls `setState` on `ImageViewerModal` while PageView is building its child. Flutter reports `setState() or markNeedsBuild() called during build`. Inline network images use preloaded bytes when opening the viewer, making this an ordinary entry path. The page remains visible in this debug reproduction; a total viewer failure is not asserted.

Fix direction: defer parent notification until after the frame or make initial child state available without a parent mutation during build. Evidence: baseline exception stack points to `image_viewer_modal.dart:437`, `:688`, and `:575`; the explicit widget probes assert and record the diagnostic.

### IS-14 — P2 — Press-and-hold ORIGINAL still shows the selected scanner mode (OPEN)

Confirmed in source: the adjustment sheet and scanner pass mode-baked bytes into `ScannerPreviewCanvas`. Long press only changes `ImageAdjustments` to neutral; it continues rendering the same `widget.previewBytes`. For B&W Text/Grayscale, color and threshold detail have already been removed before the canvas receives the bytes. The ORIGINAL badge therefore compares manual tone knobs against the selected mode, rather than showing the original capture.

Reproduce: select a monochrome mode on a colorful photo and hold the preview. Expected: original color photo while held. Actual: monochrome image remains under ORIGINAL. Fix direction: pass a separate original preview buffer and swap bytes during comparison. Executable confirmation: see `probes/pixel_probe.dart` or `probes/widget_probe.dart` and `evidence/final-audit-probes.log` for the matching IS ID.


## Validation and replay

The committed probes are **historical characterization tests**, intentionally
asserting current defects (wrong pixel/bytes/state) rather than desired fixed
behavior. They are outside normal test discovery. A future fix should add
permanent acceptance tests under `test/` and update the relevant finding.

Run from the repository root:

```sh
flutter analyze
flutter test --no-pub --concurrency=1 test/scanner test/image_processing test/attachments/image_viewer_modal_test.dart test/attachments/quiet_asset_image_view_test.dart test/attachments/image_dimension_reader_test.dart test/attachments/image_layout_calculator_test.dart test/editor/editor_image_upload_compression_test.dart test/editor/image_compression_dialog_test.dart
flutter test --no-pub --concurrency=1 handoff/audits/images-scanner-2026-11-17/probes/pixel_probe.dart handoff/audits/images-scanner-2026-11-17/probes/widget_probe.dart
dart run handoff/audits/images-scanner-2026-11-17/probes/pipeline_benchmark.dart
```

- Existing relevant tests: **114 passed**, [raw output](evidence/relevant-tests.log).
- Audit probes: **16 passed**, [raw output](evidence/final-audit-probes.log).
  IS-01 has separate rectangle/quad cases; IS-04 has new-file/overwrite cases;
  IS-08 has forced-small and ordinary eligible-GIF cases. The save cases also
  assert IS-13's caught build error. IS-12's caught application diagnostic is
  retained, while camera MissingPluginException exercises the intended fallback.
- Static analysis: `flutter analyze --no-pub`: **no issues**, [raw output](evidence/flutter-analyze.log).
- No full suite, build/deploy, real notes, cloud writes or device camera capture.

Passing controls: bounded 600px previews and 200px thumbnails, existing
geometry/detector/overlay and dewarp regressions, PDF validity/order tests,
transparent-PNG compression, dimension/layout tests and existing import-dialog
cancel/keep/compress flows. Native PDF handling already understands JPEG EXIF
orientation; the neutral raw-byte fast path is not claimed to corrupt PDF
orientation. Live corner tracking was explicitly out of scope in the scanner
spec and is not counted as an audit bug.

## Performance results

Environment: Flutter 3.47.2 / Dart 3.13.2 on Linux x64, AMD Ryzen 3 7330U (8 logical CPUs). [Runtime and CPU](evidence/environment.json), [raw VM output](evidence/dart-vm-performance.log), [all VM samples](evidence/dart-vm-performance.json), [Flutter preparation samples](evidence/flutter-preparation.json). The final VM run was serialized after the test runs; this remains a shared workstation with uncontrolled background/thermal conditions.

The real `createPageRepresentations` call on a synthetic 4000×3000 JPEG (2,091,326 bytes) took **924.6–1025.8 ms synchronously**, median **947.8 ms**. The queued event-loop callback could not run before return. Output preview/thumbnail were correctly bounded at 600px/200px. Fixture generation and warm-up are outside the timed interval; measurements use Flutter test/JIT, not a native release build.

Actual production `ScanPipelines.apply` plus JPEG quality-85 encoding, pure Dart VM JIT, five samples per cell; median milliseconds:

| Mode | 600×450 | 1600×1200 | 2048×1536 |
| --- | ---: | ---: | ---: |
| original | 29.8 | 130.4 | 211.2 |
| auto | 628.1 | 2505.3 | 3924.9 |
| document | 455.6 | 1301.6 | 1930.9 |
| whiteboard | 529.7 | 1828.0 | 2827.9 |
| grayscale | 97.5 | 619.0 | 1005.0 |
| blackAndWhite | 933.6 | 2827.2 | 4194.8 |

Sequential Auto-mode JPEG decode → pipeline → JPEG encode at 1600×1200 (one measured batch per page count):

| Pages | Total ms | Output bytes |
| --- | ---: | ---: |
| 1 | 2732.4 | 196,706 |
| 5 | 13453.6 | 983,530 |
| 10 | 26894.1 | 1,967,060 |

The VM process peak RSS was **367.0 MiB**; this includes the VM/JIT, image buffers and GC effects, and is not an allocation attribution or leak measurement. Raw samples include per-case before/after RSS and a five-sample p95 (with five observations this nearest-rank value is the maximum). Multipage batches release intermediate processing results rather than retaining the scanner UI page graph, so these are CPU-cost measurements, not full-session peak-memory tests.

The heavy modes take substantially more CPU time than Original/Grayscale in this workload. They already run in background isolates in the scanner mode-rendering/export paths; these numbers are not UI frame stalls. IS-05 identifies the distinct full-source preparation/neutral-fast-path work that still executes synchronously. The lower-level VM benchmark excludes isolate startup/transfer, camera/picker, detector/dewarp, PDF layout, encryption, storage, OCR and display rendering; no end-to-end save latency or mobile/release FPS is inferred.

## Limits

Flutter probes run with the test engine on Linux; widget tests inject native
picker results, controlled asset/detector completions and preloaded bytes.
They do not automate a real desktop picker or camera. File-picker's installed
Linux implementation was inspected to confirm it returns the selected path
without consuming `bytes`. Existing and new probes use synthetic temporary
files/data only. The cache-access finding is demonstrated at the component
boundary, not as an authenticated app lock-screen exploit. The 200-source cache
check proves retention/reuse and source inspection proves absence of a cap;
it does not measure multi-GB heap growth. RSS values belong to the pipeline
benchmark process and do not measure the inline widget cache.

Physical Android/iOS, sensor orientation, app background/resume with a camera,
permission revocation, GPU/raster frame rates, native release performance,
long-running thermal/memory pressure, real-document detector quality and OCR
model accuracy/latency remain unverified. No claim of exhaustive bug absence.
