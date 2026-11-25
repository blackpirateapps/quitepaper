# Notes list audit — November 17, 2026

Baseline: `9bf2cdd` (main). Branch: `audit/notes-list-2026-11-17`.
The original audit is preserved below; remediation status and per-finding
resolutions are updated after each individually validated fix.

## Remediation verification

All ten findings have individual fixes, documentation updates and pushes on this
branch. Final `flutter analyze` reports no issues. Running only the relevant
`flutter test --no-pub --concurrency=1 test/notes test/features/notes` checks passes
**192 tests**; no full suite ran. [Final checks and Linux profile replay](fix-verification/README.md)
include raw output, native frame/cache measurements and mobile-device limits.
The original audit probes deliberately assert baseline defects and are preserved
as historical evidence outside normal discovery.

## Original audit scope and evidence

Read `HANDOFF.md`, the tags/search guide, notes query/pagination, grouping,
metadata/thumbnail presentation, responsive layouts, selection, and export paths.
Existing focused notes/gesture tests cover filters, sort controls, pin scopes,
archive/trash, selection, protected previews, metadata extraction, and search reveal.
Additional probes exercise failure recovery, interleaved requests, large lists,
responsive breakpoints, and export persistence.

Widget tests use the real `NotesScreen`, Riverpod providers and a fresh in-memory
Drift database, with Android at 390 × 844dp and Linux at 1440 × 900dp. Failure
injection replaces only query completion/error behavior. Responsive smoke checks
also cover 320 × 568, 360 × 800, 600 × 800, 899 × 700 and 900 × 700dp.
The 1,000-note virtualization probe intentionally injects a fully loaded collection
to separate list rendering from database cost.

Native profiling uses Flutter 3.47.2 / Dart 3.13.2 on Linux under Hyprland/Wayland,
a 60Hz display, synthetic data and an in-memory SQLite database. The actual list
runs in a native profile engine at desktop and phone viewport sizes. The benchmark
records query latency, metadata prewarming, build/raster durations and screenshots.
It drives scrolling with `ScrollPosition.animateTo`; it is not a native mouse or
physical touchscreen replay. Measurements are diagnostic samples from a shared
workstation, not stable CI thresholds or disk-backed/mobile-device benchmarks.

Only Linux was connected (`flutter devices`). **Physical Android/iOS behavior,
mobile GPUs, native touch input and IME, thermal behavior and mobile memory remain
unverified.** Android platform widget tests exercise mobile behavior, while phone
profile timings describe the Linux engine displaying the phone layout.

## Findings

**10 confirmed bugs; 0 open, 10 fixed.** P1 means high priority due to incorrect context,
export integrity, or severe UI stalls; P2 means ordinary functional correctness.
NL-07 is the passing virtualization control, not a bug.

