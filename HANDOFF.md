# Quiet Paper — Engineering Handoff Document

Welcome to **Quiet Paper**! This document provides an architectural overview, codebase walkthrough, design philosophy reference, bugfix history, and practical guidelines for future engineers and AI agents working on this project.

---

## 1. Product Vision & Principles

Quiet Paper is an offline-first Android notes application inspired by the calm, distraction-free writing experience of Bear Notes.

### Key Philosophy
- **Content First**: The note content is canonical. The interface gets out of the user's way while writing.
- **Warm Editorial Aesthetic**: Soft paper tones (`#F7F6F2` Light / `#1D1C1A` Dark), deliberate typography, minimal elevation, zero noisy Material cards or busy toolbars.
- **Offline-First**: Local persistence with SQLite via Drift. Fast, resilient, and private.
- **Exceptional Core Writing Loop**: 
  - Restrained app bar (`←` ... `⋯`).
  - Document-style borderless title (30sp) & spacious body (18sp, 1.6 line height).
  - Tapping anywhere in the editor sheet automatically focuses the body and brings up the software keyboard.
  - Smart auto-titling: if no custom title is typed, the first line of content is used as title (with clean word truncation if long).
  - Document starts naturally at the top (`Alignment.topCenter`) with 24dp horizontal margins on phones and 720dp max-width centering on tablets.
  - Invisible, reliable autosave (700ms debounce, focus change, app lifecycle, exit flush).
  - Smart empty-draft disposal on exit.
  - Quiet, keyboard-aware Markdown formatting toolbar with cycling headings and selection preservation.

---

## 2. Project Architecture & Directory Layout

The application follows a clean, feature-oriented architecture:

