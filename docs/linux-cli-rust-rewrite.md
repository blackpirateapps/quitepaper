# Linux CLI Rust rewrite

Branch: `feat/linux-cli-rust-rewrite`  
Starting commit: `12c49b3`  
Started: November 25, 2026

## Progress and batch boundaries

This is a staged rewrite of the standalone Linux `qp` CLI. The Flutter desktop
application and its existing Rust watched-import bridge are separate components.
Each batch must update this report and `HANDOFF.md`, pass its focused checks, and
be committed and pushed on this branch before the next batch starts.

| Batch | Scope | Status |
| --- | --- | --- |
| 1 | Rust executable, database discovery, read-only `list` / `show` / `tags`, compatibility tests and CI | Complete and verified |
| 2 | Local `new` / `edit` / `delete` / restore, external editors and interactive picker, frontmatter/tag parsing, transactional history/search/sync-queue updates, concurrent-edit recovery | Complete and verified |
| 3 | Desktop credential-store compatibility, account/device keys, QPA1 image encryption, Markdown/clipboard imports, attachment listing/opening and draft recovery | Complete and verified |
| 4 | Encrypted note/image upload retries, auth refresh, attachment reference updates, conflict/offline recovery and `sync` | Pending |
| 5 | Switch Linux builds and DEB/RPM/AppImage/Flatpak packaging to Rust, installed-package smoke checks, remove superseded Dart-only CLI code after parity verification | Pending |

Batch 1 implements **3 of the 9 existing top-level command families**. That is a
command inventory, not a percentage of engineering completion: encryption,
attachments, sync and packaging remain substantial work. Do not switch the
installed CLI until their acceptance gates pass. The follow-up request authorizes
continuing through all remaining batches, with a separate commit and push each.

## Batch 1 implementation

`rust/quietpaper_cli` is an independent Cargo workspace package that builds a
native `qp` binary. It uses Clap for arguments, rusqlite with bundled SQLite,
Serde JSON, and Jiff for the Dart-compatible local timestamp representation.
It has no Flutter, GTK, Dart runtime or watched-import bridge dependency.
Cargo dependencies are recorded in the shared `Cargo.lock`.

Implemented commands:

- `list` / `ls`: active/archive/trash filters, pinned-only, normalized nested-tag
  filtering, title/body substring search, positive limits, JSON, TSV and a plain
  table. Flags retain the Dart names and aliases, including `--query` / `--q`.
- `show` / `cat` / `view` / `s`: full ID, unambiguous hexadecimal ID prefix of at
  least eight characters, or active-note title substring; raw Markdown, JSON and
  metadata. Explicit IDs can access archived/trashed notes.
- `tags` / `t`: pinned-first names, active note counts, JSON and a plain table.
- Global `--db`, `--no-color`, `-v` / `--version`, help and command help. Help and
  version need no database. Usage errors exit 64; operational failures exit 1.

Database selection preserves the existing precedence: explicit `--db`, nonempty
`QP_DB`, then `XDG_DATA_HOME` (or `$HOME/.local/share`) with the canonical
`com.blackpiratex.quietpaper/quiet_paper.sqlite` path preferred over the legacy
`quitepaper/quiet_paper.sqlite` file. Missing notebooks fail with instructions to
initialize in the desktop app or select an existing database.

The connection opens read-only, uses a five-second busy timeout and a deferred
read transaction for consistent note/tag snapshots, and reads committed WAL
data while the desktop app is open. There is no schema creation/migration,
`user_version` change, journal-mode switch, title repair, history mutation or
queue write. Additional desktop tables/columns remain untouched. Required
note/tag columns are checked on open; the real current Drift schema is **25**.

JSON retains the Dart note/tag key sets, nullability, local ISO timestamps with
millisecond precision, sorted tag names and display-title cleanup/derivation.
Raw display preserves Markdown bytes, including CRLF, and retains the Dart
behavior of appending a newline when missing. TSV flattens title newlines/tabs.

### Deliberate behavior differences and remaining parity

- `show` currently requires an explicit identifier; interactive selection belongs
  to batch 2. Multiple ID-prefix/title matches fail with candidate full IDs.
  The Dart prefix lookup could silently select the newest matching note.
