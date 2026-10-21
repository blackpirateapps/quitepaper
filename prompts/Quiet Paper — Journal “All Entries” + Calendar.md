# Quiet Paper — Journal “All Entries” + Calendar
## Complete Production-Ready Implementation

You are working inside the existing **Quiet Paper Flutter application**.

The application already has **Journal V1** implemented.

Current Journal navigation:

```text
JOURNAL

Today
On This Day
```

Do not rebuild those existing features.

This task is to implement the missing third Journal destination:

```text
All Entries
```

and build the complete **chronological journal archive + interactive calendar navigation experience** described below.

This must be production-quality code.

Do not create placeholder data, mock entries, hard-coded dates, fake loading states, static demo content, or TODO implementations.

Everything described here must be functional and integrated with the existing Quiet Paper architecture.

---

# 1. Read the Existing Project First

Before making any changes:

1. Read `HANDOFF.md` in full.
2. Inspect the Journal V1 implementation that already exists.
3. Inspect:
   - existing Today implementation
   - existing On This Day implementation
   - journal metadata/frontmatter handling
   - journal date storage
   - Note model
   - note repository
   - note queries
   - EditorScreen
   - note navigation
   - trash lifecycle
   - sync
   - backup/restore
   - search
   - note history
   - theme system
   - current sidebar/navigation
   - existing note list/timeline components
   - current date utilities
   - tests

Do not blindly follow this prompt if the existing Journal V1 implementation already established a better abstraction.

Reuse its models, repositories, providers, navigation, date handling, and frontmatter semantics wherever appropriate.

---

# 2. Product Definition

The Journal navigation should become:

```text
JOURNAL

Today
All Entries
On This Day
```

The three destinations have distinct purposes.

### Today

Already implemented.

Its job is:

> Open or create today's single journal entry.

Do not modify its existing behavior unless a small integration fix is required.

### All Entries

This task.

Its job is:

> Browse every journal entry chronologically.

It is the main journal archive.

### On This Day

Already implemented.

Its job is:

> Rediscover entries from previous years that occurred on today's month/day.

Do not rebuild it.

---

# 3. All Entries Is a Timeline, Not a Normal Notes List

Do NOT simply reuse the normal Notes list and filter it.

All Entries should be intentionally **time-oriented**.

The user should feel:

> “I am browsing my journal over time.”

rather than:

> “I am looking at another list of notes.”

The archive should be organized chronologically and grouped by month/year.

Example:

```text
ALL ENTRIES


SEPTEMBER 2026

01
Finally fixed the scanner
Tuesday

31
Working on note linking
Monday


AUGUST 2026

29
New theme ideas
Saturday

28
Started working on Quiet Paper
Friday
```

Only dates with actual journal entries should appear.

Do NOT display empty days.

---

# 4. All Entries + Calendar Relationship

The calendar is part of **All Entries**.

It is NOT a fourth Journal navigation item.

Architecture:

```text
Journal
│
├── Today
│
├── All Entries
│     │
│     ├── Calendar
│     │
│     └── Chronological Timeline
│
└── On This Day
```

The calendar is a navigation/browsing aid for the timeline.

---

# 5. All Entries Initial Layout

Build the page around this hierarchy:

```text
ALL ENTRIES

        September 2026
      ‹               ›

   M    T    W    T    F    S    S

             1    2    3    4    5    6
             ·         ·

   7    8    9   10   11   12   13
                       ·

  14   15   16   17   18   19   20
             ·

  21   22   23   24   25   26   27

  28   29   30


────────────────────────────────

SEPTEMBER 2026

01
Finally fixed the scanner
Tuesday

31
Working on note linking
Monday
```

This is a conceptual layout, not a demand for literal spacing.

Use the existing Quiet Paper typography/layout system.

---

# 6. Do Not Create a Calendar Page

The calendar must live inside All Entries.

Do not create:

```text
Journal → Calendar
```

Do not create:

```text
JournalCalendarScreen
```

unless the existing navigation architecture requires an internal component with that name.

The user should perceive:

> All Entries contains a calendar and a timeline.

---

# 7. Calendar Visual Philosophy

The calendar should look like:

> a beautifully typeset paper calendar.

Not:

> a business/productivity calendar.

Do not use:

- colorful day cells
- filled Material-style circles
- huge rounded cards
- gradient backgrounds
- heatmaps
- streak indicators
- mood colors
- productivity indicators
- word-count badges
- progress rings
- gamification

Prefer:

- naked date numbers
- subtle typography
- whitespace
- tiny entry indicators
- thin outlines for special states
- Quiet Paper's paper surfaces
- existing theme tokens

---

# 8. Naked Date Numbers

Most calendar dates should simply appear as numbers.

Example:

```text
1     2     3     4     5
·           ·
```

Do not put every date inside a rounded box.

A box/outline is reserved for meaningful states.

---

# 9. Journal Entry Indicator

A date with a journal entry gets a tiny, understated mark.

Recommended:

```text
12
·
```

or equivalent.

This means only:

> An entry exists on this date.

It does not encode:

- length
- mood
- importance
- productivity
- number of words
- streak

All entry dates use the same indicator.

---

# 10. Today State

Today's date should have a subtle visual distinction.

Preferred:

```text
┌───┐
│ 1 │
└───┘
```

