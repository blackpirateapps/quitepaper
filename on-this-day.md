
# Production Implementation Prompt — Expand “On This Day” with “This Time in Previous Years”

You are working on the existing **Quiet Paper notes app**.

Implement a production-ready expansion of the existing **On This Day** feature so that, in addition to showing entries from the exact same calendar date in previous years, it also surfaces entries from the **same calendar week/period in previous years**.

The implementation must be complete, polished, performant, accessible, responsive, and integrated into the existing application architecture.

**Do not create placeholders, mock data, fake UI, temporary implementations, or TODOs.**

Do not redesign the rest of the application.

---

# 1. Existing behavior must remain intact

Quiet Paper already has an **On This Day** screen.

The current screen visually follows this structure:

```text
☰     On This Day


↶  ON THIS DAY

September 6
────────────────────────────


            [empty state]

       Nothing from this date yet.
      Your first entry here will
            appear next year.
```

Preserve the existing **On This Day** experience and styling.

The new functionality is an extension of the page, not a replacement.

The existing exact-date functionality must:

* continue working exactly as before
* continue finding notes from the same calendar date in previous years
* continue opening the correct note when selected
* continue respecting the application's existing note filtering rules
* continue using the application's existing note data source/repository/query layer
* continue using the existing navigation architecture
* continue using the existing theme system
* continue using the existing typography and spacing system

Do not duplicate or rewrite existing On This Day logic unnecessarily.

First inspect the existing implementation and reuse its architecture.

---

# 2. New feature

Add a second historical section underneath the existing exact-date section.

The new section should be called:

## THIS TIME IN PREVIOUS YEARS

Do **not** call it:

* Same Week
* Weekly Memories
* Past Week
* Previous Week
* Around This Day

The UI label must be:

**THIS TIME IN PREVIOUS YEARS**

The purpose is to surface notes written during the same part of the calendar year in previous years.

---

# 3. Core behavior

Suppose the current date is:

**September 6, 2026**

and Monday is the first day of the week.

The current week is:

**September 1–7, 2026**

The historical section must compare that same calendar period against previous years.

Therefore it should produce groups such as:

```text
September 1–7, 2025

September 1–7, 2024

September 1–7, 2023

September 1–7, 2022
...
```

Within each historical year, show notes whose calendar dates fall inside that year's corresponding date range.

For example:

```text
THIS TIME IN PREVIOUS YEARS

September 1–7, 2025
────────────────────

September 3
Started working on...

September 6
Went to the library...

September 7
Finished...


September 1–7, 2024
────────────────────

September 2
...

September 5
...
```

The feature must be based on **calendar dates**, not week numbers.

Do **not** simply compare ISO week numbers.

The goal is to surface memories from the same time of year.

---

# 4. Week definition

Use the application's existing locale/week-start convention if one already exists.

If Quiet Paper currently has no configurable week-start behavior, use:

**Monday → Sunday**

as the default.

Centralize this logic in a reusable date utility instead of scattering weekday calculations throughout the UI.

For the current date:

1. determine the start of the current week
2. determine the end of the current week
3. generate the seven calendar dates
4. project those calendar dates into each previous year
5. query notes within each historical year's corresponding date range

Do not calculate this by subtracting 365 × N days.

That would produce incorrect results around leap years.

---

# 5. Important leap-year handling

This implementation must correctly handle leap years.

Examples:

### Current week around February 29

If the current week contains February 29 and a previous year is not a leap year, there is no February 29 in that year.

Do not create invalid dates.

Instead, skip that nonexistent calendar date while still evaluating the remaining valid dates in the historical range.

### Example

Current period:

```text
February 26 – March 4
```

Historical non-leap year:

```text
February 26
February 27
February 28
March 1
March 2
March 3
March 4
```

There must be no invalid February 29 query.

The implementation must also correctly handle weeks crossing a year boundary.

For example:

```text
December 29 – January 4
```

must correctly map to the corresponding period in each previous year.

Do not make assumptions that the seven days are always within one calendar year.

---

# 6. Which years should be displayed

Do not render an enormous list of decades immediately.

Initially load the **previous 5 years**.

Example:

```text
2025
2024
2023
2022
2021
```

However:

**Only display a year group when it contains at least one eligible note.**

Do not show empty year headers such as:

```text
September 1–7, 2023

No notes.
```

That creates unnecessary visual noise.

If there are additional older years available, provide a subtle:

**Show older memories**

control at the bottom.

When selected, progressively load additional historical years.

Load older years in a sensible batch, for example **5 years at a time**.

Do not load the entire lifetime history in one query.

---

# 7. Exact-date section vs historical section

Keep these conceptually separate.

The first section remains:

```text
ON THIS DAY

September 6
────────────────────
```

This section represents the exact date.

The new section is:

```text
THIS TIME IN PREVIOUS YEARS
```

and represents the surrounding calendar period.

Do not merge the two result sets into one list.

Do not move the existing exact-date entries into the weekly section.

---

# 8. Avoid confusing duplicate presentation

A note from the exact date naturally also belongs to that year's historical week.

For example:

```text
September 6, 2025
```

belongs to:

```text
September 1–7, 2025
```

This is acceptable because the two sections have different purposes.

However, make sure each note appears **only once within a given historical-year group**.

Never render the same note twice inside the same year group.

Use the stable note ID as the deduplication key.

---

# 9. Ordering

Historical years must be displayed in reverse chronological order.

Example:

```text
September 1–7, 2025

September 1–7, 2024

September 1–7, 2023

September 1–7, 2022
```

Within each year group, notes must be ordered chronologically by their note date.

Example:

```text
September 2
September 3
September 5
September 7
```

If multiple notes exist on the same date, use the application's existing note ordering convention.

Prefer reusing the same ordering semantics already used elsewhere in Quiet Paper.

---

# 10. Display date formatting

Inside historical year groups, display the actual note date.

For example:

```text
September 1–7, 2025
────────────────────

September 2

Note title
Preview text...


September 6

Another note
Preview text...
```

Do not display every entry merely as:

```text
2025
```

The user should immediately be able to see which day within the historical week the note belongs to.

Use the application's existing date formatting utilities wherever available.

Do not hardcode English date formatting into the feature if Quiet Paper already has localization infrastructure.

---

# 11. Important UI behavior

The existing top section should remain visually dominant.

The overall page should follow this hierarchy:

```text
ON THIS DAY

September 6
────────────────────────


[exact-date memories OR exact-date empty state]


THIS TIME IN PREVIOUS YEARS

September 1–7, 2025
────────────────────────

[historical memories]


September 1–7, 2024
────────────────────────

[historical memories]
```

The second section should feel like a natural continuation of the journal page.

It must **not** look like a dashboard.

Do not introduce:

* cards with large colored backgrounds
* charts
* graphs
* calendar widgets
* large badges
* excessive icons
* giant year selectors
* visually heavy containers
* gradients
* glassmorphism
* unnecessary animations

Quiet Paper should continue to feel calm, minimal, editorial, and paper-like.

---

# 12. Match the existing On This Day visual language

Use the screenshot/current implementation as the visual reference.

Preserve:

* existing page background
* existing typography
* existing heading weights
* existing muted colors
* existing horizontal dividers
* existing margins
* existing navigation/header
* existing icon style
* existing note preview styling
* existing interaction behavior

The new section should look like it was always part of the application.

Do not invent a separate design language.

---

# 13. Section heading

Use the same visual treatment already used by:

```text
↶ ON THIS DAY
```

For the new section, use an appropriate existing Quiet Paper icon if the project already has one.

Prefer a subtle history/clock/replay/calendar-related icon.

Do not introduce a new icon library merely for this feature.

If an appropriate icon already exists in the application, reuse it.

The heading should appear approximately as:

```text
◷  THIS TIME IN PREVIOUS YEARS
```

but the exact icon must follow the existing application's icon system.

The label should retain the existing uppercase, letter-spaced section-heading treatment.

---

# 14. Spacing

The additional section should have substantial vertical separation from the first section.

Do not put it immediately underneath the final note.

Use the existing spacing scale.

Conceptually:

```text
[On This Day content]


             large breathing space


THIS TIME IN PREVIOUS YEARS
```

