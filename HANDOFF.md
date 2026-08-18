# Quiet Paper — Engineering Handoff Document

Welcome to **Quiet Paper**! This document provides an architectural overview, codebase walkthrough, design philosophy reference, and practical guidelines for future engineers and AI agents working on this project.

---

## 1. Product Vision & Principles

Quiet Paper is an offline-first Android notes application inspired by the calm, distraction-free writing experience of Bear Notes.

### Key Philosophy
- **Content First**: The note content is canonical. Controls disappear when writing.
- **Warm Editorial Aesthetic**: Soft paper tones (`#F7F6F2` Light / `#1D1C1A` Dark), deliberate typography, minimal elevation, and no loud Material 3 cards.
- **Offline-First**: Local persistence with SQLite via Drift. Fast, resilient, and private.
- **Frictionless Writing**: Immediate autosave (debounced 600ms), automatic tag extraction, smooth markdown formatting toolbar, and rendered preview toggle.

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
│       └── app_theme.dart                  # Light and Dark ThemeData configurations
│
├── core/
│   ├── database/
│   │   ├── app_database.dart               # Drift SQLite database, DAOs, queries & migrations
│   │   ├── app_database.g.dart             # Generated Drift code
│   │   ├── connection/
│   │   │   └── connection.dart             # Native & In-Memory SQLite connection factories
│   │   └── tables/
│   │       ├── notes_table.dart            # Notes table schema
│   │       ├── tags_table.dart             # Tags table schema
│   │       └── note_tags_table.dart        # Note-Tag many-to-many junction schema
│   ├── markdown/
│   │   ├── markdown_helper.dart            # Text manipulation utilities (wrap, toggle prefix, links)
│   │   └── markdown_preview.dart           # Custom-styled Markdown viewer
│   ├── utils/
│   │   ├── date_formatter.dart             # Relative time & Date grouping ("Today", "Yesterday", etc.)
│   │   ├── tag_parser.dart                 # Hashtag extraction, normalization, and validation
│   │   └── debouncer.dart                  # Debounce utility for autosave and search
│   └── widgets/
│       ├── quiet_button.dart               # Minimal tonal/primary/outline buttons
│       ├── quiet_icon_button.dart          # 48x48dp accessible monochrome icon buttons
│       ├── quiet_fab.dart                  # Understated floating ＋ button
│       └── quiet_tag_chip.dart             # Textual metadata tag chip (#tag)
│
├── features/
│   ├── notes/
│   │   ├── data/
│   │   │   └── notes_repository.dart       # Repository abstraction & Drift implementation
│   │   ├── domain/
│   │   │   ├── note_model.dart             # Immutable domain Note entity
│   │   │   └── note_group.dart             # Grouping model for date buckets
│   │   ├── application/
│   │   │   ├── notes_provider.dart         # Riverpod providers for notes, tags, filter, search
│   │   │   └── sample_notes.dart           # Demo notes loader
│   │   └── presentation/
│   │       ├── notes_screen.dart           # Main note list & responsive tablet split view
│   │       └── widgets/
│   │           ├── note_list_tile.dart     # Editorial note tile with preview, tags, context actions
│   │           ├── note_date_header.dart   # Date section headers
│   │           ├── note_empty_state.dart   # Calm typography empty state
│   │           └── tags_filter_bar.dart    # Horizontal tag filter bar with note counts
│   │
│   ├── editor/
│   │   ├── application/
│   │   │   ├── editor_state.dart           # Editor state (dirty, saving, preview mode)
│   │   │   └── editor_provider.dart        # EditorNotifier with debounced autosave
│   │   └── presentation/
│   │       ├── editor_screen.dart          # Distraction-free editor screen
│   │       └── widgets/
│   │           ├── formatting_toolbar.dart # Bottom markdown formatting bar (B, I, S, H, lists, etc.)
│   │           ├── tag_editor_bar.dart     # Inline tag chips with add/remove
│   │           └── editor_stats_dialog.dart# Word count, character count, timestamps dialog
│   │
│   ├── search/
│   │   └── presentation/
│   │       └── search_screen.dart          # Fast search across titles, contents, and tags
│   │
│   └── settings/
│       ├── application/
│       │   └── settings_provider.dart      # ThemeMode notifier backed by SharedPreferences
│       └── presentation/
│           └── settings_screen.dart        # Theme selection (System/Light/Dark) & sample loader
│
└── test/
    ├── database/
    │   └── app_database_test.dart          # Unit tests for database CRUD, search, tags, migrations
    ├── utils/
    │   └── date_formatter_test.dart        # Date formatting and grouping unit tests
    └── widget_test.dart                    # Full flow and UI widget tests
```

---

## 3. Technology Stack & Key Packages

- **Flutter**: 3.44.x (Dart 3.12.x)
- **State Management**: `flutter_riverpod` (v2.6.x)
- **Persistence**: `drift` + `sqlite3_flutter_libs` + `path_provider`
- **Markdown**: `flutter_markdown`
- **Preferences**: `shared_preferences`
- **Formatting & Dates**: `intl`
- **ID Generation**: `uuid`

---

## 4. Key Design Patterns & Behaviors

### Design System & Theme Extension
Custom colors from `design.md` are accessible anywhere via `context.appColors`:
```dart
final colors = context.appColors;
// colors.background, colors.surface, colors.accent, colors.textPrimary, etc.
```

### Note Autosave
- When the user edits title or body, `EditorNotifier` updates in-memory state immediately, sets `isDirty: true`, and invokes `_debouncer.run(saveNow)`.
- When navigating back or closing the editor, `saveNow()` or `dispose()` ensures pending changes are persisted without data loss.

### Tag Parsing
- Tags can be typed naturally with `#tag` or `#nested/tag` anywhere in the note.
- `TagParser.extractTags()` skips Markdown headings (`# Heading`) and code blocks, extracts normalized tags, and stores relations in the SQLite `note_tags` table.
- Tags are cleaned up automatically when notes are deleted or tags removed.

### Responsive Split View
- On mobile devices (< 720dp), a single-column navigation is used.
- On tablets (>= 720dp), `NotesScreen` automatically switches to a master-detail split layout with a 320dp sidebar and centered editor pane.

---

## 5. Development & Testing Commands

### Run Code Generation (Drift Database)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Static Analysis
```bash
flutter analyze
```

### Run Tests
```bash
flutter test
```

### Run on Device / Emulator
```bash
flutter run
```

---

## 6. CI/CD & Build Pipeline

The repository includes a GitHub Actions workflow at [`.github/workflows/build_apk.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_apk.yml):
- Runs on every `push` and `pull_request` to `main`.
- Sets up Java 17 and Flutter stable.
- Runs `flutter analyze` and `flutter test`.
- Compiles the release Android APK (`flutter build apk --release`).
- Uploads the release artifact as `quiet-paper-release-apk`.

---

## 7. Roadmap & Recommendations for Future Iterations

1. **Tag Hierarchy Navigation**: Expand support for nested sub-tags (e.g. browsing `#work/project` as folders).
2. **Export / Import**: Add single or batch Markdown file export and import.
3. **Bluetooth Keyboard Shortcuts**: Key bindings (`Ctrl+B`, `Ctrl+I`, `Ctrl+S`, `Ctrl+N`) for hardware keyboards on Android tablets/desktops.
4. **Encrypted Backup**: Optional local backup archive with encryption.