```text
lib/
├── main.dart                               # Entry point, initializes SharedPreferences & Riverpod
├── app/
│   ├── app.dart                            # MaterialApp setup, theme bindings
│   └── theme/
│       ├── app_colors.dart                 # Color tokens & ThemeExtension<AppColors>
│       ├── app_spacing.dart                # 4dp base spacing tokens & responsive widths
│       ├── app_radii.dart                  # Corner radius tokens (8dp, 10dp, 12dp, 16dp)
│       ├── app_typography.dart             # UI and editor typography hierarchy
│       └── app_theme.dart                  # Light and Dark ThemeData configurations (with quick-dismiss tooltips)
│
├── core/
│   ├── database/
│   │   ├── app_database.dart               # Drift SQLite database (schema v2), DAOs, queries & migrations
│   │   ├── app_database.g.dart             # Generated Drift code
│   │   ├── connection/
│   │   │   └── connection.dart             # Native & In-Memory SQLite connection factories
│   │   └── tables/
│   │       ├── notes_table.dart            # Notes table schema (with performance indexes)
│   │       ├── tags_table.dart             # Tags table schema
│   │       └── note_tags_table.dart        # Note-Tag many-to-many junction schema
│   ├── markdown/
│   │   ├── markdown_chunker.dart           # Linear O(N) markdown document chunker for lazy rendering
│   │   ├── markdown_helper.dart            # Text manipulation utilities (heading cycling, wrap, links)
│   │   └── markdown_preview.dart           # Virtualized lazy-chunked Markdown viewer
│   ├── utils/
│   │   ├── date_formatter.dart             # Relative time & Date grouping ("Today", "Yesterday", etc.)
│   │   ├── tag_parser.dart                 # Hashtag extraction, normalization, and validation
│   │   └── debouncer.dart                  # Debounce utility for autosave and search
│   └── widgets/
│       ├── quiet_button.dart               # Minimal tonal/primary/destructive buttons
│       ├── quiet_icon_button.dart          # 48x48dp accessible monochrome icon buttons
│       ├── quiet_fab.dart                  # Understated floating ＋ button
│       └── quiet_tag_chip.dart             # Textual metadata tag chip (#tag)
│
├── features/
│   ├── sidebar/
│   │   └── presentation/
│   │       ├── sidebar_view.dart           # Flagship responsive navigation surface
│   │       └── widgets/
│   │           ├── sidebar_item.dart       # Calm row with reactive count badge & quiet selection
│   │           ├── tag_browser_sheet.dart  # Modal searchable tag browser
│   │           └── permanent_delete_dialog.dart # Explicit permanent deletion confirmation
│   │
│   ├── notes/
│   │   ├── data/
│   │   │   └── notes_repository.dart       # Repository abstraction & Drift implementation
│   │   ├── domain/
│   │   │   ├── note_model.dart             # Immutable domain Note entity (lifecycle fields, auto-title)
│   │   │   └── note_group.dart             # Grouping model for date buckets
│   │   ├── application/
│   │   │   ├── notes_provider.dart         # Riverpod providers for notes, destinations, tags, counts
│   │   │   └── sample_notes.dart           # Demo notes loader
│   │   └── presentation/
│   │       ├── notes_screen.dart           # Phone drawer & 3-pane tablet split view, multi-select, swipe actions
│   │       └── widgets/
│   │           ├── note_list_tile.dart     # Editorial note tile with preview, search highlight, tags, context actions
│   │           ├── note_date_header.dart   # Date section headers
│   │           ├── note_empty_state.dart   # Calm typography empty states per destination
│   │           └── tags_filter_bar.dart    # Horizontal tag filter bar with note counts
│   │
│   ├── editor/
│   │   ├── application/
│   │   │   ├── editor_state.dart           # Editor state (dirty, saving, preview mode)
│   │   │   └── editor_provider.dart        # EditorNotifier with debounced autosave, EditorParams, lifecycle & exit cleanup
│   │   └── presentation/
│   │       ├── editor_screen.dart          # Digital sheet editor (click anywhere to focus body, seamless preview switch)
│   │       └── widgets/
│   │           ├── formatting_toolbar.dart # Bottom markdown formatting bar (B, I, S, H, lists, etc.)
│   │           ├── tag_editor_bar.dart     # Inline tag chips with add/remove
│   │           └── editor_stats_dialog.dart# Word count, character count, timestamps dialog
│   │
│   ├── search/
│   │   └── presentation/
│   │       └── search_screen.dart          # Fast debounced search across titles, contents, and tags with match highlighting
│   │
│   └── settings/
│       ├── application/
│       │   └── settings_provider.dart      # ThemeMode notifier backed by SharedPreferences
│       └── presentation/
│           └── settings_screen.dart        # Theme selection (System/Light/Dark) & sample loader
│
└── test/
    ├── database/
    │   └── app_database_test.dart          # Unit tests for database CRUD, search, tags, migrations, invariants
    ├── features/
    │   └── notes_browsing_search_test.dart # Integration journeys for core writing loop, search, tags, trash persistence
    ├── markdown/
    │   ├── markdown_chunker_test.dart      # Unit tests for markdown chunker
    │   └── markdown_preview_test.dart      # Widget tests for virtualized lazy markdown preview
    ├── utils/
    │   └── date_formatter_test.dart        # Date formatting and grouping unit tests
    └── widget_test.dart                    # Full flow, sidebar, drawer, archive, trash, tablet split-view tests
```

---

## 3. Technology Stack & Key Packages

- **Flutter**: 3.44.x (Dart 3.12.x)
- **State Management**: `flutter_riverpod` (v2.6.x)
- **Persistence**: `drift` + `sqlite3_flutter_libs` + `path_provider` (Schema version 2)
- **Markdown**: `flutter_markdown`
- **Preferences**: `shared_preferences`
- **Formatting & Dates**: `intl`
- **ID Generation**: `uuid`

---

## 4. Navigation & Lifecycle Architecture

### Destinations & Invariants
Navigation is modeled by `AppDestination`:
- **`allNotes`**: Displays active notes (`!isArchived && !isTrashed`), sorted pinned first, then modified date.
- **`pinned`**: Displays active pinned notes (`isPinned && !isArchived && !isTrashed`).
- **`archive`**: Holding area for archived notes (`isArchived && !isTrashed`).
- **`trash`**: Indefinite holding area for trashed notes (`isTrashed`).
- **`tag`**: Notes filtered by specific active tag.