The page should feel intentionally spacious.

Do not compress the content just because more information is now available.

---

# 15. Historical year group design

Each year should have its own lightweight subsection.

Example:

```text
September 1–7, 2025
────────────────────────

September 2
Note title
Preview...

September 6
Note title
Preview...
```

The year-period heading should be clearly distinguishable from individual note dates, but must remain understated.

Do not make the year heading larger than the primary page title.

A good hierarchy is:

```text
Page title
↓
Section heading
↓
Historical period
↓
Entry date
↓
Note title/content
```

Use existing typography tokens wherever possible.

---

# 16. Note presentation

Do not create an entirely new note component.

Reuse the existing note preview/list component used elsewhere in Quiet Paper whenever possible.

Historical entries should support the same:

* tap/click behavior
* hover behavior where applicable
* keyboard navigation
* title rendering
* preview rendering
* attachment indicators
* tag indicators if the existing component supports them
* note navigation
* accessibility semantics

Opening a historical entry must open the real note, not a copy.

---

# 17. Empty states

The current exact-date empty state says:

> Nothing from this date yet.
> Your first entry here will appear next year.

Once the new historical section exists, the wording must be updated so that it does not imply there are no memories on the page at all.

Use a calm message such as:

**Nothing from this date yet.**

and:

**Your memories from this time in previous years appear below.**

Do not display contradictory copy such as:

> Your first entry here will appear next year.

when there may already be historical entries below.

---

# 18. Historical section empty state

If there are no notes in the historical range for any loaded previous year, do not leave a giant blank section.

Instead show a small, tasteful empty state.

Suggested copy:

**Nothing from this time yet.**

**Your memories will appear here in future years.**

Keep it visually consistent with the existing empty state.

Do not introduce excessive explanatory text.

---

# 19. Conditional rendering

The UI must intelligently adapt.

### Case 1 — exact-date entries exist, historical entries exist

Show both normally.

### Case 2 — exact-date entries do not exist, historical entries exist

Show:

```text
ON THIS DAY

September 6

[empty state]


THIS TIME IN PREVIOUS YEARS

[historical entries]
```

### Case 3 — exact-date entries exist, historical section has nothing

Show the exact-date section and a compact historical empty state.

### Case 4 — neither exists

Show a clean empty page without unnecessary historical year headers.

Do not display five empty year groups.

---

# 20. Current-year notes

The historical section must contain **previous years only**.

Never include current-year notes.

For example, if today is September 6, 2026:

```text
September 1–7, 2026
```

must not appear in the historical section.

The current year belongs only to the normal/current application content.

---

# 21. Future dates

There may be dates inside a historical seven-day projection that correspond to future dates relative to the current date.

Example:

Current date:

```text
September 3, 2026
```

Current week:

```text
August 31 – September 6, 2026
```

For a previous year, the full corresponding historical range can safely be evaluated because all dates belong to completed years.

Do not accidentally exclude historical entries simply because the corresponding month/day has not yet occurred in the current year.

The previous-year period should represent the complete seven-day historical period.

---

# 22. Date/timezone correctness

This feature is date-based, not timestamp-based.

Use the application's existing canonical timezone/date handling.

Do not derive the day directly from a UTC timestamp if the rest of the application uses local dates.

A note created at:

```text
23:30 local time
```

must belong to the correct local calendar date even when the stored timestamp's UTC date differs.

Reuse existing Quiet Paper date conversion utilities.

Do not introduce inconsistent timezone behavior specifically for On This Day.

---

# 23. Trash/deleted notes

Respect Quiet Paper's existing note lifecycle rules.

**Trashed/deleted notes must not appear in On This Day or This Time in Previous Years.**

Permanent deletion must naturally remove the note from these results because the underlying note no longer exists.

Do not query only the UI-filtered note list if the application's data model has a more authoritative active-note query.

Use the application's canonical “active/non-trash note” semantics.

---

# 24. Archived notes

Follow the existing On This Day behavior for archived notes.

If archived notes currently appear in On This Day, they should also be eligible for historical memories.

If archived notes are currently excluded, continue excluding them.

