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

## Latest Linux CLI Work

The CLI supports encrypted image attachment, automatic Markdown image imports,
clipboard screenshots, attachment listing/opening, and independent note/image
upload retries. See [the CLI guide](handoff/platform-and-builds.md#linux-cli-image-attachments)
and [engineering log 269](handoff/latest-logs.md#269-linux-cli-encrypted-image-attachments-and-standalone-uploads-november-12-2026)
for commands, credential prerequisites, failure recovery and sync boundaries.

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
