# Quiet Paper — Engineering Handoff Document

Welcome to **Quiet Paper**! This repository is an offline-first notes application inspired by the calm, distraction-free writing experience of Bear Notes and iA Writer, equipped with zero-knowledge end-to-end encrypted cloud synchronization.

> [!NOTE]
> The engineering handoff documentation has been organized into modular, domain-specific guides and versioned logs located in the **[`handoff/`](handoff/)** directory. 
> A complete, verbatim backup of the original 11,433-line document is preserved at [`handoff/backup/HANDOFF.original.md`](handoff/backup/HANDOFF.original.md).

---

## 1. Documentation Index & Modular Guides

All documentation is partitioned for fast, targeted access by engineers and AI agents:

| Guide / Document | Description & Key Topics |
| :--- | :--- |
| **[handoff/INDEX.md](handoff/INDEX.md)** | Master handoff directory, file map, and complete architectural overview. |
| **[handoff/core-architecture.md](handoff/core-architecture.md)** | Product vision, directory layout, crypto fundamentals, development commands, and security invariants (Sections 1–9). |
| **[handoff/sync-and-storage.md](handoff/sync-and-storage.md)** | Zero-knowledge E2EE (Argon2id + XChaCha20-Poly1305), Turso edge database, 3-way conflict merge engine, offline queue, and Drift SQLite persistence. |
| **[handoff/editor-and-typography.md](handoff/editor-and-typography.md)** | SuperEditor visual AST, editorial blockquotes with 3.5px accent bar & Enter continuation, LaTeX math syntax support (block formulas & Bear-style inline folding), smart todolist (optical alignment, auto-sort, collapsible done items), native code blocks with syntax highlighting, typewriter scrolling, and typography engine. |
| **[handoff/ocr-and-documents.md](handoff/ocr-and-documents.md)** | Scanned documents (`qp://document/<UUID>`), Syncfusion PDF viewer, Google ML Kit OCR, and desktop Ollama DeepSeek-OCR. |
| **[handoff/journal-and-audio.md](handoff/journal-and-audio.md)** | Daily journal, paper calendar archive, YAML frontmatter properties, audio voice memos, on-device transcription, and web clipper. |
| **[handoff/tags-and-search.md](handoff/tags-and-search.md)** | Nested tag hierarchy (`#parent/child`), Pure Bear List editorial aesthetic redesign (Sections 247 & 249), tag sync idempotency, universal fuzzy search & relevance ranking. |
| **[handoff/platform-and-builds.md](handoff/platform-and-builds.md)** | Multi-platform targets (Android, Linux, iOS, Desktop), CI/CD pipelines, automated build numbers, Linux packaging (DEB, RPM, AppImage, Flatpak), Linux native file sharing (`shareXFiles`), and first-run onboarding. |
| **[handoff/latest-logs.md](handoff/latest-logs.md)** | **Active engineering logs** for **v1.6.0+ (October 2026 – Present)**. New handoff entries should be appended here. |
| **[handoff/archive/logs-v1.5.md](handoff/archive/logs-v1.5.md)** | Historical engineering logs for **v1.5.0 through v1.5.9**. |
| **[handoff/archive/logs-v1.0-v1.4.md](handoff/archive/logs-v1.0-v1.4.md)** | Historical engineering logs for **v1.0.0 through v1.4.x**. |
| **[handoff/backup/HANDOFF.original.md](handoff/backup/HANDOFF.original.md)** | Unmodified, bit-for-bit verbatim backup of the pre-modularization document. |

---

## CI Flutter SDK baseline