rather than a large filled circle.

If today also has an entry:

```text
┌───┐
│ 1 │
└───┘
  ·
```

Keep the treatment understated.

---

# 11. Selected Date State

When a user taps a calendar date:

- visually select it
- clearly distinguish selected from normal
- distinguish selected from today
- use subtle semantic accent/outline
- do not create heavy filled states

If today is selected, combine the states elegantly.

---

# 12. Important Interaction Rule

When the user taps a calendar date:

**Do NOT immediately open the note.**

Instead:

```text
tap date
↓
date selected
↓
calendar updates
↓
selected-date preview appears
```

This is intentional.

The user should be able to browse calendar history without being repeatedly thrown into notes.

---

# 13. Selected Date Preview

When a date with an entry is selected, show a small editorial preview below the calendar.

For example:

```text
SEPTEMBER 16

The day everything clicked

Tuesday · 9:42 PM

I finally got the scanner working...
```

The title is the user's actual journal-note title.

Do not assume the title is the date.

The preview can show a short snippet using existing note-preview logic.

Keep it compact.

---

# 14. Preview With No Entry

If a selected date has no entry:

```text
SEPTEMBER 16

No journal entry
```

Do not create the entry.

Do not show a giant illustration.

Do not show:

> Start your streak!

Do not gamify the empty day.

---

# 15. Open Historical Entry

The selected preview should be tappable.

Tapping it opens the **existing note editor**.

Do not create:

- JournalViewerScreen
- JournalEntryScreen
- CalendarEntryScreen

Use the normal note navigation path.

The journal entry remains a normal Quiet Paper note.

---

# 16. “Show in All Entries”

The selected-date preview should have a natural action to locate that date in the timeline.

For example:

```text
Show in All Entries →
```

or another concise equivalent.

Tapping it must:

1. close/collapse the calendar appropriately
2. locate the corresponding entry in the All Entries timeline
3. smoothly scroll to it
4. briefly highlight the target entry
5. leave the user in the All Entries page

Do NOT navigate to another screen.

---

# 17. Calendar and Timeline Are One Experience

The core browsing flow should feel like:

```text
All Entries
       ↓
calendar
       ↓
select September 16, 2024
       ↓
see preview
       ↓
Show in All Entries
       ↓
timeline jumps to September 2024
       ↓
September 16 entry is highlighted
```

The calendar is therefore a navigation lens over the timeline.

---

# 18. Timeline Jump Must Be Robust

Do not calculate a naïve pixel offset based on:

```text
index × fixedRowHeight
```

because:

- entries have variable heights
- typography can change
- themes can change
- snippets may differ
- months contain variable numbers of entries

Use the existing list/sliver architecture.

If the timeline is lazy, develop a robust mechanism for locating an item.

Possible approaches include:

- grouped sections with known keys
- indexed item identifiers
- lazy item lookup
- controlled list repositioning

Use the approach that best fits the current project.

Do not fake exact positioning.

---

# 19. Highlight After Jump

After jumping to an entry, briefly highlight it.

Example:

```text
September 16
The day everything clicked
```

The row can receive a subtle temporary surface/accent transition.

Suggested total duration:

```text
800–1500ms
```

Then fade naturally back to normal.

Do not leave the entry permanently selected.

---

# 20. All Entries Timeline Structure

Group entries by year/month.

For example:

```text
SEPTEMBER 2026

01
Finally fixed the scanner
Tuesday · 9:42 PM

AUGUST 2026

31
Working on note linking
Monday · 8:31 PM

29
New theme ideas
Saturday
```

The grouping should be generated from journal dates.

Do not group by:

- created_at
- updated_at
- title

Journal date is authoritative for chronology.

---

# 21. Sort Order

Newest entries first.

Within each month:

newest date → oldest date.

For entries on the same date, there should only be one journal entry by invariant.

Do not use modification time as the primary journal chronology.

---

# 22. Only Existing Entries Appear

Do not create empty rows for missing dates.

Bad:

```text
Sep 1
Sep 2
Sep 3
Sep 4
Sep 5
```

when only Sep 1 and Sep 5 contain entries.

Good:

```text
Sep 1
Finally fixed the scanner

Sep 5
Exam notes
```

Missing days disappear naturally.

This keeps Journal from resembling a habit tracker.

---

# 23. Calendar Month Navigation

At the top:

```text
‹       September 2026       ›
```

Previous month:

```text
‹
```

Next month:

```text
›
```

Move exactly one month at a time.

Handle:

- January → December previous year
- December → January next year
- leap years
- month lengths

correctly.

---

# 24. Month/Year Picker

Tapping:

```text
September 2026
```

may open a compact Quiet Paper month/year selector.

Example:

```text
2026

January      February      March
April        May           June
July         August        September
October      November      December
```

Selecting a month changes the calendar's visible month.

Do not modify any journal data.

This is navigation only.

---

# 25. Current Month Shortcut

When the user has navigated far into the past, provide an unobtrusive way to return to the current month.

A compact:

```text
Today
```

action is acceptable.

Do not create a giant CTA.

---

# 26. Month Navigation Does Not Automatically Scroll Timeline

Changing:

```text
September 2026
→ August 2026
```

should primarily change the calendar.

It should not immediately scroll the timeline unless the user explicitly chooses:

```text
Show in All Entries
```

This keeps month browsing and timeline navigation distinct.

---

# 27. Selected Date After Month Change

When changing month:

- do not retain an invalid selected date
- clear selection or preserve day-of-month only when valid
- never show a date that doesn't exist

A simple safe choice is:

```text
month changed
→ selectedDate = null
```

unless there is a strong UX reason to preserve it.

---

# 28. Calendar State

Keep calendar UI state separate from journal data.

Conceptually:

```text
CalendarState
├── visibleMonth
├── selectedDate
└── expanded/collapsed
```

Do not store this in the Note or journal database.

---

# 29. Collapsible Calendar

The calendar should not permanently consume the entire screen.

Support a collapsed state.

Expanded:

```text
September 2026
calendar grid
selected preview
```

Collapsed:

```text
September 2026                           ⌄
```

or equivalent.

The timeline then occupies more space.

---

# 30. Collapse Behavior

The calendar may collapse while scrolling the All Entries timeline.

When collapsed:

- preserve current visible month
- preserve selected date where appropriate
- leave a compact month header
- make expansion easy

Do not completely remove calendar access.

---

# 31. Calendar Expansion Animation

Use subtle motion.

Recommended:

- 180–250ms
- ease-out
- no bounce
- no exaggerated scale animation

Preserve the user's timeline reading position as much as practical.

---

# 32. Scrolling With Calendar

Avoid causing the timeline to jump unpredictably.

For example:

```text
user is reading August 2025
↓
calendar collapses
```

The same timeline content should remain visually anchored as much as practical.

Do not simply rebuild the whole screen and return the user to the top.

---

# 33. Calendar Grid

Implement a real calendar grid.

Must correctly calculate:

- first weekday
- number of days
- number of weeks
- month boundaries
- leap years
- locale first weekday

Do not hard-code a particular month's layout.

---

# 34. Adjacent Month Dates

Prefer Quiet Paper's calendar showing the selected month clearly.

Adjacent-month dates may either:

- be omitted
- or appear extremely muted

Do not give them equal visual weight.

---

# 35. Weekday Labels

Keep weekday labels subtle.

Example:

```text
M    T    W    T    F    S    S
```

or locale-appropriate equivalents.

Use small muted typography.

Do not visually dominate date numbers.

---

# 36. Weekend Styling

Do not color weekends differently by default.

There should be no business-calendar aesthetic.

---

# 37. No Heatmap

Do not show different shades based on:

- word count
- number of entries
- writing frequency

One date = one entry indicator.

---

# 38. Calendar Data Query

The calendar should query only the dates needed.

Conceptually:

```text
getJournalDatesForMonth(year, month)
```

returns:

```text
{1, 3, 7, 16, 29}
```

for a month.

Do NOT load every journal body just to render the calendar.

Use the journal-date index/storage introduced by Journal V1.

---

# 39. Selected Entry Query

When selecting a date:

```text
getJournalEntry(date)
```

should retrieve the specific entry efficiently.

Do not re-query the entire archive.

---

# 40. Efficient Timeline Query

All Entries should use an efficient lazy/streamed query where appropriate.

Do not load the entire journal history into memory just because the archive exists.

A user may eventually have many years of entries.

Use:

- lazy lists
- slivers
- paginated/bounded queries
- existing reactive database streams

where appropriate.

---

# 41. Long-Term Journal Support

The architecture must work for:

- 10 entries
- 1,000 entries
- 10,000 entries

Do not design the page around a tiny journal.

The UI can remain simple while the data layer remains scalable.

---

# 42. Timeline Lazy Loading

If the existing Journal V1 All Entries data source does not already provide efficient lazy loading, implement it.

The user should be able to scroll backward through years without:

- loading every note body
- decrypting every attachment
- creating every row widget at startup

Only the data required for the visible timeline should be loaded.

---

# 43. Timeline Preview Data

Each row only needs lightweight data:

- note ID
- journal date
- title
- existing lightweight note preview/snippet
- whatever existing metadata is necessary

Do not load:

- attachments
- OCR content
- full binary resources
- unnecessary encrypted payloads

until the user opens the note.

---

# 44. Protected Journal Entries

Journal entries obey normal Quiet Paper note security.

If a historical entry is password-protected:

- do not expose protected body content in timeline previews
- do not expose protected content in selected calendar preview
- use the existing metadata policy
- opening the entry must use the existing unlock flow

Never use Journal as a privacy bypass.

---

# 45. Trashed Journal Entries

Follow the existing Journal V1 and Trash semantics.

Recommended:

- All Entries should show only active journal entries
- trash does not appear as a normal historical entry
- calendar indicators should correspond to active journal entries
- restoring an entry causes it to reappear
- permanent deletion removes it completely

Do not silently create duplicate journal entries because a matching-date entry happens to be in Trash.

Follow the existing one-entry-per-date invariant.

---

# 46. Permanent Deletion

When a journal entry is permanently deleted:

- remove it from All Entries
- remove its calendar indicator
- remove it from selected-date preview if currently selected
- free that journal date for future creation
- preserve existing resource cleanup behavior

No stale calendar state.

---

# 47. Sync

All Entries and Calendar must update when journal notes change due to sync.

Example:

