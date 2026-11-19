# Email import engineering report

Implemented on `feat/email-import`, with each of the eight phases committed and
pushed separately. The feature has automated and compilation evidence; physical
Android and installed Linux distribution verification remain outstanding.

## A. Functionality

Linux workspace/editor drops, multi-file selection, import settings, desktop
commands and email file associations open the common preview. Android accepts
supported email MIME shares/open actions through bounded native normalization.
Plain text retains Quick Capture and offers explicit Save as Email; bare URLs
retain clipping. Preview supports metadata/title/tags, three import modes,
explicit destinations, attachment review, duplicate choices, batch progress,
errors, cancellation and completion. Original messages and MIME assets enter the
existing encrypted vault. Notes remain ordinary editable/searchable notes.

## B. Architecture

The pure Dart MIME adapter enforces budgets before decoding and runs in a worker.
HTML conversion is local and network-free; CID references become encrypted local
asset links. An injectable gateway joins parser, index, destination search and
transactional persistence. The coordinator journals prepared asset IDs, validates
the latest destination, saves canonical Markdown/rich AST and preserves provenance.
The active-editor bridge prevents stale autosaves after confirmed/partial appends.

## C. Major files

| Area | Files and responsibility |
| --- | --- |
| Parser/domain | `lib/features/email_import/domain/`, `application/email_input.dart`, `email_parser.dart`, `email_html_converter.dart` |
| Persistence | `application/email_import_service.dart`, note model/mapper/repository, Drift database/schema/generated code |
| Workflow | `application/email_import_gateway.dart`, `email_editor_bridge.dart`, `presentation/` preview/launcher/workspace actions |
| Native/share | Android `IncomingShareReceiver.kt`, MainActivity/manifest, existing ShareIntentHandler/SharedFileImporter, incoming request coordinator |
| Existing systems | Attachment service/cache, Quick Capture, editor surfaces, encrypted sync/merge, backup, CLI sync, QPNote export, Linux desktop metadata |
| Verification | `test/email_import/`, relevant existing tests, `tool/verify_email_import.sh`, synthetic benchmark tool/artifact |

## D. Database and sync

Schema 20/21 → 22 adds canonical optional import sources, a derived indexed lookup
and a durable preparation journal. Existing notes default to an empty collection.
The integration migration accepts both earlier schema-21 feature layouts and
preserves template snapshots/favorites as well as existing email provenance.
Source identities union across edits/merges; backups/restores, duplication, CLI
uploads and QPNote export retain them. An older envelope cannot erase locally
retained provenance. No backend endpoints or server-visible email fields changed.
Original timestamps remain separate from actual note creation/modification times.

## E. Verification

Actual recorded checks, with overlapping test sets rather than an invented sum:

- Final `flutter analyze`: no issues.
- Recorded phase 7 focused gate: 301 tests across selected affected paths, then
  one selected real QPNote export test: **302 passed**. No full suite ran.
- Follow-ups: 49 parser/workflow/editor tests, 26 persistence/attachment tests,
  and 17 final preview/desktop/shared-text tests passed.
- Final `flutter test --no-pub --concurrency=1 test/email_import`:
  **76 passed**, covering parser/security, real persistence/recovery, UI, sharing,
  live editor appends, full editor-mode round trip and fresh-device encrypted sync.
- Backend Node 22.23.1: `npm run build` passed; selected crypto-blind, sync,
  conflict and attachment files passed **18 tests**. Backend production code stayed
  unchanged.
- Linux debug, GitHub Android debug APK and standalone Linux CLI compilation
  passed before the instruction to stop local builds. No further builds were run
  after that instruction. Android emitted inherited KGP/NDK advisories.
- Formatting, `git diff --check` and packaging-shell syntax checks passed.

Commands are preserved in engineering logs 334–341 and the focused verification
script. Fixtures are deterministic and require no mail account. The final 76-test
run and native/CLI compilation were completed before the final documentation
commit; no additional build is required to commit these documents.

[Synthetic Linux JIT observations](benchmark-linux-jit.json) measure parsing only:
10 KB plaintext 109ms; 1 MB HTML 566ms; 10 MB multipart 419ms; 40 MiB multipart
1,529ms; 50 small messages 128ms total. Main-isolate timers continued throughout.
Process peak RSS reached 580.4 MiB, including JIT, source construction, isolate
copies and prior cases. These are single observations, not mobile/release or
retained-heap measurements.

## F. Security

No mail credentials, remote parsing, HTML execution, remote-image loading or
automatic OCR were introduced. MIME/body/header/HTML budgets reject excessive or
malformed inputs. Filenames are sanitized; provider names cannot escape staging
paths. Assets use existing authenticated encryption. Preview cancellation creates
no note; incomplete saves roll back and preserve retryable cleanup journals.
Lock/logout invalidates retained preview content and pending shares. Diagnostics
expose operational errors rather than subjects, addresses, bodies or source paths.

## G. Remaining verification and limits

No Android device was connected. Actual chooser eligibility, provider grants,
ClipData and OEM cold/warm lifecycle behavior need a device replay. Linux physical
drops and installed DEB/RPM/AppImage/Flatpak behavior were not tested because the
packaging builders/test hosts were unavailable. Existing sandbox grants remain
unchanged. Hover file metadata is unavailable in the installed drop plugin.

The existing 10 MB cloud asset policy can leave larger locally accepted assets
pending; preview and documentation disclose this. Existing note payload policies
also continue to apply. Local encrypted originals and backups remain available.
This is not a claim that every accepted large import can upload under current
cloud policies. No application can recover headers/attachments that a source
Android app does not share; text/link-only imports remain explicitly labeled.

## H. Documentation

The canonical [handoff guide](../../handoff/email-import.md), root HANDOFF, index,
storage/editor/platform/search/document guides and numbered engineering logs
explain entry points, source/schema contracts, cleanup, privacy and validation
limits. The [implementation record](implementation.md) preserves phase history.

## Offline import correction — November 19, 2026

An Android report exposed a missing accountless encryption prerequisite: preview
checked `isUnlocked` before initialization and discarded the source because an
installation that never used Cloud Sync had no key. The gateway now initializes
one securely persisted local master key for a fresh signed-out notebook, and the
preview waits for that step. Storage failures preserve the source and offer Retry;
real lock/logout invalidation still discards sensitive content and pending work.
Keys survive restart, remain subject to existing asset encryption, and are reused
when setting up a new cloud vault. Existing encrypted libraries with missing keys
and adoption of differently keyed cloud vaults fail closed.

The correction passed a 140-test focused crypto/email/attachment/sync run, followed
by 20 local-key/OCR-search tests including two additional lock/clear race cases.
These runs overlap and are not a unique aggregate. Analysis and whitespace checks
pass. No app build or full test suite was run for the correction; physical Android
verification remains pending. See log 342 for exact commands and the
[offline key guide](../../handoff/email-import.md#offline-encryption-setup) for the
existing backup/master-key portability limitation.