### Zero Auto-Delete Guarantee
- Notes in Trash are **persisted indefinitely** and **NEVER automatically purged** (no 7-day or 30-day timers, no background or startup deletion).
- Permanent deletion only occurs when explicitly initiated and confirmed by the user via the `PermanentDeleteDialog`.

### List Swipe Interactions
- **Active List (`All Notes`, `Pinned`, `Tag`)**:
  - **Swipe Right (`startToEnd`)**: **Archive** note (with SnackBar "Note archived [Undo]").
  - **Swipe Left (`endToStart`)**: **Move to Trash** (with SnackBar "Note moved to Trash [Undo]").
- **Archive List**:
  - **Swipe Right**: **Unarchive** note (with SnackBar "Note unarchived [Undo]").
  - **Swipe Left**: **Move to Trash** (with SnackBar "Note moved to Trash [Undo]").
- **Trash List**:
  - **Swipe Right**: **Restore** note (with SnackBar "Note restored [Undo]").
  - **Swipe Left**: Prompts permanent deletion confirmation.

### Responsive Breakpoints
- **Compact Viewports (`< 900dp`)**: Single-column layout with app bar drawer hamburger icon opening 300dp `SidebarView`.
- **Wide Viewports (`>= 900dp`)**: Persistent 3-column split view (280dp Left Navigation Sidebar + 320dp Middle Notes List + Expanded Centered Editor).

---

## 5. Editor Features & Usability Enhancements

### Seamless Edit / Markdown Preview Mode Switching & Preview-First Flow
- **Preview-First Note Reading**: Tapping an existing note from the list or search results opens directly in Markdown Preview mode for an editorial reading experience. Creating a new note via FAB or `+` opens in edit mode with automatic body focus.
- **Top App Bar Quick Toggle Button**: An Edit button (`Icons.edit_outlined`) is positioned directly in the app bar next to the 3-dot menu when in preview mode for 1-tap editing. When in edit mode, it displays a Preview button (`Icons.remove_red_eye_outlined`) for instant preview toggling.
- **Fix for Preview Mode Switching**: In earlier builds, editing text in the editor caused `saveNote()` to update `updatedAt`, which altered the equality of the family parameter `Note`, causing Riverpod's `StateNotifierProvider.family` to recreate the `EditorNotifier` with `isPreviewMode = false`. This bug was resolved by wrapping family parameter access in `@immutable class EditorParams(this.note, {this.initialPreviewMode})` whose `operator ==` and `hashCode` rely strictly on `note.id`.
- **Instant Preview of Unsaved Edits**: When switching to preview mode, the preview renderer directly ingests the active `_contentController.text` and `_titleController.text`, rendering the live markdown immediately without waiting for debounce timers.
- **Continuous Multi-Line & Multi-Paragraph Selection**: `QuietMarkdownPreview` wraps the rendered document in Flutter's `SelectionArea` (with inner `MarkdownBody` configured with `selectable: false`), allowing continuous drag-selection and copying across lines, headings, bullet lists, blockquotes, and tables without paragraph fragmentation.

### Dynamic Auto-Titling in Editor & Lists
- **Live Editor Auto-Fill**: As the user types into the note body textarea without typing in the title field, the Title text field in the editor is automatically filled with the first line of content in real-time.
- **Smart Truncation**: If the first line is long (more than 6 words or 40 characters), it is truncated cleanly with `...` (e.g. `This is an exceptionally long first...`).
- **User Customization Priority**: If the user clicks into the Title field and explicitly enters a custom title, manual user input takes full priority. If the title is cleared, automatic first-line derivation resumes.
- **List Card Preview Snippet**: Note list cards display the auto-derived title and start the snippet preview from subsequent content lines to avoid repeating the title.