```text
sync pull
↓
new journal entry received
↓
timeline updates
↓
calendar date gets entry indicator
```

Do not require reopening the application.

Use existing reactive sync/database architecture.

Do not create a journal-specific sync system.

---

# 48. Backup and Restore

After restore:

- journal dates remain intact
- All Entries contains restored entries
- calendar indicators are correct
- selected entries open normally
- On This Day remains functional

Do not backup calendar UI state as note content.

---

# 49. Note History

Historical entries use the normal note history system.

Opening an entry from the calendar must not create a revision.

Scrolling/selecting dates must not modify notes.

Only actual edits create revisions according to existing behavior.

---

# 50. Journal Frontmatter

Do not alter the existing Journal V1 frontmatter model.

The All Entries and Calendar features should consume the already-established journal metadata.

Do not duplicate frontmatter parsing.

Do not rewrite journal frontmatter when merely browsing the archive.

---

# 51. User-Controlled Titles

All Entries must display the journal note's user-controlled title.

Example:

```text
September 1, 2026

Finally fixed the scanner
```

The date is metadata, not the note title.

If the user changes:

```text
Finally fixed the scanner
```

to:

```text
Tuesday
```

All Entries must immediately reflect the new title.

The journal date remains unchanged.

---

# 52. Date Formatting

Use the existing Quiet Paper date utilities.

Calendar dates:

```text
1
2
3
...
```

Timeline headings:

```text
SEPTEMBER 2026
```

Entry metadata may use:

```text
Tuesday · 9:42 PM
```

or the application's existing formatting style.

Respect locale presentation where existing Quiet Paper supports it.

Do not change database representation based on locale.

---

# 53. Today Is Not Automatically Created

All Entries must not create today's entry automatically.

Opening All Entries should not create a blank journal note.

Only the existing Today action creates today's entry.

This is critical.

---

# 54. Calendar Does Not Automatically Create Entries

Selecting an empty date must not create a journal entry.

The calendar is for browsing/navigation in V1.

No accidental blank journal entries.

---

# 55. Current-Day Indicator

Today should remain visually identifiable even if it has no journal entry.

This lets the user recognize:

> this is today.

If an entry exists, the entry indicator is added.

---

# 56. Calendar Selection Preview vs Timeline

There are three states:

### Calendar only

User is browsing dates.

### Calendar + selected preview

User has selected a date.

### Timeline jump

User explicitly asks to locate the entry within All Entries.

Do not merge these states into one abrupt action.

---

# 57. Calendar Header

Use:

```text
‹   September 2026   ›
```

with subtle typography.

The month title should feel editorial.

Do not use large Material DatePicker title styling.

---

# 58. All Entries Header

The page should clearly identify itself:

```text
ALL ENTRIES
```

or the existing page-header convention.

Then calendar.

Do not over-label every subsection.

---

# 59. No Redundant Breadcrumbs

Do not display:

```text
Journal / All Entries / September / ...
```

This is unnecessary.

The navigation context is already clear.

---

# 60. All Entries Empty State

If the user has never written a journal entry:

show a quiet message.

For example:

```text
ALL ENTRIES

No journal entries yet.
```

Do not auto-create one.

Do not provide a huge onboarding illustration.

Today remains the place to create the first entry.

---

# 61. Empty Calendar

If the current month has no journal entries:

the dates remain visible normally.

There are simply no entry indicators.

The calendar should still function.

---

# 62. First Historical Entry

Suppose the user has entries only from:

```text
January 2024
July 2026
September 2026
```

All Entries should show those months and not invent entries between them.

The calendar should correctly show indicators only on actual dates.

---

# 63. Month Query Strategy

Use the existing journal-date database/index.

Do not inspect every Note body's frontmatter to determine monthly indicators.

The database should provide an efficient source for journal dates.

---

# 64. Timeline Query Strategy

Use the journal-date field/index for chronological ordering.

Do not sort by title.

Do not sort by body.

Do not sort by creation timestamp unless it is an explicit secondary display detail.

---

# 65. Navigation to Entry

When opening an entry from:

- All Entries
- calendar preview
- On This Day

the destination should be the same normal Note editor flow.

Do not duplicate navigation logic.

---

# 66. Calendar Preview Navigation

Selected preview:

```text
September 16
The day everything clicked
```

tap:

→ existing editor.

No intermediate confirmation.

---

# 67. Back Navigation

Example:

```text
All Entries
↓
Select Sep 16
↓
Open entry
↓
Back
```

The user should return to the All Entries context naturally.

Preserve the page/month state where practical.

Do not reset them to the current month unexpectedly.

---

# 68. Navigation State Preservation

When returning from the editor:

- preserve All Entries scroll position
- preserve visible calendar month
- preserve selected date where practical
- preserve calendar expanded/collapsed state where practical

Do not unnecessarily reconstruct the entire page.

---

# 69. Accessibility

Calendar day cells must have semantic labels.

For example:

```text
September 16, 2026, journal entry exists
```

or:

```text
September 16, 2026, no journal entry
```

Today:

```text
September 16, 2026, today, journal entry exists
```

Selected state must be exposed.

---

# 70. Keyboard Support

Where desktop/tablet keyboard interaction exists:

- Tab → calendar controls
- Arrow keys → navigate dates
- Enter/Space → select date
- Escape → close month/year selector

