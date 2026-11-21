# Linux Rust watched-folder import

Status: **implemented; release acceptance incomplete**. Component, crash and native
integration gates pass. The acceptance limits at the end must be resolved before
claiming production readiness. No full Flutter test suite was run.

Branch: `feat/linux-rust-watched-folder-import`.
Starting HEAD: `826cc7e45ae34480047526c39f642fb627efcf0e`.
Implementation began November 20, 2026; final verification completed November 21.

## Use

Open **Settings → Import & Capture → Watched Folders** on Linux. The same screen
is available under Backup & Import. Choose an existing folder and review its
initial inventory. Choose **Import existing files**, **Only import new files**,
or **Cancel**. No import starts before that decision is durable.

Subfolders, duplicate prevention and keeping originals are fixed ON. There is one
root per installation. Quiet Paper watches while its GUI is running; startup and
resume reconcile files saved while it was closed. Pause, Resume, Rescan, Open
folder, Change folder and Remove are explicit controls. History shows results,
retryable failures and review cases. Opening a note and revealing a source require
an explicit action. Import again anyway records an explicit copy override.

For Proton Mail Free, export a chosen message as `.eml` in the browser and save it
in the enrolled folder. Quiet Paper waits for the download to settle, then uses
its existing email importer. It never connects to Proton, IMAP or a browser API.
There is no daemon, automatic OCR, source cleanup, editor navigation or per-file
notification stream.

Supported automatic extensions are `.eml`, `.pdf`, `.md`, `.markdown`, `.txt`,
`.png`, `.jpg`, `.jpeg`, and `.webp`. Email is bounded to 50 MiB, text/Markdown to
10 MiB, and PDF/images to 10,000,000 bytes, within canonical service limits. Binary
signatures are checked; empty binary files, temporary/hidden files, archives,
executables, symlinks and special files are not automatic text imports. Unsupported
image formats inside Markdown require attention rather than silently losing images.

## Architecture and importer reuse

At starting HEAD there was no Rust workspace, and Drift was schema 22. Flutter
remains **3.47.2**, Dart **3.13.2**. This feature introduces schema **23** and
Rust **1.97.1**, with matching FRB generator/Dart/crate **2.12.0**.

- `rust/quietpaper_watched_import/src/api/engine.rs`: versioned typed DTOs and
  bounded pull-event interface, snapshots, outcomes and lifecycle.
- `watch.rs`, `scan.rs`, `stability.rs`, `hashing.rs`, `worker.rs`, `rules.rs`,
  `diagnostics.rs`: recursive observation/fallback, lazy discovery, stability,
  descriptor-safe reads, hashes, owned scheduling and sanitized errors.
- `lib/features/watched_import/data/watched_import_repository.dart`: authoritative
  local enrollment, jobs, baselines, receipts, state transitions and bounded events.
- `application/canonical_import_adapter.dart`: headless integration with existing
  canonical conversion, encryption and repository APIs.
- `application/native_watched_engine.dart`, controller/provider and presentation:
  bridge wiring, lifecycle, scope/lock guards and targeted Riverpod/UI updates.

Rust owns one cancellable scheduler thread and a notify observer. Its pending
queue is capped at 256, event channel at 256, drains at 32 events, and canonical
imports at one. Dart polls at 150 ms without callbacks into disposed widgets.
Hashing streams through a 64 KiB buffer. Source bytes travel only through explicit
bounded snapshot requests; progress events contain metadata, never email content.

Recursive inotify events are hints. Reconciliation runs on startup, resume, relevant
hints, recovery and every five minutes. PollWatcher provides native fallback.
Portal roots explicitly use polling and display Degraded. Read/open events are
excluded from write-stability scheduling: stress testing found that observing our
own reads otherwise restarted the quiet timer and severely reduced throughput.
Write-close, modifications, rename/create/delete and rescan/overflow hints remain.

Stability requires three consistent identity/size/mtime observations and at least
three seconds of quiet. Each snapshot reopens the source through directory
file descriptors, using `openat2` with BENEATH, NO_SYMLINKS, NO_MAGICLINKS and
NO_XDEV; final-file NONBLOCK excludes FIFO hangs. Both descriptor and current path
identity, mtime/ctime, size and actual SHA256 must match before bytes are returned.
Linux kernel 5.6+ and an allowed `openat2` syscall are required; safety is not
silently weakened on unsupported kernels. DFS is limited to 64 directory levels
and does not follow links or cross mount boundaries. Non-UTF-8 identities retain
raw path bytes; display labels are lossy, and source URIs preserve the original bytes.