### Search with Debouncing & Highlight Matching
- **150ms Debounced Queries**: Typing in the search field is debounced by 150ms to prevent database churn while remaining snappy.
- **Subtle Match Highlighting**: Matching keywords in both note titles and body snippets are subtly highlighted with `AppColors.accent` and semibold typography.
- **Quick Capture from Search**: Dedicated `+` action in the search bar enables creating a note immediately without leaving the search screen.

### High-Performance Large Text Handling & Markdown Preview
- **Constant-Time Bounded Preview Extraction**: `Note.displayTitle` and `Note.previewSnippet` process bounded character samples (300/600 characters max) rather than scanning multi-megabyte texts, ensuring $O(1)$ instant note list rendering with zero jank even for single-line paragraphs.
- **Asynchronous Tag Extraction**: Content changes update text immediately; tag extraction and normalization run asynchronously during the 700ms debounced save cycle, preserving 60/120 FPS typing performance.
- **Linear Tag Parsing**: `TagParser` uses a linear line-by-line scanner to strip code blocks, eliminating catastrophic regex backtracking on long code fences.
- **Lazy Virtualized Chunk Rendering**: `MarkdownChunker` splits long documents into semantic chunks (preserving code fences, tables, blockquotes, and lists). `QuietMarkdownPreview` utilizes `ListView.builder` to transform and render only the visible chunks in the viewport just-in-time, keeping memory $O(1)$ bounded and scrolling buttery smooth at 60/120 FPS even for 100,000+ line documents.

### Note List Tile Header Layout & Hit-Test Resiliency
- **Fix for Note Tile Overflow and Hit-Test**: In `NoteListTile`, `formattedTime` previously attempted to embed `'Moved to Trash · <Time>'` inside the top title row. On standard mobile viewport constraints (312dp content width), this long string consumed all available horizontal flex space and caused a 1px `RenderFlex` overflow, collapsing the title's `Expanded` widget to 0 width and failing `WidgetController.longPress()` hit testing during tests.
- **Dedicated Trashed Subtitle**: `formattedTime` in the top header is now standardized to use `DateFormatter.formatNoteTileTime(...)` (e.g. `"2:05 PM"`, `"Yesterday"`) across all destinations, while `"Moved to Trash · <Bucket>"` is placed in its dedicated metadata footer below tags/preview per design specification (`sidebar.md`).

---

## 6. CI/CD & Automated Testing

### GitHub Actions Workflows
- **Test & Analyze Workflow** ([`.github/workflows/test.yml`](file:///home/dog/git/quitepaper/.github/workflows/test.yml)): Runs on every push and pull request to `main`/`master`. Executes dependency installation, code generation, `flutter analyze`, and `flutter test --coverage`.
- **Release APK Workflow** ([`.github/workflows/build_apk.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_apk.yml)): Builds release and debug APK artifacts for Android.
- **Build Linux App Workflow** ([`.github/workflows/build_linux.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_linux.yml)): Installs native Linux build toolchain (`clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libsqlite3-dev`), runs tests/analysis, builds the standalone 64-bit Linux release bundle, and uploads both tarball (`quiet-paper-linux-x64.tar.gz`) and directory artifacts.

---

## 7. Development & Testing Commands

### Run Code Generation (Drift Database)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Static Analysis
```bash
flutter analyze
```

### Run Full Test Suite
```bash
flutter test
```

### Build Linux Application
```bash
flutter build linux --release
```

### Run on Device / Emulator / Desktop
```bash
flutter run
```

---

## 8. Roadmap & Recommendations for Future Iterations

1. **Tag Hierarchy Folders**: Tree-style expandable nested tag navigation (`#work/project/2026`).
2. **Export / Import**: Batch Markdown export to ZIP and folder import.
3. **Hardware Keyboard Shortcuts**: Key bindings (`Ctrl+N`, `Ctrl+Shift+A`, `Ctrl+Shift+Delete`) for hardware keyboards on tablets/desktops.
4. **Encrypted Backup**: Optional local encrypted backup archive.