Do not interfere with note-editor shortcuts.

---

# 71. Touch Targets

The visual date can remain small.

The actual touch target should be comfortably sized.

Do not require precise tapping on tiny numerals.

---

# 72. Reduced Motion

Respect system reduced-motion preferences.

With reduced motion:

- calendar expansion is instant or very short
- timeline highlighting can be minimized
- no decorative motion

Functionality remains unchanged.

---

# 73. Theme Integration

Use the existing Quiet Paper theme tokens.

Do not hard-code:

```dart
Colors.black
Colors.white
Colors.blue
```

The calendar must work across:

- light themes
- dark themes
- warm paper themes
- future theme families

Selected and today states must remain distinguishable without relying solely on color.

---

# 74. Phosphor Icons

Use the application's canonical Phosphor icon system.

Potential icons:

- previous month
- next month
- calendar
- expand/collapse
- optional timeline navigation

Use a restrained weight.

Do not mix Material icons into the new implementation.

---

# 75. No Icon Overload

Do not place an icon beside every date.

Do not place link/arrow/calendar icons everywhere.

Typography should carry most of the interface.

---

# 76. Responsive Layout

Support:

- small phones
- large phones
- tablets
- desktop
- portrait
- landscape

On phones:

- calendar should remain comfortably tappable
- month controls should not crowd
- selected preview should remain compact

On tablets/desktop:

- use additional whitespace
- avoid making the calendar absurdly large

Do not simply scale the phone UI up.

---

# 77. Calendar Width

Keep the calendar aligned with the journal content hierarchy.

It can use the available content width, but do not stretch date cells excessively on very wide desktop displays.

Use sensible max-width/layout constraints.

---

# 78. Timeline Width

The journal timeline should use the existing Quiet Paper reading/content width.

Do not turn it into a giant full-width dashboard table.

---

# 79. Calendar Collapse on Desktop

Desktop may keep the calendar expanded longer because vertical space is available.

Phone may collapse it earlier.

Use responsive behavior, not one hard-coded rule for all devices.

---

# 80. State Management

Use the existing Riverpod/provider architecture.

Do not create a new global state-management system.

Conceptually:

```text
journalEntriesProvider
journalDatesForMonthProvider
selectedJournalDateProvider
calendarMonthProvider
```

or equivalents appropriate to the existing architecture.

---

# 81. Avoid Global Mutable State

Calendar state should belong to the All Entries feature.

Do not create a singleton containing:

```text
currentMonth
selectedDate
calendarExpanded
```

unless the existing architecture already has a well-defined navigation state mechanism.

---

# 82. Reactive Title Updates

If an open journal entry's title changes:

- its All Entries row should update
- selected preview should update when relevant

Do not require reopening All Entries.

---

# 83. Reactive Date Indicator Updates

If an entry is permanently deleted while its month is visible:

the indicator disappears.

If an entry is restored:

the indicator returns.

If a new journal note appears due to Today:

the indicator appears.

---

# 84. Do Not Rebuild the Entire Page

A title change should not rebuild the entire calendar.

A date indicator change should not rebuild unrelated timeline sections unnecessarily.

Keep rebuild boundaries localized.

---

# 85. Query Errors

If calendar date lookup fails:

- do not crash
- display the existing application error treatment
- keep All Entries usable
- allow retry where appropriate

If timeline loading fails:

- do not show raw SQL exceptions
- do not lose the current navigation state

---

# 86. No Fake Loading States

Do not show:

```text
Loading journal…
```

for every interaction.

Indexed local queries should feel immediate.

Use loading indicators only when genuinely necessary.

Keep them subtle and local.

---

# 87. No Network Dependency

All Entries and the Calendar must work offline.

Do not make network requests for:

- journal dates
- journal titles
- previews
- calendar state

Sync may happen separately through the existing background infrastructure.

---

# 88. Performance

The feature should remain responsive with very large journals.

Measure:

- month query latency
- selected-date lookup
- timeline initial load
- timeline pagination/load-more
- calendar rendering
- month switching
- timeline jump

Avoid:

- full archive scans
- full Markdown parsing for every calendar cell
- loading every note body at startup
- building thousands of widgets eagerly

---

# 89. Timeline Lazy Loading

If necessary, implement pagination/loading by month or bounded chunks.

The user should be able to scroll backward indefinitely without the entire history being loaded at once.

Choose the most natural approach for the current repository.

---

# 90. Calendar Query Caching

A small cache for recently viewed months is acceptable.

Do not create an unbounded cache.

Correct invalidation matters more than caching.

If a journal entry changes, the corresponding month's date set must update.

---

# 91. Date Query Cache Invalidation

When:

- journal entry created
- journal entry restored
- journal entry permanently deleted

invalidate/recompute the relevant month.

Do not unnecessarily invalidate every calendar month in the application.

---

# 92. On This Day Must Remain Separate

Do not use All Entries's calendar to replace On This Day.

Do not change On This Day's existing UI merely to support the calendar.

Both can share lower-level journal query utilities.

---

# 93. Reuse Existing Journal Repository

Do not create a second journal repository.

Extend the existing Journal V1 repository/service where necessary.

The architecture should have one source for journal queries.

---

# 94. Suggested Application APIs

Adapt to the actual existing Journal V1 code, but provide equivalents to:

```dart id="g38w2h"
Future<JournalEntry?> getJournalEntry(DateOnly date);

Stream<List<JournalDate>> watchJournalDatesForMonth(
  int year,
  int month,
);

Stream<List<JournalEntrySummary>> watchAllJournalEntries(...);

Future<void> rebuild/refresh journal indexes where required;
```

Use the repository's actual conventions.

Do not expose raw Drift queries to widgets.

---

# 95. Journal Entry Summary

For All Entries, create/use a lightweight summary model if necessary:

```text id="y90x7x"
JournalEntrySummary
├── id
├── journalDate
├── title
└── preview
```

Do not include heavy note content unnecessarily.

---

# 96. Grouping

Group the summaries into:

```text
year
  month
    entries
```

Prefer grouping at the query/application layer rather than repeatedly recalculating it inside the widget build method.

---

# 97. Stable Keys

Every timeline entry must use the note UUID as its stable identity.

Do not use title as a widget key.

Do not use array index as the only identity.

This is important when syncing or updating titles.

---

# 98. Calendar Cell Keys

Calendar cells should use a stable date-derived key:

```text
2026-09-16
```

or equivalent.

Do not use grid index as identity when it can cause subtle state problems.

---

# 99. Timeline Section Keys

Month sections should have stable keys based on:

```text
2026-09
```

This helps reliable scrolling and state preservation.

---

# 100. Jump-to-Date Architecture

Implement a robust mapping:

```text
journal date
→ journal note ID
→ timeline section/entry identity
→ scroll target
```

Do not rely on title matching.

---

# 101. Calendar Date With Multiple Historical Entries

The one-entry-per-day invariant means each date has at most one journal entry.

The calendar should therefore use a binary state:

```text
entry exists
```

not a count.

Do not display:

```text
3 entries
```

for a date.

---

# 102. Calendar Entry Preview Date

When previewing a selected historical entry:

show the actual journal date, not modification date as the primary heading.

Modification time may be secondary metadata.

---

# 103. Timeline Metadata

You may show:

```text
Tuesday · 9:42 PM
```

but this is secondary.

Do not make modified time the main chronological signal.

---

# 104. Journal Title Is User-Controlled

Do not auto-regenerate titles.

If an entry has a custom title:

```text
The day everything clicked
```

display that exact title.

If the title is empty, use the existing Note title fallback behavior.

---

# 105. Search Integration

Journal entries should continue to appear in global search.

Do not create a separate Journal search.

All Entries is only another way of browsing the same notes.

---

# 106. Note Links and Backlinks

Journal entries must remain ordinary notes.

They can:

- link to normal notes
- link to journal notes
- receive backlinks
- appear in the note-link picker

Do not special-case them unnecessarily.

---

# 107. Attachments and Documents

Journal entries continue supporting:

- images
- documents
- scanned PDFs
- generic attachments
- OCR
- web snapshots

No special Journal attachment system.

---

# 108. Scanner

Opening today's journal entry uses the normal EditorScreen.

The scanner remains available through the normal editor toolbar.

Do not duplicate scanner functionality.

---

# 109. Note History

All Entries must never create a history revision merely because the archive is opened or browsed.

Browsing is read/navigation state.

---

# 110. Export

Journal entries continue using existing export mechanisms.

Do not add special Journal export formats.

---

# 111. Backup/Restore

Do not serialize calendar UI state as part of journal content.

Restore journal notes and dates through the existing note/backup architecture.

---

# 112. Sync and Conflict

Do not create separate journal conflict logic unless required by the existing one-entry-per-day invariant.

Journal entries are existing notes.

Use the existing note identity/revision/conflict framework.

---

# 113. Conflict Copy Handling

If the existing conflict system supports “Keep Both,” do not allow it to violate the Journal V1 one-entry-per-date invariant.

Use the same policy already established by Journal V1.

All Entries must never crash because of duplicate journal-date conflict copies.

---

# 114. Import

If imported journal notes already support frontmatter/date classification through V1:

make them appear in All Entries and Calendar automatically.

Do not create an additional import system.

---

# 115. Timezone

Use the same local-calendar-date semantics established by Journal V1.

The calendar must present dates according to the user's local calendar.

Do not independently reinterpret timezone logic.

---

# 116. Leap Years

Calendar must handle:

- February 29
- February 28
- year transitions

correctly.

Add tests.

---

# 117. Locale

Respect existing app locale behavior.

Calendar month/day names should use appropriate locale formatting where supported.

Database dates remain normalized and locale-independent.

---

# 118. No Calendar Heatmap

Explicitly do not implement:

- writing streak
- activity intensity
- entry density
- word count heat
- mood colors

This calendar is for navigation.

---

# 119. No Habit Mechanics

Do not add:

- checkmarks for completing a day
- missed-day indicators
- streak counts
- goals
- reminders

A missing entry is simply a missing entry.

---

# 120. Visual Tone

The calendar should make the user want to browse their past.

Aim for:

- calm
- reflective
- editorial
- tactile
- spacious

Not:

- energetic
- gamified
- dashboard-like
- corporate
- productivity-oriented

---

# 121. Animation Quality

Use motion primarily to communicate state.

Good:

- date selection transition
- calendar expand/collapse
- month transition
- timeline jump
- temporary entry highlight

