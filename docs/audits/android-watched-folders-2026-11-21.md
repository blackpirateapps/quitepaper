# Android watched-folder implementation and audit

Date: November 21, 2026. Base: `d4547e7` on
`feat/linux-rust-watched-folder-import`.

## Result and scope

The base implementation exposed watched folders only on Linux and loaded a Linux
Rust shared library. Android now has a separate read-only Storage Access Framework
(SAF) engine, selected through the existing controller/provider. The system folder
picker persists read grants. Multiple folders, independent switches/type filters,
initial review, Only New, shared receipts, history and canonical importers are reused.
The Android engine polls while foregrounded (30-second reconciliation plus immediate
startup/resume/manual scans); no background service, WorkManager task or Android Rust
build is introduced. Sources remain untouched; snapshots remain in bounded RAM.

This report distinguishes executed regressions, code-review findings and device
verification limits. It does **not** claim a successful Android device/UI replay.

## Bugs found and fixed

| ID | Finding and impact | Evidence | Resolution |
| --- | --- | --- | --- |
| AW-01 | Resume reconciled only the first watched folder. Later folders could wait for periodic discovery after the app returned. | Base lifecycle called the controller's single-folder `rescan()` default. The new foreground/resume regression checks reconciliation of both handles and preservation of disabled state. | Resume uses `rescanAll()`; Android suspends provider reads and invalidates late commits outside the foreground. |
| AW-02 | Enrollment racing a foreground rescan started two engines for the same folder, overwriting a handle. | Executed race regression failed with **2 starts instead of 1** before the fix. | Per-folder startup futures coalesce concurrent starts. A folder generation change/close stops a late handle, and close waits for outstanding starts. |
| AW-03 | The initial startup-future cleanup could wait on its own future. | The first coalescing implementation returned the removed future from `whenComplete`, causing controller tests to time out. | Cleanup returns void. Startup, enrollment, restart, race and crash regressions now exercise this path. This defect was in the uncommitted implementation. |
| AW-04 | Android acknowledged a retry with a delay but immediately continued polling work. | Executed backoff regression received an event during the promised 2-second wait. | Enforce the deadline with exponential delays of 2–32 seconds, using a monotonic production clock. |
| AW-05 | Cancellation while loading a provider directory could turn a failed iterator into a successful empty inventory. | Executed cancellation regression observed a later candidate with `initialInventory=false`, although its initial inventory had never finished. | Cancelled enumeration is discarded and restarted; it cannot mark initial review complete. |
| AW-06 | Unsupported binaries and partial temporary downloads could prevent review of valid files in the same folder. | Executed mixed-directory regression produced no valid `good.txt` candidate before the fix. | Ignore unsupported temporary types; exclude signature/size failures without cancelling other eligible files. Supported partial/virtual files and genuinely incomplete listings still block acceptance. |
| AW-07 | Startup discarded Android permission error codes, leaving generic native-engine guidance. | Code review found the shared catch discarded `PlatformException.code`; the restart regression checks `permission_needed` while another root starts normally. | Preserve platform codes and isolate failed roots. The UI explains how to restore selected-tree access. |
| AW-08 | Source-opening failures from revoked grants could escape asynchronous button/menu handlers. | Code review plus the Android widget regression inject a revoked-grant error into Open Folder. | Catch the error and show recovery guidance; no uncaught widget exception. |

## Additional correctness and safety audit

These checks document design safeguards and review hardening; they are not claims
that each was a shipped bug.

- Provider IDs stay opaque. No `content://` URI is converted to a guessed filesystem
  path. Session membership limits reads to documents returned by traversal of its
  selected tree. Android/provider tree permission enforcement remains authoritative.
- Directory pages are limited to 64 entries, stability work to eight documents per
  batch, pending files to 128, traversal to 64 directory levels and 100,000 entries.
  Duplicate IDs/cycles, invalid pagination and incomplete/loading cursors fail closed.
- Three metadata observations and at least three seconds of stability precede a
  streamed hash. The canonical snapshot is reopened, bounded and rehashed; hashes,
  revisions and lengths must match. Metadata is checked before and after each read.
- Provider size/mtime can be absent or unchanged after a same-size rewrite. Content
  hashes participate in revisions, avoiding collision with an already-terminal job.
  Both Dart and pure Kotlin regressions cover this case.
- EML remains limited to 50 MiB, text/Markdown to 10 MiB, PDF/images to 10,000,000
  bytes. Stream limits also apply when declared size is null or wrong. Binary
  signatures, partial/virtual flags, hidden/temp names, early EOF, non-progressing
  streams and cancellation are covered by focused tests.
- Native reads use worker threads and cancellation signals. Signals are registered
  before the final foreground check. Stream construction failures close the already
  opened descriptor; normal, oversized, changed and cancelled reads close streams.
- Markdown images resolve by exact provider child names under the granted tree.
  Absolute/URI paths, escaping traversal and ambiguous matches are refused. Lookups
  have a 512-page budget. Related images remain part of the note, independent of
  standalone image filters; canonical image-count/combined-byte budgets still apply.
