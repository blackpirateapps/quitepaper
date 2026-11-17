# PDF viewer audit — November 16, 2026

Branch: `audit/pdf-viewer-stress-2026-11-16`. Application source: `5d869e9`.
**Remediation: 1/10 fixed; 9 open.**

Prioritize PDF-03 and PDF-04: both lose annotations after reopening. Findings
were appended immediately when confirmed; this report consolidates those notes.
PDF-02 was a suspected reload issue and is explicitly ruled out below.

## Findings and priorities

| ID | Severity | Finding | Evidence scope |
| --- | --- | --- | --- |
| PDF-03 | High | Editing during a pending save loses the newer annotations | Native Save/Back; injected storage delay; real encrypted save/reopen |
| PDF-04 | High | Back exits after failed autosave and loses annotations | Native Back; injected storage failure; reopen |
| PDF-01 | Medium | In-flight thumbnails survive deletion and return stale images | Deterministic gated service probe |
| PDF-06 | Medium | Long-PDF sidebar fails to keep the selected page visible | Native 250-page observation and isolated widget layout probe |
| PDF-07 | Medium | Invalid PDF displays a blank canvas with no error/retry message | Native malformed-byte fixture |
| PDF-08 | Medium | Narrow mobile toolbar overflows and hides document title | Android-themed widget probe, 320–600 logical pixels |
| PDF-09 | Medium | Long-PDF navigation with sidebar open stalls for seconds | Native Linux debug stress; sidebar-closed control |
| PDF-10 | Medium | Cancelling Save still creates a PDF in Downloads | Real viewer action; fake cancelled picker; temporary Downloads |
| PDF-11 | Medium | Existing file is not overwritten despite a success message | Real viewer action; desktop-style picker; temporary existing file |
| PDF-05 | Low | Header keeps an incorrect page total after the PDF loads | Native fixture with deliberately stale metadata |

## Method and evidence

Two isolated native Linux processes opened the real `DocumentViewerScreen` in a
1180×680 desktop test window. They used real Syncfusion/PDFium rendering, the
real document service, Drift in-memory metadata, real encrypted `.qpd` storage,
and the real encrypted thumbnail service. All keys and documents were synthetic;
XDG directories and document storage were temporary. SharedPreferences was mocked.
A service subclass injected only the save delay/failure for adversarial cases.
The installed app's notebook and user Downloads were not used.

Fixtures: four-page vector PDF, 250-page vector PDF (328.2KB), 12-page mixed
portrait/landscape PDF, three-page scan-like PDF with no text layer, a four-page
PDF with stale one-page metadata, and a 27-byte malformed PDF. The scan-like
fixture contains a drawn gray rectangle, not an actual scanned-photo workload.

The harness exposes a loopback-only inspection/control endpoint. Native pointer
and keyboard input exercised menus, zoom, search, layout, annotation tools,
undo/redo, save, Back, and revert. Deterministic page jumps and annotation batches
use the real public viewer controller; they are not claimed as manual pointer
drawing. Text highlighting drag attempts were inconclusive (see limits).

- **58 recorded native snapshots:** 28 in phase 1 and 30 in phase 2. Counts include
  calibration, controls and excluded attempts, not 58 independent passing tests.
- **36 simultaneous native thumbnail requests:** 36 non-null results in 881ms on
  the mixed 12-page PDF; some requested pages were cached. This is not a claim
  of 36 uncached unique raster operations.
- **100-annotation native stress:** 10 Undo and 10 Redo clicks produced 90 then
  100 annotations; encrypted save/reopen retained all 100; revert/reopen retained
  zero. Four additional native open/Back cycles passed.
- **2,500-request automated stress:** 250 unique pages, exactly one render per
  page, 250 encrypted disk reloads with no new renders, and settled deletion.
  This test uses a fake renderer; it measures service concurrency/integrity,
  not PDFium performance or validity of image decoding.
- Native zoom reached/clamped at 100% and 500%. Small-PDF search cycling,
  missing-query `0 results`, and single/continuous layout switching passed.
  Large-PDF search reached `1 of 250`, then `9 of 250` after eight Next clicks.