Avoid:

- bouncing dates
- rotating calendar icons
- exaggerated scaling
- decorative loops

---

# 122. Month Transition

When moving between months, use a subtle transition if practical.

Recommended:

- slight fade/slide
- 150–200ms
- no bounce

Do not animate if it causes layout instability.

Correctness and responsiveness take priority.

---

# 123. Calendar Accessibility Focus

When the month changes, ensure keyboard/screen-reader focus remains logical.

Do not leave focus on an element that no longer exists.

---

# 124. Timeline Accessibility

Each entry should expose:

```text
September 16, 2026
The day everything clicked
Tuesday
```

as an understandable accessible unit.

---

# 125. Test: No Journal History

Verify:

```text
All Entries
```

shows the empty state.

Calendar still renders.

No accidental journal creation occurs.

---

# 126. Test: Several Months

Create entries:

```text
2026-09-01
2026-08-31
2026-08-14
2026-06-03
```

Verify:

- grouping
- order
- calendar indicators
- month navigation

---

# 127. Test: Calendar Selection

Tap:

```text
September 14
```

Verify:

- selected state
- preview
- no navigation yet

Then tap preview.

Verify:

- existing EditorScreen opens

---

# 128. Test: Empty Calendar Date

Tap a date with no entry.

Verify:

- selected state
- “No journal entry”
- no creation
- no timeline jump

---

# 129. Test: Show in All Entries

Select an existing historical date.

Tap Show in All Entries.

Verify:

- calendar collapses appropriately
- timeline jumps correctly
- correct entry is visible
- temporary highlight appears

---

# 130. Test: Month Navigation

Navigate:

```text
January 2026
→ February 2026
→ March 2026
→ January 2027
```

Verify correct calendars and year changes.

---

# 131. Test: Current Month Return

Navigate years into the past.

Tap the current-month shortcut.

Verify the current month is restored.

---

# 132. Test: Timeline Scrolling

Scroll through a large journal.

Verify:

- smooth scrolling
- correct lazy loading
- no duplicate rows
- no jumping
- stable month headers

---

# 133. Test: Title Update

Open a journal entry and change:

```text
Old Title
```

to:

```text
New Title
```

Return to All Entries.

Verify the timeline/preview updates.

Journal date remains unchanged.

---

# 134. Test: Permanent Deletion

Permanently delete a journal entry.

Verify:

- row disappears
- calendar indicator disappears
- date shows no entry
- no stale selected preview
- date can later be recreated through Today if appropriate

---

# 135. Test: Restore

Move entry to Trash.

Restore it.

Verify:

- timeline returns
- calendar indicator returns
- title/metadata preserved

---

# 136. Test: Sync

Sync a journal entry from another device.

Verify:

- timeline updates
- calendar indicator updates
- entry opens correctly

---

# 137. Test: Protected Entry

Create a protected journal entry.

Verify:

- timeline does not leak protected body
- calendar selected preview does not leak protected body
- opening invokes existing unlock flow

---

# 138. Test: Backup/Restore

Backup and restore journal history.

Verify:

- dates
- titles
- content
- relationships
- Today
- All Entries
- On This Day

remain functional.

---

# 139. Test: Leap Year

Verify February 2024/2028 behavior.

Verify February 29 is displayed only in leap years.

---

# 140. Test: Locale Week Start

Where localization is supported, verify first weekday behavior follows existing locale conventions.

---

# 141. Test: Large Dataset

Use a realistic dataset:

```text
5,000+ normal notes
1,000+ journal entries
```

Verify:

- All Entries initial render remains responsive
- calendar remains responsive
- month lookup remains fast
- timeline does not eagerly instantiate 1,000 rows
- jump-to-date remains reliable

---

# 142. Test: Offline

Disable network.

Verify:

- All Entries works
- Calendar works
- historical entries open
- timeline works
- no runtime network requests are required

---

# 143. Test: Reduced Motion

Enable system reduced-motion behavior.

Verify the interface remains usable with minimal/no animation.

---

# 144. Testing Migration

Do not introduce another migration unless required by the existing Journal V1 schema.

If schema changes are needed:

- preserve all existing data
- test every supported migration path
- verify Journal V1 still works
- verify All Entries works after migration

---

# 145. Performance Profiling

Measure, rather than merely assume:

- calendar month query duration
- selected-date query duration
- initial timeline load
- timeline page/load chunk duration
- jump-to-entry behavior
- month switch duration

Do not claim performance improvements without evidence.

---

# 146. Error Recovery

If an entry referenced by a timeline row disappears:

- handle gracefully
- remove stale UI state
- do not crash

If a selected entry is deleted while selected:

- preview updates
- calendar updates
- timeline updates

---

# 147. No Raw Database Errors in UI

Never display:

```text
SqliteException(...)
```

or stack traces to users.

Use existing Quiet Paper error presentation.

---

# 148. No Duplicate Query Systems

Do not create:

```text
AllEntriesRepository
JournalCalendarRepository
JournalTimelineRepository
```

all separately querying the same notes table.

Reuse the existing Journal repository/application layer.

Separate components only when responsibilities genuinely differ.

---

# 149. No Duplicate Date Logic

Use the existing Journal V1 date utility.

Do not implement month/day calculations independently in:

- calendar
- timeline
- On This Day

