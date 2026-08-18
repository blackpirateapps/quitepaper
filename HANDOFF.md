# Quiet Paper — Engineering Handoff Document

Welcome to **Quiet Paper**! This document provides an architectural overview, codebase walkthrough, design philosophy reference, bugfix history, end-to-end encrypted sync specification, and practical guidelines for future engineers and AI agents working on this project.

---

## 1. Product Vision & Principles

Quiet Paper is an offline-first notes application inspired by the calm, distraction-free writing experience of Bear Notes, equipped with zero-knowledge end-to-end encrypted cloud synchronization.

### Key Philosophy
- **Content First**: The note content is canonical. The interface gets out of the user's way while writing.
- **Warm Editorial Aesthetic**: Soft paper tones (`#F7F6F2` Light / `#1D1C1A` Dark), deliberate typography, minimal elevation, zero noisy Material cards or busy toolbars.
- **Offline-First & Local Persistence**: Local persistence with SQLite via Drift. Fast, resilient, private, and fully operable offline without network connectivity.
- **Zero-Knowledge Encryption**: Note contents (title, body, tags) are encrypted client-side using Argon2id and XChaCha20-Poly1305 before leaving the device. The backend and cloud database are crypto-blind and never possess plaintext content or master keys.
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

The repository contains both the Flutter client and the TypeScript/Vercel serverless backend in the same mono-repo:

```text
.
├── backend/                                # TypeScript Vercel serverless backend
│   ├── package.json                        # Backend dependencies (@libsql/client, firebase-admin, zod, vitest)
│   ├── tsconfig.json                       # ES2022 TypeScript configuration
│   ├── vercel.json                         # Vercel serverless routing
│   ├── .env.example                        # Environment variables template
│   ├── migrations/
│   │   └── 001_initial_schema.sql          # Turso / libSQL SQL schema
│   ├── src/
│   │   ├── api/
│   │   │   ├── handler.ts                  # Centralized REST API router
│   │   │   └── index.ts                    # Vercel serverless entrypoint
│   │   ├── auth/
│   │   │   ├── firebase.ts                 # Firebase Admin token verification
│   │   │   └── middleware.ts               # requireFirebaseAuth() auth & user resolver
│   │   ├── db/
│   │   │   ├── client.ts                   # Turso/libSQL client connection factory
│   │   │   └── migrate.ts                  # Database migration runner
│   │   ├── keys/
│   │   │   └── keyService.ts               # Wrapped master key storage & rotation
│   │   ├── sync/
│   │   │   └── syncService.ts              # Revision tracking, push/pull, idempotency & conflicts
│   │   ├── validation/
│   │   │   └── schemas.ts                  # Zod validation schemas & payload limits
│   │   └── errors/
│   │       └── apiError.ts                 # Structured error classes
│   └── tests/
│       ├── auth.test.ts                    # Authentication & identity isolation tests
│       ├── keys.test.ts                    # Wrapped key storage & rotation tests
│       ├── sync.test.ts                    # Revision tracking & idempotency tests
│       ├── conflict.test.ts                # Revision conflict detection tests
│       └── crypto-blind.test.ts            # Privacy assurance & zero decryption verification
│
├── docs/                                   # Architectural and security documentation
│   ├── encryption.md                       # Cryptographic primitives, key hierarchy & envelope format
│   ├── authentication.md                   # Firebase auth vs encryption separation
│   ├── sync-protocol.md                    # Cursor-based sync protocol & conflict handling
│   └── security-review.md                  # Threat model, trust boundaries & security invariants
│
├── lib/
│   ├── main.dart                           # Entry point, initializes SharedPreferences & Riverpod
│   ├── app/
│   │   ├── app.dart                        # MaterialApp setup, theme bindings
│   │   └── theme/
│   │       ├── app_colors.dart             # Color tokens & ThemeExtension<AppColors>
│   │       ├── app_spacing.dart            # 4dp base spacing tokens & responsive widths
│   │       ├── app_radii.dart              # Corner radius tokens (8dp, 10dp, 12dp, 16dp)
│   │       ├── app_typography.dart         # UI and editor typography hierarchy
│   │       └── app_theme.dart              # Light and Dark ThemeData configurations
│   │
│   ├── core/
│   │   ├── auth/
│   │   │   └── auth_service.dart           # AuthService interface, FirebaseAuthService, MockAuthService
│   │   ├── crypto/
│   │   │   ├── crypto_service.dart         # Argon2id KDF & XChaCha20-Poly1305 AEAD implementation
│   │   │   └── key_manager.dart            # KeyManager, FlutterSecureStorage & lifecycle management
│   │   ├── sync/
│   │   │   ├── sync_models.dart            # SyncPayload, PushResponse, PullResponse, SyncState
│   │   │   ├── sync_api_client.dart        # HttpSyncApiClient & MockSyncApiClient
│   │   │   ├── sync_engine.dart            # Offline queue coordinator & debounced sync engine
│   │   │   └── sync_provider.dart          # Riverpod providers for auth, crypto, key manager & sync
│   │   ├── database/
│   │   │   ├── app_database.dart           # Drift SQLite database (schema v3), DAOs & migrations
│   │   │   ├── app_database.g.dart         # Generated Drift code
│   │   │   ├── connection/
│   │   │   │   └── connection.dart         # Native & In-Memory SQLite connection factories
│   │   │   └── tables/
│   │   │       ├── notes_table.dart        # Notes table schema (with revision, dirty, syncedAt)
│   │   │       ├── tags_table.dart         # Tags table schema
│   │   │       ├── note_tags_table.dart    # Note-Tag junction schema
│   │   │       ├── sync_metadata_table.dart# Key-value sync metadata table (cursor, device ID)
│   │   │       └── sync_queue_table.dart   # Offline deletion/mutation queue table
│   │   ├── markdown/
│   │   │   ├── markdown_chunker.dart       # Linear O(N) markdown document chunker for lazy rendering
│   │   │   ├── markdown_helper.dart        # Heading cycling, link wrapping, text utilities
│   │   │   └── markdown_preview.dart       # Virtualized lazy-chunked Markdown viewer
│   │   ├── utils/
│   │   │   ├── date_formatter.dart         # Relative time & Date grouping ("Today", "Yesterday", etc.)
│   │   │   ├── tag_parser.dart             # Hashtag extraction and normalization
│   │   │   └── debouncer.dart              # Debounce utility for autosave and search
│   │   └── widgets/
│   │       ├── quiet_button.dart           # Minimal tonal/primary/destructive buttons
│   │       ├── quiet_icon_button.dart      # 48x48dp accessible monochrome icon buttons
│   │       ├── quiet_fab.dart              # Understated floating ＋ button
│   │       └── quiet_tag_chip.dart         # Textual metadata tag chip (#tag)
│   │
│   └── features/
│       ├── sidebar/presentation/           # Navigation drawer and 3-pane sidebar
│       ├── notes/                          # Notes browsing, domain models, lists, tags filter
│       ├── editor/                         # Digital sheet editor, live auto-titling, markdown preview
│       ├── search/presentation/            # Fast 100% offline debounced search with highlight matching
│       ├── sync/presentation/              # Sync auth dialog, password change & recovery key UI
│       ├── settings/presentation/          # Theme selection, sample loader, import & sync management
│       └── import/                         # Recursive Markdown folder import
│           ├── domain/markdown_import_item.dart
│           ├── application/markdown_frontmatter_parser.dart
│           ├── application/markdown_import_scanner.dart
│           ├── application/markdown_import_service.dart
│           └── presentation/               # Import preview screen, item cards & tag dialog
│
└── test/
    ├── crypto/
    │   └── crypto_test.dart                # Unit tests for Argon2id, XChaCha20, Master Key & KeyManager
    ├── sync/
    │   └── sync_engine_test.dart           # Multi-device sync, recovery, offline search & password rotation tests
    ├── database/
    │   └── app_database_test.dart          # Database CRUD, search, tags, migrations, invariants
    ├── import/                             # Unit & Widget tests for frontmatter, scanning, import service & UI
    ├── markdown/                           # Chunker & Markdown preview virtualized tests
    ├── utils/                              # Date formatting tests
    └── widget_test.dart                    # Full UI integration journeys
```