All Flutter workflows pin **Flutter 3.47.2** (Dart 3.13.2), matching the SDK used
for local validation. Following the unpinned `stable` channel installed Flutter
3.50.0 in CI and caused 396 analyzer diagnostics, primarily Material library
deprecations. Keep the workflow pins aligned when deliberately upgrading the SDK;
see [engineering log 270](handoff/latest-logs.md#270-pin-the-ci-flutter-sdk-after-analyzer-drift-november-13-2026).

## Current App Release

The app release is **1.6.3+21**. Runtime fallbacks, the Linux CLI, packaging,
Windows resource fallbacks, and both public-site copies use **1.6.3**. CI continues
to derive build numbers from the Git commit count. See the
[version checklist](handoff/platform-and-builds.md#3-app-version-bump-checklist)
and [engineering log 277](handoff/latest-logs.md#277-release-version-bump-to-163-build-21-november-15-2026).

## Linux CI Async Test Stability

Image import tests now wait for the compression dialog or inserted attachment
instead of sleeping before settling an active progress spinner. Scanner viewer
and card tests wait for loaded page metadata while allowing native file I/O to
complete. These changes address the recent Linux workflow test failures; see
[engineering log 312](handoff/latest-logs.md#312-linux-ci-image-import-and-document-viewer-async-test-races-november-17-2026).

## Latest Linux CLI Work

The CLI supports encrypted image attachment, automatic Markdown image imports,
clipboard screenshots, attachment listing/opening, and independent note/image
upload retries. See [the CLI guide](handoff/platform-and-builds.md#linux-cli-image-attachments)
and [engineering log 269](handoff/latest-logs.md#269-linux-cli-encrypted-image-attachments-and-standalone-uploads-november-12-2026)
for commands, credential prerequisites, failure recovery and sync boundaries.

## PDF Viewer Stress Audit — Remediation

The [PDF viewer audit](handoff/audits/pdf-viewer-stress-2026-11-16/README.md)
against `5d869e9` found 10 confirmed bugs. **10/10 now fixed; 0 open.**
Each fix has its own commit, focused regression coverage, and resolution in the
audit report. Full-suite testing is excluded from this remediation.

Coverage includes two isolated native Linux test windows, 58 recorded snapshots,
a 250-page PDF, 100-annotation undo/redo/save/revert checks, 36 concurrent native
thumbnail requests, and a new 2,500-request thumbnail service stress test.
Native screenshots, raw records, probe sources and explicit limitations are in
the report. The suspected reload-loss issue was ruled out. The original audit ran only 48 focused
viewer/annotation/thumbnail/renderer tests; remediation validation is recorded per fix below.
No full suite ran. The existing
OCR test fixture now isolates annotation resolution and drains PDF startup work,
removing database warnings. See log 313.

## Checklist Stress Audit — All 12 Findings Fixed

All findings in the [comprehensive checklist audit](handoff/audits/checklist-stress-2026-11-16/README.md)
are fixed on `fix/visual-markdown-editor-input`, with a separate commit/push for
each bug. Visual checklist selection replacement, nesting, forward Delete,
Tag/Link Note markers, IME newline/composition, rapid native creation, paste and
long-list navigation are covered, as are Markdown compound-task continuation,
Super Editor nesting and Linux Home input.

[Native fix verification](handoff/audits/checklist-stress-2026-11-16/fix-verification/README.md)
preserves exact-content acceptance evidence for rapid 41-task creation, clipboard
paste/save/reopen, ten Down presses in 250 tasks, and Home after ordinary/folded
lists. All these native checks have zero Flutter runtime errors. Per-fix analysis
and relevant tests pass; the full suite is left to GitHub Actions. Physical mobile
and CJK input methods and release-mode performance remain unverified. See logs
299–310 for implementation and per-fix validation.

## Native Formatting Toolbar Audit

**Native re-audit fixes (2026-11-16): all 8/8 findings fixed and verified.**
Math preserves valid JSON and accepts immediate input; active-field mode switches
retain live controllers; native clicks synchronize the document caret; code
language selection and Markdown history restore focus; Tag and Link Note keep
their insertion carets and autocomplete works. Each finding has a separate fix
commit and resolution in the [tracked audit](handoff/audits/visual-markdown-native-2026-11-16/README.md).
[Native replay evidence](handoff/audits/visual-markdown-native-2026-11-16/fix-verification/README.md)
records all eight passing with no Flutter runtime errors. Analysis is clean and
52 relevant tests pass across per-fix runs; the full suite was left to CI.
Visual Math uses an editable math fenced block. See engineering logs 287–297.
The code-insertion focus failure reported at test line 172 matches the intermediate
caret changes, corrected in `74aa61a`; that test passes in the correction's
[GitHub test run](https://github.com/blackpirateapps/quitepaper/actions/runs/43818439696).
Current-branch follow-up checks pass all 37 tests in the two relevant editor files.

The four original Visual/Markdown toolbar audit findings were fixed. Divider
insertion focuses its continuation paragraph; Visual code insertion focuses the
code field and persists code/language edits; Visual toolbar and keyboard history
share document snapshots without observing disposed segment controllers; Markdown
code overlays preserve the text field and its input connection when fences appear
or disappear. Reproductions, regression coverage, original native audit scope and
sample artifacts remain in [`EDITOR_TOOLBAR_AUDIT.md`](EDITOR_TOOLBAR_AUDIT.md).
See engineering logs 281–285 in [`handoff/latest-logs.md`](handoff/latest-logs.md).

## Latest Visual and Markdown Editor Stability

Visual mode now retains text-field focus and caret positions around mixed lists,
resolves checklist edits by block ID, and transfers keyboard input into paragraphs
after leaving a checklist. Source selection changes no longer roll back pending
visual text. Markdown fields around tables retain their input connections, and
inline links preserve editing offsets. Native title-to-body and click-to-body
keyboard input passed on this laptop under Hyprland/Wayland in both modes. The
installed app was **1.6.2+456**; the fixed regular Linux debug build is in
`build/linux/x64/debug/bundle/`. See
[engineering log 279](handoff/latest-logs.md#279-visual-and-markdown-editor-focus-caret-and-linux-input-stability-november-15-2026).

## Latest Super Editor Polish

Super Editor smart checklists now preserve the Android keyboard and visible caret
when checking or folding items. Completed rows leave no hidden spacing, and
paragraphs below folded lists remain compact and left aligned. Rapid toggles,
undo/redo, and nested-list preservation are covered by regression tests; Markdown
preview checklists fill the page column instead of centering short lists. See
[engineering log 278](handoff/latest-logs.md#278-super-editor-smart-checklist-focus-folding-and-preview-alignment-november-15-2026).

Super Editor math now parses display formulas before CommonMark, preserves TeX
and internal blank lines, and recognizes math in keyboard and native-menu paste.
The math insertion menu retains its caret anchor and opens the formula input;
inline folding preserves document offsets and formatting during edits. See
[engineering log 276](handoff/latest-logs.md#276-super-editor-math-parsing-paste-insertion-and-editing-stability-november-15-2026).

Super Editor now separates the title and body with a themed divider. Submitting
the title places a visible caret at the beginning of the body, and empty editable
bodies display `Start writing...` until text is entered. See
[engineering log 271](handoff/latest-logs.md#271-super-editor-title-to-body-caret-divider-and-placeholder-november-15-2026).

Visual and Markdown modes now handle physical Enter and numpad Enter in the
title directly, placing the caret in the body so typing can continue immediately
on Linux. Mobile Next uses the same focus transition. See
[engineering log 275](handoff/latest-logs.md#275-visual-and-markdown-title-enter-focus-on-linux-november-15-2026).

## Latest Desktop and Tablet Search Workspace

The notes-list pull-to-search animation now keeps rows aligned with the sliding
card, commits on release, and accepts Back during opening. Search focus waits
until the slide finishes; pointer cancellation restores notes. A separate native
Linux test window exercised phone/tablet layouts with isolated sample data and
Wayland pointer drags. See the [swipe-search audit](handoff/audits/swipe-search-2026-11-17/README.md)
and engineering log 311 for evidence, coverage and mobile-device limits.

Search now uses compact results beside a read-only preview at widths of 600dp
and above, including portrait tablets. Search and category filters stay above
the results pane; a draggable divider resizes the panes. The first result previews
automatically, and Open/Edit actions open the selected item separately. See
[engineering log 273](handoff/latest-logs.md#273-desktop-and-tablet-search-results-and-preview-workspace-november-15-2026).

Search categories now use content-width underline tabs with result counts on
desktop, tablet, and mobile. See
[engineering log 274](handoff/latest-logs.md#274-search-category-underline-tabs-on-all-screen-sizes-november-15-2026).

Desktop toolbar and keyboard search now open immediately. The split pane retains
its height when the notes list is hidden, and disabling swipe-to-search no longer
disables explicit search actions. See
[engineering log 272](handoff/latest-logs.md#272-linux-search-opening-delay-and-collapsed-desktop-pane-november-15-2026).

## 2. Quick Architectural Reference

### Core Principles
- **Zero-Knowledge Encryption**: Note titles, bodies, tags, and document contents are encrypted client-side using `Argon2id` (19MB, 2 iterations, 16-byte salt) and `XChaCha20-Poly1305`. The cloud backend (Turso libSQL on Vercel) is crypto-blind and holds zero keys.
- **Offline-First Persistence**: Local SQLite via Drift (`AppDatabase`) is canonical on-device. Mutations queue in `SyncQueueTable` when offline and push automatically upon reconnect.
- **Visual Editor AST Source of Truth**: The visual editor (`SuperEditor`) uses an in-memory RichDocument AST as the source of truth, enabling zero-compilation autosaves without repeated markdown serialization.
- **Non-Destructive Storage**: Original PDFs, scanned documents, and web clipper HTML snapshots remain immutable in the encrypted vault.

### Core Testing & Development Commands
```bash
# Run Flutter unit and widget tests
flutter test

# Run Flutter static analysis
flutter analyze

# Regenerate Drift database and Riverpod models
dart run build_runner build --delete-conflicting-outputs

# Run backend tests (TypeScript / Vitest)
cd backend && npm test
```

---

## 3. Instructions for Future AI Agents

In accordance with [`AGENTS.md`](file:///home/dog/git/quitepaper/AGENTS.md):
1. **Always consult relevant domain guides** in [`handoff/`](handoff/) before implementing changes to avoid breaking established subsystem architecture.
2. **Log new engineering work**:
   - Append detailed entries to **[`handoff/latest-logs.md`](handoff/latest-logs.md)**.
   - Include: numbered section, motivation, architectural design, modified files, and test verification results.
3. **Keep domain guides updated**: If introducing a new architectural pattern or subsystem, update the corresponding file in [`handoff/`](handoff/).

### CL-01 checklist audit fix — Replace selected task text on Enter

Visual checklist Enter uses the ordered replacement range, preserving styled prefix/suffix spans and committing the split as one undo step. Forward and reverse widget regressions assert task text, focus selection and undo. flutter analyze: no issues; rich_text_checklist_editor_test.dart: 11 passed. Full suite left to GitHub Actions.

### CL-02 checklist audit fix — Preserve Visual task hierarchy

ChecklistItemBlock now stores indentation with backward-compatible JSON defaults. Parsing, serialization, copies, equality, Enter continuation and row padding preserve nesting and completion state. Regressions cover Markdown/JSON round trips and nested editing. flutter analyze: no issues; parser/serializer and checklist tests: 31 passed. Full suite left to GitHub Actions.

### CL-03 checklist audit fix — Join tasks with forward Delete

Forward Delete at a collapsed task-end caret merges the following task while retaining styled text, the current checkbox state, the join caret and one-step undo. Other Delete operations retain native text-field behavior. flutter analyze: no issues; rich_text_checklist_editor_test.dart: 13 passed. Full suite left to GitHub Actions.

### CL-04 checklist audit fix — Keep checklist toolbar markers and insertion caret

Checklist controller listeners now publish text edits and their selections even while the insertion menu owns focus; unfocused selection-only notifications stay ignored. Actual EditorScreen toolbar regressions verify Tag typing, Link Note autocomplete and saved rich JSON. flutter analyze: no issues; dual-mode editor and checklist tests: 37 passed. Full suite left to GitHub Actions.

### CL-06 checklist audit fix — Let IME confirm composition before splitting tasks

Hardware Enter no longer invokes checklist structure edits while the row has a nonempty composing range. The IME-channel regression checks unchanged content/composition, then verifies Enter resumes continuation after composition ends. Physical CJK keyboards remain outside this widget validation scope. flutter analyze: no issues; rich_text_checklist_editor_test.dart: 14 passed. Full suite left to GitHub Actions.

### CL-07 checklist audit fix — Continue quoted and numbered Markdown tasks

Markdown smart Enter recognizes checkbox markers inside quote and numbered prefixes, resets new tasks to unchecked and increments numbered tasks. Enter replacing a forward/reverse selection now deletes that range and preserves task continuation; regression cases cover compound prefixes and ordered delimiters. flutter analyze: no issues; markdown_smart_editing_test.dart: 14 passed. Full suite left to GitHub Actions.

### CL-08 checklist audit fix — Load nested Super Editor tasks without merging children

The math-aware Markdown loading and structured-paste boundary now parses each task row before CommonMark can fold descendants into one parent element. Each task retains independent text, inline formatting, two/four-space nesting and completion state. Parser round trips and actual Super Editor edit/save regressions cover the audited fixture. flutter analyze: no issues; smart-task and quiet-super-editor tests: 63 passed. Full suite left to GitHub Actions.

### CL-05 checklist audit fix — Turn platform newlines into checklist structure

Visual checklist IME updates split styled text into unchecked continuation tasks or exit an empty task into a paragraph. Multiline edits preserve neighbors and indentation, move focus/caret to the resulting block, and commit as one undo step. Widget IME-channel cases cover continuation, empty exit and multiline continuation/exit; physical phones remain untested. flutter analyze: no issues; checklist and Visual stability tests: 33 passed. Full suite left to GitHub Actions.

### CL-09 checklist audit fix — Preserve rapid native checklist input

Enter resolves live task models and moves the existing mounted TextField, controller and focus node into the continuation row. Linux splits on the ordered IME newline so hardware Enter cannot overtake earlier printable input; queued old-buffer updates are rebased after the split. Native 41-task creation now preserves every exact label, focus and persisted JSON, with zero Flutter errors; durable evidence is in fix-verification/cl09-native.jsonl.gz. flutter analyze: no issues; checklist and Visual stability tests: 35 passed; native rapid-creation acceptance passed. Full suite left to GitHub Actions.

### CL-10 checklist audit fix — Paste at the AST caret and replace selected tasks

Visual snippet insertion now splices parsed blocks into the AST selection, preserving styled prefix/suffix spans, checkbox/nesting metadata, unaffected block identities and the resulting caret. It replaces forward/reverse cross-task selections in one undo step. Native clipboard paste, delayed autosave and reopening now preserve the exact audited task order/state; evidence is in fix-verification/cl10-native.jsonl.gz. flutter analyze: no issues; rich controller and dual-mode editor tests: 43 passed; native paste/reopen acceptance passed. Full suite left to GitHub Actions.

### CL-12 checklist audit fix — Keep long-list arrow navigation responsive and focused

Task boundary navigation handles repeated keys, publishes the destination synchronously and transfers the existing input client between rows. Selection-only changes skip full-surface reconstruction and unchanged task spans are not invalidated. Native ten-Down navigation in 250 tasks now reaches Task 0010 at offset 9 with all labels exact and zero Flutter errors. Widget regressions inspect focus, caret and stable EditableText identity per event and navigate back to the start. flutter analyze: no issues; Visual stability, checklist and large-document tests: 39 passed; native 250-task navigation acceptance passed. Full suite left to GitHub Actions.

### CL-11 checklist audit fix — Consume Linux Home at the paragraph boundary

A dedicated Super Editor Linux keyboard plugin moves/extends the caret for plain Home and consumes the key even if it cannot move. This prevents the native IME from reinserting its synthetic prefix and paragraph buffer. Ctrl/Meta/Alt combinations retain existing handlers. Folded and nonfolded widget/native cases preserve exact Tail text, caret and saved Markdown; evidence is in fix-verification/cl11-native.jsonl.gz. flutter analyze: no issues; smart-task and quiet-super-editor tests: 65 passed; native folded/nonfolded Home acceptance passed. Full suite left to GitHub Actions.

### PDF-03 fixed — November 17, 2026

Annotation saves share a pending snapshot and track mutation revisions. Completing a save retains newer live annotations and dirty state; export uses the same serialized save path. The delayed-storage regression reopens the final PDF and verifies both annotations.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_save_test.dart`. No full suite ran.


### PDF-04 fixed — November 17, 2026

Back now waits until all annotation revisions are stored before closing. A storage failure keeps the viewer and edits open with a Retry action; repeated Back requests share the exit operation. Tests cover failure/retry and Back during a delayed save with newer edits.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_save_test.dart`. No full suite ran.


### PDF-01 fixed — November 17, 2026

Thumbnail requests carry a document generation. Deletion invalidates old renders, drains pending writes, and gates replacement requests until disk cleanup completes. Gated regressions verify replacement bytes, encrypted reload, and no recreation of deleted-document directories; all eight relevant cache tests pass.

Validation: `flutter analyze`; `flutter test test/documents/pdf_thumbnail_invalidation_test.dart test/documents/pdf_thumbnail_service_test.dart test/documents/pdf_thumbnail_stress_test.dart`. No full suite ran.


### PDF-06 fixed — November 17, 2026

The sidebar uses a fixed list item extent derived from its width and scaled label height, shared by tile layout and selected-page scrolling. All eight relevant tests pass, including 250-page jumps at three widths and two text scales with full selected-tile visibility.

Validation: `flutter analyze`; `flutter test test/documents/pdf_thumbnail_sidebar_test.dart test/documents/document_viewer_thumbnail_test.dart`. No full suite ran.


### PDF-07 fixed — November 17, 2026

Syncfusion load failures now set a visible document error, remove the blank viewer and zoom controls, and hide misleading page context. Try Again resolves and initializes the document afresh. The load-failure/retry regression and three annotation-save regressions pass.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_loading_test.dart test/documents/document_viewer_save_test.dart`. No full suite ran.


### PDF-08 fixed — November 17, 2026

Toolbars below 768 pixels keep annotation tools, unsaved-annotation Save, and Document options visible; secondary actions remain in that menu. Clean and dirty layouts retain readable title width at 320/360/390/600 pixels without overflow. Four layout and four OCR action tests pass; physical-device validation remains outside this run.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_layout_test.dart test/documents/document_viewer_ocr_menu_test.dart`. No full suite ran.


### PDF-09 fixed — November 17, 2026

Long jumps render only destination thumbnails; concurrent native renders share one PDF handle and dimension lookup, close on final release, and compress PNGs off the UI isolate. Native page sizes enforce the pixel budget without rescanning the PDF. All 18 focused tests pass. A fresh native Linux debug replay completes six jumps in 0.466–0.759s including 450ms intentional waits, with visible selected tiles and no Flutter errors; see fix-verification/README.md.

Validation: `flutter analyze`; `flutter test test/documents/pdf_thumbnail_sidebar_test.dart test/pdf/syncfusion_pdf_page_renderer_test.dart test/documents/pdf_raster_policy_test.dart`. No full suite ran.


### PDF-10 fixed — November 17, 2026

A normal null or empty picker response now returns immediately, with no filesystem fallback or saved notification. Only picker unavailability enters the Downloads fallback. Three isolated filesystem regressions cover both cancellation responses and successful fallback output.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_export_test.dart`. No full suite ran.


### PDF-11 fixed — November 17, 2026

Desktop picker destinations are now always written and flushed before reporting success, replacing and truncating existing content. Mobile native pickers continue to own writing their supplied bytes. Five export regressions verify exact output for new/existing files, both cancellation responses, and unavailable-picker fallback.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_export_test.dart`. No full suite ran.


### PDF-05 fixed — November 17, 2026

The header now uses the page total reported by the loaded PDF rather than stored metadata. A real four-page fixture deliberately reports one metadata page; navigation to page four shows Page 4 of 4. All nine related loading, save, and compact-layout tests pass.

Validation: `flutter analyze`; `flutter test test/documents/document_viewer_loading_test.dart test/documents/document_viewer_save_test.dart test/documents/document_viewer_layout_test.dart`. No full suite ran.

PDF remediation is complete: all ten fixes are pushed on
`audit/pdf-viewer-stress-2026-11-16`. The audit summary and per-finding statuses
are aligned at 10/10 fixed, and the ordinary Linux debug bundle is restored.

### PR #9 integration — November 17, 2026

Reconciled the PDF viewer remediation with current main while preserving the
completed checklist, search, and Linux CI fixes. The PDF audit is log 313; the
integration and combined-branch validation are recorded in log 314. The document
guide now reports all ten PDF findings resolved.


## Android Web Clipper Audit — November 17, 2026

The [Android web clipper audit](handoff/audits/android-web-clipper-2026-11-17/README.md)
records **16/16 fixed; 0 open**, with individual reports, resolutions and replayable evidence.
The initial ten cover snapshot image/CSS persistence, hidden snapshot failures,
ignored tag removals, canonical/redirect asset bases, stale browser state, wrong
image substitution, editor navigation after saving, and dropped repeated shares.

The [USB follow-up](handoff/audits/android-web-clipper-2026-11-17/usb-device-follow-up/README.md)
adds six: URL-dialog loading overflow, triplicated layout-table prose, documents
reduced to an index appendix, missing code figures, star-alt photo filtering, and
failed pages marked ready. Five new findings have physical-device/real-page
evidence; the star-alt finding is component-only. Actual WebView/save interaction
also confirms WC-09 and stale state confirms WC-07 on a Redmi K20 Pro, Android 16.
The original audit made no application changes. Subsequent remediation fixes all 16 findings; per-finding resolutions and regression validation follow below.

The original audit’s final `flutter analyze` was clean. Initial checks passed 42 clipper tests, 15 Quick
Capture tests and ten probes; the USB follow-up passes 23 relevant existing tests
and four focused probes, with concurrency 1. No full suite ran. Executable audit
sources were archived in Markdown and removed. Temporary Android build settings
were restored, and the separate audit app was uninstalled. The original installed
Quiet Paper and its notes were left untouched. Use USB and serialized builds for
replay: an earlier emulator/build attempt was stopped after a reported host crash.

### WC-01 Android web clipper fix

Saved snapshot image sources now contain vault URLs; the viewer decrypts and embeds image bytes in memory for offline rendering, removing competing srcset references.

Validation: flutter analyze: clean; 7 service, snapshot and image hydration tests passed. No full suite ran.

### WC-02 Android web clipper fix

Scan results retain prepared snapshot HTML, including inlined CSS, and saving reuses that HTML before rewriting downloaded image sources. The preview and saved snapshot now share the fetched styling.

Validation: flutter analyze: clean; 13 service, scanner and snapshot tests passed. No full suite ran.

### WC-03 Android web clipper fix

Snapshot write failures emit failed progress and propagate to the preview error handler. Saving stops before note persistence and never emits complete for the failed request.

Validation: flutter analyze: clean; 7 service and preview tests passed, including injected vault failure. No full suite ran.

### WC-04 Android web clipper fix

The saved note and Markdown use exactly the preview tag selection. Default chips remain in the preview, but removing either or all chips is respected, including explicit empty tags in repository persistence.

Validation: flutter analyze: clean; 10 service, browser acquisition and preview tests passed. No full suite ran.

### WC-05 Android web clipper fix

Browser payloads resolve resources and source metadata against the final loaded document URL. Canonical publication URLs remain metadata and no longer redirect relative images or hyperlinks to another origin.

Validation: flutter analyze: clean; 16 scanner, browser controller and acquisition parity tests passed. No full suite ran.

### WC-06 Android web clipper fix

Direct acquisition follows a bounded HTTP redirect chain while retaining the final document URL. Extraction, source metadata, relative links, image probes and snapshot bases now use that final URL.

Validation: flutter analyze: clean; 10 redirect, scanner and parity tests passed, including a real local HTTP redirect. No full suite ran.

### WC-07 Android web clipper fix

Browser state copyWith now distinguishes omitted transient messages from explicit null. Navigation and reset calls can clear old error/status messages while unrelated copies preserve them.

Validation: flutter analyze: clean; 11 browser controller and screen tests passed. No full suite ran.

### WC-08 Android web clipper fix

Image download mappings and Markdown resolution retain full query identity. Query-free aliases and path-only fallbacks were removed, so a failed image cannot inherit another illustration. Regression coverage checks both persisted snapshot and Markdown.

Validation: flutter analyze: clean; 9 service and downloader tests passed. No full suite ran.

### WC-09 Android web clipper fix

Browser previews return the saved note without opening an editor themselves. The browser resets processing state and replaces its own route with the saved editor in all three save paths. A route-observer regression verifies only the preview is popped and the replacement editor holds the saved note.

Validation: flutter analyze: clean; 5 navigation, browser and preview widget tests passed. No full suite ran.

### WC-10 Android web clipper fix

Quick Capture queues distinct incoming requests while a capture route is open and opens them in FIFO order after that route closes. Duplicate active or queued shares are suppressed without discarding other URLs. Disposal clears queued session state.

Validation: flutter analyze: clean; 16 coordinator, Quick Capture screen and normalizer tests passed. No full suite ran.

WC-04 follow-up: the Markdown converter also respects explicit tag selections in YAML frontmatter. Service regressions now inspect YAML entries as well as the Note model, covering the second default-tag insertion path. Validation: flutter analyze clean; 11 service, converter and browser acquisition tests passed.

### WC-11 Android web clipper fix

URL dialog actions wrap independently across lines when available width is insufficient, including when Continue adds a loading spinner. All actions stay within the dialog at 320, 360 and 392.7 dp.

Validation: flutter analyze: clean; 4 focused URL dialog widget tests passed. No full suite ran.

### WC-12 Android web clipper fix

Nested and presentation/layout tables convert as document flow, preserving paragraphs, headings and fenced code once. Flat tables enumerate only direct row cells, preventing descendant-cell duplication while retaining ordinary data-table Markdown.

Validation: flutter analyze: clean; 17 converter, scanner and service tests passed. No full suite ran.

### WC-13 Android web clipper fix

Scored sections expand to a shared multi-section document container instead of discarding sibling chapters. Whole-body extraction is marked as fallback, and semantic sections/headings survive noise names such as Comments and Header Fields. A local replay of RFC 9110 retains all 154 h1/h2/h3 headings and all 161 pre blocks (previously 1 and 0).

Validation: flutter analyze: clean; 15 permanent extraction/scanner/parity tests and one temporary RFC replay passed; temporary local-file probe removed. No full suite ran.

### WC-14 Android web clipper fix

Figure conversion preserves every child instead of selecting only the first image. Code-only and mixed-content figures retain fenced examples, explanatory text, all illustrations and italic captions exactly once.

Validation: flutter analyze: clean; 12 converter, picture extraction and service tests passed. No full suite ran.

### WC-15 Android web clipper fix

Alt-text filtering no longer treats the substring star as decoration. Astronomy photos, Star labels and Startup descriptions survive both DOM and URL filtering; explicit rating-star labels and tiny icons remain excluded.

Validation: flutter analyze: clean; 17 image-filter, picture extraction and scanner tests passed. No full suite ran.

### WC-16 Android web clipper fix

Main-frame load failures latch to the current navigation generation, cancel readiness/slow-load timers and keep Clip disabled. Late progress, finish and pending JavaScript callbacks cannot promote a failed page or replace its requested URL with a Chromium error URL. Retry/new navigation starts a fresh generation; subframe and cancellation errors remain nonfatal.

Validation: flutter analyze: clean; 17 focused browser lifecycle, state, screen and save-navigation tests passed. No full suite ran.

Android web clipper remediation complete: **16/16 fixed; 0 open**. Final combined web clipper and Quick Capture regression run: **92 passed**, serialized with `--concurrency=1`; Flutter analysis is clean. All fixes and progress updates were committed and pushed individually (WC-04 also has a YAML-frontmatter follow-up). No full suite, Android build or new physical-device replay was run.

## Main CI test stabilization — November 17, 2026

The Test & Analyze run `44049227585` and Linux run `44049227588` at `810704c` both passed static analysis but failed the scanner document-viewer widget test because Syncfusion's 500ms tile callback remained pending. The former also failed the desktop PDF overwrite test when its fixed 150ms delay expired before the flushed file write completed and the success snackbar appeared.

The scanner test now unmounts the viewer and drains the deferred tile callback before exiting. PDF export tests use the existing bounded `pumpUntilFound` helper to wait for the actual success UI, allowing real filesystem work to complete; exact-byte equality, truncation of an existing longer file, cancellation and Downloads-fallback assertions remain intact. No application behavior or workflow checks were changed.

Validation: reproduced the pending-timer failure before the fix; `flutter analyze --no-pub` reports no issues, and `flutter test --no-pub --concurrency=1 test/scanner/scanner_ui_test.dart test/documents/document_viewer_export_test.dart` passes all **8 tests**. No full suite ran locally.

## PR #10 integration with main

Merged the main-branch PDF viewer teardown and export-wait test fixes into the Android web clipper branch before merging PR #10. Resolved the HANDOFF append conflict by retaining both the completed 16-finding web clipper remediation and the main CI stabilization notes.

Combined-branch validation: `flutter analyze` reports no issues; `flutter test --no-pub --concurrency=1 test/web_clipper test/quick_capture test/scanner/scanner_ui_test.dart test/documents/document_viewer_export_test.dart` passes **100 relevant tests**. No full suite ran locally. PR #10's previous CI failures were the two timing failures corrected in main's `201c5e3`; main's subsequent Test & Analyze run `44078219655` passed.

## Notes List Bug and Performance Audit — November 17, 2026

The [notes list audit](handoff/audits/notes-list-2026-11-17/README.md) records
**10/10 fixed; 0 open** on `audit/notes-list-2026-11-17`, based on main `9bf2cdd`.
They cover hidden load errors, sort-order corruption by grouping, stale preview
metadata, refresh truncation, request-generation collisions, ineffective Retry,
cache thrashing, desktop ZIP overwrite failure, omitted journal/share fields,
and stale rows after a failed context switch. Per-finding fixes and validation
are recorded below and in the audit report.

The original audit passed **141 existing notes/gesture tests** and **21 audit
probes** that characterized failures and checked virtualization/responsive
layouts. Those historical probes intentionally assert the old defects. Native
Linux profile measurements use 10,000 synthetic notes and desktop/phone viewports.
The report preserves sources, logs, screenshots, measurements and explicit limits.
Only Linux was connected: Android widget tests exercise mobile behavior, but
physical Android/iOS and mobile performance remain unverified. Static analysis
is clean. No full suite ran.

### NL-01 notes list fix — November 17, 2026

Phone and desktop lists show a load error with Retry before the empty-state branch. Retry recovers existing notes; genuinely empty libraries retain their ordinary empty state.

Validation: `flutter analyze`: no issues; `flutter test test/notes/notes_list_audit_regression_test.dart`: 4 passed. No full suite ran.

### NL-02 notes list fix — November 17, 2026

Grouping preserves query order with contiguous date buckets, uses the selected created/updated date, and groups title sorts without date reordering. Phone/desktop regressions cover all sort directions and pin settings; 85-note keyset pagination checks preserve order at each page boundary.

Validation: `flutter analyze`: no issues; focused audit, domain and pin tests: 35 passed; expanded audit regressions including keyset boundaries: 7 passed. No full suite ran.

### NL-03 notes list fix — November 17, 2026

Metadata cache keys compare exact content, title, timestamp, tag values and snippet rather than content length and partial hashes. Same-time tag edits and same-length body replacements now produce fresh metadata, while unchanged values reuse cached instances. Exact note-ID invalidation preserves other IDs.

Validation: `flutter analyze`: no issues; cache, journal metadata, scrolling and screen regression files: 19 passed. No full suite ran.

### NL-04 notes list fix — November 17, 2026

Refresh reconstructs the loaded window using bounded keyset pages and publishes the replacement atomically. Regressions retain 440 and 1,000 loaded IDs, edited content and continuation cursors; phone and desktop lists preserve a deep visible row and its scroll position.

Validation: `flutter analyze`: no issues; collection recovery, pagination races and screen regressions: 16 passed. No full suite ran.

### NL-05 notes list fix — November 17, 2026

The collection notifier assigns monotonically increasing request generations to every initial load and refresh. Async success, error and load-more cleanup check the current generation and mounting before updating state. Regressions cover both completion orders, stale failures, overlapping refresh/filter/sort changes, disposal and old-page cleanup during a new page request.

Validation: `flutter analyze`: no issues; collection recovery and pagination race files: 12 passed. No full suite ran.

### NL-06 notes list fix — November 17, 2026

Retry dispatches the recorded failed operation: initial load, refresh, or next page. Failed refreshes restart at the beginning even at end-of-list, and failed pages retry their cursor without losing loaded notes. Automatic scrolling leaves a displayed error intact until Retry or explicit refresh.

Validation: `flutter analyze`: no issues; collection recovery and screen regression files: 23 passed. No full suite ran.

### NL-08 notes list fix — November 17, 2026

Removed collection-wide metadata and thumbnail scans from both list providers and the screen. Mounted tiles extract lazily; grouped data watches notes/sort rather than loading flags. Speculative prewarm fills unused capacity without evicting recent entries. Linux profile replay reduces repeated 600/1,000-note prewarm from 364/598ms medians to at most 1 microsecond, with no Flutter errors; raw evidence and physical-mobile limits are in fix-verification/README.md.

Validation: `flutter analyze`: no issues; cache, scrolling, redesign and screen regression files: 50 passed. Native build/raster p95 stays below 16.67ms in both layouts, with one desktop build outlier. No full suite ran.

### NL-09 notes list fix — November 17, 2026

Desktop ZIP exports always replace and flush picker-returned paths before reporting success. Null/empty picker responses cancel without writing; picker and filesystem failures show an export error. Mobile pickers retain ownership of supplied bytes. Regressions decode exact new/overwritten archives and cover cancellation and failures.

Validation: `flutter analyze`: no issues; ZIP export and multi-selection tests: 16 passed. No full suite ran.

### NL-10 notes list fix — November 17, 2026

Full and paginated reads share a complete NoteEntity-to-Note mapper, including journalDate, shareId and shareUrl. Batch tag hydration remains unchanged. Regressions compare every persisted domain field across active, Archive and Trash reads, including journal/share flags and local pins.

Validation: `flutter analyze`: no issues; database query and pin-scope files: 25 passed. No full suite ran.

### NL-11 notes list fix — November 17, 2026

New queries immediately clear old rows, counts and cursors, including destination, tag, sort and filter transitions. Query changes also end batch selection so old IDs cannot be acted on under the new query. Phone/desktop regressions assert empty loading/error collections, no actionable old rows, and successful Retry with the new predicates retained.

Validation: `flutter analyze`: no issues; screen, recovery and selection regression files: 46 passed. No full suite ran.

All ten notes list findings are resolved with separate commits and pushes on
`audit/notes-list-2026-11-17`. Final combined validation passes **192 relevant
notes and gesture tests** with clean Flutter analysis. Original characterization
probes remain archived outside normal discovery; permanent acceptance tests
verify the fixes. The Linux profile replay and its explicit mobile limits are in
[fix verification](handoff/audits/notes-list-2026-11-17/fix-verification/README.md).
No full suite ran.
The normal Linux profile bundle was rebuilt from `lib/main.dart` after the
isolated benchmark; its restore log is retained with the verification evidence.

## Images and Document Scanner Audit — November 17, 2026

The [image/scanner audit](handoff/audits/images-scanner-2026-11-17/README.md)
records **14 confirmed bugs, all open**, on `audit/images-scanner-2026-11-17`
from `8724bf0`. Each finding was documented when discovered. Coverage includes
crop/rotation correctness, preview/export parity, desktop image saves, GIF
compression, async image/detector races, plaintext-cache access and retention,
and scanner/viewer lifecycle errors. This branch contains audit documentation,
reproduction sources and measured evidence; application behavior is unchanged.

**114 relevant existing tests and 16 audit characterization probes pass.** The
probes assert baseline defects and are kept outside normal test discovery;
they are evidence, not acceptance tests for future fixes. The full suite was
not run. Dart VM mode/encoding and multipage benchmarks and a Flutter 12 MP
preparation measurement are retained with explicit Linux/JIT and device limits.
Final Flutter analysis reports no issues. See engineering log 328 for scope and validation.

### IS-01 image/scanner audit fix — November 17, 2026

Rectangle crops and perspective quads now apply in oriented source coordinates before rotation in both processing paths. Four-rotation pixel regressions preserve the selected red region and output orientation.

Validation: 5 processor/dewarp tests passed. Flutter analysis clean. No full suite ran.

### IS-02 image/scanner audit fix — November 17, 2026

Review and adjustment canvases render bounded crop/dewarp previews, discard stale geometry jobs, and return to source framing for corner editing. Scanner review now supplies the selected document quad.

Validation: 15 scanner review/editor tests passed. Flutter analysis clean. No full suite ran.

### IS-03 image/scanner audit fix — November 17, 2026

Both CPU image-processing paths now apply the exact preview color matrix with one final channel clamp. Pixel regressions cover lifted blacks, mixed brightness/contrast/saturation and grayscale, allowing JPEG rounding.

Validation: 11 tone/geometry tests passed. Flutter analysis clean. No full suite ran.