| ID | Status | Priority | Confirmed defect | Direct evidence |
| --- | --- | --- | --- | --- |
| [NL-01](#nl-01-initial-load-failure-looks-like-an-empty-library) | Fixed | P2 | Initial database failure shows “No notes yet” without Retry | Android and Linux screen probes |
| [NL-02](#nl-02-date-grouping-breaks-the-selected-sort-order) | Fixed | P2 | Date grouping reorders title-sorted notes | Query A/B/C renders A/C/B on both layouts |
| [NL-03](#nl-03-metadata-cache-retains-stale-tags) | Fixed | P2 | Cache identity excludes tags and content identity | Updated tags remain old in preview metadata on both layouts |
| [NL-04](#nl-04-refresh-discards-loaded-pages-after-250-notes) | Fixed | P2 | Refresh drops previously loaded notes beyond the batch cap | 440 loaded becomes 250; total stays 440 |
| [NL-05](#nl-05-refresh-and-query-generations-collide) | Fixed | P1 | A stale refresh overwrites a newer context | Archive query is replaced with active-note data |
| [NL-06](#nl-06-retry-does-not-retry-a-failed-refresh) | Fixed | P2 | Retry is a no-op after refresh fails at end of list | No new query; error remains |
| [NL-08](#nl-08-prewarming-above-cache-capacity-reparses-the-whole-collection) | Fixed | P1 | Repeated prewarming churns the complete 500-entry cache | Zero cached instances survive at 600/1,000 notes |
| [NL-09](#nl-09-desktop-zip-overwrite-reports-success-without-saving) | Fixed | P1 | Existing nonempty ZIP export destination is not written | Old file contents remain while UI reports success |
| [NL-10](#nl-10-paginated-note-mapping-drops-journal-and-sharing-fields) | Fixed | P2 | Paginated mapping omits journal/share metadata | Full lookup retains fields; page lookup returns null |
| [NL-11](#nl-11-failed-context-switch-displays-the-previous-contexts-notes) | Fixed | P1 | Failed context switch displays notes from the old context | Active note remains visible under Archive on both layouts |

### NL-01: Initial load failure looks like an empty library

**Fixed.** Phone and desktop lists show a load error with Retry before the empty-state branch. Retry recovers existing notes; genuinely empty libraries retain their ordinary empty state.

Validation: `flutter analyze`: no issues; `flutter test test/notes/notes_list_audit_regression_test.dart`: 4 passed. No full suite ran.

**Location:** `lib/features/notes/presentation/notes_screen.dart:1367` and `:2699`;
`lib/features/notes/application/notes_query_provider.dart:455`.

**Reproduce:** Make the first `executeNotesQuery` fail (for example, a local
storage read error) and open All Notes. The probe injects a `StateError`.

**Expected:** A load failure with a reachable retry action; do not imply the
library is empty or encourage creating a replacement note.

**Observed:** State retains the error, but both layouts render `NoteEmptyState`
with “No notes yet”. The error footer is created only in the populated list
branch, so no Retry exists. This is separate from an actually empty library.

**Suggested correction:** Handle the initial-error state before the empty-state
branch and retry the initial query. Preserve the ordinary empty-state experience.
**Acceptance:** Fail first query, see error/retry, recover to existing notes after
retry, on phone and desktop. Evidence: `NL-01` probe records in `probes.log.txt`.

### NL-02: Date grouping breaks the selected sort order

**Fixed.** Grouping preserves query order with contiguous date buckets, uses the selected created/updated date, and groups title sorts without date reordering. Phone/desktop regressions cover all sort directions and pin settings; 85-note keyset pagination checks preserve order at each page boundary.

Validation: `flutter analyze`: no issues; focused audit, domain and pin tests: 35 passed; expanded audit regressions including keyset boundaries: 7 passed. No full suite ran.

**Location:** `lib/features/notes/domain/note_group.dart:20`;
`lib/features/notes/application/notes_query_provider.dart:627`.

**Reproduce:** Create Alpha and Charlie with yesterday's modification time and
Beta with today's time. Select Title ascending with pinned-first off.

**Expected:** Alpha, Beta, Charlie.
**Observed:** SQLite correctly returns that order; grouping collects all notes
in each modification-date bucket and renders Alpha, Charlie, Beta. Verified in
the actual phone and desktop list, not merely the grouping helper. Created-time
sorting also feeds this same modification-date grouping path; that additional
permutation has not been independently asserted.

**Suggested correction:** Make grouping depend on the active sort: avoid date
buckets for title sorting and use the appropriate date for date-based sorts.
**Acceptance:** Assert rendered order across mixed dates for both title directions
and created/updated sorts, including pins and page boundaries.

### NL-03: Metadata cache retains stale tags

**Fixed.** Metadata cache keys compare exact content, title, timestamp, tag values and snippet rather than content length and partial hashes. Same-time tag edits and same-length body replacements now produce fresh metadata, while unchanged values reuse cached instances. Exact note-ID invalidation preserves other IDs.

Validation: `flutter analyze`: no issues; cache, journal metadata, scrolling and screen regression files: 19 passed. No full suite ran.

**Location:** `lib/features/notes/domain/note_metadata_extractor.dart:152` and `:194`.

**Reproduce:** Warm a tile with tags `[before]`; publish a copy of the same note
with tags `[after]` while retaining ID, title, content and `updatedAt`. The probe
uses `updateLocalNote` to isolate the presentation contract.

**Expected:** Metadata and tag chips reflect `[after]`.
**Observed:** The collection model has `[after]`, but `extract` returns the old
cached metadata containing `[before]` on both layouts.

The key uses ID, millisecond timestamp, title hash, content **length**, and
precomputed snippet. It omits tags and the actual content identity. Therefore a
same-length body change at the same timestamp can also collide; the executed
probe directly confirms the tag case only. This does not claim every normal
save retains its timestamp.

**Suggested correction:** Include all metadata inputs in revision identity or
invalidate on every relevant model mutation. **Acceptance:** Same-time tag changes
and same-length body replacements produce fresh metadata; unchanged notes still
hit the bounded cache.

### NL-04: Refresh discards loaded pages after 250 notes

**Fixed.** Refresh reconstructs the loaded window using bounded keyset pages and publishes the replacement atomically. Regressions retain 440 and 1,000 loaded IDs, edited content and continuation cursors; phone and desktop lists preserve a deep visible row and its scroll position.

Validation: `flutter analyze`: no issues; collection recovery, pagination races and screen regressions: 16 passed. No full suite ran.

**Location:** `lib/features/notes/application/notes_query_provider.dart:540`;
`lib/features/notes/domain/notes_query.dart:21`.

**Reproduce:** Load all 440 notes through real keyset pagination, then refresh.
A table update or a list mutation can trigger this same refresh path.

**Expected:** Retain the loaded window, cursor progression and scroll continuity.
**Observed:** Refresh clamps its query to `NotesQuery.maxBatchSize` (250) and
replaces the whole collection. Only 250 notes remain loaded although `totalCount`
stays 440. The data is still in the database and can be repaginated; this is
loaded-window loss, not note deletion. Native profiling separately measures the
same path after loading 1,000 notes.

**Suggested correction:** Refresh the loaded window in bounded pages or reconcile
loaded pages without truncation. **Acceptance:** Update a note after scrolling
beyond 250/1,000 notes; retain the visible anchor, loaded IDs and a valid cursor.

### NL-05: Refresh and query generations collide

**Fixed.** The collection notifier assigns monotonically increasing request generations to every initial load and refresh. Async success, error and load-more cleanup check the current generation and mounting before updating state. Regressions cover both completion orders, stale failures, overlapping refresh/filter/sort changes, disposal and old-page cleanup during a new page request.

Validation: `flutter analyze`: no issues; collection recovery and pagination race files: 12 passed. No full suite ran.

**Location:** `lib/features/notes/application/notes_query_provider.dart:426`,
`:530`, and `:548`.

**Deterministic reproduction:**

1. Complete initial active generation 1.
2. Start a refresh; it assigns collection generation 2 without advancing the
   separate `notesQueryProvider` generation.
3. Switch to Archive. The query provider advances from 1 to 2, so the archive
   request and older active refresh share the same generation.
4. Complete Archive first, then complete the older active refresh.

**Expected:** Ignore the stale active response.
**Observed:** State still says `context: archive`, but contains the active note.
The generation comparison accepts both completions. This can present a note in
the wrong destination and makes context-specific batch actions unsafe. The probe
asserts the exact interleaving; no scheduling luck or network timing is required.

**Suggested correction:** Use a notifier-owned monotonically increasing request
identity for all initial loads and refreshes; check query identity and mounting
before accepting responses. **Acceptance:** Exercise both completion orders and
multiple refresh/filter/destination changes, with only the current request winning.

### NL-06: Retry does not retry a failed refresh

**Fixed.** Retry dispatches the recorded failed operation: initial load, refresh, or next page. Failed refreshes restart at the beginning even at end-of-list, and failed pages retry their cursor without losing loaded notes. Automatic scrolling leaves a displayed error intact until Retry or explicit refresh.

Validation: `flutter analyze`: no issues; collection recovery and screen regression files: 23 passed. No full suite ran.

**Location:** `lib/features/notes/application/notes_query_provider.dart:573` and `:468`.

**Reproduce:** Load a one-note library completely (`hasMore: false`), inject a
refresh failure, then invoke Retry.

**Expected:** Repeat the failed refresh and clear the error after recovery.
**Observed:** Because notes are present, `retry()` calls `loadMore()` instead.
`loadMore()` returns immediately when `hasMore` is false. Query count stays at
2 and the error persists. With more pages, this dispatch can instead request the
next page without retrying the failed refresh; that variant is source-derived.

**Suggested correction:** Track which operation failed and retry that operation.
**Acceptance:** Failed initial, refresh and next-page operations each recover
without losing loaded notes, filters or sort.

### NL-08: Prewarming above cache capacity reparses the whole collection

**Fixed.** Removed collection-wide metadata and thumbnail scans from both list providers and the screen. Mounted tiles extract lazily; grouped data watches notes/sort rather than loading flags. Speculative prewarm fills unused capacity without evicting recent entries. Linux profile replay reduces repeated 600/1,000-note prewarm from 364/598ms medians to at most 1 microsecond, with no Flutter errors; raw evidence and physical-mobile limits are in fix-verification/README.md.

Validation: `flutter analyze`: no issues; cache, scrolling, redesign and screen regression files: 50 passed. Native build/raster p95 stays below 16.67ms in both layouts, with one desktop build outlier. No full suite ran.

**Location:** `lib/features/notes/application/notes_query_provider.dart:605`;
`lib/features/notes/domain/note_metadata_extractor.dart:174` and `:265`.

**Reproduce:** Prewarm 600 or 1,000 unchanged notes in list order twice.

**Expected:** Repeated state notifications reuse cached visible/recent metadata;
cache size stays bounded and expensive parsing does not block UI work.
**Observed:** Capacity is 500. Starting the next sweep at note zero evicts cached
notes before the sweep reaches them. Every retained cached instance is replaced
at 600 and 1,000 notes, whereas all instances survive at 400 and 500. This runs
synchronously from `groupedNotesCollectionProvider`, which watches the entire
collection state, including loading flag changes. Thumbnail prewarming also scans
notes after builds. Debug and native profile measurements are separated below.

**Suggested correction:** Prewarm only newly loaded/revised notes and a bounded
visible window, separate collection data from loading-state dependencies, and
schedule expensive work outside a single UI frame. Do not simply unbound the LRU.
**Acceptance:** Repeated 600/1,000-note state changes preserve useful cache entries
and meet a defined frame budget on native desktop and physical mobile devices.

### NL-09: Desktop ZIP overwrite reports success without saving

**Fixed.** Desktop ZIP exports always replace and flush picker-returned paths before reporting success. Null/empty picker responses cancel without writing; picker and filesystem failures show an export error. Mobile pickers retain ownership of supplied bytes. Regressions decode exact new/overwritten archives and cover cancellation and failures.

Validation: `flutter analyze`: no issues; ZIP export and multi-selection tests: 16 passed. No full suite ran.

**Location:** `lib/features/notes/presentation/notes_screen.dart:679`.

**Reproduce:** Select two notes using desktop modifier selection. Choose Export
as ZIP, select an existing nonempty destination, and confirm overwrite. The test
picker returns a real temporary file containing `EXISTING CONTENT` and retains
the generated ZIP bytes; like the desktop picker, it does not write those bytes.

**Expected:** Replace/truncate the file with the generated archive before success.
**Observed:** The conditional writes only when the destination is missing or zero
bytes. Existing content stays unchanged, yet “Exported 2 notes” appears. No
user file is used by the probe. The same code also swallows write exceptions;
that path is noted from source and not counted as an independently tested defect.

**Suggested correction:** Explicitly write/flush picker-returned desktop paths,
respect cancellation and report write failure. Keep platform-specific picker
ownership of mobile bytes. **Acceptance:** New and existing paths contain an
exact, readable archive of the selected notes; failures show no success message.

### NL-10: Paginated note mapping drops journal and sharing fields

**Fixed.** Full and paginated reads share a complete NoteEntity-to-Note mapper, including journalDate, shareId and shareUrl. Batch tag hydration remains unchanged. Regressions compare every persisted domain field across active, Archive and Trash reads, including journal/share flags and local pins.

Validation: `flutter analyze`: no issues; database query and pin-scope files: 25 passed. No full suite ran.

**Location:** `lib/features/notes/data/notes_query_executor.dart:144`.

**Reproduce:** Persist a note with journal date `2026-11-17`, then set its local
share ID/URL through `setNoteShareInfo`. Read it by ID and through the list query.

**Expected:** Both return the same journal/share fields.
**Observed:** Full lookup retains all fields; the paginated mapper omits
`journalDate`, `shareId`, and `shareUrl`, returning null. Thus `isJournal` and
`isShared` are false for the list's snapshot. Opening a list note passes that
snapshot to the editor. Share menu logic branches on `isShared`; database share
bookkeeping itself is protected from ordinary saves. No backend share deletion
or end-to-end public-sharing failure is claimed by this component probe.

**Suggested correction:** Share a complete row-to-domain mapper between read
paths. **Acceptance:** Paginated/full results agree on all persisted Note fields,
including journal and existing share metadata, without extra per-row queries.

### NL-11: Failed context switch displays the previous context's notes

**Fixed.** New queries immediately clear old rows, counts and cursors, including destination, tag, sort and filter transitions. Query changes also end batch selection so old IDs cannot be acted on under the new query. Phone/desktop regressions assert empty loading/error collections, no actionable old rows, and successful Retry with the new predicates retained.

Validation: `flutter analyze`: no issues; screen, recovery and selection regression files: 46 passed. No full suite ran.

**Location:** `lib/features/notes/application/notes_query_provider.dart:429` and `:455`;
`lib/features/notes/presentation/notes_screen.dart:1367` and `:2699`.

**Reproduce:** Load an active note, then make the Archive query fail while
switching to Archive. No overlapping refresh is necessary.

**Expected:** Show the Archive load error with Retry; previous-context notes must
not be actionable as Archive notes.
**Observed:** `_loadInitial` changes the query but retains `state.notes`. Its
failure handler ends loading without discarding or fencing that old collection.
Both phone and desktop show the active note in Archive. The error uses the
“Couldn't load more notes” footer even though a new context failed to load.

**Impact:** The displayed context no longer describes the actionable rows.
A similar failed Trash switch would reach the same state path; destructive
Trash actions were not replayed and no deletion claim is made.

**Suggested correction:** Retain stale data only when it belongs to the current
query, and handle new-query failure distinctly. **Acceptance:** Inject failures
on destination, tag, sort and filter transitions and assert that no old-query
row can be selected or mutated under the new query.

## Original audit performance and verification results

The following results describe the baseline before remediation. The permanent
acceptance tests and current profile replay are recorded in the resolutions and
[fix verification](fix-verification/README.md).

Original commands, measured timings, raw logs and replay instructions follow. Bug-probe passes mean the defects were reproduced; they
do not mean the application is bug-free or the findings have been fixed.

### Final focused checks

- `flutter test --no-pub --concurrency=1 test/notes test/features/notes --reporter expanded`:
  **141 passed**. [Existing test log](existing-tests.log.txt).
- `# Historical characterizations assert the old bugs and will fail after fixes:
# flutter test --no-pub --concurrency=1 handoff/audits/notes-list-2026-11-17/replay/notes_list_audit_test.dart --reporter expanded`:
  **21 passed** (14 bug characterizations, 2 virtualization controls, 5 responsive
  controls). [Probe log](probes.log.txt). These tests deliberately assert observed
  defective behavior and live outside normal `test/` discovery.
- `flutter analyze --no-pub`: **no issues**; [analysis log](analysis.log.txt).
  The initial plain `flutter analyze` also resolved dependencies; its one audit
  fixture lint was corrected before final validation. Dependencies were not upgraded.
- Native profile build and completed replay: [build log](profile-build.log.txt),
  [runtime log](native-runtime.log.txt), [measurements](native-profile.json),
  [window verification](window-verification.json), [desktop screenshot](desktop.png),
  [phone screenshot](phone.png).

The original audit ran no full Flutter test suite and changed no application
source, database schema, installed app, user note or account. Remediation adds
permanent acceptance tests under `test/notes/`; original replay probes below
remain historical defect characterizations and are not remediation checks.

### Native query and cache measurements

There are 10,000 synthetic notes, each with a 1,563-character Markdown body;
queries fetch 40 notes. Query measurements exclude one warmup and retain 20
samples. Cache measurements retain 7 repeated sweeps after one prewarm.
All table values below are milliseconds, converted from the JSON's microseconds.

| Operation | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Updated sort, first page | 75.716 | 76.954 | 77.570 |
| Title sort, first page | 18.327 | 18.880 | 19.436 |
| Has Links content filter, first page | 120.557 | 122.995 | 123.661 |
| Repeated metadata prewarm, 400 notes | 0.326 | 0.407 | 0.407 |
| Repeated metadata prewarm, 500 notes | 0.409 | 0.443 | 0.443 |
| Repeated metadata prewarm, 600 notes | **364.336** | 523.251 | 523.251 |
| Repeated metadata prewarm, 1,000 notes | **598.281** | 641.749 | 641.749 |

The 600/1,000-note sweeps exceed the 16.67ms budget for a 60Hz frame by about
22/36 times at the median. This directly measures synchronous metadata work,
not an end-to-end response-time guarantee. Identity probes independently prove
that the cliff is cache churn, rather than merely more notes being processed.

Loading 1,000 notes through pagination took 1,721.577ms in this run. Refresh
returned in 99.221ms but reduced the loaded collection from **1,000 to 250**,
independently reproducing NL-04. Query latency is asynchronous; it must not be
read as an equivalent UI-thread blocking duration. These measurements do not
isolate the query count, ordering, tag hydration or database-isolate overhead.

### Native scrolling and virtualization controls

Each layout scrolls down to offset 10,000 and back with two four-second linear
animations after warmup. Lazy-list extent estimates may change during layout;
the saved initial extent is an estimate, not an assertion of full content height.
Both layouts retain 1,000 loaded notes and mount 13 tiles at rest.

| Metric | Desktop 1280 × 680 | Phone layout 390 × 680 |
| --- | ---: | ---: |
| Recorded frames | 396 | 348 |
| Build median / p95 / max (ms) | 2.100 / 7.715 / 10.476 | 2.995 / 7.629 / 16.675 |
| Raster median / p95 / max (ms) | 2.313 / 2.919 / 3.229 | 1.933 / 2.351 / 2.500 |
| Total-span p95 / max (ms) | 16.730 / 22.335 | 13.132 / 21.666 |
| Frames with build or raster >16.667ms | 0 | 1 |
| Recorded Flutter errors | 0 | 0 |

Frame totals include engine scheduling. Counts are recorded engine frames, not
a claim of uninterrupted 60fps; neither compositor presentation nor missed vsyncs
are independently traced. One isolated phone-layout build at 16.675ms is not
classified as a separate app bug. The synchronous cache cliff is the repeatable
performance finding. Scrolling with a bounded set of mounted tiles remains a
passing control; the debug widget probe independently mounts at most 11 tiles
on phone and 9 on desktop while jumping through 1,000 plain-text notes.

### Replay and exclusions

From the checkout root:

```sh
flutter test --no-pub --concurrency=1 test/notes test/features/notes --reporter expanded
# Historical characterizations assert the old bugs and will fail after fixes:
# flutter test --no-pub --concurrency=1 handoff/audits/notes-list-2026-11-17/replay/notes_list_audit_test.dart --reporter expanded
flutter analyze --no-pub
flutter build linux --profile --no-pub -t handoff/audits/notes-list-2026-11-17/replay/notes_list_profile.dart
python3 handoff/audits/notes-list-2026-11-17/replay/run_native.py
# Restore the ordinary profile entry point after the isolated audit closes:
flutter build linux --profile --no-pub -t lib/main.dart
```

[Widget probe source](replay/notes_list_audit_test.dart),
[native harness](replay/notes_list_profile.dart), and
[isolated launcher](replay/run_native.py) are retained exactly for review/replay.
The launcher assumes this Linux checkout, `/proc`, `dbus-run-session`, a running
Hyprland session with its Lua dispatcher API, and Flutter Linux build dependencies.
It creates fresh XDG directories, selects the window by its exact executable,
resizes only that window, and validates the PNG dimensions. Its output is written
to a new `/tmp/qp-notes-native-*` directory printed on completion.

An initial native run was discarded for desktop layout/frame claims because the
compositor tiled its window to 672dp despite the requested MediaQuery width. A
subsequent extent-threshold lookup was also discarded. The final retained replay
checks actual render sizes, locates the scroll position through a rendered tile,
and exits successfully. These harness problems are not counted as application
bugs. The restored normal profile build is recorded in `restore-build.log.txt`.

Runtime stderr includes isolated-session accessibility/keyring/desktop-portal
messages and caught secure-storage fallback diagnostics. These are distinct from
the empty Flutter-error collection and from the clean analyzer. The first native
build emitted third-party whisper/json C++ deprecation warnings; the final cached
build log has no compiler diagnostics. No dependency code was changed.

This audit does not exercise real attachment decoding, authenticated sync, native
file-picker dialogs, screen readers, physical touchscreens, software keyboards,
mobile memory/thermal limits, release builds or disk-backed database latency.
Existing note-list thumbnail component tests ran, but the stress dataset uses no
real attachment files. Export verification uses the actual list UI, generated ZIP
bytes and a temporary file with a controlled picker response.
