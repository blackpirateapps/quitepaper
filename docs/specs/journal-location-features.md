# Journal Location Features — Implementation Spec

> Status: **Approved design, not yet built.** Author: product brainstorm, 2026-10-09.
> Audience: a coding agent picking this up cold in a new session. Read §0–§2 before touching any feature section.

---

## 0. Scope & Guiding Constraints

### What this delivers
Four independent, additively-shippable features that put the already-captured journal
`location` frontmatter to use:

1. **Timeline dateline** — a quiet metadata line on each All Entries timeline tile.
2. **Calendar travel marker** — distinguish days whose entry is `moment: travel` in the month grid.
3. **On This Day place** — append the place to each historical entry's "years ago" line.
4. **Places page** — a new sidebar surface that browses journal entries grouped by place.

### Explicitly OUT of scope (decided, do not build)
- **No maps / map tiles anywhere.** Map tiles leak the viewport to a tile server on every
  pan, which conflicts with the app's zero-knowledge identity. Pins/tiles are deferred indefinitely.
  (`LocationService.openInMaps` for a *single* entry already exists and may stay; do not add
  aggregate map views.)
- **No location-based calendar marker.** The calendar marker keys off `moment: travel` ONLY,
  not off any home/away location inference (see §4-vs-§5 note below).
- **No automatic location inference** for backfill (no reading photos, OS location history, etc.).
  Backfill is manual only.

### Design philosophy (hard constraints — violating these fails review)
- Warm paper aesthetic, a **single accent color** (`colors.accent`, a terracotta red). Do not
  introduce a second hue or a multi-color legend.
- Calm and editorial: generous whitespace, small-caps section labels, restrained type.
  Prefer shape/weight contrast over color; prefer text over chrome.
- Everything location-related is **opt-in / degrades gracefully**: when a note has no location,
  no moment, etc., the UI shows nothing extra rather than an empty placeholder.
- Offline-first, zero-knowledge. No new outbound network calls beyond the existing OSM
  reverse-geocode path in `LocationService`.

---

## 1. Existing Architecture (ground truth)

### 1.1 Frontmatter shape
Journal entries are ordinary Markdown notes. Metadata lives in YAML frontmatter at the top of
`note.content`. Canonical serialized shapes (as written by `FrontmatterEditorHelper`):

```yaml
---
journal: true
date: 2026-10-09
moment: travel          # one of JournalMoment keys (ordinary, travel, work, family,
                        #   social, health, creative, celebration, difficult, reflection)
mood: 7                 # integer 1..10
activities: [running, reading]
location:
  address: "Kolkata, West Bengal, India"
  latitude: 22.5726
  longitude: 88.3639
weather:
  temperature: 24.0
  condition: "Cloudy"
  code: 3
---
```

Notes:
- `journal: true` + `date:` are managed by `JournalMetadataService`. Everything else is managed
  by `FrontmatterEditorHelper`.
- The parser is tolerant of key aliases (e.g. `lat`/`latitude`, `lng`/`lon`/`longitude`,
  `name`/`address`) and missing geocode (address may be empty with coords, or coords may be `0.0`).
- `JournalLocation.isEmpty` ⇔ blank address AND lat==0 AND lng==0. Treat such a note as having
  **no location**.

### 1.2 Key files
| Concern | File |
| --- | --- |
| Location model | `lib/core/location/location_models.dart` (`JournalLocation`) |
| Location acquisition + reverse geocode + openInMaps | `lib/core/location/location_service.dart` |
| Frontmatter parse + surgical read/write of every key | `lib/features/editor/application/frontmatter_editor_helper.dart` |
| Parsed frontmatter doc model | `lib/features/editor/domain/frontmatter_document.dart` |
| Journal/date frontmatter | `lib/core/journal/application/journal_metadata_service.dart` |
| Moment / Mood / Weather value types | `lib/core/journal/domain/journal_moment.dart`, `journal_mood.dart`, `journal_weather.dart` |
| Cached list/display metadata | `lib/features/notes/domain/note_metadata_extractor.dart` (`NoteMetadata` + LRU cache) |
| All Entries timeline tile | `lib/features/journal/presentation/widgets/journal_timeline_tile.dart` |
| All Entries view | `lib/features/journal/presentation/journal_all_entries_view.dart` |
| Calendar grid | `lib/features/journal/presentation/widgets/journal_calendar_view.dart` |
| On This Day view | `lib/features/journal/presentation/on_this_day_view.dart` |
| Sidebar nav | `lib/features/sidebar/presentation/sidebar_view.dart` |
| Nav destinations enum | `lib/features/notes/application/notes_provider.dart` (`AppDestination`, `WorkspaceContextType`) |
| Journal stream providers | `lib/features/journal/application/journal_providers.dart` |
| Journal repo/service | `lib/features/journal/application/journal_service.dart`, `lib/features/notes/data/notes_repository.dart` |
| Settings persistence | `lib/features/settings/application/default_settings_provider.dart`, `settings_provider.dart` (SharedPreferences) |
| Default Settings UI | `lib/features/settings/presentation/default_settings_screen.dart` |

