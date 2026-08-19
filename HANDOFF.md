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












