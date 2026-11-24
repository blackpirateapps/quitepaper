# Journal audit — November 24, 2026

Status: **first pass complete; 10 confirmed open bugs, no fixes.** Findings were
recorded as they were confirmed. The unresolved stress observation below is
excluded from that count.

**Second pass complete:** [10 additional findings and evidence](round-2/README.md)
continue the numbering through JRN-020, bringing the cumulative total to **20
confirmed open bugs**. The original ten findings below are preserved.

Branch: `audit/journal-rigorous-2026-11-24`. Application source:
`12c49b30b62ca72e13cfffd3c577857db7c51e09`.
Environment: Flutter 3.47.2 / Dart 3.13.2, Linux debug build on Hyprland/Wayland.

The existing focused gate passed **207 tests**:
`flutter test test/journal test/notes/note_metadata_journal_test.dart`.
Initial and final `flutter analyze` reported no issues. The full suite was not run.
Additional adversarial probes have **4 passes and 10 failures** across 14 cases;
several failures describe the same underlying bug. Their failures are audit
evidence, not fixed regressions. See [raw results](adversarial-tests.txt).
An additional New York DST run has **one failing case**, reproducing JRN-009.
The passing baseline is **not warning-free**: `place_alias_store_test.dart`
emits two pre-existing Drift multiple-database warnings, alongside secure-storage
fallback diagnostics. The trace points to fresh provider containers overriding
preferences but not database/key-manager dependencies. This is a test-fixture
isolation concern, distinct from the ten application bugs. It is preserved in
the raw log; no warning suppression or fixture fix was applied in this audit.
An isolated rerun of that file passes all **9 tests** and repeats the same two
warnings; see [fixture rerun](place-alias-fixture-warnings.txt). These nine tests
overlap the 207-test gate and are not counted as additional distinct cases.

Native verification uses the actual `QuietPaperApp`, journal screens, editor,
repository and SQLite, hosted by a temporary audit entrypoint. Only synthetic
notes are used, with an in-memory database, mock preferences and isolated XDG
directories. The Dart VM service exposes a test extension for inspection and
pointer events. Hyprland keyboard injection verifies real typing, leaving the
editor and reopening its saved contents. This does not establish persistence
across a process restart. Location/weather acquisition and cloud sync are not
part of this isolated window's acceptance coverage.

## Fix progress

JRN-001–003 are fixed with repository regression coverage. See the November 24
[handoff](../../../HANDOFF.md) for implementation and validation. The findings
and evidence below describe the original audited revision; JRN-004–020 remain open.

## JRN-001 — Ordinary date properties claim a canonical journal day

**Severity: high. Status: confirmed by repository probes.**

Steps:
1. Save an ordinary note titled `Invoice` with content
   `---\ndate: 2026-01-15\n---\nInvoice body`, without a journal flag.
2. Fetch it, then call `getOrCreateJournalEntry(DateTime(2026, 1, 15))`.
3. Repeat with `journal: false` and another date.

Expected: the ordinary note stays outside the journal and opening the journal
day creates or retrieves a separate journal entry.

Actual: the ordinary note has `isJournal == true`; opening January 15 returns
the invoice's ID. Explicit `journal: false` also becomes a journal note.
The ordinary note occupies the unique canonical day and appears in journal
queries. This can misroute Today/backfill into unrelated content.

Cause: `JournalMetadataService.extractJournalMetadata` returns a `journalDate`
even when `isJournal` is false. `AppDatabase.saveNote` consumes that date without
checking the flag, and `Note.isJournal` derives its value from the stored date.
Evidence: the first two failures in [adversarial-tests.txt](adversarial-tests.txt).

## JRN-002 — Nested YAML dates override the journal's top-level date

**Severity: high. Status: confirmed by metadata probe.**

Steps: extract journal metadata from:

```yaml
---
journal: true
date: 2026-01-15
source:
  date: 2020-02-20
---
Body
```

Expected: the canonical journal date is `2026-01-15`.

Actual: extraction returns `2020-02-20`. The parser trims indentation before
matching keys, treating nested properties as top-level keys. Saving content
without an explicit date argument can therefore index it under the wrong day.
Evidence: `nested YAML date must not overwrite top-level journal date` in
[adversarial-tests.txt](adversarial-tests.txt).

## JRN-003 — Journal frontmatter rewriting destroys nested date properties