- Title lookup searches titles only; the Dart helper also searched note bodies.
- Search/tag/title substring input treats `%`, `_` and backslashes literally.
  Deleted tags cannot match a filter. The Dart SQL allowed wildcard expansion
  and did not exclude deleted tag rows in this filter.
- Tag counts exclude archived/trashed notes. The Dart query counted `note_tags`
  rows even when its active-note join did not match.
- Invalid/zero limits and simultaneous `--json --plain` are usage errors.
- Terminal tables are plain text with fixed-width Unicode-safe truncation,
  absolute timestamps and `*` pins. ANSI styling, relative-time labels and
  terminal-width adaptation are not ported in this batch. `--no-color` is accepted.
- Version output identifies the Rust batch. `new`, `edit`, `delete`, `attach`,
  `attachments` and `sync` are unavailable in this binary, with ordinary usage
  errors. There is no delegation to Dart.
- Linux release workflows still package the existing Dart executable. The new
  Rust binary is run explicitly from the Cargo output directory during migration.

## Build, run and validation

```sh
cargo build --locked -p quietpaper_cli
target/debug/qp --help
target/debug/qp --db /path/to/quiet_paper.sqlite list --json
target/debug/qp show NOTE_ID --raw
target/debug/qp tags --json
```

Run the focused acceptance gate after `flutter pub get`:

```sh
bash scripts/test_rust_cli.sh
```

The gate runs Rust formatting, Clippy with warnings denied, package-specific
Rust tests, a debug binary build, `flutter analyze`, and only `test/cli` Flutter
tests. `QP_RUST_CLI_BIN` enables three cross-language tests against a notebook
created by the actual `AppDatabase` Drift migration. Those compare Dart/Rust JSON,
test a live desktop write and CRLF, and check that notes/schema/sync queues remain
unchanged by reads. Flutter-only runs skip those three tests with an explicit
reason; the dedicated `.github/workflows/linux_cli_rust.yml` always enables them.

Rust tests use disposable SQLite fixtures, not the user's notebook, and cover
CLI parsing/error codes, empty output, aliases, all filters, literal wildcard
handling, deleted/empty tags, ambiguity, JSON shape, path precedence, concurrent
WAL access, uncommitted writes and storage immutability. Unit tests cover
frontmatter title display and safe Unicode truncation.

Batch 1 verification on November 25, 2026:

| Check | Result |
| --- | --- |
| `cargo fmt -p quietpaper_cli -- --check` | Pass |
| `cargo clippy --locked -p quietpaper_cli --all-targets -- -D warnings` | Pass, no warnings |
| `cargo test --locked -p quietpaper_cli` | 12 tests pass (1 unit, 11 process/database tests) |
| `cargo build --locked -p quietpaper_cli` and binary help/version smoke | Pass |
| `flutter analyze` | No issues |
| `QP_RUST_CLI_BIN="$PWD/target/debug/qp" flutter test --no-pub test/cli` | 53 tests pass, including all 3 Drift/Rust compatibility tests |
| `cargo audit` | Pass, no vulnerabilities |
| `cargo deny check advisories licenses sources bans` | Pass; duplicate-version warnings permitted by existing policy |
| `git diff --check` | Pass |

The final dependency graph uses rusqlite 0.43 / libsqlite3-sys 0.40 and Jiff 0.2.
Initial dependency checks flagged the older bundled SQLite and an unmaintained
date library; both were replaced before acceptance, without advisory ignores.
Cross-language tests compare persisted whole-second timestamps, matching Drift
and the Dart CLI's database reader rather than the unrounded create result.

No full Flutter test suite was run. Packaged installation, production notebook
access and cloud operations are outside batch 1 validation. The GitHub workflow
is added; the recorded passing results above are local execution, not a claim
that a remote workflow has finished.

## Batch 2 implementation and verification

Adds `new`/`create`/`add`/`n`, `edit`/`e`/`modify`, and
`delete`/`rm`/`del`, including pin/unpin, trash, restore and permanent deletion.
Six of nine command families are now implemented. New notes accept piped
Markdown or an external editor; editor selection respects `--editor`, `QP_EDITOR`,
`VISUAL`, `EDITOR` and installed fallbacks. Shell-style quoting is parsed without
executing a shell. Interactive note selection uses a numbered prompt on stderr.
Temporary editor files and recovery drafts are private; unchanged/empty edits
cancel, failed editors preserve drafts, and concurrent notebook changes prevent
overwrite. Protected/rich-document editing is directed to the desktop app.