---

# 150. No Duplicate Note Navigation

Use the existing note-navigation service/route.

Calendar, timeline, and On This Day should ultimately open the same note destination.

---

# 151. Final Acceptance Criteria

The feature is complete only when:

- [ ] Journal navigation contains Today, All Entries, On This Day.
- [ ] Today remains functional.
- [ ] On This Day remains functional.
- [ ] All Entries is fully implemented.
- [ ] All Entries is a chronological journal archive.
- [ ] Entries are grouped by month/year.
- [ ] Newest entries appear first.
- [ ] Only actual journal entries appear.
- [ ] Missing dates are not rendered as empty timeline entries.
- [ ] Calendar is integrated into All Entries.
- [ ] Calendar is not a fourth Journal destination.
- [ ] Calendar is not a separate journal page.
- [ ] Calendar shows the current month initially.
- [ ] Calendar correctly marks dates containing entries.
- [ ] Calendar correctly marks today.
- [ ] Calendar supports date selection.
- [ ] Date selection does not immediately navigate away.
- [ ] Selected date preview appears.
- [ ] Empty dates show “No journal entry” or equivalent.
- [ ] Existing journal entry preview can open the existing EditorScreen.
- [ ] Calendar month navigation works.
- [ ] Month/year navigation works.
- [ ] Current month shortcut works.
- [ ] Calendar can collapse.
- [ ] Calendar can expand.
- [ ] Calendar/timeline interaction works.
- [ ] “Show in All Entries” jumps to the selected entry.
- [ ] Timeline jump is robust with variable row heights.
- [ ] Target entry receives temporary highlight.
- [ ] Back navigation returns correctly.
- [ ] All Entries scroll position is preserved appropriately.
- [ ] Calendar month state is preserved appropriately.
- [ ] Calendar does not create empty entries.
- [ ] All Entries does not create today's entry automatically.
- [ ] User-controlled journal titles are respected.
- [ ] Journal dates remain independent of titles.
- [ ] Existing journal frontmatter remains authoritative.
- [ ] Existing note editor is reused.
- [ ] No JournalEditorScreen is introduced.
- [ ] Journal notes remain ordinary Notes.
- [ ] Tags continue working.
- [ ] Attachments continue working.
- [ ] Documents/scans continue working.
- [ ] OCR continues working.
- [ ] Note links/backlinks continue working.
- [ ] Search continues working.
- [ ] History continues working.
- [ ] Sync continues working.
- [ ] Trash behavior remains correct.
- [ ] Permanent deletion removes calendar/timeline state.
- [ ] Restore returns calendar/timeline state.
- [ ] Backup/restore remains correct.
- [ ] Protected journal entries do not leak content.
- [ ] Offline operation works.
- [ ] Theme integration is complete.
- [ ] Phosphor icons are used for new UI.
- [ ] Accessibility semantics are implemented.
- [ ] Reduced motion is supported.
- [ ] Responsive phone/tablet/desktop layouts work.
- [ ] Large datasets remain performant.
- [ ] Calendar does not eagerly load journal bodies.
- [ ] Timeline is lazy/efficient.
- [ ] No full archive scan occurs for every calendar interaction.
- [ ] No hard-coded demo dates/data remain.
- [ ] No placeholders remain.
- [ ] No TODO implementation remains.
- [ ] No raw database errors are exposed.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.
- [ ] Release build succeeds.

---

# 152. Required Final Engineering Report

After implementation, report:

## Existing Journal V1 integration

Explain exactly which existing Journal abstractions were reused.

## All Entries architecture

Explain how chronological entries are queried/grouped.

## Calendar architecture

Explain how calendar dates and entry indicators are queried.

## Timeline

Explain how lazy loading works.

## Calendar → timeline navigation

Explain how a selected date is located in the timeline without fragile pixel calculations.

## Calendar state

Explain selected date, visible month, and collapse/expand state.

## Database

List any schema/query/index changes.

## Performance

Provide measured results for:

- month query
- selected entry query
- timeline initial load
- jump-to-entry

## Security

Confirm protected notes and zero-knowledge behavior remain intact.

## Sync/trash/restore

Explain how the new page reacts to lifecycle changes.

## Testing

Report actual:

```bash
flutter analyze
flutter test
flutter build apk --release
```

results.

## Remaining limitations

Only report genuine limitations discovered during implementation.

---

# Final Design Principle

The Journal should now feel like three simple doors:

```text
JOURNAL

Today
```

> Where I write today.

```text
All Entries
```

> Everything I've written, over time.

```text
On This Day
```

> What I wrote on this date in previous years.

Inside **All Entries**, the calendar is simply another way of moving through that history.

The desired experience is:

```text
All Entries
        ↓
September 2026 calendar
        ↓
tap September 16
        ↓
“ The day everything clicked ”
        ↓
Show in All Entries
        ↓
timeline smoothly moves to September 16
        ↓
entry briefly highlights
        ↓
tap entry
        ↓
existing Quiet Paper Editor
```

The calendar should feel like a **quiet navigation instrument**, not a productivity dashboard.

The timeline should feel like a **personal archive**, not another Notes list.

And the entire feature should remain faithful to the core Quiet Paper principle:

> **The journal is still your notebook. The calendar simply helps you remember where you wrote.**