---

## 3. Cryptography & Key Management

### Cryptographic Hierarchy
1. **Master Key**: Randomly generated 256-bit (32-byte) secret key created on the user's device.
2. **Password-Derived Key**: User's Quiet Paper encryption password is fed through **Argon2id** (`memory: 19MB`, `iterations: 2`, `salt: 16 random bytes`) to produce a 32-byte wrapping key.
3. **Wrapped Master Key**: The Master Key is wrapped with the password key using **XChaCha20-Poly1305** AEAD with authenticated associated data (`quietpaper:key-wrap:v1`).
4. **Content Encryption**: Each note's `title`, `body`, and `tags` are serialized into JSON and encrypted using the Master Key via **XChaCha20-Poly1305** with unique 24-byte nonces and note-bound associated data (`quietpaper:note:<noteId>:v1`).

### Critical Product Rule: Separate Passwords
- **Firebase Authentication password**: Answers *"Who is this user?"*. Managed by Firebase.
- **Quiet Paper encryption password**: Answers *"Can this user decrypt notes?"*. Managed on-device.
- Changing/resetting the Firebase password **NEVER** grants access to notes or changes encryption keys.
- Changing the Quiet Paper encryption password **ONLY** re-wraps the master key with a fresh salt and does **NOT** re-encrypt existing note ciphertexts.

---

## 4. Backend & Turso Cloud Database

- **Framework**: TypeScript serverless API running on Vercel.
- **Database**: Turso / libSQL distributed SQLite.
- **Schema**:
  - `users`: Maps `firebase_uid` (UNIQUE) to internal `id`.
  - `encryption_keys`: Stores versioned `wrapped_master_key`, `wrapped_nonce`, `kdf_salt`, `kdf_parameters`, and recovery wraps.
  - `notes`: Stores metadata (`id`, `created_at`, `updated_at`, `archived`, `trashed`, `pinned`, `revision`, `deleted_at`) and encrypted blobs (`content_ciphertext`, `content_nonce`, `encryption_key_version`). **Zero plaintext content columns**.
  - `sync_changes`: Append-only revision log for cursor-based delta syncing.
  - `idempotency_keys`: Caches responses for retry requests.

---

## 5. Development & Testing Commands

### Backend Tests (Vitest)
```bash
cd backend
npm test          # Runs 14 tests (auth, keys, sync, conflict detection, crypto-blindness, key rotation verification)
npm run build     # Runs TypeScript compiler (tsc)
```

### Flutter Code Generation (Drift Database)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Static Analysis
```bash
flutter analyze   # Zero errors / zero warnings
```

### Full Flutter Test Suite
```bash
flutter test      # 85 tests covering crypto, sync engine, multi-device flow, UI, editor, frontmatter & markdown preview
```

---

## 6. Markdown Folder Import Specification

Quiet Paper features a recursive local Markdown folder importer:
- **Directory Traversal**: Recursively scans user-selected folders to arbitrary subfolder depths for `.md` and `.markdown` files.
- **Permissions**: Requests storage permissions on Android (including `MANAGE_EXTERNAL_STORAGE` on Android 11+ and legacy storage permissions on Android 10 and below) to ensure full recursive folder access.
- **Frontmatter & Title Parsing**: Extracts YAML frontmatter (`--- ... ---`) metadata (title, tags, creation and modification dates). If `title` is defined in frontmatter, it takes precedence; otherwise defaults to filename without extension.
- **Verbatim Content Preservation**: The entire markdown document content (including frontmatter) is preserved as-is in the note body without stripping.
- **Hierarchical Subfolder Tagging**: Automatically converts subfolder directory names into normalized tags (e.g. `Articles/Wikipedia/Topic.md` -> tags `articles`, `wikipedia`).
- **Tag Merging**: Combines subfolder tags, frontmatter `tags` / `tag` / `categories`, and inline `#hashtags` found in the document body.
- **File Metadata & Timestamp Preservation**: Prioritizes frontmatter creation and update timestamps (supporting ISO8601, numeric epoch timestamps, slash formats, and diverse date patterns) and falls back accurately to local file properties (`stat.modified`, `stat.changed`) so imported notes retain their original dates.
- **Interactive Import Screen**: Displays all discovered files with relative paths, sizes, dates, content previews, and tag chips. Users can check/uncheck individual items, select/deselect all, add or delete tags per-item, batch-tag selected notes, and edit titles before committing the import.