The adapter consumes exactly the verified in-memory snapshot, never a stale Dart
path. EML reuses `EmailParser` and `EmailImportService`: the same RFC/MIME decoding,
HTML sanitization, sender/date metadata, CID handling, provenance, original source
and encrypted attachments as manual import. There is no second MIME implementation.
Optional planned-note-ID and transaction hooks extend that service without changing
manual drag/drop, sharing or editor behavior. Existing email gateway initialization
also supports fresh device-only notebooks.

Markdown reuses `MarkdownImageParser`, frontmatter handling and
`MarkdownImportService`. Its new optional extraction/resolution callbacks leave
manual behavior intact. Pure extraction is bounded to 101 references to reject
more than 100 without constructing an unbounded list. Rust resolves explicit
relative image paths and the canonical common attachment directories within the
approved root. Images are staged sequentially with a 50 MiB combined budget;
missing or unsafe access fails the note rather than retaining a broken
local reference. PDF and image imports reuse DocumentService and AttachmentService,
with planned IDs, no plaintext cache and no unsolicited OCR. Canonical `qp://`
links and ordinary note indexing/sync behavior are retained.

## Transactions, recovery and privacy

`watched_folders`, `watched_import_jobs`, `watched_import_receipts`,
`watched_import_baseline`, `watched_import_events` and `watched_import_stages` are
installation-local tables. Existing schema-22 databases upgrade, and defensive
column checks accept the earlier unreleased schema-23 layout. Generated Drift
output remains coherent; the custom table convention matches existing email
preparation and provenance-index tables.

An automatic receipt is unique by vault scope, SHA256 and byte size. Explicit
copies have their own recorded override ID; they do not remove or bypass the
automatic receipt constraint. Notes, tags, search/link/source indexes, dirty sync
state and the receipt commit in one canonical Drift transaction. The job and
planned note ID are durable before preparation. There is no receipt without a
persisted note, and receipts have no note-delete foreign-key cascade.

Ciphertext stages are journaled before writes. Email uses its existing preparation
journal; other formats use `watched_import_stages`. Commit deletes stage journals
in the note/receipt transaction. Failure or next-start recovery purges uncommitted
ciphertext, including PDF files written before a metadata row existed. Failed
cleanup retains its journal. SQLite/filesystem atomicity is not claimed.

| Interruption | Recovery |
| --- | --- |
| Before or during encrypted staging | No note/receipt; journal removes partial ciphertext, then retry uses durable job identity. |
| Inside the note/receipt transaction | SQLite rolls back all note/index/receipt changes; journals compensate file writes. |
| After commit, before native ACK | Receipt prevents another automatic note; committed assets remain. |
| During initial review | Reopen pending review. An incomplete interrupted baseline requires Cancel/reselection; never guess old/new membership. |
| While locked or changing account | Generation/scope checks reject late commits and clear history caches; native work waits. |
| Root disappears or changes identity | Preserve configuration/history; recover the same identity or require explicit reselection. |

Only New uses content identities, so a baseline file renamed or copied inside the
root remains skipped. Arrivals after initial inventory are not turned into baseline
skips. A changing/incomplete inventory holds the decision for attention. Changed
bytes create a new note; a prior receipt with the same email Message-ID and different
bytes requires explicit review. Receipt deduplication applies to watched imports;
manual imports retain their established duplicate-preview workflow.

Native timers own exponential backoff/jitter. Attempt counts and returned retry
timestamps are recorded durably; startup immediately reconciles and checks receipts
before attempting any recovered work. Explicit Retry advances job generation.
Terminal states cannot silently become active. History is pruned to 500 events
and the UI reads 100; dedup receipts are not pruned. Folder removal retains notes
and receipts. Deliberate vault erasure clears watcher state and receipts.

Watcher paths, baselines, jobs and receipts are excluded from cloud synchronization
and backup payload v1. Restoring notes never activates a folder on another machine.
A new installation must enroll its own folder and establish its own receipt history.

**Existing local-at-rest limitation:** ordinary note titles, bodies and provenance
are plaintext in local SQLite, as before this feature. Assets and cloud payloads
use existing encryption. The watcher adds no plaintext email snapshots, temp copies,
decoded-message logs, Rust database, keys, tokens or network calls. It does not
claim to encrypt the ordinary local notes database or implement ad hoc crypto.