### 1.3 Data & performance notes
- `Note` already carries `journalDate`, `tags`, `displayTitle`, `previewSnippet`,
  `isPasswordProtected`, `createdAt`, `updatedAt`.
- Frontmatter metadata (location/moment/etc.) is NOT in a DB column; it lives in `note.content`.
- `NoteMetadataExtractor.extract(note)` is the hot path for lists; it is LRU-cached (max 500) and
  keyed on content hash. **Any per-tile location read MUST go through this cache**, never re-parse
  frontmatter in `build()`.
- The calendar's "has entry" set comes from `journalDatesForMonthStreamProvider(month)` →
  `watchJournalDatesForMonth` (a `Set<String>` of `YYYY-MM-DD`). This is DB-level and does not
  know about moments.

---

## 2. Shared Foundations (build these FIRST — all features depend on them)

### 2.1 Extend `NoteMetadata` with cached journal metadata
Add to `NoteMetadata` (and populate in `NoteMetadataExtractor.extract`):
- `JournalLocation? location`
- `String? moment` (normalized key)
- `int? mood`
- `JournalWeather? weather`

Populate by reusing `FrontmatterEditorHelper.parse(note.content)` (it already parses all of these)
rather than writing new regexes. Guard with `note.isPasswordProtected` (do not parse/expose
metadata for locked notes — mirror the existing nulling of `attachmentSummary`/`thumbnailData`).
Keep the existing cache-key scheme; these fields ride along for free on cache hits.

Rationale: the dateline (Feature 1), Places grouping (Feature 4), and any moment/weather display
all read from one cached place; no feature re-parses frontmatter per frame.

### 2.2 Place normalization + clustering (`JournalPlace`)
Create a small domain service, e.g. `lib/core/journal/domain/journal_place.dart` +
`lib/core/journal/application/place_grouping_service.dart`.

**Grouping is label-first, radius-second — NEVER exact-coordinate match** (GPS jitter guarantees
exact coords never repeat):

1. **Primary key = normalized place label** derived from `JournalLocation.address`. Normalize by:
   - taking the **city/locality token** (and region/country for the coarser granularities),
   - lowercasing, trimming, collapsing whitespace, stripping diacritics for the match key only
     (keep a pretty display label separately),
   - applying any user merge aliases (§2.3) and known equivalents.
2. **Radius fallback** for entries whose geocode failed or disagrees: cluster by coordinate
   proximity using haversine distance. Suggested thresholds (device uses `LocationAccuracy.medium`):
   - **spot** tier ≈ 150–300 m (same building/block),
   - **neighborhood** merge ≈ 1–2 km.
   Default the Places page to **city-label** grouping; radius clustering only names/merges
   otherwise-unlabeled coordinate blobs ("Unnamed place near 22.57, 88.36").
3. **Granularity** is a user-facing toggle: **City / Region / Country** (city default). Country view
   is the travel-history lens ("India 240 · Nepal 12 · UK 3").

A `JournalPlace` aggregate should expose: canonical display name, match key, granularity level,
entry count, date span (first→last), and the list of member note ids.

