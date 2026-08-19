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

## 12. Sync Push Deletion Tombstone Validation & New Device Sync Fix

### Problem
- On a fresh device installation or during normal usage, when empty drafts are discarded or notes are permanently deleted before sync, deletion tombstones with empty ciphertext and nonce (`contentCiphertext: ''`, `contentNonce: ''`, `isDeleted: true`) are enqueued in `sync_queue`.
- When triggering sync, the backend Zod validation schema `noteChangeSchema` previously enforced strict non-empty string length constraints (`.min(1)` for `contentCiphertext` and `.min(12)` for `contentNonce`), failing with HTTP `400 BAD_REQUEST: Invalid sync push body: String must contain at least 1 character(s)` on `changes.0.contentCiphertext` and `changes.0.contentNonce`.
- Additionally, when pulling deleted notes from the server, `SyncEngine` invoked `AppDatabase.deletePermanently()`, which unintentionally re-enqueued the deleted note IDs back into the local `sync_queue` for subsequent push.

### Solution
1. **Conditional Backend Validation (`backend/src/validation/schemas.ts`)**:
   - Refactored `noteChangeSchema` to default `contentCiphertext` and `contentNonce` to empty strings and apply `superRefine`.
   - Active notes continue to strictly enforce `.min(1)` for ciphertext and `.min(12)` for nonce.
   - Deleted notes (`isDeleted === true` or `deletedAt != null`) are permitted to send empty strings for ciphertext and nonce.
2. **Pull Queue Loop Prevention (`lib/core/database/app_database.dart` & `sync_engine.dart`)**:
   - Added `{bool enqueueSync = true}` optional parameter to `deletePermanently()`, `emptyTrash()`, `deletePermanentlyBatch()`, and `deleteNote()`.
   - `SyncEngine` passes `enqueueSync: false` when applying pulled deletions so incoming remote deletions are deleted locally without being re-enqueued for push.
3. **Defensive Model Deserialization (`lib/core/sync/sync_models.dart`)**:
   - Updated `NoteSyncPayload.fromJson` and `PullChangeItem.fromJson` to use null-coalescing (`as String? ?? ''`) for ciphertext and nonce fields.

---

## 13. GitHub Releases Auto-Update Engine

### Overview
Quiet Paper features a native, background-aware auto-update engine powered directly by GitHub Releases (`https://github.com/blackpirateapps/quitepaper`):
- **GitHub Releases Integration**: Queries `https://api.github.com/repos/blackpirateapps/quitepaper/releases/latest` for release metadata, semver versions, release notes changelog, and multi-architecture APK assets.
- **Smart Architecture Matching**: Uses native Android ABI detection (`Build.SUPPORTED_ABIS`) via platform channel to select the matching APK binary (`arm64-v8a`, `armeabi-v7a`, `x86_64`, with fallback to `universal`).
- **App Launch Prompt**: When the app is launched fresh (after being closed from recents), an asynchronous background check verifies if a newer release exists. If available and not snoozed, the warm editorial `UpdateDialog` appears.
- **30-Day Snooze Mechanism**:
  - The update dialog features a "Don't remind me for 30 days" checkbox when dismissing.
  - Snooze expiry timestamp and snoozed version are persisted in `SharedPreferences` (`update_snoozed_until`, `update_snoozed_version`).
  - Subsequent app launches within 30 days suppress prompts for that specific version while still permitting prompts if a newer version is subsequently published.
- **In-App Direct Downloader**:
  - Downloads the selected APK streamingly to the application's temporary cache directory with real-time percentage and byte progress updates (`LinearProgressIndicator`).
- **Android Package Installer & Permission Handling**:
  - Registers `REQUEST_INSTALL_PACKAGES` permission and `androidx.core.content.FileProvider` in `AndroidManifest.xml` (`@xml/file_paths`).
  - Platform MethodChannel (`com.blackpiratex.quietpaper/updater`) triggers `Intent.ACTION_VIEW` with `application/vnd.android.package-archive` and `FLAG_GRANT_READ_URI_PERMISSION`.
  - Checks `canRequestPackageInstalls()` on Android 8.0+ and provides one-tap navigation to system settings (`ACTION_MANAGE_UNKNOWN_APP_SOURCES`) if installation permission has not yet been granted.
- **Settings Screen Integration**:
  - Displays current version in the About section and provides an on-demand "Check for updates" button that bypasses snooze.

---

## 14. Local Backup & Rolling Auto-Backup System

### Overview
Quiet Paper includes a complete, high-fidelity local backup system with optional client-side encryption and automated daily rolling backups:

- **Unified Backup Format (`.qpbackup`)**:
  - **Unencrypted Format (`quietpaper:backup:v1`)**: Canonical UTF-8 JSON containing full notebook snapshot (notes, tags, markdown contents, pinned/archived/trash states, timestamps, schema version).
  - **Encrypted Envelope (`quietpaper:encrypted-backup:v1`)**: Protected with **Argon2id** key derivation (`19MB memory`, `2 iterations`) and **XChaCha20-Poly1305** authenticated encryption. Decryption immediately verifies the Poly1305 MAC tag and rejects incorrect passwords.
- **Manual Backup & Restore Dialogs**:
  - [`CreateBackupDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/create_backup_dialog.dart): Live note statistics preview, optional password toggle with confirmation, and folder destination selector.
  - [`RestoreBackupDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/restore_backup_dialog.dart): File selector, password unlock interface for encrypted snapshots, pre-restore validation summary, and 3 restore conflict strategies:
    1. **Merge (Recommended)**: Adds missing notes, updates local notes if the backup version has a newer `updatedAt`, and preserves newer local edits.
    2. **Keep Both**: Re-generates UUIDs and appends `(Restored)` title suffix for colliding notes.
    3. **Clean Replace**: Erases current notebook and restores the exact backup snapshot.