The Linux runner already uses GApplication single-instance behavior. Within the
GUI process, native initialization rejects duplicate engines, controller startup
is idempotent, and shutdown joins the owned worker. Isolated test sessions must
also use an isolated notebook, as the acceptance tools do.

## Job states and troubleshooting

Durable jobs progress from `ready` through `importing` to `imported`; enrollment
holds them in `awaiting_review`. Receipt and baseline matches end in
`duplicate_skipped` and `baseline_skipped`. Transient failures become
`retry_scheduled` or `waiting_for_unlock`; exhausted/permanent failures become
`failed`, and changed Message-ID provenance requires `needs_attention`. Explicit
Retry returns a retryable job to `ready` with a new generation. An explicit copy
creates a new override job and planned note ID. The repository rejects illegal
transitions; startup resets interrupted `importing` jobs only after stage recovery.

If the feature reports `native_unavailable_or_incompatible`, rebuild with the pinned
Rust/FRB versions and run the bundle smoke command below. Missing or incompatible
native code leaves other app features usable. `root_identity_or_access` requires
restoring the same directory identity or explicitly selecting a replacement.
`review_interrupted` / `inventory_incomplete` means Only New cannot safely infer
membership: cancel and reselect once the directory is stable/readable. Polling
fallback remains functional and is displayed as Degraded. Linux kernels before
5.6 or sandboxes denying `openat2` cannot use the safe source reader.

## Clean-clone development and CI

Install Flutter 3.47.2, rustup, a C/C++ toolchain, cmake, ninja, pkg-config, GTK3,
SQLite, libsecret and the existing GStreamer build dependencies. The pinned Rust
file installs rustfmt/clippy. Linux packaging additionally needs dpkg, rpm/rpm2cpio,
cpio and Flatpak builder/AppStream compose. No extra Rust prerequisite is added to
Android/iOS/Windows/macOS build jobs.

```sh
flutter pub get
scripts/install_frb_codegen.sh "$HOME/.cargo/bin"
cargo install cargo-expand --version 1.0.127 --locked --jobs 2
flutter_rust_bridge_codegen generate
scripts/check_rust_bridge.sh
dart run build_runner build
scripts/test_watched_import_linux.sh
flutter run -d linux
flutter build linux --release
scripts/smoke_linux_rust_bundle.sh "$PWD/build/linux/x64/release/bundle"
```

Cargokit automatically compiles and bundles `lib/libquietpaper_watched_import.so`.
There are no manual target-directory copies. Only the Linux FFI plugin scaffold is
included. Vendored Cargokit has a small documented patch to honor the exact selected
Rust toolchain rather than moving stable; debug/profile/release pass `--locked`.
Codegen glue is checked in and regenerated, never edited manually. The generator
release download is SHA256 pinned.

The new watched-import workflow performs native fmt/clippy/test/check, generated
bridge/Drift checks, focused Flutter tests, RustSec/licensing and real FFI smoke.
Linux build/release workflows build through the same Cargokit path and extract/load
tarball, DEB, RPM and AppImage artifacts. Flatpak copies the already-built bundle.
AppImage tool 1.9.1 and embedded runtime 20251108 are separately checksum pinned;
compression uses bounded parallelism. Flatpak moves from end-of-life GNOME 47 to
GNOME 50, preserves the CLI's executable snapshot by disabling stripping, and
keeps existing filesystem grants. No home-wide grant was added. Official release
publication remains restricted to main/version tags.

Cargo-audit 0.23.0 and cargo-deny 0.22.0 are installed with locked dependencies.
Notify's CC0 license is explicitly allowed; allo-isolate's shipped Apache license
is clarified with a file-content hash because its manifest omits the field. No
advisories are ignored. The new crate follows the existing package's GPL-3.0-or-later
metadata; FRB and Cargokit retain their own upstream licenses.

## Verification and remaining acceptance gates