Start with `phase1-summary.jsonl` and `phase2-summary.jsonl`. Compressed
`phase*-native-results.jsonl.gz` preserve full widget labels/geometry, controller
annotation lists, save events, errors and frame timing samples. `after-stall.json`
preserves recovery state/frame samples; `native-control-timings.json` transcribes
the recovery/control request measurements from driver stdout. Screenshots contain only synthetic documents.
`*-probes.jsonl` preserve service, sidebar, mobile layout and export observations.
Probe/harness sources are retained as `.dart.txt`, outside the executable test
suite. Their successful execution means observations were recorded; it does not
mean their expected application behavior passed. Native scripts retain failed
assertions and driver limits for transparency.

## Validation

`flutter analyze --no-pub`: **no issues found**, recorded in `final-analyze.log`.
All **48 focused tests passed** across these files (`final-tests.log`):

- `test/documents/document_viewer_zoom_test.dart`
- `test/documents/document_viewer_thumbnail_test.dart`
- `test/documents/document_viewer_text_selection_test.dart`
- `test/documents/document_viewer_ocr_menu_test.dart`
- `test/documents/pdf_thumbnail_service_test.dart`
- `test/documents/pdf_thumbnail_stress_test.dart` (new durable stress coverage)
- `test/documents/pdf_raster_policy_test.dart`
- `test/documents/annotation_text_selection_test.dart`
- `test/documents/annotation_models_test.dart`
- `test/pdf/syncfusion_pdf_page_renderer_test.dart`

The baseline 47 tests passed before the new stress test. Log review identified
four Drift multiple-database warnings in the existing OCR viewer fixture. Its
annotation resolver is now mocked, its PDF fixture is valid, and 600ms pumps
complete Syncfusion's 500ms startup timer. The final run has no Drift warnings;
`pre-isolation-tests.log.gz` and `isolation-intermediate-tests.log.gz` preserve the
warning and startup-timer investigation (read with `gzip -dc <file>`). Text logs have only trailing whitespace
stripped for clean Git diffs. **No full suite ran.**
Native exception arrays were empty in all recorded snapshots. The malformed PDF
reported a PDF load failure through its callback, and the injected save failure
appears in debug output; neither is a Flutter framework exception. The mobile
320px observational probe caught the expected 16px RenderFlex overflow and logged
it as a finding. These distinctions matter when reading the passing test counts.

## Limits, controls and excluded observations

- **PDF-02 ruled out:** dirty Reload retained the annotation; after full settling,
  normal Back autosave and reopening retained it too. No reload-loss bug is claimed.
- Some native overflow-menu attempts failed to activate or select the intended
  item. These driver/targeting attempts are excluded. Initial stress scripts
  stopped at a timeout or failed assertion; later checks count only when they
  were separately replayed and recorded.
- Large-document search streams partial counts. An early `1 of 8` observation
  preceded its eventual `1 of 250` result; the premature assertion is excluded.
- Two native text-highlight drag probes did not create an annotation; valid text
  hit-testing/gesture targeting was not established. These are inconclusive,
  not a confirmed highlighting bug or passing end-to-end selection coverage.
  Native sticky-note placement succeeded. Existing selection-related tests pass.
- One initial export probe hung on filesystem setup inside Flutter's fake clock
  and was interrupted. The corrected isolated probe passed and both export
  observations were repeated; the final run also observed the overwrite success
  notification after clearing the previous snackbar.
- Physical Android/iOS, release/profile performance, real scanned-photo PDFs,
  password-protected PDFs, printing, system share dialogs, OCR engines, hyperlink
  navigation, and accessibility/screen readers were not exercised. The native
  environment emitted portal/accessibility warnings; no screen-reader claim is made.
- The first Linux build emitted existing whisper_ggml C++ deprecation warnings.
  Static analysis and focused Flutter test results are reported independently.

Both isolated native process groups were closed. Temporary executable audit
entry points/probes were removed after archiving. The ordinary `lib/main.dart`
Linux build is restored; its result is retained in `normal-build.log`.

## PDF-01 — deleting thumbnails does not cancel in-flight generation

**Fixed. (November 17, 2026). Medium. Deterministic service-level race probe.**

Resolution: Thumbnail requests carry a document generation. Deletion invalidates old renders, drains pending writes, and gates replacement requests until disk cleanup completes. Gated regressions verify replacement bytes, encrypted reload, and no recreation of deleted-document directories; all eight relevant cache tests pass.