- **Automated Daily Rolling Backups**:
  - Triggers non-blocking in background on app launch if $\ge 24$ hours have elapsed since the previous backup.
  - User chooses the destination directory via folder picker.
  - User chooses retention limit (**3, 5, 10, or 30 rolling backups**).
  - Automatically prunes older `quietpaper_autobackup_*.qpbackup` files in the folder when the count exceeds the retention limit.
  - [`AutoBackupPasswordDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/auto_backup_password_dialog.dart): Allows configuring an optional background encryption password securely persisted in `FlutterSecureStorage` so daily rolling backups can execute unattended.
- **Cloud Sync Compatibility**: Restored notes are saved with `isDirty: true` and `serverRevision: 0`, seamlessly queuing them for cloud sync.

---

## 15. Auth Session & Cryptographic Key Persistence Across App Restarts & Updates

### Problem & Root Cause
Prior to this fix, users found themselves logged out whenever the app was updated or closed from recents:
1. **In-Memory Firebase Auth State**: `FirebaseAuthService` stored `_currentUser` only as an in-memory field. Process termination (such as during APK updates or OS process reclaim) wiped the session, resetting `currentUser` to `null`.
2. **Missing Token Refresh on Launch**: The app did not restore credentials or exchange the stored `refreshToken` for a valid `idToken` upon startup.
3. **Master Key Volatility**: `SecureKeyManager` maintained the decrypted `_cachedMasterKey` exclusively in RAM, requiring repeated encryption password entries to re-unlock notes after restarts.

### Solution
- **Persistent Auth Session in FlutterSecureStorage**:
  - `FirebaseAuthService` automatically persists and serializes `AuthUser` (User ID, Email, `idToken`, `refreshToken`, `tokenExpiresAt`) to platform-encrypted secure storage (`quietpaper_auth_session_v1`).
  - `FirebaseAuthService.initialize()` is called at application boot in `main.dart`, restoring the active session and refreshing tokens via Firebase SecureToken API if expired.
  - Calling `signOut()` cleanly wipes the persisted session.
- **Persistent Hardware-Backed Master Key Storage**:
  - `SecureKeyManager` persists the unwrapped Master Key in `FlutterSecureStorage` (`quietpaper_master_key_v1`) using Android Keystore / iOS Keychain encryption upon initial password setup or unlock.
  - `SecureKeyManager.initialize()` restores the unlocked state on app startup, ensuring uninterrupted zero-knowledge encryption sync across app updates and launches.
  - Calling `clearLocalKeys()` or explicit logout purges the stored master key and wrapped key data.

---

## 16. Scoped Storage-Safe Local Backup File Creation

### Problem & Root Cause
On Android 10+ (and especially Android 11+ / API 30+ Scoped Storage), calling `FilePicker.platform.getDirectoryPath()` and then attempting to create a new file directly via POSIX `File('/storage/emulated/0/...').writeAsString()` threw `PathAccessException: Cannot open file ... (OS Error: Operation not permitted, errno = 1)` because direct filesystem write access outside app-private directories is restricted by modern Android Scoped Storage policies.

### Solution
- **Native Storage Access Framework (SAF) File Saving**:
  - `BackupService.generateBackupBytes()` now renders the full unencrypted or Argon2id-encrypted `.qpbackup` binary in memory.
  - `CreateBackupDialog` invokes `FilePicker.platform.saveFile(...)` passing the pre-rendered payload bytes, default filename (`quietpaper_backup_YYYY-MM-DD_HHMMSS.qpbackup`), and extension filter (`qpbackup`).
  - On Android, `FilePicker` utilizes Android's native `ACTION_CREATE_DOCUMENT` Storage Access Framework, allowing the user to select any storage location (Downloads, Documents, External SD, Google Drive) while the system ContentResolver streams bytes directly with zero permission errors.
  - On Desktop/iOS platforms, `saveFile` writes the file natively or returns the verified destination path.

---

## 17. App Version Bump Checklist

When releasing a new version of Quiet Paper, ensure the version string (and incremental build number) is consistently bumped across the following files:

| File | Parameter / Location | Description & Purpose |
|---|---|---|
| [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml#L19) | `version: X.Y.Z+N` | Flutter build version name (`X.Y.Z`) and Android/iOS build number / `versionCode` (`N`). |
| [`lib/core/update/update_provider.dart`](file:///home/dog/git/quitepaper/lib/core/update/update_provider.dart#L10) | `currentVersion: 'X.Y.Z'` | Used by `UpdateService` to compare with GitHub Release tags (`vX.Y.Z`) and trigger in-app update prompts. |
| [`lib/core/backup/backup_provider.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_provider.dart#L17) | `appVersion: 'X.Y.Z'` | Stored in Riverpod `backupServiceProvider` and written to backup manifest headers. |
| [`lib/core/backup/backup_service.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_service.dart#L19) | `this.appVersion = 'X.Y.Z'` | Default constructor parameter for `BackupService` manifest generation. |
| [`lib/features/settings/presentation/settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart#L783) | `'Version X.Y.Z • ...'` | Displayed to the user under **Settings → About**. |

---

## 18. Auto-Dismissing Undo SnackBars (`persist: false`)

### Problem & Root Cause
In recent versions of Flutter (Flutter 3.44+), `SnackBar` introduced the `persist` property which defaults to `action != null` (`persist = persist ?? action != null;`). Consequently, any SnackBar rendered with an action (such as the `'Undo'` button on archive, unarchive, trash, and restore notifications) defaults to `persist: true`. When `persist: true`, the internal Scaffold timeout timer in `ScaffoldMessengerState` returns early without calling `hideCurrentSnackBar(reason: SnackBarClosedReason.timeout)`, causing "Note archived" and "Undo" banners to persist on screen indefinitely unless dismissed manually.

### Solution
- Set `persist: false` on all action-bearing SnackBars across [`notes_screen.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/notes_screen.dart) and [`search_screen.dart`](file:///home/dog/git/quitepaper/lib/features/search/presentation/search_screen.dart).
- Ensured `ScaffoldMessenger.of(context).clearSnackBars()` is called prior to presenting new SnackBars in multi-select batch actions and dialog callbacks.
- Added automated widget tests to verify that archive/undo SnackBars automatically timeout and dismiss after their configured duration.

---

## 19. Settings Restore Backup Dialog Responsive Action Layout & Overflow Fix

### Problem & Root Cause
In [`RestoreBackupDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/restore_backup_dialog.dart), the validated preview state displayed a single horizontal `Row` containing "Change File" (left), "Cancel" (middle-right), and the primary "Restore X Notes" button (right). On mobile devices with $\le 400\text{dp}$ screen width (accounting for dialog insets and inner padding), the combined intrinsic width of these 3 actions exceeded available horizontal space, causing the "Restore X Notes" button to overflow past the right boundary of the dialog card. Additionally, dialog contents lacked `SingleChildScrollView`, which could risk vertical clipping on small screens.

### Solution
- **Responsive Layout via `LayoutBuilder`**:
  - For narrow viewports ($< 390\text{dp}$ available dialog width), "Change File" is rendered on its own row, with "Cancel" and "Restore X Notes" wrapped in an end-aligned `Wrap` widget.
  - For wider viewports ($\ge 390\text{dp}$), the actions render inline as a single balanced row.
- **`SingleChildScrollView` Container**:
  - Wrapped dialog bodies across [`RestoreBackupDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/restore_backup_dialog.dart), [`CreateBackupDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/create_backup_dialog.dart), and [`AutoBackupPasswordDialog`](file:///home/dog/git/quitepaper/lib/core/backup/presentation/auto_backup_password_dialog.dart) in `SingleChildScrollView` inside `ConstrainedBox` to ensure complete vertical responsiveness.
- **Unit & Widget Tests**:
  - Added narrow layout test coverage in [`test/backup/backup_dialog_test.dart`](file:///home/dog/git/quitepaper/test/backup/backup_dialog_test.dart) ensuring zero rendering exceptions or layout overflows.

---

## 20. Settings Screen iOS Grouped Table & Bear Notes Aesthetic Overhaul

### Problem & Motivation
The Settings interface previously utilized floating Material cards with separated outline/tonal buttons, inconsistent icon alignment, standard Material switches, and loose spacing. To achieve the clean, editorial Bear Notes aesthetic while preserving the app's warm cozy dark/light color palette, the Settings screen was refactored into an iOS Grouped Table style.

### Key Architectural & UI Enhancements
1. **Grouped Containers & Flush Rows**:
   - Replaced loose floating elements with flush, stacked rows inside `_SettingsGroup` containers styled with tight corner radii (`BorderRadius.circular(11)`), subtle borders (`colors.divider`), and internal anti-aliasing clip.
   - Stacked rows are separated by ultra-thin dividers with an exact `indent: 52` (16dp padding + 24dp icon bounding box + 12dp spacing), aligning the start of the divider with text content.
2. **Row-Based Actions & Trailing Chevrons**:
   - Replaced individual button widgets ("Sync Now", "Change Password", "Sign Out", "Create Backup", "Restore Backup", "Choose folder", "Select files", "Load sample notes", "Check for updates") with full-width clickable `_SettingsRow` elements featuring leading icons and trailing right-pointing chevrons (`Icons.chevron_right_rounded`).
   - "Create Backup" uses coral accent typography while maintaining identical background styling for visual harmony.
   - Destructive actions ("Sign Out") render in subtle error hues.
3. **Refined Typography & Section Headers**:
   - Section headers ("CLOUD SYNC & ENCRYPTION", "APPEARANCE", "IMPORT", "LOCAL BACKUP & RESTORE", "SAMPLE NOTES", "ABOUT") are formatted in uppercase, 11.5sp, bold weight, with +1.1 letter tracking, and positioned tightly (8dp) above their corresponding grouped container.
   - Explanatory copy uses 12.5sp with 1.45 line-height for optimal legibility.
4. **Standardized iOS Controls & Uniform Icons**:
   - Replaced thick Android Material toggles with `CupertinoSwitch` (with `activeTrackColor: colors.accent`).
   - Standardized all leading icons within fixed 24x24 bounding boxes with 20sp glyphs, centered vertically against primary title text.
5. **Tablet Responsiveness**:
   - Grouped table list is constrained to a max-width of `680dp` centered on tablet viewports, preventing awkward horizontal stretching on wide screens while maintaining comfortable margins.
6. **Automated Verification**:
   - Added unit and widget tests in [`test/settings/settings_screen_test.dart`](file:///home/dog/git/quitepaper/test/settings/settings_screen_test.dart) covering all grouped sections, interactions, and tablet layout constraints.

---

## 21. Multi-Architecture Android APK Build & Separate Upload Workflow

### Motivation
Previously, the `Build Android APK` CI workflow ([`.github/workflows/build_apk.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_apk.yml)) only built a single monolithic release APK (`app-release.apk`) and uploaded it under a single artifact name. For modern Android installations, architecture-specific APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) offer dramatically smaller download footprints and faster installations.

### Enhancements
1. **Split-Per-ABI & Universal Builds**:
   - Compiles split-per-ABI APKs (`flutter build apk --split-per-abi --release`) for `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
   - Compiles a universal fallback release APK (`flutter build apk --release`).
2. **Version Extraction & Naming Standard**:
   - Extracts semantic app version from `pubspec.yaml`.
   - Standardizes output naming:
     - `quiet-paper-${VERSION}-arm64-v8a.apk`
     - `quiet-paper-${VERSION}-armeabi-v7a.apk`
     - `quiet-paper-${VERSION}-x86_64.apk`
     - `quiet-paper-${VERSION}-universal.apk`
3. **Separate & Combined Artifact Uploads**:
   - Uploads individual artifacts for each architecture (`quiet-paper-${VERSION}-arm64-v8a`, `quiet-paper-${VERSION}-armeabi-v7a`, `quiet-paper-${VERSION}-x86_64`, `quiet-paper-${VERSION}-universal`) via `actions/upload-artifact@v4`.
   - Uploads a bundled archive containing all APKs (`quiet-paper-${VERSION}-all-apks`).

---

## 22. Markdown-Aware WYSIWYG Editor (V1)

### Motivation & Core Architectural Principles
Prior to V1, the editor presented plain, unformatted text while editing, requiring users to toggle to Markdown preview mode to inspect document hierarchy and formatting. To provide a calm, distraction-free writing experience inspired by Bear Notes and Typora:
1. **Markdown is the Source of Truth**: The underlying note content remains a standard Markdown string. No custom rich-text JSON, HTML, Delta, ProseMirror, or Quill AST document models are introduced.
2. **TextSpan Dynamic Presentation**: Formatting is computed purely in presentation via `MarkdownEditingController.buildTextSpan()` and `MarkdownParser.buildTextSpan()`, generating a styled `TextSpan` tree while leaving underlying characters 100% intact.
3. **1:1 Selection and Cursor Accuracy**: There is an exact 1:1 correspondence between character indices in the editable text and Flutter's selection/caret offsets. Copying returns the exact Markdown source, pasting preserves Markdown structure, and standard undo/redo remains native and uninterrupted.
4. **Zero Migration Required**: Existing notes in SQLite/cloud sync load immediately with zero database schema migrations or data conversions.

### Core Components
- [`MarkdownToken` & `MarkdownTokenType`](file:///home/dog/git/quitepaper/lib/features/editor/domain/markdown_token.dart): Semantic token definitions for block and inline elements.
- [`MarkdownStyles`](file:///home/dog/git/quitepaper/lib/features/editor/domain/markdown_styles.dart): Centralized, theme-aware style definitions adapting to Light/Dark modes via `AppColors` and `AppTypography`.
- [`MarkdownTokenizer`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_tokenizer.dart): Deterministic tokenizer scanning blocks and inline elements with support for escaping, nesting, and graceful tolerance of incomplete syntax.
- [`MarkdownParser`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_parser.dart): High-performance linear parser compiling text into styled `TextSpan` trees with Android IME composing underline support (`composingRange`).
- [`MarkdownEditingController`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_editing_controller.dart): `TextEditingController` subclass providing dynamic theme-aware styling.
- [`MarkdownTextInputFormatter`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_text_input_formatter.dart): Formatter handling auto-continuation for unordered lists (`- `, `* `, `+ `), auto-incrementing ordered lists (`1. `, `2. `), blockquotes (`> `), and clearing empty markers on Enter.
- [`MarkdownEditor`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart): Dedicated editorial writing sheet widget embedded in [`EditorScreen`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart).

### Supported Syntax & Visual Representations
- **Headings**: `#` to `######` render with proportional font sizes (`editorH1` to `editorH6`), bold typography, and subdued syntax markers (`#`).
- **Bold & Italic**: `**bold**`, `__bold__`, `*italic*`, `_italic_`, `***bold italic***`, `___bold italic___` with subtle delimiters.
- **Strikethrough & Highlight**: `~~strikethrough~~` (line-through decoration) and `==highlight==` (soft amber/accent background tint).
- **Inline Code & Code Blocks**: `` `code` `` and fenced ` ```lang ... ``` ` with monospace typography and subdued fences.
- **Lists & Quotes**: Unordered lists (`- `, `* `, `+ `), ordered lists (`1. `, `2. `), and blockquotes (`> `) with accent markers and comfortable indentation.
- **Links & Tags**: `[link title](url)` with interactive styling, bare URLs, and `#tag` highlights.
- **Escapes & Tolerant Parsing**: `\*`, `\_`, etc. are preserved literally without false formatting, and incomplete Markdown never crashes the editor.

---

## 23. Markdown Editor V2 (Smart Markdown, Keyboard Shortcuts, Selection Toolbar, Interactive Checklists)

### Architectural Overview
Building upon the V1 presentation-only styling engine, V2 adds rich editing superpowers while strictly adhering to the core principle: **Markdown is the single canonical data store**. All operations directly manipulate the underlying Markdown source string, ensuring 100% data integrity, instant autosave, and seamless participation in native undo/redo.

### 1. Smart Markdown Editing (`MarkdownTextInputFormatter`)
- **Checklist Continuation & Clearing**:
  - Pressing Enter at the end of `- [ ] Task` creates a new uncompleted task `- [ ] `.
  - Pressing Enter on a completed task `- [x] Task` creates a new uncompleted task `- [ ] `.
  - Pressing Enter on an empty checklist marker `- [ ] ` or `- [x] ` cleanly terminates the checklist and clears the line prefix.
  - Supports indented/nested checklists (`  - [ ] `).
- **Code Block Safety**:
  - Inside fenced code blocks (`` ``` `` or `~~~`), Enter behaves normally without inserting list or quote markers.
- **Auto-Pairing & Delimiter Skipping**:
  - Typing delimiters (`*`, `_`, `~`, `` ` ``, `[`, `(`) around selected text automatically wraps the selection.
  - Typing a closing delimiter when the cursor is directly before that matching character advances the cursor without producing duplicates.

### 2. Context-Aware Formatting Utilities (`MarkdownFormatter`)
- Pure, functional transformations for `TextEditingValue` covering `toggleBold`, `toggleItalic`, `toggleStrikethrough`, `toggleInlineCode`, `createLink`, `toggleChecklist`, `toggleBulletList`, `toggleOrderedList`.
- Automatically detects if the selected text (or surrounding characters) already have formatting delimiters and toggles them off without creating invalid nested syntax.

### 3. Keyboard Shortcuts (`CallbackShortcuts`)
- Physical & hardware keyboard support across Android, desktop, web, and tablets:
  - `Ctrl+B` / `Cmd+B`: Toggle Bold.
  - `Ctrl+I` / `Cmd+I`: Toggle Italic.
  - `Ctrl+Shift+X` / `Cmd+Shift+X`: Toggle Strikethrough.
  - `Ctrl+` ` / `Cmd+` `: Toggle Inline Code.
  - `Ctrl+K` / `Cmd+K`: Insert / Edit Link dialog ([`LinkPromptDialog`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/link_prompt_dialog.dart)).
  - Standard editing shortcuts (`Ctrl+C`, `Ctrl+V`, `Ctrl+X`, `Ctrl+A`, `Ctrl+Z`, `Ctrl+Shift+Z`) remain completely native.

### 4. Selection-Aware Formatting Toolbar (`contextMenuBuilder`)
- Integrated into Flutter's `contextMenuBuilder` to provide floating, touch-friendly formatting actions (`Bold`, `Italic`, `Strike`, `Code`, `Link`, `Checklist`) alongside native text actions (`Cut`, `Copy`, `Paste`, `Select All`).
- Responsive positioning adapts automatically to viewport, orientations, and keyboard insets.

### 5. Interactive Markdown Checklists
- **Visual Presentation**: Checklist markers `- [ ] ` and `- [x] ` / `- [X] ` are tokenized with distinct syntax styling (`checklistMarker` and `checklistMarkerChecked`), with completed task text styled using `taskTextCompleted` (subtle strikethrough).
- **Tap Hit-Testing & Direct Toggling**: Tapping directly on the checkbox marker area of a checklist item immediately toggles between `- [ ] ` and `- [x] ` in the Markdown source, updates controller text, triggers autosave, and preserves selection.

---

- [x] Search is 100% local and functions completely without network connectivity.
- [x] Trash notes are persisted indefinitely with zero auto-delete.
- [x] Idempotency keys prevent duplicate note creation on network retries.
- [x] Conflict detection returns structured `SYNC_CONFLICT` on stale `baseRevision`.
- [x] Atomic login: If encryption password is wrong, Firebase session is immediately terminated and app stays logged out.
- [x] Password rotation verification: Changing encryption passwords requires verifying ownership with current password or recovery key, and backend enforces cryptographic proof (`key_auth_commitment`).
- [x] Outdated or duplicate key versions during rotation are rejected with `409 CONFLICT`.
- [x] Deletion tombstones with empty ciphertexts sync cleanly without schema validation errors.
- [x] GitHub Releases update engine automatically detects architecture-specific APKs, handles 30-day snooze, and triggers in-app package installation.
- [x] Local backup engine creates and restores `.qpbackup` snapshots with optional Argon2id encryption, conflict strategies, and daily rolling auto-backups with retention pruning.
- [x] User auth sessions and unlocked master keys are securely persisted in Android Keystore / iOS Keychain across app updates and process restarts.
- [x] Local backup file creation utilizes Android Storage Access Framework (SAF) to write `.qpbackup` files safely on modern Android Scoped Storage without permission exceptions.
- [x] App version bump procedure is documented in HANDOFF.md across all 5 code locations.
- [x] Undo action SnackBars explicitly set `persist: false` to ensure reliable auto-dismissal after duration.
- [x] Settings restore and backup dialog action layouts are fully responsive and wrapped with `SingleChildScrollView` to prevent UI overflow.
- [x] Settings screen conforms to the iOS Grouped Table / Bear Notes aesthetic with flush grouped rows, Cupertino controls, indented dividers, and tablet max-width constraints.
- [x] Android CI build workflow (`build_apk.yml`) builds multi-architecture APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `universal`) and uploads them as separate artifacts.
- [x] Markdown Editor V2 implements smart editing (checklist continuation/clearing, delimiter skipping, code fence safety), keyboard shortcuts (Ctrl+B/I/Shift+X/`/K), selection-aware context toolbar, and interactive checkbox tapping.
- [x] Heading, Checkbox, List & Quote whitespace preservation: Whole-remainder line parsing and adjacent span merging ensure all spaces typed immediately after hashes (`#`), checkboxes (`- [ ]`), list bullets (`-`, `1.`), and quotes (`>`) as well as trailing spaces appear instantly at their full layout width without disappearing or cursor delay.
- [x] Typography Settings with sticky live preview, curated font presets, dynamic Google Fonts API fetcher, custom TTF/OTF local font loader, and responsive dimension controls (font size, line height, letter spacing, paragraph width, paragraph indent).
- [x] Note-level security features: Read-Only mode toggle to lock editing and prevent accidental keystrokes, and individual note password protection with Argon2id and XChaCha20-Poly1305 AEAD client-side encryption.
- [x] Linux compile workflow (`build_linux.yml`) configured for manual invocation via `workflow_dispatch` only.
- [x] Version bumped to `1.4.0+6` across all 5 code locations (`pubspec.yaml`, `update_provider.dart`, `backup_provider.dart`, `backup_service.dart`, `settings_screen.dart`).

---

## 24. Typography Customization & Global Styling Engine

### Architectural Overview
Quiet Paper features a comprehensive typography engine that allows users to customize their writing and reading environment with persistent state across app restarts, responsive layout constraints, dynamic font registration, and reactive live preview.

### Domain Model & State Management
- **`TypographySettings`** ([`lib/features/settings/domain/typography_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/typography_settings.dart)):
  - Immutable configuration model managing:
    - `headingFontFamily`: Font family for `#` to `######` headings and document title (defaults to system/body font).
    - `bodyFontFamily`: Font family for editor body paragraphs, blockquotes, and lists.
    - `codeFontFamily`: Font family for inline code and codeblocks (defaults to `'monospace'`).
    - `fontSize`: Base body font size (default: 18.0 pt, range: 12.0–32.0 pt).
    - `lineHeight`: Vertical line height multiplier (default: 1.6x, range: 1.0–2.5x).
    - `letterSpacing`: Character tracking spacing in px (default: 0.0 px, range: -1.0–2.0 px).
    - `paragraphWidth`: Content width constraint (`Narrow` [540dp], `Medium` [720dp], `Full` [unconstrained]).
    - `paragraphIndent`: Left start indent for content (0–40 px).
    - `customFonts`: List of dynamically loaded font families.
  - Proportional heading scales (`scaledTitleSize` [30pt at 18pt base], `scaledHeading1Size` [26pt], `scaledHeading2Size` [22pt], `scaledHeading3Size` [19pt], `scaledHeading4Size` [18pt], `scaledHeading5Size` [17pt], `scaledHeading6Size` [16pt], `scaledCodeSize` [15pt]).
- **Bundled Fonts & Font Resolution** ([`lib/core/utils/font_family_helper.dart`](file:///home/dog/git/quitepaper/lib/core/utils/font_family_helper.dart)):
  - 8 core font families and variants are baked directly into the APK assets (`assets/fonts/`) and declared in `pubspec.yaml` for instant 100% offline access: `Inter`, `Roboto`, `Lora`, `Merriweather`, `Open Sans`, `Lato`, `JetBrains Mono`, `Fira Code`.
  - Dynamic resolution via `FontFamilyHelper.getTextStyle` which falls back smoothly to `GoogleFonts.getFont()` for the entire 1,500+ Google Fonts catalog or system fonts.
- **`TypographySettingsNotifier`** ([`lib/features/settings/application/typography_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/typography_provider.dart)):
  - Persists JSON state in `SharedPreferences` under key `typography_settings_v1`.
  - `loadCustomFontFromFile(filePath)`: Reads raw TTF/OTF bytes from device storage and registers font dynamically using Flutter's `FontLoader`.
  - `resetToDefault()`: Restores factory defaults with a single tap.

### UI / UX Implementation
- **`TypographySettingsScreen`** ([`lib/features/settings/presentation/typography_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/typography_settings_screen.dart)):
  - Single, unified scroll flow (no sticky header).
  - **Group 1 (Typefaces)**: Heading, Body, and Code font rows opening [`FontPickerSheet`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/font_picker_sheet.dart).
  - **Group 2 (Dimensions)**: Minimalist coral sliders with live numeric badges for Font Size, Line Height, Letter Spacing, and Paragraph Indent.
  - **Group 3 (Layout & Actions)**: Cupertino segmented control for Paragraph Width (`Narrow`, `Medium`, `Full`), and centered coral "Reset to Default" button.
  - **Group 4 (Bottom Live Preview)**: Placed naturally at the bottom of the page in a rounded `12dp` card with generous height and no artificial clipping, rendering full Markdown (headings, formatted body, quote, checklist, and code blocks) dynamically in real-time.
- **`FontPickerSheet` & `GoogleFontsSheet`** ([`lib/features/settings/presentation/widgets/`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/)):
  - Fast font picker with live typography preview for each font item.
  - "Google Fonts" browser action displaying a searchable catalog with category filtering (Sans-serif, Serif, Monospace, Handwriting, Display).
  - "Import .ttf" button for custom local fonts.

---

## 25. Note-Level Security Features (Read-Only Mode & Password Protection)

### 1. Read-Only Mode
- **Purpose**: Prevents accidental keystrokes, edits, or deletions when reading notes or reviewing references.
- **Implementation**:
  - Toggled from the editor overflow menu or the app bar lock icon button.
  - Passes `readOnly: true` to both Document Title `TextField` and `MarkdownEditor`.
  - Automatically hides the formatting toolbar when read-only mode is active.
  - Displays a subtle lock badge in the `AppBar` actions with tooltip "Read-only mode (tap to unlock)".

### 2. Individual Note Password Protection
- **Cryptographic Architecture** ([`lib/features/notes/application/note_security_service.dart`](file:///home/dog/git/quitepaper/lib/features/notes/application/note_security_service.dart)):
  - **Key Derivation**: Argon2id KDF (`memory: 19MB`, `iterations: 2`, `parallelism: 1`, `hashLength: 32`) with a unique 16-byte random salt per note.
  - **Cipher**: XChaCha20-Poly1305 AEAD with a 24-byte random nonce and 16-byte MAC authentication tag.
  - **Payload Format**: Encrypts `{title, content, tags, hint}` into an encrypted envelope header:
    `<!-- quiet-paper-encrypted-note-v1:{"version":1,"salt":"...","nonce":"...","ciphertext":"...","hint":"..."} -->`
  - In SQLite and cloud sync, the note title is stored as empty and content is stored as the encrypted envelope string.
- **Editor & UI Integration**:
  - **Note List**: Displays a lock icon (`Icons.lock_rounded`) and masked preview snippet (`🔒 Password protected note`).
  - **Unlock View** ([`lib/features/editor/presentation/widgets/password_unlock_view.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/password_unlock_view.dart)): Full-screen unlock prompt embedded inside `EditorScreen` requesting the password, displaying optional hint, and showing clear error feedback on incorrect attempt.
  - **Overflow Actions**: Includes "Protect with password", "Change note password", "Remove password protection", and "Lock note now".

---

## 26. WYSIWYG Heading Whitespace Loss & FUTO Android IME Composing Fix

### Problem & Root Cause
On Android devices (specifically tablets running predictive or on-device voice/neural IMEs such as FUTO Keyboard), typing headings (`#`, `# Hello `, `# Hello world`) exhibited whitespace drops, collapsed whitespace spans, and frozen caret advancement:
1. **Regex Re-parsing & Spans Boundary Fragmentation**: The heading parser previously used regex capture groups (`^(\s*)(#{1,6})(?:([ \t])(.*)|$)`), extracting hashes, separator whitespace, and content into distinct captures. When reassembled, typed spaces immediately following hashes or between words could become isolated into standalone whitespace-only `TextSpan`s.
2. **IME Composing Underline Collision**: Android IMEs maintain an active composing range across active tokens. When composing range decoration (`TextDecoration.underline`) was applied across fragmented spans or whitespace-only spans, text layout engines could treat trailing/boundary spaces as zero-width or defer their caret offset calculation.
3. **Inadequate Text-Only Test Coverage**: Previous unit tests asserted `TextSpan.toPlainText()`, which only verified string presence without verifying `RenderEditable` layout metrics, glyph boundaries, or caret X-position advancement during live IME composition.

### Architectural Solution & Heading-Span Invariants
- **Single-Pass Source-Slice Heading Scanner** ([`lib/features/editor/application/markdown_parser.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_parser.dart)):
  - Replaced double-regex matching with a deterministic single-pass scanner (`_tryParseHeading`).
  - Scans indentation, counts 1–6 `#` hash markers, and validates heading separator whitespace in $O(N)$ linear time.
  - Passes the exact remaining source—including leading separators, consecutive spaces, and trailing whitespace—directly into `_parseInlineSegments` with exact absolute offsets.
  - Maintains the **source-contiguous heading run invariant**: the heading content remainder is emitted as a contiguous source slice without artificial boundary splitting, preserving exact character indices and font metrics.
- **Composing-Range Compatibility**:
  - Marker styling inherits identical font size, line height, and baseline metrics from the target heading level (`styles.getHeadingStyle(level)`), avoiding font-metric jumping.
  - Active Android composing underline decorations are applied seamlessly across contiguous span slices without zero-width whitespace collapses.
- **Widget-Level Regression Coverage** ([`test/editor/markdown_editor_widget_test.dart`](file:///home/dog/git/quitepaper/test/editor/markdown_editor_widget_test.dart) & [`test/editor/markdown_parser_test.dart`](file:///home/dog/git/quitepaper/test/editor/markdown_parser_test.dart)):
---

## 27. End-to-End Encrypted Images & Attachments Architecture

### Architectural Overview & Zero-Knowledge Invariants
Quiet Paper supports inline images and binary attachments with strict zero-knowledge security guarantees and high-performance direct cloud storage offloading:
1. **Zero Raw Image Payload on Vercel Backend**:
   - Vercel serverless functions act purely as an authentication and authorization control plane.
   - Serverless functions never receive, decrypt, or proxy binary image payloads.
   - All image encryption (`XChaCha20-Poly1305`) occurs strictly client-side on the user's device using the user's Master Key.
2. **Direct-to-Cloudinary Upload Protocol via Signed Parameters**:
   - Flutter requests cryptographic upload authorization from backend (`POST /api/v1/attachments/upload-auth`).
   - The backend validates Firebase JWT identity, signs parameters with SHA-1 HMAC (`CLOUDINARY_API_SECRET`), and returns signed Cloudinary parameters (`uploadUrl`, `apiKey`, `signature`, `timestamp`, `publicId`, `folder`).
   - Flutter uploads ciphertext directly to Cloudinary (`multipart/form-data`) as `raw` resource type.
   - Flutter confirms upload with backend (`POST /api/v1/attachments/confirm`), updating the metadata record in Turso/libSQL.
3. **Internal `qp://` Canonical Resource Scheme**:
   - Canonical internal URI: `qp://asset/<UUID>` (and `qp://note/<UUID>` for cross-note linking).
   - URIs are parsed, validated, and resolved locally by [`QuietPaperResourceResolver`](file:///home/dog/git/quitepaper/lib/core/uri/resource_resolver.dart).
   - Markdown documents embed images via standard markdown syntax `![Alt Text](qp://asset/<UUID>)`.
   - Internal `qp://` links are guarded in [`LinkLauncherHelper`](file:///home/dog/git/quitepaper/lib/core/utils/link_launcher_helper.dart) and never passed to the external browser launcher.

### Cryptographic Specification ([`AttachmentCrypto`](file:///home/dog/git/quitepaper/lib/core/attachments/attachment_crypto.dart))
- **Cipher**: XChaCha20-Poly1305 AEAD with 256-bit key length and 192-bit (24-byte) random nonce.
- **Binary Header**:
  - `0..3` (4 bytes): Magic header ASCII `'QPA1'` (`[0x51, 0x50, 0x41, 0x31]`).
  - `4..27` (24 bytes): Random cryptographic nonce.
  - `28..` (N bytes): Ciphertext + 16-byte Poly1305 MAC tag.
- **Associated Authenticated Data (AAD)**:
  `quietpaper:asset:<attachmentId>:<variant>:v1`
  Cryptographically binds the encrypted binary directly to its logical attachment ID and variant type, preventing cross-asset swap attacks.
- **Integrity**: SHA-256 digest computed across plaintext and stored with metadata for integrity validation.

### Database Schema v4 ([`AppDatabase`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart))
- Schema updated from version 3 to version 4 with automatic SQLite migrations:
  - **`attachments` Table**:
    `id` (UUID PK), `note_id` (FK to notes), `mime_type`, `byte_size`, `sha256`, `local_path`, `cloud_url`, `cloud_public_id`, `upload_state` (`local_only`, `upload_pending`, `synced`, `download_pending`, `error`), `is_dirty`, `is_deleted`, `created_at`, `updated_at`, `synced_at`.
  - **`attachment_variants` Table**:
    `id` (PK), `attachment_id` (FK), `variant_type` (`original`, `preview`, `thumbnail`), `local_path`, `cloud_url`, `cloud_public_id`, `byte_size`, `created_at`, `updated_at`.
  - SQLite indexes on `note_id`, `upload_state`, and `is_dirty`.

### Editor & Markdown Rendering Integration
- **WYSIWYG Markdown Parser** ([`MarkdownParser`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_parser.dart)):
  - Image tokenization `![alt](url)` executes prior to link tokenization.
  - Retains strict 1:1 character source length and offset invariants.
- **Image View Component** ([`QuietAssetImageView`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/quiet_asset_image_view.dart)):
  - Resolves `qp://asset/<UUID>` through `QuietPaperResourceResolver`.
  - Reads encrypted file from app-private storage, decrypts in memory with Master Key, and caches decrypted byte buffers ephemerally in RAM.
  - Smooth shimmer placeholder during loading, graceful error state on missing/corrupted files, and locked badge if key manager is locked.
- **Editor Toolbar** ([`FormattingToolbar`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart)):
  - Image picker button invoking system gallery picker, automatically importing image into attachment storage, generating UUID, encrypting payload, inserting `![Image](qp://asset/<UUID>)` at cursor position, and triggering background sync.

### Backup & Restore Integration ([`BackupService`](file:///home/dog/git/quitepaper/lib/core/backup/backup_service.dart))
- `.qpbackup` JSON schema and Argon2id encrypted envelopes now serialize attachment records and base64-encoded encrypted payloads (`BackupAttachment`).
- Full round-trip restore into clean databases re-populates both database metadata and encrypted local disk files without requiring network connectivity.

### Backend Infrastructure (`backend/`)
- **Required Environment Variables**:
  - `CLOUDINARY_CLOUD_NAME`: Cloudinary cloud name.
  - `CLOUDINARY_API_KEY`: Cloudinary REST API key.
  - `CLOUDINARY_API_SECRET`: Cloudinary API secret for HMAC-SHA1 signatures.
  - `CLOUDINARY_FOLDER`: Root folder for storing Quiet Paper encrypted raw blobs (e.g. `quietpaper_assets`).
- **REST Endpoints**:
  - `POST /api/v1/attachments/upload-auth`: Generates signed Cloudinary upload params.
  - `POST /api/v1/attachments/confirm`: Validates and saves attachment metadata.
  - `GET /api/v1/attachments/:id`: Retrieves metadata for specific attachment.

### Settings Sync Feedback & Error Surfacing
- **Interactive Sync Now Feedback**:
  - The "Sync Now" action in [`SettingsScreen`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart) provides instant interactive visual feedback (progress indicators and SnackBars).
  - On Success: Informs the user of total notes and image attachments synced (`Sync complete: Notes & X image(s) synced`).
### Multi-Device Image Sync & On-Demand Cloud Resolution
- **Sync Pre-fetching** ([`SyncEngine`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart)):
  - During the note pull phase, `SyncEngine` scans decrypted markdown bodies for `qp://asset/<UUID>` links.
  - Automatically queries `GET /api/v1/attachments/:id` for any missing attachment metadata records and persists them locally with state `synced`.
- **On-Demand Resolution & Download** ([`AttachmentService`](file:///home/dog/git/quitepaper/lib/core/attachments/attachment_service.dart)):
  - When `resolveAsset(assetId)` runs on a new or secondary device, if the local attachment record is missing or lacks `cloudUrl`, it calls [`SyncApiClient.getAttachmentMetadata`](file:///home/dog/git/quitepaper/lib/core/sync/sync_api_client.dart) directly.
  - Downloads the encrypted ciphertext directly from Cloudinary using `cloudUrl`.
  - Saves the encrypted blob to app-private storage, decrypts with the Master Key in memory, verifies SHA-256 integrity, caches in RAM, and displays seamlessly in [`QuietAssetImageView`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/quiet_asset_image_view.dart).

### Protected Note Title Preservation & Version 1.4.1
- **Title Preservation**:
  - When custom password protection is applied to a note, only the note body and tags are encrypted into the encrypted envelope.
  - The note's title is preserved in SQLite, note tiles, note cards, editor app bar, and password unlock modal, rather than being wiped and replaced with generic placeholder text.
  - [`Note.displayTitle`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_model.dart#L37) returns the note's real title (`title.trim()`), only falling back to `'Untitled'` if no title was ever set.
- **Version Bump**:
  - App version bumped to `1.4.1` (build `+7`) across [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml#L19), [`update_provider.dart`](file:///home/dog/git/quitepaper/lib/core/update/update_provider.dart#L10), and [`settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart#L620).

---

## 28. In-Note Search & Replace and Gesture Navigation

### Gestures & Navigation
- **Swipe Down to Search (Notes List)**:
  - Pulling down on the note list or empty state on Phone and Tablet triggers navigation to the global [`SearchScreen`](file:///home/dog/git/quitepaper/lib/features/search/presentation/search_screen.dart).
  - Detected via `NotificationListener<ScrollNotification>` (`OverscrollNotification` & `ScrollUpdateNotification` at top scroll offset) with `AlwaysScrollableScrollPhysics` across list and empty states.
- **Swipe from Left to View Sidebar**:
  - **Phone Layout**: Swiping from the left edge smoothly opens the navigation drawer using `Scaffold.drawerEnableOpenDragGesture` and `drawerEdgeDragWidth`.
  - **Tablet Layout**: When the navigation sidebar pane is collapsed in focus mode, swiping horizontally from the left edge restores `isNavSidebarVisible = true`.

### In-Note Search & Replace (Editor & Preview)
- **Gestures, iOS Animation & Shortcuts**:
  - Swiping/pulling down at the top of the editor or markdown preview smoothly reveals the in-note search bar using an iOS Bear Notes style springy slide-and-fade transition (`SizeTransition`, `FadeTransition`, `SlideTransition` driven by `Curves.easeOutCubic` / `Curves.easeInCubic`) with tactile `HapticFeedback.lightImpact()`.
  - Closing the search bar gracefully collapses and slides it upward out of view.
  - Expandable Replace row inside [`InNoteSearchBar`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/in_note_search_bar.dart) expands and collapses with smooth `AnimatedSize`.
  - `Ctrl+F` / `Cmd+F` opens Find in note.
  - `Ctrl+H` / `Cmd+H` opens Find with Replace.
  - `Escape` closes search, unfocuses search fields, and clears all match highlights.
  - Dedicated search button in the Editor `AppBar` and "Find in note" option in the overflow bottom sheet menu.
- **1:1 WYSIWYG High-Contrast Search Term Highlighting (Always Yellow/Amber)**:
  - [`MarkdownParser.buildTextSpan`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_parser.dart) performs multi-pass segment slicing: slices styled spans by case-insensitive search matches without mutating character offsets or underlying text.
  - **All Matching Occurrences**: Highlighted with high-contrast golden amber background (`#FFE066` in Light Mode, `#7A5C1E` in Dark Mode) and dark/light high-contrast text (`#242018` / `#FFFFFAED`).
  - **Active Match**: Highlighted with vivid deep amber gold fill (`#F59E0B` in Light Mode, `#FBBF24` in Dark Mode), high-contrast text (`#1A1810` / `#1E1B13`), and `FontWeight.w800`, maintaining consistent yellow/amber aesthetic throughout.
  - Seamlessly preserves Android IME composing underline slicing, caret metrics, selection, and undo/redo stacks.
  - [`MarkdownEditingController`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_editing_controller.dart) manages search query state and active match ranges with instant reactive notifications.
- **Real-Time Markdown Preview Search Highlighting**:
  - [`SearchMatchSyntax`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_highlight.dart) and [`SearchMatchElementBuilder`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_highlight.dart) highlight search matches seamlessly inside rendered [`QuietMarkdownPreview`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart) using the matching golden amber styling.
  - Equipped `MarkdownBody` instances with dynamic `ValueKey('preview_body_${bodyIndex}_${widget.searchQuery ?? ''}')` ensuring `flutter_markdown` re-parses the AST in real time as the user types in the search field without requiring mode toggling.
- **Search & Replace UI**:
  - [`InNoteSearchBar`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/in_note_search_bar.dart) provides query input, match counter (`X/Y`), previous and next navigation buttons (with wrap-around), close button, and expandable replace row.
  - "Replace" replaces the active match, updates the document, and recalculates matches.
  - "All" replaces all occurrences throughout the document with feedback notification.
  - Read-only locked notes automatically disable replace controls while allowing find and navigation.

### In-Editor Undo & Redo
- **Dual-Stack In-Memory History**:
  - [`UndoRedoManager`](file:///home/dog/git/quitepaper/lib/features/editor/application/undo_redo_manager.dart) maintains discrete undo (`_undoStack`) and redo (`_redoStack`) snapshot stacks during each active editing session.
  - Captures text state and cursor/selection positions with snapshot timestamps.
  - **Continuous Typing Batching**: Continuous keystrokes within `typingDebounceDuration` (600ms) update the top snapshot in place to prevent cluttering the undo stack with single-character steps.
  - **Immediate Atomic Snapshots**: Programmatic markdown formatting operations (bold, italic, list insertion, headings, code blocks, links, images, tag insertion) and newline breaks trigger immediate atomic snapshots.
- **UI & Keyboard Shortcut Integration**:
  - **Formatting Toolbar**: Undo (`Icons.undo_rounded`) and Redo (`Icons.redo_rounded`) buttons are integrated into the start of [`FormattingToolbar`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart), automatically enabling/dimming based on stack state.
  - **Desktop/Hardware Shortcuts**: `Ctrl+Z` / `Cmd+Z` for Undo; `Ctrl+Shift+Z` / `Cmd+Shift+Z` / `Ctrl+Y` for Redo wired up via `CallbackShortcuts`.
  - Cleared automatically on note exit and session completion.

### Session-Based Version History & Cloud Sync
- **Session Lifecycle & Micro-Edit Filtering**:
  - [`VersionSessionTracker`](file:///home/dog/git/quitepaper/lib/features/editor/application/version_session_tracker.dart) tracks the state of a note from session open to close (or background/sleep flush).
  - **Micro-Edit Filter**: Discards trivial accidental taps or micro-adjustments ($< 10$ character delta, $< 3$ word delta, unchanged title/tags/markdown structure).
  - Substantive edits auto-commit a new [`NoteVersion`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_version_model.dart) with incremented `versionNumber`, formatted timestamp, word count, character count, and delta summary tag (e.g. `+45 words`, `Title updated`, `Tags modified`).
  - **Auto-Pruning**: Automatically retains the latest 50 versions per note (`pruneOldNoteVersions(noteId, maxKeep: 50)`), cleanly pruning older snapshots.
- **Zero-Knowledge Encryption & Cloud Sync**:
  - Client-side encryption: [`SyncEngine`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart) encrypts version payloads (title, content, tags) with the user's Master Key using **XChaCha20-Poly1305** before cloud synchronization.
  - Turso/libSQL backend migration `backend/migrations/003_note_versions_schema.sql` creates `note_versions` table indexed by `(user_id, note_id, version_number)` and `(user_id, revision)`.
  - REST endpoints `/api/v1/sync/versions/push` and `/api/v1/sync/versions/pull` in `backend/src/sync/syncService.ts` and `backend/src/api/handler.ts` provide revision-tracked sync.
- **Version History Sheet & Non-Destructive Restore**:
  - Accessible from the editor overflow menu (`⋯` -> "Version history").
  - [`VersionHistorySheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/version_history_sheet.dart) displays real-time stream of past versions (`watchVersions`), formatted timestamps, word counts, and delta summaries.
  - **Version Inspection & Copy**: Tapping a version previews title, tags, and full Markdown content, with a "Copy Text" action.
  - **Non-Destructive Restoration**: "Restore" action automatically commits the current note state as a version first, then loads the selected version into the active editor and autosaves to database and cloud sync.

