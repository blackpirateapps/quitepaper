# Linux Rust watched-folder import

Starting HEAD: `826cc7e45ae34480047526c39f642fb627efcf0e`.
Branch: `feat/linux-rust-watched-folder-import`.

## Architecture audit

The checkout has no Rust workspace. Flutter is 3.47.2 / Dart 3.13.2.
Drift is schema 22; `saveNote` maintains tags, FTS, link and email source indexes
and dirty sync metadata. Local ordinary note titles/bodies are plaintext SQLite;
assets and cloud payloads are encrypted. This feature does not change that policy.

EML uses `EmailParser` / `EmailImportService`, including bounded MIME decoding,
HTML sanitization, CID resolution, source provenance and encrypted originals.
`email_import_preparations` is the durable ciphertext cleanup journal.
Markdown uses `MarkdownImportService` and the existing frontmatter parser;
PDF and images use `DocumentService` and `AttachmentService`.
The settings/import views currently own navigation; automatic import must invoke
headless services and must not open editors or display per-file dialogs.

Linux builds use CMake and copy the entire bundle into DEB/RPM/AppImage/Flatpak.
Existing Flatpak grants cover Documents and Downloads, not arbitrary home access.
There is no existing persistent folder-portal grant integration.

## Verification record

Implementation and verification are in progress. No full Flutter suite is allowed
on this laptop. All local Flutter test commands name explicit feature files or
directories and use concurrency 1. Native compilation uses bounded parallelism.
No production readiness or installed-package verification is claimed here.

## Implemented boundary and lifecycle

`rust/quietpaper_watched_import` owns one cancellable scheduler thread, a notify
observer (or native PollWatcher fallback), lazy descriptor-based DFS, a 256-entry
candidate queue and one outstanding canonical import. Source hashing uses 64 KiB
buffers. The bridge uses bounded typed pull batches every 150 ms instead of
unbounded callbacks; shutdown invalidates the handle and joins the worker.
Reconciliation runs on startup/resume, native hints and every five minutes.
Stability requires three observations and three seconds of quiet; the import
snapshot rechecks descriptor/path identity, size, ctime/mtime and SHA256.

`WatchedImportRepositoryAdapter` owns authoritative local state in schema 23.
`CanonicalImportAdapter` calls the existing MIME parser and EmailImportService,
MarkdownImportService, AttachmentService, DocumentService and NotesRepository.
EmailImportService's optional planned-note-ID/transaction hook permits its normal
note/tag/search/dirty-sync transaction to include the unique success receipt.
The generic formats journal encrypted stage IDs before file writes and remove
journals in the note/receipt transaction. Recovery purges uncommitted ciphertext,
including PDF stages without a metadata row. A lost ACK is resolved by the receipt.
No success receipt cascades when its note is deleted. Explicit copies use an
independent recorded override ID and preserve the automatic receipt constraint.

The first root is saved pending before observation begins. Only New matches
baseline content hashes, including after renames; arrivals after initial inventory
are not turned into baseline skips. An incomplete or changing inventory holds the
decision rather than guessing. Root identity changes fail closed. The GTK native
chooser replaces the command-based file picker for this screen; Flatpak uses the
portal's directory grants, and portal roots force native polling. No broad home
permission is added. Installed Flatpak grant persistence remains an acceptance gate.

Lock/clear/logout generations invalidate in-flight commit checks. Account scopes
are checked before processing and during the commit barrier. Folder enrollment
never follows an account to another identity. No settings or native startup runs
on non-Linux platforms. Imports never navigate or show per-file toast notifications.

## Initial verification evidence

- `flutter analyze`: no issues (multiple runs).
- `flutter test --no-pub --concurrency=1 test/watched_import`: 15 passed.
- The selected email/import/attachment/document/template/settings/clipper run
  recorded in engineering log 343: 189 passed. No complete Flutter suite ran.
- `cargo fmt --all -- --check`, `cargo clippy --workspace --all-targets --locked -- -D warnings`,
  `cargo test --workspace --locked -- --test-threads=1` and `cargo check --workspace --locked`: passed.
  Native tests include six unit cases and two substantive integration cases plus
  their subprocess entry helper. There are no disabled acceptance tests.
- `scripts/check_rust_bridge.sh` with the checksum-verified 2.12.0 generator: passed.
- `dart run build_runner build --delete-conflicting-outputs`: passed; this SDK
  reports that the obsolete delete flag is ignored. Generated Drift output is coherent.
- Ordinary `flutter build linux --debug`: passed. Cargokit built and bundled the library.
- `scripts/smoke_linux_rust_bundle.sh build/linux/x64/debug/bundle`: real ELF64 x86_64
  load through generated FRB passed with `LD_LIBRARY_PATH` removed, including
  verified source snapshot, ACK and source-byte preservation.

Further native crash/stress, security, release/package and sandbox acceptance
checks are still in progress. Green component tests alone are not a production
readiness declaration.