**Severity: high. Status: confirmed for ensure and remove operations.**

Steps:
1. Pass frontmatter containing `source:\n  date: 2020-02-20` to
   `ensureJournalFrontmatter`, requesting canonical date `2026-01-15`.
2. Separately pass a journal frontmatter block containing the same nested
   property to `removeJournalFrontmatter`.

Expected: add/update/remove only the top-level journal-managed properties;
preserve the nested source date and its indentation.

Actual: ensure replaces the nested line with top-level `date: 2026-01-15`,
leaving an empty `source:`. Remove deletes the nested date entirely. This loses
user metadata, including when stripping journal properties from conflict copies.
Both rewrite loops flatten indentation before key matching.
Evidence: the two frontmatter-preservation failures in
[adversarial-tests.txt](adversarial-tests.txt).

## JRN-004 — Failed journal creation returns an unsaved ghost entry

**Severity: high. Status: confirmed with injected SQLite write failure.**

Steps:
1. On an isolated database, install a `BEFORE INSERT ON notes` trigger which
   executes `RAISE(ABORT, 'audit simulated write failure')`.
2. Request creation of a journal entry for an empty day.

Expected: creation reports the storage error so the UI can offer recovery.

Actual: `getOrCreateJournalEntry` completes successfully with a newly constructed
`Note` even though the insert failed. Its catch handles every error as a possible
concurrent-creation race, and its final fallback returns an unpersisted note if
the follow-up lookup finds nothing. The caller cannot distinguish this from a
saved entry. The trigger is a deterministic failure injection; a real disk-full
incident was not induced.
Evidence: `failed SQLite insert must report failure rather than return ghost
note` in [adversarial-tests.txt](adversarial-tests.txt).

## JRN-005 — Calendar preview opens trashed entries without restoration

**Severity: medium. Status: confirmed by widget probe and native UI.**

Steps:
1. Create a journal entry for November 24, 2026, then move it to Trash.
2. Open All Entries and select November 24 in the calendar.
3. Click the preview's title.

Expected: show a trashed-entry state and route opening through the existing
Restore & Open / Cancel confirmation.

Actual: the calendar has no active-entry dot, but its preview displays the
trashed note, snippet and `Show in All Entries`. Clicking the title opens its
editor directly with no restore prompt. It is still absent from the active
entry count. The selected-date stream includes trashed notes, while the preview
does not check `isTrashed` and navigates directly to the editor.

Evidence: [trashed preview](04-trashed-preview.png),
[editor reached from that preview](05-trashed-editor.png), the selected-trashed-day
probe failure, and the corresponding `trash` / `tap` records in
[native-results.jsonl](native-results.jsonl). The same behavior was observed
after trashing an already-selected day.

## JRN-006 — Month/year picker overflows short viewports

**Severity: medium. Status: confirmed by widget layout probe and native dialog.**

Steps: render the journal month/year picker at a 640 × 320 logical-pixel
viewport, as on a landscape phone or short desktop window.

Expected: controls remain reachable through fitting or scrolling.

Actual: Flutter reports a bottom `RenderFlex` overflow of **157 pixels**. The
dialog uses a fixed column with a non-scrolling, shrink-wrapped month grid and
footer. Its vertical content cannot fit the available height.
Evidence: `month picker must remain usable at phone landscape height` in
[adversarial-tests.txt](adversarial-tests.txt). Resizing the actual Linux window
to 640 × 320 and clicking its month heading also produced an overflow, **141
pixels** with the production app theme; see [native dialog](09-short-month-picker.png)
and its runtime exception in [native-results.jsonl](native-results.jsonl). The
different pixel counts reflect the test theme versus the production app theme.

## JRN-007 — Bengali dates leave day numbers in English

**Severity: low. Status: confirmed by widget probe and native UI.**

Steps: enable Bengali dates and open All Entries, with the calendar expanded
and journal timeline visible.

Expected: displayed date numerals follow the Bengali setting; stored canonical
keys remain ASCII.

Actual: month/year headings and weekday labels localize, but calendar days and
timeline day-number columns retain ASCII digits such as `24`. The calendar
renders `'$dayNumber'`; the timeline uses `formatDayTwoDigits` without locale
formatting.
Evidence: [native Bengali calendar](03-bengali-calendar.png) and `Bengali calendar
must use Bengali day numerals` in [adversarial-tests.txt](adversarial-tests.txt).