Verification: `flutter analyze` and `flutter test test/documents/pdf_thumbnail_invalidation_test.dart test/documents/pdf_thumbnail_service_test.dart test/documents/pdf_thumbnail_stress_test.dart` passed. No full suite ran.

Start rendering a thumbnail for source A and hold the renderer before completion.
Call `deleteThumbnails(documentId)`, then request the same page for replacement
source B. Release A. The replacement receives A's image (last byte 1, expected 2),
only one render runs, and the deleted encrypted cache directory is recreated.
`deleteThumbnails` removes memory/disk entries but retains `_inFlightJobs`;
the old completion repopulates memory and persists the stale image. This can
undo annotation-save/revert invalidation or recreate deleted-document thumbnails.
Native timing of this race remains unmeasured; the injected gate makes its
ordering deterministic. Evidence: `thumbnail-probes.jsonl`, probe source.

## PDF-03 — edits during a pending save are lost and marked clean

**Fixed. (November 17, 2026). High. Delayed-storage native save and reopen.**

Resolution: Annotation saves share a pending snapshot and track mutation revisions. Completing a save retains newer live annotations and dirty state; export uses the same serialized save path. The delayed-storage regression reopens the final PDF and verifies both annotations.

Verification: `flutter analyze` and `flutter test test/documents/document_viewer_save_test.dart` passed. No full suite ran.

Add note A, start Save Annotations, then add note B before the storage write
finishes. Both notes exist during the pending save. When the older snapshot
finishes, the save handler clears dirty state and replaces the viewer source
with that snapshot. Reopening contains only A: B is lost without a warning.
The storage delay is injected (3 seconds); serialization, annotation events,
real encrypted writes, Save click and Back click use production code. Root:
`_manualSaveAnnotations` unconditionally clears `_isDirty` and installs its
captured bytes after awaiting storage, without a mutation generation check.
Evidence: native results `Delayed manual save` through `Reopen after editing`.

## PDF-04 — Back closes the viewer after a failed annotation save

**Fixed. (November 17, 2026). High. Native Back, injected storage failure, reopen.**

Resolution: Back now waits until all annotation revisions are stored before closing. A storage failure keeps the viewer and edits open with a Retry action; repeated Back requests share the exit operation. Tests cover failure/retry and Back during a delayed save with newer edits.

Verification: `flutter analyze` and `flutter test test/documents/document_viewer_save_test.dart` passed. No full suite ran.

Add an annotation, make storage fail, and press Back. The viewer closes despite
the failed save; reopening has zero annotations. The failure appears only in
debug output, with no retry/discard prompt. Real viewer annotations and native
Back input were used; a FileSystemException was injected at the storage boundary.
The PopScope callback always calls Navigator.pop after `_autoSaveIfDirty`, whose
catch logs and swallows the error. It never verifies that dirty state cleared.
Evidence: native results `One dirty annotation before Back` through `Reopen
after failed exit autosave`, runtime log injected failure.

## PDF-05 — header keeps stale page totals after PDF load

**Open. Low. Stale-metadata fixture.**

Open a four-page PDF whose stored pageCount is 1 and jump to its fourth page.
Syncfusion reports four pages and the sidebar shows four, but the header reads
`Page 4 of 1 (1 page)`. `onDocumentLoaded` updates `_pageCount`; the header instead
reads `docInfo.pageCount`. This fixture deliberately injects stale metadata;
a normal import creating incorrect metadata was not established. Evidence:
native results `PDF actual page count` and `Navigate actual fourth page`.

## PDF-06 — large-document sidebar scrolls away from the active page

**Fixed. (November 17, 2026). Medium. 250-page widget probe and native observation.**

Resolution: The sidebar uses a fixed list item extent derived from its width and scaled label height, shared by tile layout and selected-page scrolling. All eight relevant tests pass, including 250-page jumps at three widths and two text scales with full selected-tile visibility.

Verification: `flutter analyze` and `flutter test test/documents/pdf_thumbnail_sidebar_test.dart test/documents/document_viewer_thumbnail_test.dart` passed. No full suite ran.

Set the active page to 125 in a standard 140px thumbnail sidebar. The selected
tile is outside the visible viewport after scrolling settles. Native random
jumps also showed page 125 in the header while the sidebar displayed pages
118–124. `_onActivePageChanged` assumes 195px per item; actual tiles occupy
about 201.25px, so the position error grows with page index. The widget probe
uses null thumbnail images to isolate layout; native rendering uses PDFium.
Evidence: `sidebar-probes.jsonl`, `250 page random jump 125` native record.