---

## 7. Markdown Preview & YAML Frontmatter Properties

Quiet Paper's Markdown preview integrates Obsidian-inspired properties with the calm, warm aesthetic of Bear Notes:
- **Zero Raw YAML Leakage**: In preview mode, YAML frontmatter delimiters (`--- ... ---`) and raw YAML syntax are completely stripped from the rendered body, avoiding unsightly code blocks or horizontal rules.
- **Recognized Metadata Display**:
  - `title`: Extracted and displayed as the canonical document title (30sp bold editorial typography).
  - `source`: Rendered with `Icons.link_rounded`. If a URL (`http://`, `https://`, `www.`), rendered with interactive link styling, open-in-new icon, and tap link callback. Plain-text sources are styled cleanly with primary text.
  - `author`: Rendered with `Icons.person_outline_rounded` and supports single strings or multiline YAML lists.
  - `created`: Rendered with `Icons.calendar_today_outlined` and formatted cleanly into human-readable dates (`MMM d, yyyy`), with robust fallback for custom raw date strings.
  - `description`: Rendered with `Icons.notes_rounded` supporting multiline text, folded strings (`>`), and literal blocks (`|`).
- **Automatic Filtering**: Any unrecognized frontmatter keys (such as `status`, `rating`, `id`, `aliases`, or custom YAML attributes) are automatically omitted/hidden from the preview.
- **Bear Aesthetic Properties Card**: Displayed in a warm `colors.surface` container with subtle borders (`colors.divider`), rounded corners (`AppRadii.borderMd`), muted 14dp monochrome icons (`colors.textTertiary`), fixed-width aligned labels (80dp, `AppTypography.caption`), and comfortable row dividers.
- **Verbatim Storage Preservation**: Full frontmatter raw text remains 100% intact in edit mode, local Drift SQLite database, and end-to-end encrypted sync payloads.

---

## 8. Release & CI/CD Workflows

### Multi-Architecture GitHub Release Workflow (`.github/workflows/release.yml`)
- **Trigger**: Manually dispatched via GitHub Actions UI (`workflow_dispatch`) with optional tag/title/draft/prerelease flags, or automatically on git tag push (`v*`).
- **Builds**:
  - `quiet-paper-<version>-arm64-v8a.apk` (Modern 64-bit Android)
  - `quiet-paper-<version>-armeabi-v7a.apk` (32-bit legacy Android)
  - `quiet-paper-<version>-x86_64.apk` (x86_64 Chromebooks / Emulators)
  - `quiet-paper-<version>-universal.apk` (Universal FAT binary)
- Automatically attaches all 4 APK binaries as release assets to the GitHub Release.

---

## 9. Security Guarantees & Verification Checklist

- [x] Plaintext titles, bodies, and tags never reach network requests or server storage.
- [x] Database table `notes` has no `title`, `body`, or `tags` columns.
- [x] Backend source code contains zero decryption methods or global decryption keys.
- [x] Argon2id parameters strictly enforce 19MB memory, 2 iterations, 16-byte cryptographically secure salts.

---

## 10. Hyperlink Security, Dedicated Full-Page Auth & Bugfixes