The following commands use explicit Flutter paths and concurrency 1. A full
Flutter suite is forbidden on this laptop and was never invoked.

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 test/watched_import test/email_import test/import test/database test/attachments/attachment_service_test.dart test/documents/document_service_test.dart test/templates/template_database_test.dart test/settings/settings_screen_test.dart test/web_clipper/browser_acquisition_service_test.dart test/web_clipper/web_clipper_service_test.dart test/web_clipper/web_image_downloader_avif_test.dart
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked -- --test-threads=1
cargo check --workspace --locked
cargo audit
cargo deny check advisories licenses sources bans
cargo build --workspace --locked
QP_WATCHED_NATIVE_LIBRARY="$PWD/target/debug/libquietpaper_watched_import.so" flutter test --no-pub --concurrency=1 tool/watched_import_native_test.dart
dart run tool/benchmark_watched_import.dart "$PWD/target/debug/libquietpaper_watched_import.so"
```

| Gate | Evidence/status |
| --- | --- |
| Flutter analysis | PASS, no issues. |
| Broad focused Flutter gate | PASS, 235 tests. Includes 35 database tests, real encrypted EML parity, format imports, backups, lock/account guards, existing manual/editor/share/clipper coverage and three subprocess crash scenarios. |
| Final watcher follow-up | PASS, 22 overlapping storage/controller tests after durable retry/history cleanup changes; six final widget cases also pass. |
| Native fmt/clippy/check/tests | PASS, 8 unit cases and 3 integration entries (one is the child entry used by the real restart test). |
| Native-to-canonical EML integration | PASS through the real generated bridge, initial review, encrypted assets, atomic receipt, copied-source dedup and deleted-note protection. |
| Source immutability | PASS in storage/native/crash tests and package smoke fixtures. |
| Security and licensing | PASS against RustSec database `f291af9b1cc0d21dfcea1709d6b037963cef262b`; no vulnerabilities. Cargo-deny passes, with duplicate-version warnings from transitive syn/windows-sys versions. |
| Drift/codegen/shell/YAML | PASS; generation coherence and syntax checks. |
| Ordinary Linux debug/release and CLI compilation | PASS; final package verification recorded below. Existing Whisper C++ deprecation warnings are unrelated to Flutter analysis. |
| DEB, RPM, AppImage and tarball | PASS: fresh release artifacts extracted into temporary directories; readelf/ldd, real FRB stable-source/snapshot/ACK smoke, Flutter asset manifest and packaged CLI version checks. |
| Installed Flatpak, GNOME 50 | PASS: installed into disposable user installation/home; runtime sandbox loads packaged native library, observes and verifies a synthetic source, ACKs, and runs packaged CLI. No real notebook or display access. Persistent portal grants and graphical desktop behavior remain unverified. |

Actual native measurements use synthetic fixtures, not a real mailbox:
10,001-file lazy discovery took **5.29 ms** in the recorded Linux run with at most
four additional descriptors. The 1,000-file event-burst benchmark processes verified
snapshots and ACKs through FRB, samples RSS and repeats startup five times; its raw
result is in [the evidence file](linux-rust-watched-import-evidence.json). This measures native scheduling
and snapshot delivery, **not** total MIME conversion/encryption throughput or GUI
frame time. The first stress attempt failed its deadline because of self-generated
open events; the read-event filter and a permanent regression correct that defect.

**NOT VERIFIED / release acceptance incomplete:** a real anonymized Proton browser
export (fixtures are synthetic), interactive persistent folder-portal grants across
Flatpak restart/revocation, physical Wayland/X11 keyboard/file-manager interaction,
Android/iOS/Windows/macOS compilation for this change, actual privileged mount/inotify
exhaustion scenarios, complete 10,000-file canonical-import throughput, and GUI
frame-time profiling during that workload. Non-Linux setting visibility is covered
by existing platform-targeted widget tests; that is not a substitute for device builds.

The checked artifact hashes are recorded in the evidence JSON. Reproduce the package
checks after an ordinary release/CLI build with:

```sh
scripts/verify_linux_package.sh deb "$PWD/build/linux/dist/quiet-paper-1.6.4-amd64.deb"
scripts/verify_linux_package.sh rpm /absolute/path/to/quitepaper-1.6.4-1.x86_64.rpm
scripts/verify_linux_package.sh appimage "$PWD/build/linux/dist/Quiet_Paper-1.6.4-x86_64.AppImage"
scripts/verify_linux_package.sh tarball /absolute/path/to/quiet-paper-linux-x64.tar.gz
dart compile exe tool/smoke_watched_import.dart -o build/qp_watched_smoke
scripts/verify_flatpak_bundle.sh "$PWD/build/linux/dist/quiet-paper-1.6.4-x86_64.flatpak" "$PWD/build/qp_watched_smoke"
```

The installed Flatpak verifier requires the GNOME 50 platform already installed;
it creates and removes its own private installation and user-data directories.
It does not install over the user's Quiet Paper application. Local host-package
extraction verifies relocatability on this Fedora host, not a full distro matrix.