Do not silently change archive semantics while implementing this feature.

---

# 25. Pinned/favorited/tagged notes

Do not change note metadata behavior.

Historical notes should remain ordinary notes.

Do not automatically pin, favorite, or tag them.

Do not add a special historical-note database flag.

This feature should be derived from the note's existing creation/date metadata.

---

# 26. Data/query architecture

Do not solve this by downloading the user's entire note database and filtering everything in the UI.

Use the application's existing repository/database query architecture.

The preferred flow is:

```text
On This Day screen
        ↓
date-range service/query
        ↓
notes repository
        ↓
filtered historical results
        ↓
UI model/view model
        ↓
render
```

Keep date calculations separate from rendering.

Create a reusable historical-range abstraction where appropriate.

For example, conceptually:

```text
HistoricalPeriod
    year
    startDate
    endDate
    entries
```

Use the project's actual architecture and naming conventions rather than blindly copying these names.

---

# 27. Efficient querying

The implementation must be efficient for users with thousands of notes.

Do not perform one expensive full-database scan for every year.

Prefer efficient date-range queries.

A query should be capable of expressing something equivalent to:

```text
date >= historicalStart
AND date <= historicalEnd
AND note is active
```

Use indexed date fields when available.

If the underlying database supports indexes, verify that the relevant date field is indexed or use the project's established indexing strategy.

Do not introduce a schema migration merely for this feature unless the existing architecture genuinely requires it.

---

# 28. Avoid N+1 queries

Do not perform:

```text
for every year
    query notes
```

if the data layer can efficiently retrieve a larger range and group the results in memory.

However, do not fetch the entire historical database either.

Choose the most efficient strategy supported by the current backend.

The final implementation should be appropriate for:

* 10 notes
* 1,000 notes
* 10,000+ notes

without a noticeable UI slowdown.

---

# 29. Lazy loading older years

The first load should cover the previous five years.

Older years should load only when requested.

When the user taps:

```text
Show older memories
```

load the next historical batch.

The UI must show a proper loading state during this operation.

Do not freeze the interface.

Do not block the entire page while older years are fetched.

---

# 30. Loading state

Use the application's existing loading-state conventions.

Do not introduce a giant spinner in the middle of the page.

Prefer:

* subtle progress indication
* inline loading
* skeletons only if the app already uses them

Do not introduce blur-based loading.

The user's existing preference is explicitly:

**No blur loading.**

---

# 31. Error handling

Historical memory loading must fail gracefully.

If the historical query fails:

* do not crash the page
* do not destroy the exact-date content
* preserve already loaded results
* show a subtle retry affordance
* log the underlying error using the application's existing logging/error reporting mechanism

Example UI:

**Couldn't load older memories.**

**Try again**

Do not display raw database errors to the user.

---

# 32. Interaction

Every historical note must be fully interactive.

On click/tap:

```text
historical note
      ↓
open existing note viewer/editor
```

Use the existing navigation mechanism.

Do not duplicate note-opening logic.

On desktop:

* support mouse interaction
* support keyboard focus
* support Enter/Space where appropriate

On touch:

* ensure comfortable hit areas
* avoid hover-only functionality

---

# 33. Accessibility

The new section must be accessible.

Ensure:

* section headings use semantic heading levels consistent with the existing page
* note entries have meaningful accessible labels
* dates are understandable to screen readers
* interactive elements have visible focus states
* touch targets are sufficiently large
* color is never the only way to communicate meaning

Do not create inaccessible custom gestures.

Respect system text scaling where the application currently supports it.

---

# 34. Responsive behavior

The feature must work properly on:

* phones
* tablets
* desktop
* narrow desktop windows

Do not introduce a desktop-only layout.

On narrow screens:

* dates must not overflow
* long note titles must wrap or truncate using the existing behavior
* the historical section must remain readable
* horizontal scrolling should not be required for ordinary content

---

# 35. Animation

Do not add excessive animation.

If the application has established transition animations, reuse them.

The appearance of historical results can use a very subtle transition if appropriate, but the feature must remain calm and instantaneous-feeling.

Avoid:

* bouncing
* large sliding panels
* parallax
* flashy transitions