### 2.3 Manual merge / alias store (user-editable)
Users can **manually merge** two or more place clusters into one and pick the canonical name; they
can also rename. Persist a merge/alias map (key → canonical key + display name). This is user
intent about their own vault, so **persist it with the synced vault data**, not device-local
SharedPreferences (so merges carry across devices). Define a small synced settings/document record
for it; follow the backup/sync patterns used by other journal metadata. Merges must be reversible
(unmerge) and must never mutate note frontmatter — they are a presentation-layer mapping only.

### 3. Feature 1 — Timeline Dateline (All Entries tiles)

**Where:** `journal_timeline_tile.dart`, inside the right-hand content `Column`, as a new row placed
**after** the preview snippet (lines ~221–233) and **before** the tags `Wrap` (lines ~236–251).

**What it shows:** one quiet metadata line, built from `NoteMetadata` (§2.1). Compose only the parts
that exist, joined by ` · `:
- place (from `location`, city-level display) — e.g. `Kolkata`
- weather glyph + temp (from `weather`) — e.g. `☁ 24°`
- mood indicator (from `mood`) — optional; keep subtle

Example rendered line: `Kolkata · ☁ 24°`. If none exist, render nothing (no SizedBox, no dot).

**Styling:** `AppTypography.caption`, `color: colors.textSecondary` (or `textTertiary` to sit quieter
than the preview), ~11.5–12px, single line, `TextOverflow.ellipsis`. A small leading location glyph
(`PhosphorIconsRegular.mapPin`) at ~12px is allowed but keep it monochrome `textTertiary`.

**Toggle:** gated by a Default Settings boolean **"Show place & weather on entries"** (default ON).
When OFF, the line is never rendered. Persist via `DefaultSettings` (SharedPreferences).

**Tap (optional, nice-to-have):** tapping the place segment navigates to that place in the Places
page (Feature 4). Only wire this once Feature 4 exists.

**Constraints:** must not increase tile height when absent; must not re-parse frontmatter (read
`NoteMetadata` only); respect `isPasswordProtected` (locked notes show no dateline).

---

## 4. Feature 2 — Calendar Travel Marker

**Decision:** mark ONLY entries whose `moment == 'travel'`. Do **not** differentiate the other nine
moments (ordinary/work/family/etc.) — ten markers would require a legend and a multi-color palette,
which breaks the calm single-accent design. Do **not** use any location/home-away inference here.

**Where:** `journal_calendar_view.dart`, the per-day entry dot (lines ~392–400). Today the dot is a
3.5px filled circle in `colors.accent` when `hasEntry`.

**Rendering rule for the dot:**
- no entry → transparent (unchanged)
- entry, not travel → filled accent circle (unchanged, the baseline)
- entry, `moment: travel` → **distinct treatment via shape/weight, not a new color**. Preferred:
  a small **hollow ring** (accent stroke, transparent fill, same ~4px footprint). Acceptable
  alternatives if the ring reads poorly at size: a slightly larger filled dot, or a tiny
  `PhosphorIconsRegular.airplane` glyph under the number. **Keep it in `colors.accent`.**

**Data:** read `travelDatesForMonthProvider(visibleMonth)` (§2.4) alongside the existing
`journalDates` set. A date is travel iff it's in both sets.

**Graceful degradation:** entries with no moment, or `moment` ≠ travel, render the plain dot. Never
show a marker on a day with no entry. Update the Semantics label to append `', travel'` when applicable.

---

## 5. Feature 3 — On This Day Place

**Where:** `on_this_day_view.dart`. Each historical entry currently shows a date + a relative-year
chip (e.g. `October 9, 2020` · `6 years ago`). Append the entry's place to that line.

**Format:** `October 9, 2020 · 6 years ago · Mumbai` — place segment from `NoteMetadata.location`
(city-level display), styled as the existing muted metadata (`colors.textSecondary`, caption).

## 6. Feature 4 — Places Page

A new journal surface that browses journal entries grouped by place. Mirrors the structure and tile
reuse of All Entries.

### 6.1 Navigation
- Add `places` to `AppDestination` and `WorkspaceContextType` (`notes_provider.dart`), and wire it
  through the same places `onThisDay`/`allJournalEntries` are wired: `notes_screen.dart` (phone +
  tablet split layouts), `notes_query_provider.dart`, `note_empty_state.dart`.