## JRN-008 — Renaming a coordinate-only place has no visible effect

**Severity: medium. Status: confirmed by grouping probe and native Rename flow.**

Steps:
1. Group an entry with blank address and coordinates `22.57, 88.36`.
2. Add a self-mapping alias for that place's match key with display name `Home`,
   as `PlaceAliasStore.rename` does, and regroup.

Expected: the place card displays `Home`.

Actual: it still displays `Unnamed place near 22.57, 88.36`. Labeled grouping
consumes aliases, but `_groupByRadius` receives no alias map and always generates
its display label. The Places UI offers Rename for these cards and writes an
alias which the grouping path ignores. This also warrants checking merge
behavior for coordinate-only places; that broader case is not yet verified.
Evidence: `coordinate-only place rename must affect displayed group` in
[adversarial-tests.txt](adversarial-tests.txt). In the native Places screen,
long-pressing the coordinate-only card, choosing Rename, typing `Home` using
native keyboard events and submitting Rename leaves its generated label
unchanged. See [typed name](16-coordinate-rename-input.png),
[unchanged card](13-coordinate-rename.png) and the final rename records in
[native-results.jsonl](native-results.jsonl). The card splits its coordinate
label into `Unnamed place near 22.57` and `88.36`; the long-press target in the
replay is the first text component.

## JRN-009 — Spring DST change merges visits separated by 31 calendar days

**Severity: low. Status: confirmed in an America/New_York Dart test process.**

Steps: run the visit-gap probe under `TZ=America/New_York`, clustering entries
dated March 1 and April 1, 2026, with the default 30-day visit-gap threshold.

Expected: two visits, because the dates are 31 calendar days apart.

Actual: one visit. Spring DST makes the elapsed duration 30 days and 23 hours;
`date.difference(previous).inDays` truncates it to 30. Calendar-date grouping
therefore incorrectly joins visits across the threshold. The same probe passes
in Asia/Kolkata, where the elapsed duration is exactly 31 days.
Evidence: [DST probe output](dst-probe.txt). Run with
`TZ=America/New_York flutter test --no-pub --reporter expanded test/journal/journal_audit_probe_test.dart --plain-name '31 calendar day gap must split visits across DST'`.

## JRN-010 — Show in All Entries jumps to the wrong month with wrapped titles

**Severity: medium. Status: confirmed in the native 1,005-entry archive.**

Steps:
1. Populate 1,000 consecutive journal days ending November 24, 2026, plus the
   older historical entries. Use titles long enough to wrap to two lines.
2. At a 700 × 700 logical-pixel window size, open All Entries, expand its calendar
   and select June 15, 2024.
3. Click `Show in All Entries` in the selected-day preview.

Expected: the June 15 tile scrolls into view and is highlighted.

Actual: the viewport lands around **December 8–2, 2024**; June 15 is not visible.
The same jump passed with short titles. `_jumpToEntry` estimates every preceding
item as 80 pixels, while the wrapped-title tiles in this replay measure 95 or
114 pixels. Its second visibility check reuses the `targetKey` captured before
lazy construction, so a previously unbuilt target is never looked up again.

Evidence: [selected June date](14-long-title-preview.png),
[incorrect December destination](15-long-title-jump.png), and the `longTitles`,
June selection, `tap` and subsequent snapshot records in
[native-results.jsonl](native-results.jsonl). The snapshot records exact visible
tile dates and their rectangles; the captured target date remains `2024-06-15`.

## Passing additional checks and current limits

- 100 concurrent requests for one date return one persisted canonical entry;
  the journal-integrity query finds no duplicates.
- Trash/restore preserves the canonical ID and saved reflection.
- **76,336** valid calendar dates, spanning 1896–2104 and leap-century boundaries,
  round-trip through canonical date formatting and parsing.
- In the Linux window, native keyboard input appended `Native journal saved.`;
  leaving and reopening the entry retained it. See
  [saved/reopened editor](06-saved-reopened.png).
- The native window renders seven prior same-day entries and groups 35 located
  entries into two Places cards. Native drill-in opens Kyoto's journal entries.
  After the larger seed, Places groups 1,000 located entries into three cards,
  including the coordinate-only entry used for JRN-008. Native multi-place merge
  and historical pagination were not completed; their existing focused widget
  and provider tests passed in the 207-test gate.