---

# 36. “Show older memories” behavior

The control should appear only when older years remain available to load.

After all relevant configured/history-supported years are exhausted, remove the control.

Do not show:

```text
Show older memories
```

when there are no older years to inspect.

The system should determine availability based on the user's actual note history where practical rather than blindly allowing infinite meaningless requests.

---

# 37. Database boundaries

Never query before the user's earliest possible note date.

For example, if the oldest note in the database is from 2023, there is no reason to repeatedly query 1990–1995.

The implementation should stop historical loading once it goes beyond the earliest eligible note date, where this information is available.

This is especially important for performance.

---

# 38. Historical year with no entries

Do not render:

```text
September 1–7, 2022
```

unless that year has at least one note in the historical range.

This keeps the interface clean.

The user should see actual memories, not a list of empty years.

---

# 39. Historical date grouping

Within each year:

```text
September 1–7, 2025
```

notes should be grouped by their actual day when practical.

For example:

```text
September 1

Note A
Preview...


September 4

Note B
Preview...

Note C
Preview...


September 7

Note D
Preview...
```

Avoid repeating the date beside every note if multiple notes share the same date.

This creates a much cleaner journal-like presentation.

Use the existing note-list visual language to determine the exact layout.

---

# 40. Mobile presentation

The screenshot provided is a phone layout.

The mobile implementation is especially important.

Maintain the same calm vertical rhythm.

The page should feel approximately like:

```text
On This Day


↶ ON THIS DAY

September 6
────────────────


[exact-date content]


↷ THIS TIME IN PREVIOUS YEARS

September 1–7, 2025
────────────────

September 3
Note...


September 6
Note...


September 1–7, 2024
────────────────

September 2
Note...
```

Do not turn the historical section into horizontally scrolling cards.

Do not use a carousel.

---

# 41. Date-period wording

For historical groups, generate the period label from the actual projected historical dates.

For example:

```text
September 1–7, 2025
```

If the range crosses months:

```text
August 31 – September 6, 2025
```

If the range crosses years, format it correctly according to the application's date formatter.

Do not assume every period is:

```text
Month Day–Day, Year
```

Use a proper range formatter.

---

# 42. Internationalization

Do not hardcode date names such as:

```text
September
Monday
Sunday
```

Use the application's localization/date-formatting infrastructure.

The underlying algorithm must remain locale-independent.

The week-start day should follow existing app behavior where such configuration is already present.

UI strings such as:

```text
THIS TIME IN PREVIOUS YEARS
Nothing from this time yet.
Show older memories
```

must be added to the application's localization system rather than embedded directly in UI code.

If Quiet Paper currently supports only one language, still structure the feature correctly for future localization.

---

# 43. State management

Use the existing state-management architecture.

Do not create an isolated global state mechanism solely for this screen.

The state should distinguish at least:

```text
initial/loading
loaded
loading older memories
error
no results
```

and maintain:

```text
exact-date entries
historical year groups
hasMoreHistoricalYears
currently loading older years
```

using the project's existing conventions.

---

# 44. Avoid unnecessary schema changes

Do not add a field such as:

```text
isHistoricalMemory
```

A note does not become historical because the UI displays it here.

Historical membership must always be derived dynamically from the note's date.

This ensures the feature remains correct forever.

---

# 45. Caching

Use existing caching mechanisms where appropriate.

If Quiet Paper already caches note lists or date-range results, integrate with that mechanism.

Do not create a second competing cache.

Historical data should remain correct after a note is:

* created
* edited
* moved
* restored from trash
* deleted
* synchronized from another device

The On This Day screen should refresh/invalidate appropriately.

---

# 46. Sync behavior

Because Quiet Paper supports synchronization, historical memories must be derived from the same synchronized note dataset.

A note arriving through sync should automatically become eligible for the historical section when its date falls inside a historical period.

Do not create a local-only historical record.

Do not store historical-section membership separately.

---

# 47. New note creation from this screen

Do not introduce a new note-creation workflow unless the existing On This Day screen already has one.

This feature is about retrieval and memory resurfacing.

Preserve the current screen's existing actions.

---

# 48. Testing requirements

