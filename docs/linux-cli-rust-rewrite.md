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
| 2 | Local `new` / `edit` / `delete` / restore, external editors and interactive picker, frontmatter/tag parsing, transactional history/search/sync-queue updates, concurrent-edit recovery | Pending |
| 3 | Desktop credential-store compatibility, account/device keys, QPA1 image encryption, Markdown/clipboard imports, attachment listing/opening and draft recovery | Pending |
| 4 | Encrypted note/image upload retries, auth refresh, attachment reference updates, conflict/offline recovery and `sync` | Pending |
| 5 | Switch Linux builds and DEB/RPM/AppImage/Flatpak packaging to Rust, installed-package smoke checks, remove superseded Dart-only CLI code after parity verification | Pending |

Batch 1 implements **3 of the 9 existing top-level command families**. That is a
command inventory, not a percentage of engineering completion: encryption,
attachments, sync and packaging remain substantial work. Do not switch the
installed CLI until their acceptance gates pass. This session ends after batch 1
is verified, committed and pushed, as requested.

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

## Next batch acceptance

Batch 2 must preserve the desktop schema and shared write contract: atomically
save notes, normalized tags, history, FTS projections and sync queue records;
retain all desktop-owned fields; detect concurrent changes before overwriting;
preserve recoverable editor drafts; exercise successful saves and rollback using
actual Drift-created notebooks. Attachment-bearing edits must wait for batch 3
or fail explicitly without changing private asset references. Continue on this
branch and update this report with the next batch's exact completed scope.