### Interactive Hyperlink Safety & Domain Trust Persistence
- **Link Tap Handler**: Clicking any markdown link (`[text](url)` or raw URL) or frontmatter `source` URL invokes `LinkLauncherHelper.handleLinkTap(context, url)`.
- **Domain Extraction & Trust Check**: Extracts the normalized domain host from the URL and checks the persisted trusted domains list in `SharedPreferences`.
- **Trusted URLs**: If the domain is already trusted, opens immediately in the default system browser via `url_launcher` (`LaunchMode.externalApplication`).
- **Confirmation Dialog (`LinkConfirmationDialog`)**: If the domain is not yet trusted, prompts the user with an editorial dialog featuring:
  - Header with external link icon and domain title.
  - Scrollable and selectable monospaced container displaying the complete URL (gracefully handling long paths, query parameters, and soft hyphenation).
  - "Trust links from [domain] in the future" checkmark (persisted to `SharedPreferences`).
  - "Cancel" and "Open Link" action buttons.

### Full-Page Dedicated Authentication & Encryption Screens
- **`SyncAuthScreen`**: Dedicated full-page route replacing dialog popups for Cloud Sync onboarding, Step 1 (Email), Step 2 (Account Password), Step 3 (Encryption Password), Step 4 (Recovery Key generation & confirmation), and Sign In.
- **`ChangeEncryptionPasswordScreen`**: Dedicated full-page route for master password rotation with step 1 current ownership verification (via current password or emergency recovery key) and step 2 new encryption password entry.
- **Animated Loading Cues**: High-visibility loading banners and animated progress indicators with clear status explanations during Argon2id key derivation (~300-500ms), Firebase authentication, and vault re-wrapping.
- **`QuietButton(isLoading: true)`**: Displays an inline animated spinner with disabled interactions during async operations.

### Note Lifecycle & Black Screen Bug Fix
- **Tablet vs Phone Navigator Guard**: In split-view tablet layout, `EditorScreen` is an embedded pane rather than a pushed route. Direct calls to `Navigator.of(context).pop()` previously popped the root route, causing the app container to turn black.
- **Fix**: Implemented `isTabletEditor ? widget.onClose?.call() : if (Navigator.canPop()) Navigator.pop()`.
- **Auto-Dismissing SnackBars**: Added `ScaffoldMessenger.of(context).clearSnackBars()`, `behavior: SnackBarBehavior.floating`, and `dismissDirection: DismissDirection.horizontal` to prevent lingering undo banners.

---

## 11. Markdown Highlight (`==text==`), Dynamic Tag Filter Bar & Version 1.2.0

### Markdown Highlight Syntax (`==text==`)
- **Syntax Extension**: Implemented `HighlightSyntax` extending `md.InlineSyntax(r'==([^=\n\r]+)==')` to parse `==highlighted text==` into `<mark>` AST nodes.
- **Visual Builder**: Implemented `HighlightElementBuilder` registered on `QuietMarkdownPreview` to render highlights with a soft, warm amber/accent background tint (`colors.accent.withValues(alpha: 0.22)`), subtle rounded corners, and semi-bold typography matching Bear's clean editorial aesthetic.

### Dynamic Tags Filter Bar Positioning & Auto-Scroll
- **Active Tag Priority**: In `TagsFilterBar`, whenever a tag filter is active (`selectedTagFilterProvider != null`), the selected tag is dynamically moved from its position in the list to index 1 (immediately next to the "All" pill).
- **Auto-Scroll to View**: Converted `TagsFilterBar` to `ConsumerStatefulWidget` listening to `selectedTagFilterProvider`. When a user selects a tag from the sidebar or tag browser sheet that was previously off-screen in the horizontal bar, the list automatically animates its scroll position to `0.0`, bringing "All" and the active tag into full view.
- **Toggling & Reset**: Tapping the active tag chip deselects it and smoothly restores the default list order.

---

- [x] Search is 100% local and functions completely without network connectivity.
- [x] Trash notes are persisted indefinitely with zero auto-delete.
- [x] Idempotency keys prevent duplicate note creation on network retries.
- [x] Conflict detection returns structured `SYNC_CONFLICT` on stale `baseRevision`.
- [x] Atomic login: If encryption password is wrong, Firebase session is immediately terminated and app stays logged out.
- [x] Password rotation verification: Changing encryption passwords requires verifying ownership with current password or recovery key, and backend enforces cryptographic proof (`key_auth_commitment`).
- [x] Outdated or duplicate key versions during rotation are rejected with `409 CONFLICT`.



