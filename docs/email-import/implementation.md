# Email import implementation record

## Phase 1 — repository audit (2026-11-19)

Branch: `feat/email-import`, based on `e812cc6`. Flutter 3.47.2 / Dart 3.13.2.
Read root handoff, modular index and architecture/editor/storage/documents/platform/
search guides, recent engineering logs and the complete `prompts/email.md` spec.
Source, rather than historical guide examples, establishes the following contracts.

- `Note` carries canonical Markdown or RichDocument JSON. `mapNoteEntity` is the
  common full/paginated mapper. Drift schema is **20**, not the old guide's v3.
  `AppDatabase.saveNote` transaction maintains tags, FTS and links. Extend this
  boundary with optional source records and a derived indexed source table.
- `NotePlaintext` is the encrypted sync payload. `SyncEngine`, conflict resolver,
  CLI upload and backup note models require provenance propagation. Union source
  identities on merges; do not add server-visible email fields or endpoints.
- `AttachmentService.importGenericFileFromBytes` encrypts into the existing vault;
  `importImageFromBytes(skipOcr: true)` supplies CID images. Generic storage and
  cloud uploads currently cap at 10,000,000 bytes. Email's 50 MiB original and
  25 MiB decoded-part limits require an explicit local import allowance; preserve
  upload retry/errors when account/server limits prevent larger asset sync.
  `purgeLocalAttachment` removes preparation leftovers. Use transaction rollback
  plus ciphertext cleanup, with durable recovery for interrupted preparation.
- Main notes workspace has three `DropTarget`s, all calling
  `_handleDroppedFileToNewNote`, which handles only its first file. Editor owns a
  separate `DropTarget` / `_handleDroppedFiles`. Intercept email batches before
  either existing insertion path, preserving ordinary image/document behavior.
- Settings `BackupImportSettingsScreen` owns existing import actions. No global
  command palette implementation exists (the platform guide describes one).
  Add a small searchable desktop command entry point using existing modal styles.
- `ShareIntentHandler` uses installed `receive_sharing_intent` **1.9.0** and handles
  only the first file. Inspected plugin Kotlin: it copies content URIs via
  `FileDirectory`, ignores ClipData and subjects, and may emit both initial and
  stream delivery. Extend the current handler with bounded ContentResolver
  normalization and request IDs rather than relying on path conversion.
- `QuickCaptureCoordinator` queues distinct active shares. Preserve this behavior
  and expose explicit Save as Email; ordinary text/URLs retain existing routing.
- HTML clipper converter is article oriented (frontmatter, remote images). Email
  needs a dedicated network-free sanitizer/converter, sharing canonical Markdown
  conventions without changing clipper semantics.
- Parser dependency candidate: enough_mail (MPL-2.0, maintained MIME and charset
  support); inspect resolved implementation before use. Wrap it with preflight
  size/header/part/depth/transfer-decoding limits, since convenience decoding alone
  does not establish bounded processing. Run parsing in a worker isolate.
  Upstream: https://pub.dev/packages/enough_mail and its license/changelog.
- Flatpak already permits Documents/Downloads and portal-selected files. Do not
  broaden finish-args. File URI decoding must preserve portal paths and report
  inaccessible drops. DEB/RPM/AppImage consume the same native bundle.

## Validation strategy

Every phase runs `flutter analyze`, only relevant selected tests, `git diff --check`,
updates HANDOFF and the numbered engineering log, then commits and pushes before
starting the next phase. Never run the full Flutter test suite. Parser fixtures,
real in-memory Drift/encrypted-vault tests, preview widgets and platform boundary
regressions are required. Final validation includes Linux and Android compilation
where installed tooling permits. Record unavailable packaging/device checks
explicitly; automated tests do not establish physical-device behavior.

Phase 1 baseline results are recorded in engineering log 334.

## Phase 2 — parser and models

Added enough_mail **3.0.0**, MPL-2.0, inspected resolved sources and license.
Only RFC header/parameter/date/charset codecs are used. The bounded MIME range
walker avoids the library's eager message tree parsing and its diagnostic output;
upstream diagnostics are suppressed within parsing zones so malformed content is
never printed. New transitive packages are enough_convert, basic_utils, asn1lib,
encrypter_plus and pointycastle; no existing package version changed.

`EmailInput` normalizes file URIs, reads bounded files and inspects content.
`EmailParser` runs in an isolate, preserves raw bytes, selects alternatives,
collects attached messages opaquely, validates transfer encodings and enforces
raw/header/body/part/depth/attachment budgets before decoding. `EmailHtmlConverter`
never resolves URLs and emits images only for matching CID parts. HTML is never
rendered directly. `EmailMessage`, `EmailAttachment`, `EmailImportMode` and
versioned `NoteImportSource` establish the shared feature contracts.