- A native attempt to seed 1,000 entries lost the VM connection and the app
  process exited. There is no captured crash cause or completed seed count, so
  this is an unresolved stress observation, not a confirmed application bug or
  a passing test of incremental insertion. A fresh replay batching the seed
  into one SQLite transaction completed with **1,005 entries** (1,000 consecutive
  days plus five non-overlapping historical dates). The seed plus VM snapshot
  took 32.2 seconds in debug mode; this is setup time, not a rendering benchmark.
- On that 1,005-entry archive, `Show in All Entries` reached June 15, 2024 and
  made its timeline tile visible. See [old-date preview](11-old-date-preview.png)
  and [jump destination](12-timeline-jump.png). This pass uses short titles;
  wrapped titles instead reproduce JRN-010.
- One Linux `receive_sharing_intent/events-media` `MissingPluginException` occurs
  during app startup, before journal actions. It remains in the raw error records
  and is not counted as a journal finding. Secure-storage keyring-unlock warnings
  also occurred. Startup/bootstrap equivalence with the normal entrypoint has
  not been established, so no production startup conclusion is claimed.
- Existing place-alias-store test fixtures also produce Drift warnings when a
  second provider container instantiates a database through the default key
  manager. Thus the repository's zero-warning test requirement is not met on the
  unchanged source, despite all 207 baseline assertions passing. Fixing that
  fixture is deferred with the user's request to document without fixing.

Physical Android/iOS devices, CJK input methods, midnight rollover, real GPS and
weather requests, cloud synchronization and release-mode timing were not tested.
No restart-durability or physical-device acceptance is inferred from this audit.
The isolated test windows were closed after verification.

## Evidence and replay

- [Initial analysis](flutter-analyze.txt), [final analysis](flutter-analyze-final.txt),
  [207-test focused gate](relevant-tests.txt), [adversarial results](adversarial-tests.txt)
  [DST results](dst-probe.txt) and [isolated fixture warnings](place-alias-fixture-warnings.txt).
- [Adversarial test source](adversarial_probe_test.dart.txt),
  [native harness source](native_harness.dart.txt), [VM/keyboard driver](native_driver.py)
  and [raw VM action results](native-results.jsonl).
- [Incremental-window runtime log](native-runtime-incremental.txt) and
  [batched-replay runtime log](native-runtime-batched.txt). Ephemeral VM session
  codes are replaced with `VM_SESSION` in committed evidence. The action log
  retains unsuccessful selector attempts and taps outside the viewport; these
  attempts are not counted as bugs or successful interactions. Later records
  and screenshots show the corrected, successful reproductions.
  Trailing log whitespace is normalized for Git's whitespace check.

The executable probes are archived as `.dart.txt` so intentional failures and
the VM test extension are not added to application builds or ordinary CI tests.
To replay the 14 adversarial cases from the repository root:

```sh
cp handoff/audits/journal-2026-11-24/adversarial_probe_test.dart.txt test/journal/journal_audit_probe_test.dart
flutter test --no-pub --reporter expanded test/journal/journal_audit_probe_test.dart
TZ=America/New_York flutter test --no-pub --reporter expanded test/journal/journal_audit_probe_test.dart --plain-name '31 calendar day gap must split visits across DST'
rm test/journal/journal_audit_probe_test.dart
```

Both test commands deliberately fail on the audited application revision. The
207 existing tests remain passing; application behavior was not changed to make
the new reproduction assertions pass.

For native replay, copy `native_harness.dart.txt` to
`tool/journal_audit_native.dart`. Create fresh config/data/cache directories,
set `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME` to them, and launch:

```sh
flutter run -d linux -t tool/journal_audit_native.dart --no-pub --disable-dds --host-vmservice-port=38919
```

Capture that command's output in a runtime log and pass its path to
`native_driver.py`, whose module docstring shows the command format. `seed`
uses one transaction; `longTitles` changes the synthetic archive to wrapped
titles; `coordinate` adds the coordinate-only location. Dates in the seed are
relative to the device clock, so adjust the historical selection when replaying
on another day. Remove the temporary entrypoint when finished.

No production Dart, schema, synchronization or native-platform source changes
are included in this branch. Only the audit artifacts and handoff documentation
are committed.