- Add a **"Places"** row to the JOURNAL section of `sidebar_view.dart`, directly below
  "On This Day". Icon suggestion: `PhosphorIconsRegular.mapPin` (regular/fill mirror the existing
  selected-state icon-swap pattern used by the other journal rows).

### 6.2 Top level — place list
A scrollable list of **place cards** (typographic, NO map thumbnail). Each card shows:
- **Place name** (primary) + country/region (secondary), at the current granularity.
- **Entry count**.
- **Date span** — e.g. `2019 – 2026`, or `Oct 2024` for a single-visit place.
- Optional: dominant moment or a one-line latest snippet. Keep it quiet.

Header controls (match the editorial header style of On This Day / All Entries):
- **Granularity toggle**: City / Region / Country (default City). See §2.2.
- **Sort toggle**: Frequency (most-written first) / Recency (most recent entry first) /
  First-seen (chronological discovery — good for travel) / A–Z. Default **Recency** or **Frequency**.
- Reuse the existing search affordance if cheap; otherwise defer.

### 6.3 Drill-in — a single place
Tapping a card opens that place's entries as the **existing All Entries timeline**
(`JournalTimelineTile`), reverse-chronological, filtered to the place's member notes.
- Header: place name, entry count, date span.
- **Sub-group by visit**: cluster consecutive date ranges into visits and show them as sub-headers
  (e.g. `October 2024 · 5 entries`, `March 2026 · 2 entries`) so revisits are legible.
- Per-entry `openInMaps` (single entry) is allowed here since it's not an aggregate map.

### 6.4 Entries WITHOUT location — **silent exclusion (chosen) + backfill**
Decision (chosen option): **unlocated entries are silently excluded from Places.** Places is a
*lens*, not the canonical archive — **All Entries remains the home of every entry**, so nothing is
lost or hidden from the user's primary flow.
- **Do NOT** add a "Without location" / "Unknown" bucket. (Considered and explicitly rejected.)
- Because location capture is new and most historical entries predate it, the located set will start
  small. **Show a calm learning/empty state** (not a wall of Unknown) when the located set is empty
  or tiny, reusing the On This Day empty-state voice, e.g. *"Places you write from will gather here."*
  Reuse the empty-state tone/components already in `note_empty_state.dart` / On This Day.
- The path to give an old entry a location is the **backfill nudge** (§6.5), plus the manual place
  picker it opens.

### 6.5 Backfill nudge (exact behavior — build to spec)
**Purpose:** let the user retroactively add a place to a journal entry that has none. Manual only —
never infer location automatically.

**Trigger:** when a journal entry **without** a location is opened/viewed, surface a subtle, inline,
dismissible nudge (not a blocking modal) offering to add a place. Do not nudge on non-journal notes,
on locked notes, or when the global setting (below) is OFF, or when this specific day is locally
suppressed.

**The nudge offers a place picker** (its primary action) that lets the user choose from their known
places (§2.2), type a custom place, or use current device location via `LocationService`
(with the caveat that "now" may differ from where the entry was written — current location is a
convenience, not a default). Writing the place calls
`FrontmatterEditorHelper.updateLocation(...)` on the note content; then invalidate
`NoteMetadataExtractor` for that note id.

**Buttons / actions (all four required):**
1. **Add place** — primary; opens the picker described above.
2. **Not now** — dismiss for now; the nudge may appear again later (no state persisted).
3. **Don't ask again for this day** — suppress the nudge **for this entry's date only**, remembered
   **locally** (device-local SharedPreferences; do NOT sync). Reopening the same day's entry will not
   nudge. Store as a set of suppressed `YYYY-MM-DD` strings.
4. **Don't ask again** — turns OFF the global setting (§6.6) automatically, AND shows a brief tooltip
   / snackbar: *"You can change this later in Settings."* After this, no entry nudges anywhere.

### 6.6 Settings
Add to **Default Settings** (`default_settings_screen.dart` + `default_settings_provider.dart`,
persisted via SharedPreferences):
- **"Suggest adding a place to past entries"** — boolean, default **ON**. This is the master switch
  the "Don't ask again" button flips to OFF.