Create/extend automated tests for the date logic.

At minimum test:

### Normal dates

```text
September 6
September 1–7
```

### Leap years

```text
February 29
February 26–March 4
```

### Non-leap historical year

Ensure February 29 is handled safely.

### Year boundary

```text
December 29–January 4
```

### First/last day of year

Test dates around:

```text
January 1
December 31
```

### Multiple years

Verify:

```text
2025
2024
2023
...
```

are ordered correctly.

### Empty years

Verify years containing no notes are not rendered.

### Duplicate notes

Verify the same note cannot appear twice within the same historical group.

### Trash

Verify trashed notes do not appear.

### Current year

Verify current-year notes never appear in the historical section.

### Timezone

Verify local-calendar dates remain correct across UTC boundaries where applicable.

---

# 49. UI tests

Add UI/widget/integration tests appropriate to the project's testing architecture.

At minimum verify:

1. Exact-date section still renders.
2. Historical section appears when historical notes exist.
3. Historical section remains hidden/compact when there are no results.
4. Historical years are ordered newest → oldest.
5. Notes are ordered chronologically.
6. Selecting a historical note opens the correct note.
7. “Show older memories” loads more historical years.
8. Loading state appears correctly.
9. Errors do not destroy the rest of the page.
10. Empty states do not create redundant empty year groups.

---

# 50. Performance testing

Test with a large note dataset.

The implementation must not:

* freeze rendering
* perform unnecessary full-database scans
* perform an N+1 query for every note
* rebuild the entire page unnecessarily when one historical result changes

Use memoization/selectors/reactive queries according to the application's architecture.

Only recompute affected historical groups when possible.

---

# 51. Refresh behavior

The screen should update correctly when:

* a new note is created
* an existing note's date changes
* a note is deleted
* a note is restored
* sync brings in new notes
* sync removes notes
* the user changes timezone/date context if the app supports such behavior

Do not require the user to fully restart the app.

Use the existing reactive/update mechanisms.

---

# 52. Do not alter the existing design system

Do not introduce new global colors, fonts, radius values, shadows, or spacing tokens solely for this screen.

Use the application's existing design tokens/theme system.

The feature must automatically respect:

* light mode
* dark mode
* any existing Quiet Paper themes
* system appearance where supported
* typography settings
* accessibility settings

---

# 53. Dark mode

The new section must not contain hardcoded light-theme colors.

Everything must use existing semantic theme tokens.

Verify that:

* section icon
* section label
* period heading
* dates
* note titles
* previews
* dividers
* empty state
* loading state
* error state
* buttons

all remain correct in every existing theme.

---

# 54. No visual redesign of the existing On This Day page

Do not:

* move the header
* redesign the hamburger menu
* redesign the primary page title
* change the existing exact-date empty-state illustration
* replace the existing note-list design
* add a calendar picker
* add filters
* add a search bar

unless the existing application's architecture requires a tiny integration change.

This task is specifically the historical-week expansion.

---

# 55. Suggested internal architecture

Adapt this concept to the actual project rather than copying blindly:

```text
OnThisDayScreen
    |
    ├── ExactDateSection
    |
    └── HistoricalMemoriesSection
            |
            ├── HistoricalYearGroup
            │       ├── PeriodHeader
            │       └── HistoricalEntries
            |
            └── LoadOlderMemories
```

Date logic:

```text
CurrentDate
    ↓
CurrentWeekRange
    ↓
HistoricalYearRanges
    ↓
Repository Query
    ↓
Group By Historical Year
    ↓
Group By Calendar Date
    ↓
UI
```

Keep the date calculation logic independently testable.

---

# 56. Algorithm requirements

Implement a reliable utility that conceptually performs:

```text
getCurrentWeekRange(date)
```

Then:

```text
getHistoricalWeekRange(currentWeekRange, previousYear)
```

The historical range must preserve the calendar month/day positions of the seven-day period while safely handling:

* leap years
* month boundaries
* year boundaries

Do not implement the historical calculation as:

```text
currentDate - 365 days
```

or:

```text
currentDate - 52 weeks
```

These can produce incorrect historical comparisons.

---