18 focused tests use 22 deterministic email fixtures plus generated boundary
cases. They cover Unicode, RFC 2047/2231, alternative fallback, mixed/related/
nested MIME, binary and attached-message bytes, malformed data, filenames,
unsafe HTML/URLs, resource budgets, isolate parsing, normalization and provenance.

## Phase 3 — storage and synchronization

Schema 21 and source propagation are implemented across note mapping, repository,
encrypted sync/merge, backup/restore, duplication, CLI upload and QPNote export.
The transaction coordinator handles new/editable/archive/append, source identity,
CID replacement, representation deduplication, stale destination checks and
rollback. A durable UUID preparation journal enables interrupted-file cleanup.
63 selected existing/new regressions passed, followed by 34 persistence/export/CLI
tests after adding full backup restoration coverage. Flutter analysis is clean.
Original and MIME asset limits are enforced locally; the existing cloud 10 MB
policy is unchanged and may prevent large-asset upload. Such assets remain local
and pending/error under the standard encrypted sync machinery.

## Phase 4 — preview workflow

Added responsive review, three modes, destination search, optional shared metadata,
title/tags, attachments, duplicate review, error/progress/summary and cancellation.
Parsing and save go through an injectable application gateway. Batch previews
retain only one full email at a time and verify source hashes again at save.
Secure cache invalidation clears retained preview plaintext and stale callbacks.
24 selected UI/storage tests and a final 9-widget rerun pass; analysis is clean.

## Phase 5 — Linux integration

Global/workspace/editor drops, multi-picker, command discovery, file associations
and live-editor adoption are connected. 60 focused drop/editor tests plus 3 live
append tests pass; Linux debug compilation succeeds. Packaging scripts pass syntax
checks, but installed-package/sandbox replay remains unverified because package
builders are unavailable. No Flatpak grants changed. The drop plugin provides no
hover filenames, so classification occurs on drop. Imported notes suppress remote
link preview fetching when opened. See engineering log 338 for validation limits.

## Phase 6 — Android integration

The existing ShareIntentHandler now consumes bounded native normalization with
request IDs and a serial coordinator. ContentResolver handles streams, names,
MIME metadata and ClipData on cold/warm SEND/MULTIPLE/VIEW; private staging is
acknowledged/removed and secure clears invalidate pending input. Quick Capture
retains normal text/URL behavior and exposes explicit Save as Email.
47 selected regressions pass, analysis is clean and the GitHub Android debug APK
builds. Native hardware/provider replay is pending (adb reports no devices).
The build retains existing Kotlin-plugin and NDK-version warnings; no unrelated
package upgrade or build-policy change was introduced.

## Phase 7 — regression review

The focused gate passed 301 selected Flutter tests plus one specifically selected
real QPNote export test (302 total). Follow-up parser/workflow/editor, persistence/
attachment and final UI/share runs passed 49, 26 and 17 tests respectively; these
sets overlap. Final feature files contain 76 tests. Static analysis is clean.
Backend compilation and 18 selected opaque sync/attachment contract tests passed.
Linux and GitHub Android debug builds succeeded, with inherited Android toolchain
advisories and no physical-device claim.

The review strengthened pre-DOM bounds, CRLF/charset/date adapters, meaningful
fingerprints, source-only merges, QPNote mapping, lock-time request ownership,
partial-batch reconciliation, progress counts and recoverable ciphertext cleanup.
Only the selected message retains full preview bytes; imported assets do not
preload the plaintext cache. Worker hashing and rich append conversion avoid
capturing storage/platform objects.

Synthetic parser observations are in `benchmark-linux-jit.json`, reproduced with
`dart run tool/email_import_benchmark.dart`. The largest 41,943,563-byte case took
1,529ms while a 10ms main-isolate timer fired 149 times. Whole-process peak RSS was
580.4 MiB including JIT, source construction, worker copies and previous cases.
These single Linux JIT runs measure parsing, not encryption, mobile or release
performance. See engineering log 340 for all actual commands and limitations.

## Phase 8 — final documentation

Added the canonical handoff guide and A–H engineering report, and updated subsystem
indexes/guides. Final analysis and all 76 email-feature tests passed. Linux,
Android GitHub debug and standalone CLI compilation completed before the user's
instruction to stop builds; no further builds were started afterward. The final
commit is documentation only, using that completed validation plus diff checks.
Physical-device/installed-package checks and existing cloud size constraints are
explicitly recorded. All eight phases are committed and pushed independently.