Writes open an existing notebook read/write with foreign keys enabled; no
schema is created or migrated. Immediate transactions include notes, normalized
Unicode/frontmatter tags, deterministic tag IDs, per-tag pin caches, version
history, both search indexes and queue entries. Failed history/index/queue writes
roll everything back. Desktop-owned provenance/share/revision fields survive.
Trash removes search entries; restore rebuilds them; permanent deletion retains
a sync tombstone. Attachment-bearing saves are explicitly blocked until batch 3.
Automatic cloud upload follows in batch 4; current writes remain queued locally.

Validation: Rust fmt and Clippy with warnings denied pass; 13 Rust tests pass.
`flutter analyze` reports no issues. The focused `test/cli` run plus the corrected
compatibility-file rerun passes all 58 relevant Flutter cases, including eight
Rust/Drift cases. New checks cover desktop-readable writes, per-tag pins, history,
FTS, trash/restore/cascades, injected history failure rollback, private recovery
and a real concurrent SQLite edit during an external editor session. No full suite.

## Next batch acceptance

Batch 4 must upload encrypted note/image snapshots using existing endpoints,
verify the account key, refresh authentication without rewriting GUI credentials,
retain pending state after offline/conflict/reference failures and concurrent GUI
edits, and leave desktop pull cursors untouched. Test against controlled HTTP
endpoints and Dart decryption before changing release packaging.

## Batch 3 implementation and verification

Adds `attach` and `attachments`/open, bringing eight of nine command families to
Rust. `new` and `edit` support repeatable `--attach`, `--clipboard`, `--compress`
and `--base-dir`; the temporary batch-2 attachment guard is removed. CommonMark
parser source offsets import only actual local image destinations/reference
definitions, retaining code/frontmatter/remote examples and surrounding bytes.
Canonical source paths deduplicate within a save. Ordinary imports preserve
PNG/JPEG/GIF/WebP/AVIF bytes (10 MiB); optional still-image JPEG conversion uses
quality 85, orientation correction, a 2560-pixel bound and bounded decoder/input
memory. Animated images cannot be silently flattened. AVIF remains supported as
original bytes; this Rust decoder build explicitly refuses AVIF compression.

Read-only desktop credentials support Secret Service on the configured notebook
and the AES-256-GCM fallback beside custom databases. Keyring entries take
precedence; fallback key derivation matches the machine ID, user and salt format.
Argon2id/XChaCha20-Poly1305 unwraps existing password-wrapped keys in a terminal;
scripts with locked keys fail clearly. Sensitive key/password/decrypted buffers
are zeroized. No credentials are written, exported or refreshed on disk.

QPA1 envelopes use the existing header, versions, 24-byte random nonce and
attachment-bound AAD. Encrypted files are created as 0600 before transactional
note/history/search/queue/attachment-row commits. Failed transactions delete
staged files and preserve the original draft. Database paths are canonicalized so
stored attachment paths remain valid across invocation directories. Clipboard
helpers have output/time limits. Opening images requires a terminal and uses a
private temporary directory, removed after viewer acknowledgement or an error.

Validation: Rust fmt/Clippy pass, **16 Rust tests** and **63 focused Flutter CLI
tests** pass, and `flutter analyze` is clean. New Drift/Dart tests decrypt Rust
QPA1 data, verify fallback-store immutability, source-image preservation,
deduplication, attachment-row visibility, rollback cleanup and JPEG conversion.
Actual pseudo-terminal tests unwrap a Dart-produced key with the correct password
and reject the wrong password; a controlled clipboard helper covers screenshot
import and noninteractive viewer refusal. Rust tests cover tampering/identity
binding, image bounds/animation and Markdown source ranges. Cargo deny passes;
two narrow BSD-3-Clause license exceptions cover `sha1_smol` (UUID v5) and
`subtle` (constant-time crypto), without advisory ignores. No full suite or real
notebook/keyring/clipboard/viewer/cloud access ran.