# 57. Example expected behavior

Assume:

```text
Today = September 6, 2026
Week = Monday September 1 → Sunday September 7
```

Historical results:

```text
THIS TIME IN PREVIOUS YEARS

September 1–7, 2025
    September 2
        Note A
    September 6
        Note B

September 1–7, 2024
    September 1
        Note C
    September 5
        Note D

September 1–7, 2023
    [no notes]
```

The 2023 group should **not be displayed**.

The next visible group should therefore be the next year with actual matching notes.

---

# 58. Example with no exact-date memory

If there is no September 6 note in previous years but there are notes on September 3 and September 5:

```text
ON THIS DAY

September 6

[existing exact-date empty state]


THIS TIME IN PREVIOUS YEARS

September 1–7, 2025
────────────────────────

September 3
Note title
Preview...

September 5
Note title
Preview...
```

This should feel completely intentional rather than like an error state.

---

# 59. Example with no historical memories

If there are no notes anywhere in the previous five years for the corresponding period:

```text
ON THIS DAY

September 6

[existing empty state]


THIS TIME IN PREVIOUS YEARS

[small calm empty state]

Nothing from this time yet.
Your memories will appear here in future years.
```

Do not show five empty year headers.

---

# 60. Acceptance criteria

The implementation is complete only when all of the following are true:

* Existing On This Day behavior remains functional.
* Exact-date entries still work.
* A new **THIS TIME IN PREVIOUS YEARS** section exists.
* It uses the same calendar-period logic rather than week numbers.
* Monday–Sunday is used unless the app already has another week-start setting.
* Previous years are evaluated correctly.
* Leap years are handled safely.
* Nonexistent February 29 dates are never generated.
* Cross-year weeks work correctly.
* Current-year entries are excluded from historical groups.
* Trashed/deleted notes are excluded according to existing lifecycle rules.
* Historical years are sorted newest → oldest.
* Notes within each historical year are sorted chronologically.
* Empty historical years are hidden.
* The first five previous years are checked initially.
* Older years can be loaded progressively.
* No unnecessary full-database scan is performed.
* No N+1 query pattern is introduced.
* Historical entries open the real note.
* Existing note components are reused where possible.
* The feature works on mobile and desktop.
* The feature is touch friendly.
* The feature is keyboard accessible.
* The feature works across all existing themes.
* No blur-loading is introduced.
* Loading and error states are handled gracefully.
* Localization/date formatting uses existing infrastructure.
* Sync-created notes automatically participate.
* Note changes correctly update historical results.
* Automated tests cover date edge cases.
* UI/integration tests cover the major states.
* No placeholder implementation remains.
* No TODOs remain for core functionality.
* No unrelated parts of Quiet Paper are redesigned.

---

# 61. Implementation process

Before changing code:

1. Inspect the current On This Day screen.
2. Identify the existing exact-date query/service/repository.
3. Identify the application's canonical note-date representation.
4. Identify existing timezone/date utilities.
5. Identify the existing note list/preview component.
6. Identify the state-management pattern used by the screen.
7. Identify existing theme and localization infrastructure.
8. Identify existing tests around date-based note retrieval.

Then implement the feature **inside the existing architecture**.

Do not create competing abstractions when an existing one can be extended cleanly.

After implementation:

1. Run formatting/linting.
2. Run all relevant unit tests.
3. Run UI/widget/integration tests.
4. Test light and dark themes.
5. Test mobile and desktop layouts.
6. Test leap-year and year-boundary dates.
7. Test with empty, small, and large note datasets.
8. Verify synchronization/update behavior.
9. Verify note navigation from historical results.
10. Remove all temporary debugging code and placeholder data.

---

# Final design goal

The finished screen should feel like a natural evolution of the current Quiet Paper On This Day page.

The user should be able to open it and immediately understand:

**ON THIS DAY**
→ memories from this exact date

**THIS TIME IN PREVIOUS YEARS**
→ memories from the same period of the year

The feature should feel **quiet, personal, chronological, and effortless**, not like a statistics or calendar dashboard.

Do not over-design it.

The existing visual language shown in the provided On This Day reference should remain the source of truth for the UI.