- (Feature 1's **"Show place & weather on entries"** toggle also lives here.)

## 7. Persistence Summary

| Data | Where | Synced? | Notes |
| --- | --- | --- | --- |
| Note location/moment/mood/weather | note frontmatter (`note.content`) | yes (vault) | source of truth; already encrypted/synced |
| Cached journal metadata | `NoteMetadata` LRU cache (in-memory) | n/a | derived; invalidate on note edit |
| Place merge/alias map | synced vault settings record (§2.3) | **yes** | user intent, carries across devices; reversible; never mutates frontmatter |
| "Show place & weather on entries" toggle | SharedPreferences (DefaultSettings) | no | per-device preference |
| "Suggest adding a place…" master toggle | SharedPreferences (DefaultSettings) | no | per-device; flipped off by "Don't ask again" |
| Per-day backfill suppression set | SharedPreferences (device-local) | **no** | `Set<String>` of `YYYY-MM-DD`; internal, no UI |

---

## 8. Privacy & Security Constraints
- **No map tiles / no new network calls.** The only permitted network use is the existing
  `LocationService` reverse-geocode (native geocoder → OSM Nominatim) during location capture/backfill.
- The **Places page aggregates everywhere the user has been onto one screen** — more sensitive in
  aggregate than scattered entries. It MUST sit behind the same lock/encryption gate as the rest of
  the vault, and MUST NOT read/parse location for `isPasswordProtected` notes.
- Merge/alias data and backfilled locations are user content; keep them inside the encrypted vault
  (merge map) / in frontmatter (backfilled coords). Device-local toggles contain no location data.

---

## 9. Testing Requirements
Follow the repo workflow in `AGENTS.md` (`flutter analyze` clean, `flutter test` green) before
committing. Add coverage:
- **§2.1** extractor: location/moment/mood/weather parsed into `NoteMetadata`; locked notes nulled;
  cache hit returns same instance; empty-location note → `location == null`/isEmpty.
- **§2.2** grouping: label normalization (diacritics, case, whitespace, `Kolkata`/`Calcutta`-style
  aliases), radius fallback clustering (haversine thresholds), granularity City/Region/Country.
- **§2.3** merge: merge N clusters → one canonical; rename; unmerge; frontmatter untouched; survives
  a sync/backup round-trip.
- **Feature 1**: dateline composes only present parts; absent → nothing rendered; toggle OFF hides it.
- **Feature 2**: travel date → ring/marker; non-travel entry → plain dot; no entry → nothing;
  semantics label.
- **Feature 3**: place appended when present; identical to today when absent.
- **Feature 4**: unlocated entries excluded; empty/learning state when located set tiny; visit
  sub-grouping; sort + granularity toggles.
- **§6.5 nudge** (highest-risk, test thoroughly): nudge shows only for unlocated unlocked journal
  entries with global toggle ON and day not suppressed; "Add place" writes frontmatter + invalidates
  cache; "Not now" persists nothing; "Don't ask again for this day" suppresses that date locally and
  not others; "Don't ask again" flips master toggle OFF + shows the tooltip and suppresses everywhere.

---

## 10. Suggested Build Order
1. **§2.1** cached metadata (unblocks everything).
2. **Feature 3** (On This Day place) + **Feature 1** (dateline) — smallest, pure-additive, no new nav.
3. **Feature 2** (calendar travel marker) — needs §2.4.
4. **§2.2/§2.3** place grouping + merge, then **Feature 4** page shell → list → drill-in → empty state.
5. **§6.5/§6.6** backfill nudge + settings.
6. **§6.7** home detection (optional / defer).

Each numbered step is independently shippable and should land analyze-clean + tests-green per `AGENTS.md`.

---

## 11. Decisions Locked In (so a future session doesn't re-litigate)
- Maps: **out**, indefinitely.
- Calendar marker: **`moment: travel` only**, shape/weight not color, single accent.
- Other 9 moments on the calendar: **not differentiated** (too noisy).
- Places grouping: **label-first, radius-fallback**, never exact coords; City/Region/Country toggle.
- Manual cluster merge: **yes**, user-editable, synced, reversible, non-destructive.
- Unlocated entries in Places: **silent exclusion**; **no Unknown bucket**; All Entries stays canonical.
- Backfill: **manual only** (no auto-inference), with the exact 4-button nudge + master setting +
  local per-day suppression specified in §6.5–§6.6.




