# Quiet Paper — Engineering Handoff Document

Welcome to **Quiet Paper**! This document provides an architectural overview, codebase walkthrough, design philosophy reference, and practical guidelines for future engineers and AI agents working on this project.

---

## 1. Product Vision & Principles

Quiet Paper is an offline-first Android notes application inspired by the calm, distraction-free writing experience of Bear Notes.

### Key Philosophy
- **Content First**: The note content is canonical. The interface gets out of the user's way while writing.
- **Warm Editorial Aesthetic**: Soft paper tones (`#F7F6F2` Light / `#1D1C1A` Dark), deliberate typography, minimal elevation, zero noisy Material cards or busy toolbars.
- **Offline-First**: Local persistence with SQLite via Drift. Fast, resilient, and private.
- **Exceptional Writing Flow**: 
  - Restrained app bar (`←` ... `⋯`).
  - Document-style borderless title (30sp) & spacious body (18sp, 1.6 line height).
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
│   │   ├── markdown_helper.dart            # Text manipulation utilities (heading cycling, wrap, links)
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
│   │   │   └── editor_provider.dart        # EditorNotifier with debounced autosave & exit cleanup
│   │   └── presentation/
│   │       ├── editor_screen.dart          # Distraction-free digital sheet editor screen
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

### Top-Aligned Document Sheet Layout
- The editor body uses `Align(alignment: Alignment.topCenter, child: ConstrainedBox(...))` to avoid vertical centering on short notes.
- Notes start immediately at the top below the transparent app bar with standard 16dp vertical padding and 24dp horizontal margins on mobile devices.
- On tablets and desktop viewports, content is constrained to 720dp max-width and centered horizontally.

### Invisible, Multi-Stage Autosave
- **Debounced Keystrokes**: 700ms after the last edit, SQLite write is triggered quietly without noisy "Saved" popups.
- **Focus Blur**: When switching focus between title, body, or external controls, pending changes are persisted.
- **App Lifecycle Changes**: `WidgetsBindingObserver` listens for `paused` / `inactive` / `detached` states to flush changes when app is backgrounded.
- **Exit Flush & Empty Cleanup**: When leaving the editor (`handleExitCleanup()`), if both title and content are blank, the draft is cleaned up so empty entries do not clutter the notes list.

### Tag Parsing
- Tags can be typed naturally with `#tag` or `#nested/tag` anywhere in the note.
- `TagParser.extractTags()` skips Markdown headings (`# Heading`) and code blocks, extracts normalized tags, and stores relations in the SQLite `note_tags` table.
- Tags are cleaned up automatically when notes are deleted or tags removed.

### Responsive Split View
- On mobile devices (< 720dp), a single-column navigation is used.
- On tablets (>= 720dp), `NotesScreen` automatically switches to a master-detail split layout with a 320dp sidebar and centered editor pane.

---

## 5. CI/CD & Android Keystore Signing

The repository includes a complete GitHub Actions workflow at [`.github/workflows/build_apk.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_apk.yml) that builds release APKs automatically.

### Configuring Custom Keystore Signing

To sign release builds with your own Android keystore in GitHub Actions, add the following **Repository Secrets** (**Settings → Secrets and variables → Actions → New repository secret**):

| Secret Name | Description | Value / Generation |
| :--- | :--- | :--- |
| `KEYSTORE_BASE64` | Base64-encoded string of your `.jks` or `.keystore` file | Generate with `base64 -w 0 upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | Password for the keystore file | Password entered when creating the keystore |
| `KEY_ALIAS` | Key alias name inside the keystore | e.g. `upload` or `key0` |
| `KEY_PASSWORD` | Password for the key alias | Password entered for the key alias |

> **Graceful Fallback**: If these secrets are not configured (e.g. on forks or pull requests), Gradle automatically falls back to debug signing so CI builds remain green and always produce a testable APK artifact.

---

## 6. Development & Testing Commands

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

## 7. Roadmap & Recommendations for Future Iterations

1. **Tag Hierarchy Navigation**: Expand support for nested sub-tags (e.g. browsing `#work/project` as folders).
2. **Export / Import**: Add single or batch Markdown file export and import.
3. **Bluetooth Keyboard Shortcuts**: Key bindings (`Ctrl+B`, `Ctrl+I`, `Ctrl+S`, `Ctrl+N`) for hardware keyboards on Android tablets/desktops.
4. **Encrypted Backup**: Optional local backup archive with encryption.