- Schema 25 adds local `display_name` for provider folder labels. Migration from
  schema 24 retains enabled/type settings; earlier migrations and backups are tested.
  Roots, jobs and grants are excluded from the app's custom backup/sync payloads.
  This does not claim a change to Android OS backup policy or to pre-existing broad
  storage declarations in the manifest. This watcher does not request/use them.
- Account/lock changes invalidate all imports; disable/filter/remove invalidates
  only its folder. Backgrounding during a snapshot cannot commit a late note or
  receipt after the controller observes suspension. Shared receipts still deduplicate
  across roots, including overlapping selections. Removal preserves notes/receipts.
- No original source writes/deletions, plaintext staging files, message-content
  logs, notifications, cloud mailbox access, automatic OCR or unsolicited navigation
  were added. Human folder labels replace opaque provider URIs in cards.

## Executed validation

Final verification completed with Flutter 3.47.2 / Dart 3.13.2, Gradle 9.1.0,
Java 17 and the configured Android-37 compile SDK.

| Gate | Result |
| --- | --- |
| `flutter analyze` | **PASS: no issues** |
| Explicit Flutter paths below | **PASS: 114 tests**, including three subprocess crash-recovery scenarios |
| Focused `WatchedDocumentReaderTest` JVM class | **PASS: 12 tests, 0 skipped/failures/errors** |
| Existing real Linux Rust→Dart→canonical-import integration | **PASS: 1 test**, two folders, filters, shared receipts and independent removal |
| Android GitHub debug app assembly | **PASS** |
| Android instrumented test APK assembly | **PASS** (compilation/packaging only) |
| Real Android SAF/system-picker test execution | **NOT VERIFIED: host emulator crashes** |

```sh
flutter analyze
flutter test --no-pub --concurrency=1 \
  test/watched_import \
  test/templates/template_database_test.dart \
  test/database/database_migration_test.dart \
  test/email_import/email_persistence_test.dart \
  test/settings/settings_screen_test.dart

# Executed using the installed Gradle 9.1.0 runtime and Java 17:
gradle -p android :app:testGithubDebugUnitTest \
  --tests 'com.blackpiratex.quietpaper.watched.WatchedDocumentReaderTest' \
  :app:assembleGithubDebug :app:assembleGithubDebugAndroidTest \
  --max-workers=2 --console=plain

QP_WATCHED_NATIVE_LIBRARY="$PWD/target/debug/libquietpaper_watched_import.so" \
  flutter test --no-pub --concurrency=1 tool/watched_import_native_test.dart
```

The native library used by the Linux regression was the previously built contract-2
library; Rust code did not change in this Android feature. Android build output
contains existing Gradle/Kotlin migration and dependency deprecation warnings;
there are no diagnostics from the new watcher Kotlin classes. The required Flutter
static analysis is clean. The full Flutter test suite was not run.

Built artifacts (ignored by Git):
`build/app/outputs/apk/github/debug/app-github-debug.apk` and
`build/app/outputs/apk/androidTest/github/debug/app-github-debug-androidTest.apk`.
No APK was installed on a user device or published.

## Android device verification limit

An isolated API-35 AOSP emulator was created under `/tmp`, without using an existing
user AVD. Both KVM configurations (SwiftShader and GPU off) and a software/TCG boot
exited with **SIGSEGV / exit 139** before completing Android startup. TCG progressed
through guest init/zygote; no stable boot or usable system picker was obtained.
This is a host-emulator failure, not a passing application/device result.

`WatchedFolderSafTest` is checked in and its instrumented APK compiles. It exercises
the real picker, two persistent grants, provider enumeration, verified reads,
Markdown images, session isolation, background rejection and grant revocation.
Its runtime result remains **NOT VERIFIED** until run on a working emulator/device.
Physical-device provider behavior (local/SD/cloud), picker grant persistence after
process death, permission revocation, battery behavior and large-file memory remain
release acceptance items. The unit/channel/widget tests do not substitute for them.

On a disposable emulator/device, run only this class:

```sh
flutter build apk --debug --flavor github --no-pub
cd android
# Use the project's Gradle 9.1.0 wrapper/runtime and configured Android SDK/JDK.
./gradlew :app:connectedGithubDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.blackpiratex.quietpaper.watched.WatchedFolderSafTest \
  --max-workers=2
```

The instrumented test creates and removes only its own UUID-named
`Download/QuietPaperAudit-*` directory. It does not require all-files permission.
Android 11+ disallows selecting the Downloads root and certain other roots;
select a subfolder such as `Downloads/Quiet Paper` in ordinary use.

References: [Android SAF and persistent tree grants](https://developer.android.com/training/data-storage/shared/documents-files),
[DocumentsContract](https://developer.android.com/reference/android/provider/DocumentsContract),
[AndroidX Test stable versions](https://developer.android.com/jetpack/androidx/releases/test).
