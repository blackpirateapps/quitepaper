# Journal audit, second pass — November 24, 2026

Original audit status: **complete; 10 additional confirmed bugs, 20 cumulative.**

Follow-up: JRN-001–010 from the first pass are now fixed; the ten second-pass
findings below (JRN-011–020) remain open. See [fix progress](../README.md#fix-progress).

This extends the [first audit](../README.md), preserving its ten findings as
JRN-001–010. Application source remains `12c49b3`; the starting audit commit is
`b280a92` on `audit/journal-rigorous-2026-11-24`. New findings are written here as
they are confirmed. Synthetic data and isolated databases are used throughout.

The eleven additional edge probes have **three passes and eight failures**.
A separate weather-race widget probe fails its preservation assertion. All
**72 existing focused tests pass** in this pass, without warnings in their logs.
See [edge results](edge-probes.txt), [weather race](metadata-race.txt),
[58 focused journal tests](relevant-tests.txt) and
[14 existing Properties tests](properties-tests.txt). These totals describe this
pass's runs; many of the 58 journal tests overlap the first pass's 207-test gate.

## JRN-011 — Merging a previously merged place splits its members apart

**Severity: medium. Confirmed by store/grouping probe and native UI.**

Steps:
1. Merge Alpha and Beta into a place named Trip.
2. Select Trip and Gamma, then merge them into Journey.
3. Regroup the three original entries using the updated alias map.

Expected: Journey contains all three entries.

Actual: Alpha and Beta remain in a separate Trip group; Gamma alone becomes
Journey. `PlaceAliasStore.merge` rewrites the selected canonical keys but does
not redirect existing aliases pointing to those keys. The grouper resolves only
one alias hop. This breaks repeated merges, a normal action on the Places screen.
Evidence: `merging an already merged place retains every constituent` in
[edge-probes.txt](edge-probes.txt).
Native replay selected Alpha/Beta, typed Trip and submitted the modal, then
selected Trip/Gamma and submitted Journey. It leaves **Journey: 1 entry** and
**Trip: 2 entries**. See [first merge](03-first-merge.png),
[split after second merge](04-repeated-merge-split.png) and the raw alias maps
in [native-results.jsonl](native-results.jsonl). Early attempts selected the
underlying toolbar's duplicate Merge label; the successful records tap the
modal button's recorded rectangle and retain typed names in the field snapshots.

## JRN-012 — Older asynchronous alias decoding rolls back newer state

**Severity: medium. Confirmed with controlled decode completion order.**

Steps: emit two repository row snapshots, complete the second snapshot's
asynchronous decode with `New name`, then finish the older decode with `Old name`.

Expected: the newer snapshot remains authoritative.

Actual: store state changes back to `Old name`. The asynchronous `watchRows`
listener assigns every decoded map without sequencing, cancellation or a version
check. Slow decryption of an older snapshot can undo the visible result of a
newer rename/merge until another database emission happens. This probe controls
decode timing at the repository boundary; it does not claim a measured network
or cryptographic timing incident.
Evidence: `encrypted alias snapshots cannot roll back after newer decode
completes` in [edge-probes.txt](edge-probes.txt).

## JRN-013 — Failed place-alias writes disappear on reopening with no recovery

**Severity: high. Confirmed with real SQLite failure injection.**

Steps:
1. Use an unlocked alias repository backed by an isolated SQLite database.
2. Install a `BEFORE INSERT ON place_aliases` trigger that aborts writes.
3. Rename a place to Home, then remove the trigger so writes can succeed again.
4. Dispose and reopen the alias store against the same database.

Expected: a recoverable error or retained pending write preserves the user's
mutation; recovery must not silently discard the action.

Actual: the optimistic in-memory mutation is not persisted and Home is absent
after reopening. `_persist` swallows the database exception, retains no retry
record and does not report failure to the UI. Its comment says rows retry next
cycle, but no dirty row was written for sync to retry. Repeated multi-key merge
writes are also not transactional, though partial-merge recovery is not yet
separately tested. Failure injection models an insert failure, not an actual
disk-full event.
Evidence: `failed alias write must retry after database recovers` in
[edge-probes.txt](edge-probes.txt).

## JRN-014 — Equivalent Unicode place names create duplicate cards

**Severity: low. Confirmed by grouping probe.**

Steps: group entries with addresses `São Paulo, Brazil` and
`Sa\u0303o Paulo, Brazil` (precomposed versus combining-tilde spelling).

Expected: both canonical Unicode spellings of the same city form one place.

Actual: two groups. `normalizeKey` maps precomposed accented letters, but leaves
combining marks intact. Visually identical names from different text sources
therefore get different keys despite the normalization contract's diacritic
folding. Evidence: `canonically equivalent Unicode place names must group
together` in [edge-probes.txt](edge-probes.txt).

## JRN-015 — A cluster spanning the antimeridian is labeled near Greenwich

**Severity: medium. Confirmed by coordinate-grouping probe.**

Steps: group blank-address entries at latitude 10 with longitudes `179.999` and
`-179.999`. They are approximately 219 meters apart, within the 1,500-meter radius.

Expected: a single unnamed place labeled near longitude ±180.

Actual: the label is `Unnamed place near 10.00, 0.00`, roughly 17,791 km from
the entries. Cluster distance uses haversine correctly, but the longitude
centroid uses an ordinary arithmetic mean across the ±180 wrap. The resulting
place identity and displayed location are geographically wrong.
Evidence: `coordinate cluster centroid stays near the antimeridian` in
[edge-probes.txt](edge-probes.txt).

## JRN-016 — Rounded coordinate keys merge separate proximity clusters

**Severity: medium. Confirmed by coordinate-grouping probe.**

Steps: group blank-address entries at `(1.0051, 103.0051)` and
`(1.0149, 103.0149)` using the default 1,500-meter radius.

Expected: two places; haversine distance exceeds the configured radius.

Actual: one place with both entries. Proximity clustering initially separates
them, but both centroid keys round to `~coord:1.01,103.01`. Inserting both into
the accumulator map joins them again, overriding the distance decision.
Evidence: `rounded coordinate keys must not join clusters beyond the radius`
in [edge-probes.txt](edge-probes.txt).

## JRN-017 — Missing weather measurements become invented clear, 0°C weather

**Severity: low. Confirmed with a mocked HTTP response.**

Steps: return HTTP 200 and `{"current":{}}` from the injected weather client.

Expected: report malformed/incomplete weather, leaving existing metadata intact.

Actual: `WeatherService.fetchWeather` returns `JournalWeather(0.0°C, Clear sky,
code: 0)`. Missing temperature and WMO code default to zero, so an incomplete
response becomes plausible but fabricated journal metadata. A complete weather
response and an HTTP 503 response both pass their respective positive/error
checks. No claim is made that the live weather API returned this payload.
Evidence: `incomplete current weather must not invent sunny zero Celsius` in
[edge-probes.txt](edge-probes.txt).

## JRN-018 — Today and On This Day remain on yesterday after midnight/resume

**Severity: medium. Confirmed in the native app through its Dart VM.**

Steps:
1. Open the isolated app on November 24 and visit On This Day.
2. Advance only that process's wall clock to November 25, 00:05.
3. Deliver inactive/resumed lifecycle transitions and inspect the app again.

Expected: Today status and historical queries/headings refresh for November 25.

Actual: `DateTime.now()` and the canonical date helper report November 25, but
`todayJournalDateProvider` still returns `2026-11-24`, the historical reference
remains November 24, and On This Day still displays November 24. The providers
cache clock values without a midnight timer or resume invalidation. Opening
Today uses a fresh clock in the service, which can disagree with the cached
Today-status subscription.

Evidence: [before midnight](01-before-midnight.png),
[after midnight/resume](02-after-midnight-resume.png) and matching `clock`,
`actualToday`, `cachedToday` and `cachedHistoryReference` fields in
[native-results.jsonl](native-results.jsonl).
The [clock shim](clock_shift.c) shifts wall time only inside the test process
and its child tools; monotonic time and the machine's system clock are unchanged.
This is a controlled forward-clock/resume reproduction, not an overnight wait.

## JRN-019 — Adding an older backfill fails to reveal older memories

**Severity: medium. Confirmed by repository/provider integration and native UI.**

Steps:
1. With reference date November 24, 2026, open historical memories with only a
   2025 journal entry. The initial five-year window has no older years to load.
2. Backfill November 23, 2010, which belongs to the historical week but is not
   an exact November 24 match.
3. Return to the historical view in the same provider scope.

Expected: `Show older memories` becomes available for the newly backfilled year.

Actual: the repository correctly reports earliest year 2010, but
`historicalWeekProvider.hasMoreOlderYears` stays false. The cached
`earliestJournalYearFutureProvider` does not watch database changes and is not
invalidated by journal creation. The added memory remains outside the five-year
query window with no control to load it until the provider is refreshed/recreated.
Evidence: `older backfill must enable loading older memories without restart`
in [edge-probes.txt](edge-probes.txt).
Native replay starts with cached/database year 2025. Backfilling November 23,
2010 changes the database year to 2010, but leaves the cached year at 2025 and
`hasMoreOlderYears` false. See [before backfill](08-history-before-backfill.png),
[after backfill](09-history-after-backfill.png) and the `historyStatus` VM records.

## JRN-020 — Finishing a weather fetch overwrites edits made while it was pending

**Severity: high. Confirmed by the real Properties widget and native editor.**

Steps:
1. Open a journal's expanded Properties with an existing coordinate location.
2. Click Fetch Weather and hold its HTTP response pending.
3. Update the live editor document while the request is pending.
4. Complete the response with valid temperature and weather-code measurements.

Expected: add weather to the latest document, preserving the intervening edits.

Actual: the Properties callback submits weather plus the old body, dropping the
text added during the request. `_fetchWeather` snapshots `widget.rawDocument`
before awaiting network work and later applies metadata to that stale snapshot.
The reproducer verifies the production button reached the delayed client and
that valid weather was added, then fails because the concurrent body edit is
missing. It does not call a rewritten metadata implementation.
Evidence: [weather race output](metadata-race.txt). An initial smaller-widget
attempt also encountered a layout overflow; that incidental layout issue is
not yet counted as a separate confirmed bug.
In the native app, the real Fetch Weather button reached a delayed mock HTTP
client once. Hyprland keyboard input appended ` TEST` while it was pending;
completing valid weather removed ` TEST` from the visible body. See
[pending edit](05-weather-pending-edit.png),
[lost edit on completion](06-weather-completion-lost-edit.png) and the matching
field snapshots/request count in [native-results.jsonl](native-results.jsonl).
No live weather or GPS request was made for this reproduction.
Leaving and reopening the journal still shows the body without ` TEST`; see
[reopened entry](07-weather-lost-edit-reopened.png).

## Passing checks and current limits

- Complete mocked weather responses retain measured temperature and WMO code;
  HTTP errors surface as `WeatherFetchException`.
- A journal entry's canonical ID and saved body survive closing its SQLite
  connection and opening a fresh connection to the same temporary file. This
  strengthens the first pass's editor reopen coverage without claiming an
  application-process restart or mobile-device durability test.
- Native replay confirms repeated merges, midnight/resume staleness, older-year
  backfill staleness, and weather-related text loss, including reopening afterward.
- Final static analysis is clean. The clock shim also builds with
  `cc -Wall -Wextra -Werror -shared -fPIC ... -ldl` without warnings.
- The new disk-durability probe initially kept an unrelated in-memory database
  open, which triggered Drift's multiple-database diagnostic. Its final fixture
  closes that unused database before opening file connections; the final edge
  log contains no warnings. No application code or global warning suppression
  was changed. The first pass's existing alias-fixture warnings remain unresolved.
- The initial weather widget attempt at 800-pixel width showed a 54-pixel
  horizontal overflow under the test font plus a secondary inspector error.
  Its [initial log](metadata-race-initial.txt) is retained. The race was isolated
  at 1,400 pixels, and the native 700-pixel production-theme reproduction had
  no new rendering errors. The initial layout diagnostic is not counted as a
  separate application bug.
- The isolated Linux window still emits the previously recorded startup sharing
  plugin exception and keyring warnings. They are not new journal findings.
- Physical mobile devices, live GPS/weather, real cloud delivery/decryption
  latency and an actual overnight wait remain untested. The process clock was
  advanced for the rollover test. The previous unresolved incremental-seed
  process exit was not reclassified or claimed fixed in this pass.

## Evidence and replay

Production source, schema and protocols are unchanged. The temporary test
entrypoints and intentional-failure tests are archived as `.dart.txt`; ordinary
CI does not run them. The native window was closed and its clock offset reset
to zero before finishing.

- [Edge probe source](edge_probe_test.dart.txt) and
  [metadata-race probe source](metadata_race_probe_test.dart.txt). Copy them to
  `test/journal/journal_round_two_probe_test.dart` and
  `test/journal/journal_metadata_race_probe_test.dart`, then run only those files
  with `flutter test --no-pub --reporter expanded ...`. Remove the copies afterward.
  On this revision the eleven edge cases produce 3 passes/8 failures and the
  separate race case fails, exposing the documented bugs.
- [Native harness](native_harness.dart.txt), [VM/native-keyboard driver](native_driver.py),
  [runtime log](native-runtime.txt) and [VM action records](native-results.jsonl).
  Copy the harness to `tool/journal_audit_native.dart` to launch an isolated
  window as in the [first pass's replay instructions](../README.md#evidence-and-replay).
  Its new actions include `mergeFixture`, `historyFixture`, `olderBackfill`,
  `historyStatus`, `deferWeather`, `completeWeather` and `resume`. The weather
  actions intercept HTTP in the gesture's zone while using the production UI.
- For clock replay, compile [clock_shift.c](clock_shift.c), put `0` in a fresh
  offset file, and launch the isolated app with `LD_PRELOAD` pointing to the
  compiled library and `QP_AUDIT_CLOCK_FILE` pointing to that file. After opening
  historical memories, write a forward offset in seconds which crosses the
  next local midnight, invoke `resume`, then inspect `actualToday`, `cachedToday`
  and `cachedHistoryReference`. Restore `0` afterward. The runtime log's ephemeral
  VM session codes are redacted; the driver reads live codes from a fresh log.
- Raw action records retain failed duplicate-label selector attempts before the
  successful native merge replay. Only the successful reproductions and their
  corresponding snapshots support the confirmed findings.