## PDF-07 — malformed PDFs leave a blank viewer with no error or retry message

**Fixed. (November 17, 2026). Medium. Native Linux invalid-PDF fixture.**

Resolution: Syncfusion load failures now set a visible document error, remove the blank viewer and zoom controls, and hide misleading page context. Try Again resolves and initializes the document afresh. The load-failure/retry regression and three annotation-save regressions pass.

Verification: `flutter analyze` and `flutter test test/documents/document_viewer_loading_test.dart test/documents/document_viewer_save_test.dart` passed. No full suite ran.

Open the synthetic encrypted document containing `%PDF-1.7` followed by invalid
data. Syncfusion reports a load failure and zero pages, but the app continues to
display a blank canvas, zoom controls and `Page 1 of 1`. No error or retry message
appears. The `onDocumentLoadFailed` callback only calls debugPrint and never
sets an error state. The fixture deliberately injects malformed bytes through
the document service; a normal import accepting this file was not established.
Evidence: `native-corrupt-pdf.png`, `Corrupt PDF after loading settles` snapshot,
phase 2 runtime log. A native PDF load callback failure is distinct from a
Flutter exception, so the captured exception array remains empty.

## PDF-08 — narrow mobile toolbar has no room for the document title

**Open. Medium. Android-themed widget layout probe; physical mobile untested.**

At 320 logical pixels, a RenderFlex overflows by 16 pixels. At both 320 and
360 logical pixels, the PDF toolbar's always-visible actions consume the
available width and the document title has zero width. The title and page-count
context are not readable. This probe uses the real viewer widget with a fake
document resolver, not an Android device. Evidence: `layout-probes.jsonl` and
the retained layout probe source. The title is only 22px wide at 390px; it has 232px at 600px.

## PDF-09 — large-document random navigation produces multi-second stalls

**Open. Medium, native Linux debug performance scope.**

On the synthetic 250-page, 328KB text PDF, the random-jump sequence
2 → 125 → 200 → 50 → 249 stopped when the audit state endpoint exceeded its
15-second response timeout. A subsequent state request took 15.75 seconds.
Flutter FrameTiming samples included total frame spans of 9.67 and 17.49 seconds;
no Flutter exception was captured. The initial sequence did not finish, so its
later stress checks are not counted as passing. Native sample timings include
instrumentation and debug overhead; release behavior is unmeasured. A later control in the fresh second process, with the sidebar closed, completed
five jumps (125, 200, 50, 249, 1) in 0.98–1.04 seconds each, including 950ms of
intentional waits. This implicates sidebar work but does not establish a precise
root cause. The likely
interaction between thumbnail generation and large scroll jumps needs profiling;
no precise root cause has been proven. Evidence: `native-stress-initial.log`,
`after-stall.json`, native snapshots and timing samples.

## PDF-10 — cancelling Save PDF still writes a file to Downloads

**Open. Medium. Real viewer action with cancelled picker and isolated filesystem.**

Click Save PDF to storage and cancel the file picker (returns null). The viewer
continues into its fallback and writes the PDF to Downloads anyway, then shows
a saved notification. The probe redirects Downloads to a temporary directory
and confirms the file exists after cancellation. `_savePdfToStorage` treats a
cancelled picker like an unavailable picker; it should return on cancellation.
Evidence: `export-probes.jsonl`, `cancel-pdf-save`. No user Downloads were touched.

## PDF-11 — saving over an existing nonempty PDF reports success without writing

**Open. Medium. Real viewer action with path-only picker response.**

Save to an existing nonempty file and confirm its replacement in a desktop-style
picker. The viewer reports Document saved, but the existing bytes are unchanged.
`_savePdfToStorage` writes only when the selected file does not exist or is empty.
The probe returns an existing temporary path without writing bytes, matching
desktop path-only pickers, and confirms the unrelated content survives unchanged.
Evidence: `export-probes.jsonl`, `overwrite-existing-pdf`. The installed Linux FilePicker implementation returns a path and ignores its
bytes argument, matching this simulation. Platform picker behavior was simulated; no native overwrite dialog or user file was used.
