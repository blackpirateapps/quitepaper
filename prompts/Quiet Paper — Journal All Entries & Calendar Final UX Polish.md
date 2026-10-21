# Quiet Paper — Journal All Entries & Calendar Final UX Polish

You are working inside the existing **Quiet Paper Flutter application**.

The Journal feature has already been implemented and the current structure is:

```text
JOURNAL

Today
All Entries
On This Day
```

`Today` and `On This Day` are already implemented.

`All Entries` is also currently implemented with:

- an All Entries header
- a calendar
- chronological journal entries grouped by month
- entry indicators
- date selection
- entry preview/navigation

This task is a **production-quality visual, interaction, responsive-layout, and UX refinement pass** over the existing **All Entries + Calendar** implementation.

Do not rebuild the Journal architecture from scratch.

Do not create placeholder implementations.

Do not create mock data.

Do not create a second journal system.

Everything must use the real Quiet Paper data, existing Journal V1 architecture, existing Note model, existing EditorScreen, existing navigation, existing journal metadata/frontmatter, existing database queries, existing themes, and existing Phosphor icon system.

The goal is to make the current implementation feel **finished, deliberate, premium, calm, editorial, and unmistakably Quiet Paper**.

---

# 1. Current Problem

The current implementation is functional, but the UI shown in the provided screenshots has several problems:

1. On mobile, **“All Entries” appears twice**, indicating two overlapping/duplicated header layers.
2. The calendar occupies too much vertical space.
3. The calendar feels like a large generic card rather than an integrated part of the journal.
4. There are too many controls competing inside the calendar header.
5. The selected/today accent is too visually strong.
6. The timeline currently feels somewhat like a conventional list rather than an editorial journal archive.
7. Calendar and timeline hierarchy can be improved.
8. The overall layout needs to feel more cohesive between mobile and desktop/tablet.
9. The calendar should function as a **navigation tool**, not a separate calendar application.
10. The current design needs the refinement described below.

---

# 2. Core Product Model

The Journal remains:

```text
Today
All Entries
On This Day
```

Their roles are:

### Today

Open/create today's single journal entry.

### All Entries

Browse the complete journal chronologically.

### On This Day

View previous-year entries that occurred on today's month/day.

Do not change these product roles.

---

# 3. All Entries Must Remain the Main Archive

All Entries is the user's complete journal history.

It should answer:

> “What have I written over time?”

It should not behave like the normal Notes list.

Do not add:

- sort controls from the normal Notes list
- arbitrary filters
- Smart View controls
- productivity metrics
- streaks
- heatmaps
- mood states
- word counts
- writing statistics

The archive is intentionally temporal.

---

# 4. Critical Fix: Remove the Duplicate Mobile Header

The supplied mobile screenshot currently shows two instances of:

```text
All Entries
```

and two toolbar/header layers.

This must be fixed completely.

There must be exactly **one visible All Entries page header**.

The intended mobile header is approximately:

```text
☰   All Entries                  ⌕   Calendar
```

or the equivalent using the existing Phosphor icon system.

The exact layout should follow existing Quiet Paper navigation conventions.

Do not solve this by merely adding padding or overlaying one header.

Find the actual source of the duplicate header and remove the redundant layer.

Do not break:

- navigation drawer
- back navigation
- search
- calendar toggle
- tablet layout
- desktop 3-pane layout

---

# 5. Desktop Header

On desktop/tablet, All Entries should live naturally inside the existing application shell.

Do not create an additional application-level toolbar if the existing shell already provides the appropriate navigation/header structure.

The conceptual structure should be:

```text
Sidebar
│
├── All Entries pane
│     ├── All Entries header
│     ├── Calendar
│     └── Timeline
│
└── Existing note/editor pane
```

Do not duplicate application chrome.

---

# 6. All Entries Header Controls

The All Entries header should contain only useful actions.

Primary:

```text
All Entries                         Search   Calendar
```

Potential actions:

- Search
- Calendar toggle

Do not include normal Notes-list controls such as:

- sort
- filter
- arbitrary more menus

unless the existing architecture requires them for another legitimate function.

The Journal archive is intentionally simpler.

---

# 7. Calendar Is Not a Fourth Navigation Item

Do not add:

```text
Calendar
```

to the Journal sidebar.

The structure must remain:

```text
Today
All Entries
On This Day
```

The calendar belongs inside All Entries.

---

# 8. Calendar Should Be an Integrated Navigation Surface

The calendar should feel like part of All Entries rather than a standalone application component.

The conceptual flow is:

```text
All Entries
    ↓
calendar
    ↓
select date
    ↓
inspect entry
    ↓
jump/open entry
```

It is a navigation aid over the chronological archive.

---

# 9. Remove the Giant Calendar Card

The current implementation wraps the calendar in a large rounded card.

Do not preserve that visual treatment if it continues to make the calendar look like a separate widget.

Prefer an integrated editorial surface:

```text
September 2026                     ‹   ›

M    T    W    T    F    S    S

      1    2    3    4    5    6
      ·         ·

 7    8    9   10   11   12   13
           ·
```

Use:

- spacing
- subtle divider
- typography
- Quiet Paper paper surface

rather than a large bordered card.

A very restrained background treatment is acceptable if required by the existing theme, but avoid the appearance of a generic DatePicker component.

---

# 10. Calendar Should Be More Compact

The current mobile calendar is too tall and dominates the screen.

Reduce:

- vertical padding
- excess whitespace
- control spacing
- oversized date row spacing

while preserving comfortable touch targets.

The calendar should make room for the journal archive below it.

The user should see meaningful timeline content without scrolling past a giant calendar.

---

# 11. Calendar Default State

When entering All Entries:

- show the current month
- visually identify today
- do not automatically select today
- do not automatically create today's journal entry
- do not automatically open a journal note

The distinction is:

```text
Today = visually identifiable
Selected date = user-selected
```

Do not conflate those states.

---

# 12. Today Visual State

Today should be recognizable but subtle.

Preferred treatment:

- thin rounded outline
- minimal semantic accent
- no huge filled circle
- no heavy badge

If today has an entry, add the normal entry indicator.

Conceptually:

```text
      ┌───┐
      │ 1 │
      └───┘
        ·
```

Keep the treatment restrained.

---

# 13. Selected Date Visual State

The selected date should be visually distinct from today.

Do not use a visually heavy filled circle.

Use:

- thin outline
- soft semantic surface
- subtle accent

If selected date = today:

combine the states gracefully instead of stacking multiple loud treatments.

---

# 14. Entry Indicator

A date with an entry receives a tiny understated indicator.

Example:

```text
16
·
```

A date without an entry:

```text
16
```

All entries use the same indicator.

Do not encode:

- word count
- activity
- mood
- importance
- writing frequency
- streak

One dot means:

> There is a journal entry here.

---

# 15. Do Not Use Calendar Heatmaps

Do not use different colors/intensities to represent activity.

Do not show:

- light/medium/dark entry density
- contribution-grid behavior
- writing streak colors

The calendar is a navigation tool.

---

# 16. Do Not Color Weekends

Do not visually distinguish Saturday/Sunday by default.

Avoid business-calendar aesthetics.

Use the same typography for all days.

---

# 17. Weekday Labels

Use subtle weekday labels:

```text
M   T   W   T   F   S   S
```

or localized equivalents.

They should be:

- small
- muted
- visually secondary

Do not let them dominate the calendar.

---

# 18. Month Header

Simplify the month header.

Preferred:

```text
‹       September 2026       ›
```

The month title is centered.

Previous/next month controls sit at the edges.

Avoid putting several unrelated controls around the month title.

---

# 19. Separate Calendar Toggle From Month Navigation

The calendar expansion/collapse control should not compete with month navigation.

The All Entries header owns:

```text
Calendar
```

The calendar itself owns:

```text
‹   September 2026   ›
```

Each control has one clear responsibility.

---

# 20. Calendar Collapse

The calendar must support a compact/collapsed state.

Expanded:

```text
All Entries                  Search  Calendar

September 2026
calendar

selected date preview
```

Collapsed:

```text
All Entries                  Search  Calendar

September 2026
```

followed by:

```text
SEPTEMBER 2026
timeline...
```

The calendar can automatically collapse as the user scrolls the archive where appropriate, but do not make the behavior aggressive or disorienting.

---

# 21. Calendar Expansion Animation

Use restrained motion:

- approximately 180–250ms
- ease-out
- no bounce
- no excessive scaling

Respect reduced-motion settings.

The timeline should remain visually stable while the calendar expands/collapses.

Do not cause unnecessary scroll jumps.

---

# 22. Mobile Calendar Priority

On mobile, prioritize the timeline.

After a user has begun reading the archive, the calendar should not permanently consume most of the screen.

A compact month header is enough while the user is scrolling.

The calendar should be easy to reopen.

---

# 23. Desktop Calendar Priority

On desktop/tablet, the calendar may remain expanded for longer because more vertical space is available.

However, it should still be visually restrained.

Do not make the calendar disproportionately large simply because there is available space.

---

# 24. Date Selection Must Not Navigate Immediately

When a user taps:

```text
September 16
```

the calendar should:

1. select September 16
2. update visual state
3. show a selected-date preview

It should NOT immediately navigate into the note.

This preserves browsing.

---

# 25. Selected-Date Preview

When an entry exists:

```text
SEPTEMBER 16

The day everything clicked

Tuesday · 9:42 PM

I finally got the scanner working...
```

The selected-date preview should feel like part of the calendar and archive.

Do not make it a large floating card.

It should be an editorial content block.

---

# 26. Preview Typography

The title should be the dominant element.

The date should be secondary.

Do not make the title look like metadata.

Preferred conceptual hierarchy:

```text
September 16, 2025

The day everything clicked

Tuesday · 9:42 PM
```

The user's title must remain untouched.

---

# 27. No Entry Selected

If the user selects an empty date:

```text
SEPTEMBER 16

No journal entry
```

Do not create anything.

Do not show a large illustration.

Do not encourage streak behavior.

---

# 28. Do Not Create Arbitrary Journal Entries From Calendar

The calendar is for browsing.

Only the existing **Today** flow creates today's journal entry.

Do not add arbitrary historical-date creation in this refinement pass.

---

# 29. Open Entry

Tapping the selected entry preview opens the existing note editor.

No:

- JournalViewerScreen
- JournalEntryScreen
- CalendarEntryScreen

Use the normal existing note navigation flow.

---

# 30. “Show in All Entries”

When a historical date is selected, provide an appropriate action to locate that date in the timeline.

Conceptually:

```text
Show in All Entries →
```

When used:

1. calendar collapses or reduces appropriately
2. timeline moves to the corresponding entry
3. target entry becomes visible
4. target receives a temporary subtle highlight
5. user remains on All Entries

Do not open another page.

---

# 31. Timeline Scroll Must Be Robust

Do not use:

```text
index * fixedRowHeight
```

or another fragile pixel approximation.

Entries have variable:

- title lengths
- previews
- typography
- metadata

Use stable item identifiers and the current list/sliver architecture.

If necessary:

```text
journal date
→ note UUID
→ timeline item key
→ locate/scroll
```

The solution must remain reliable across different themes/font settings.

---

# 32. Timeline Highlight

After jumping to an entry:

briefly emphasize that entry.

Use:

- subtle surface transition
- slight accent
- restrained duration around 800–1500ms

Then return to normal.

Do not leave permanent selection styling.

---

# 33. All Entries Timeline Design

Make the timeline feel like a **personal archive**, not a NoteList clone.

Recommended:

```text
SEPTEMBER 2026
──────────────────────────

01
Tue

September 1, 2026
Finally fixed the scanner
This is a note I'm writing...

AUGUST 2026
──────────────────────────

31
Mon

August 31, 2026
Working on note linking
I am supposed to...
```

The exact typography should follow the existing Quiet Paper design system.

Do not copy this layout literally if an existing component already provides a better implementation.

---

# 34. Editorial Timeline Feel

The archive should use:

- typography
- whitespace
- thin dividers
- subtle vertical relationships
- restrained metadata

Avoid:

- card grids
- large rounded list tiles
- heavy shadows
- excessive borders

The timeline should look like pages/entries in a personal archive.

---

# 35. Date Typography

The date should be visually meaningful.

A useful hierarchy is:

```text
01
Tue
```

as the date block,

and:

```text
September 1, 2026
Title
Preview
```

as the entry information.

The date block may use the accent only when the entry is the current/target state.

Otherwise keep it neutral.

---

# 36. Vertical Accent Line

The current implementation uses an accent vertical line beside the active entry.

Keep the concept only if it remains visually subtle.

Recommended:

- neutral line for normal entries
- semantic accent line for selected/highlighted entry

Do not make every entry look “selected.”

---

# 37. Month Section Headers

Month headings should have generous breathing room.

Example:

```text
SEPTEMBER 2026

────────────
```

then entries.

When moving to:

```text
AUGUST 2026
```

provide more space above the heading.

Do not compress sections together.

---

# 38. Calendar → Timeline Visual Relationship

The calendar and timeline should clearly belong to the same archive.

For example:

```text
September 16 selected
        ↓
September 2026
        ↓
16 — The day everything clicked
```

Use the same semantic date formatting and accent treatment.

Do not make the calendar and timeline look like two unrelated widgets.

---

# 39. Calendar Month Navigation

Previous/next month:

- one month at a time
- correct year boundaries
- correct month lengths
- correct leap years

Do not alter journal data.

Changing calendar month only changes navigation state.

---

# 40. Month/Year Picker

Make the month/year title tappable if appropriate.

Allow jumping to distant history through a compact month/year selector.

Conceptually:

```text
2026

January     February     March
April       May          June
July        August       September
October     November     December
```

This is navigation only.

Do not allow it to modify journal dates.

---

# 41. Year Selector Refinement

If implementing a separate year selector, subtly indicate years containing journal entries.

Example:

```text
2026 ·
2025 ·
2024
2023 ·
2022
2021
2020 ·
```

The dot means:

> This year contains at least one journal entry.

Do not show entry counts.

Do not create a contribution graph.

This feature is optional only if it can be implemented cleanly with the existing architecture.

---

# 42. Current-Month Shortcut

When the user has navigated far into the past, provide a compact way to return to the current month.

For example:

```text
Today
```

or equivalent.

This must simply return the calendar to the current month/date context.

It must NOT create today's journal entry.

---

# 43. Calendar State Preservation

If the user:

```text
September 2026
→ August 2024
→ select August 14
→ open entry
→ Back
```

the All Entries experience should return to the previously viewed context.

Preserve where practical:

- calendar visible month
- selected date
- expanded/collapsed state
- timeline scroll position

Do not unexpectedly reset everything to the current month.

---

# 44. Timeline Scrolling Should Not Synchronize Aggressively With Calendar

Do NOT automatically update the calendar's selected date on every timeline scroll event.

The calendar is a navigation tool.

Once the user manually scrolls the timeline:

- the selected calendar date can remain as the last explicit selection
- the timeline should remain independent

Do not create expensive bidirectional synchronization that makes the UI confusing.

---

# 45. Entry Indicators Should Appear Immediately After Creation

If the user creates today's journal entry:

the relevant calendar date should gain its indicator when the data changes.

Example:

```text
1
```

→

```text
1
·
```

A tiny fade/scale animation is acceptable.

Do not require app restart.

---

# 46. Entry Indicator Animation

When an entry is newly created, restored, or otherwise becomes visible for a month:

the indicator may animate subtly:

- 120–200ms
- fade/scale
- no bounce

If this causes complexity, prioritize correctness over animation.

---

# 47. Calendar Month Transition

When switching months:

use a subtle transition if practical:

- slight fade
- slight horizontal slide
- 150–200ms

Do not use:

- 3D rotations
- page flips
- exaggerated parallax

Respect reduced motion.

---

# 48. Calendar Grid Stability

Calendar grid must correctly handle:

- 28-day months
- 29-day February
- 30-day months
- 31-day months
- 4/5/6 week calendar layouts

Avoid large layout changes where practical.

Do not allow invalid dates.

---

# 49. Locale

Follow existing Quiet Paper locale/date conventions.

The week should begin on the appropriate localized weekday.

Do not hard-code Monday/Sunday if the existing application supports locale-specific behavior.

---

# 50. Calendar Month/Year Representation

The persisted journal date remains locale-independent.

Calendar presentation may be localized.

Do not store presentation-format dates.

---

# 51. All Entries Empty State

When no journal entries exist:

```text
ALL ENTRIES

No journal entries yet.
```

The calendar can still display the current month.

Do not automatically create today's entry.

Do not display a large illustration.

---

# 52. Sparse Journal History

If entries exist only on a few dates:

the calendar simply shows those dates with indicators.

Do not compensate for sparse journaling with:

- warnings
- missed days
- streak language
- empty-day markers

Missing entries are normal.

---

# 53. First Entry / Oldest History

Do not add a large celebratory block.

The archive should naturally end at the oldest entry.

A subtle first-entry feeling is acceptable:

```text
December 3, 2021

The beginning
```

but do not add gamification.

---

# 54. Long-Term History

Design for years of journal history.

The data layer must handle:

- hundreds of entries
- thousands of entries
- long gaps between entries

without loading all note bodies at once.

---

# 55. All Entries Timeline Must Be Lazy

Use lazy rendering/querying where appropriate.

Do not eagerly instantiate thousands of journal-entry widgets.

Do not load full Markdown for every historical row.

Use lightweight summaries.

---

# 56. Timeline Row Data

A row should only require:

- note ID
- journal date
- user-controlled title
- lightweight preview
- necessary metadata

Do not load:

- attachments
- PDFs
- images
- OCR blobs
- heavy document data

until the user opens the note.

---

# 57. Calendar Data Query

For each visible month, query only the dates necessary to render entry indicators.

Do not parse every journal body's frontmatter just to determine whether an entry exists.

Use the existing journal-date index/schema.

---

# 58. Selected Date Query

When a calendar date is selected:

perform a targeted journal-entry lookup.

Do not reload the entire journal database.

---

# 59. Backlink/Note Link Compatibility

Do not modify note-link architecture.

Journal entries remain ordinary notes.

The new All Entries page and calendar must not interfere with:

- `qp://note/<UUID>`
- backlinks
- link picker
- note navigation

---

# 60. Attachments/Scanner Compatibility

Opening a journal entry still opens the normal EditorScreen.

The normal editor continues to support:

- images
- PDFs
- scanned documents
- attachments
- OCR
- links

Do not create journal-specific attachment/editor logic.

---

# 61. Protected Journal Entries

Protected journal notes must follow existing security policy.

Do not expose protected body content in:

- timeline previews
- calendar selected-date previews
- year/month browsing metadata

Use existing note protection behavior.

Opening the entry uses the existing unlock mechanism.

---

# 62. Trash

All Entries should follow the existing Journal V1 trash behavior.

Recommended:

- active journal entries appear normally
- trashed entries are excluded from the normal archive
- calendar indicators reflect active entries
- restore brings the entry back

Do not create duplicate entries because of trash state.

---

# 63. Permanent Delete

When a journal entry is permanently deleted:

- its timeline row disappears
- its calendar indicator disappears
- selected preview updates
- the date becomes empty
- that date may later be used by Today again

No stale cached UI.

---

# 64. Sync

When sync changes journal entries:

- All Entries reacts
- calendar indicators update
- titles/previews update
- no manual refresh should be necessary

Do not introduce a separate journal sync system.

---

# 65. Backup/Restore

After restore:

- journal entries appear normally
- calendar indicators work
- All Entries works
- historical navigation works

Calendar state itself is not backed up as note data.

---

# 66. History

Browsing the calendar must never create note history revisions.

Opening a journal entry must not mark the note dirty unless the user edits it.

Existing editor dirty-state protections remain intact.

---

# 67. Frontmatter

Do not modify the existing Journal V1 frontmatter format.

All Entries reads existing journal metadata through the established application layer.

Do not rewrite frontmatter during browsing.

Do not append calendar information to note Markdown.

---

# 68. User-Controlled Titles

All Entries must use the user's actual title.

Example:

```text
September 1, 2026

Finally fixed the scanner
```

The date is metadata.

The title is user-controlled.

Changing the title must not change journal date.

---

# 69. No Date-In-Title Assumption

Do not assume:

```text
title = September 1, 2026
```

Journal entries may have any title.

Empty titles use existing note fallback behavior.

---

# 70. Phosphor Icons

Use the application's canonical Phosphor icon system.

Use restrained icons for:

- search
- calendar toggle
- previous month
- next month
- expand/collapse
- optional current-month shortcut

Do not introduce Material icons.

Do not add icons to every calendar day.

---

# 71. Icon Weight

Follow the existing Quiet Paper icon-weight rules.

Do not mix arbitrary icon weights.

Controls should feel cohesive.

---

# 72. Theme System

Use existing semantic theme tokens.

Do not hard-code colors.

Verify:

- light paper
- dark paper
- all current theme families
- system appearance

The calendar should not become visually loud in dark mode.

---

# 73. Accent Color Restraint

The current implementation uses the accent strongly in:

- selected calendar day
- selected timeline entry
- vertical timeline line
- Today indicator
- sidebar selection

Reduce the overall visual dominance.

Use accent primarily for:

- selected state
- today state
- active/important interaction feedback

Normal dates/entries should remain neutral.

---

# 74. No Permanent Accent on Every Entry

Do not color every journal date or timeline entry with the accent.

The accent should communicate state.

---

# 75. Mobile Layout

Mobile should have exactly one All Entries header.

Recommended:

```text
☰   All Entries                 ⌕  Calendar
```

then:

```text
September 2026
calendar
```

then:

```text
SEPTEMBER 2026
timeline
```

No duplicate title.

No duplicate hamburger.

No generic shell toolbar + page toolbar combination.

---

# 76. Desktop Layout

Desktop should use the existing 3-pane structure.

The middle All Entries pane contains:

```text
All Entries
calendar
timeline
```

The right pane continues showing the selected/open note using the existing application behavior if currently supported.

Do not change unrelated pane behavior.

---

# 77. Tablet Layout

Use available width intelligently.

Do not simply enlarge mobile controls.

The calendar should breathe more but remain restrained.

---

# 78. Calendar Width

Do not let the calendar become excessively wide on large displays.

Date cells should retain comfortable proportions.

Use sensible content-width constraints.

---

# 79. Timeline Width

Use the existing Quiet Paper content/read width.

Do not create a full-width dashboard timeline.

---

# 80. Calendar Search Interaction

The existing All Entries search action should remain available.

Search and Calendar are separate controls.

Do not merge them into a giant search/calendar overlay.

---

# 81. Calendar Accessibility

Each date must have accessible semantics.

Examples:

```text
September 16, 2026, journal entry exists
```

or:

```text
September 16, 2026, no journal entry
```

Today/selected states must also be exposed.

Do not rely on color alone.

---

# 82. Calendar Touch Targets

Keep visual numbers compact but make the actual hit areas comfortably touchable.

Do not require users to tap directly on the numeral.

---

# 83. Timeline Accessibility

Each entry should expose enough context to be meaningful:

```text
September 16, 2026
The day everything clicked
Tuesday
```

Do not make the screen reader announce implementation IDs.

---

# 84. Keyboard Support

Desktop/tablet keyboard support should include where practical:

- Tab
- arrows
- Enter/Space
- Escape for selectors

Do not interfere with the existing editor shortcuts.

---

# 85. Reduced Motion

Honor system reduced-motion preferences.

With reduced motion:

- calendar expansion can be instant
- month transitions can be disabled
- timeline highlight can be shortened
- entry-indicator animations can be disabled

Functionality remains unchanged.

---

# 86. State Management

Use the existing Riverpod/provider architecture.

Do not introduce a new global state system.

Keep calendar UI state separate from journal data:

```text
CalendarState
├── visibleMonth
├── selectedDate
└── expanded/collapsed
```

Journal data remains in the existing repository/application layer.

---

# 87. Stable Keys

Use stable identities.

Calendar cells:

```text
YYYY-MM-DD
```

Timeline entries:

```text
note UUID
```

Month sections:

```text
YYYY-MM
```

Do not use list indices as permanent identity.

---

# 88. Reactive Updates

All Entries must react appropriately to:

- note creation
- title changes
- deletion
- restoration
- sync
- conflict resolution

The user should not need to restart the app.

---

# 89. Avoid Full-Screen Reloads

A calendar date change must not rebuild:

- the entire note/editor pane
- unrelated sidebar sections
- the complete timeline if not required

Use localized updates.

---

# 90. Scroll Position Preservation

Calendar expansion/collapse and navigation should preserve the user's reading position where practical.

Do not:

```text
collapse
→ rebuild
→ scroll to top
```

or similar.

---

# 91. Timeline Jump Context

When Show in All Entries is used:

the target month should remain the current calendar context.

Example:

```text
September 2024
```

not suddenly:

```text
September 2026
```

after returning from the editor.

---

# 92. Year/Month Navigation Should Not Change Data

All month/year controls are presentation/navigation state.

They never:

- create entries
- modify dates
- modify titles
- modify Markdown

---

# 93. Calendar Should Not Modify Journal Frontmatter

Browsing the calendar does not touch frontmatter.

Selecting a date does not touch frontmatter.

Opening All Entries does not touch frontmatter.

---

# 94. Performance

The final implementation must remain performant with large histories.

Measure:

- calendar month query
- selected-date query
- initial All Entries load
- timeline chunk loading
- jump-to-entry
- month switching

Avoid full-table body scans.

---

# 95. Offline

All Entries and Calendar must work fully offline.

They must not require:

- sync
- network
- cloud queries

The local database is authoritative for the UI.

---

# 96. Caching

Small bounded caches are allowed if profiling justifies them.

Do not create:

- unbounded month caches
- full-note caches
- unnecessary global state

Correct invalidation is more important than aggressive caching.

---

# 97. Error Handling

If a calendar/timeline query fails:

- do not crash
- do not show raw SQLite/Drift errors
- use existing Quiet Paper error UI
- preserve navigation state

Do not create a broken blank page.

---

# 98. Loading States

Do not show large loading screens for tiny local queries.

The user experience should feel:

```text
tap month
→ new calendar
```

not:

```text
Loading journal...
```

for every action.

Use only localized progress treatment when genuinely necessary.

---

# 99. Calendar Design Language

The final visual result should feel like:

> a paper calendar distilled into typography and tiny ink marks.

Use:

- clean numbers
- thin outlines
- subtle dots
- warm surfaces
- understated typography

Do not copy the appearance of:

- Google Calendar
- Apple Calendar
- Material DatePicker
- habit trackers

---

# 100. Timeline Design Language

The final archive should feel like:

> a personal literary archive.

Use:

- date as structure
- title as content
- preview as context
- month headings
- whitespace
- thin separators

Avoid conventional card-stack UI.

---

# 101. Optional Tiny “Entry Exists” Animation

When a date gains an entry:

```text
16
```

becomes:

```text
16
·
```

A tiny fade/scale animation is acceptable.

Do not let this become distracting.

---

# 102. Current Month Shortcut Behavior

When jumping back to the current month:

- visible month becomes current month
- calendar selection is sensible
- timeline is not automatically opened
- Today still behaves independently

Do not create today's entry.

---

# 103. Calendar and All Entries Persistence

When the user leaves and later returns to All Entries, preserve navigation context where practical.

However, do not persist ephemeral calendar state to the database.

Use normal UI/navigation state mechanisms.

---

# 104. Timeline Entry Preview

Keep previews short.

Use the existing note-preview/snippet implementation.

Do not load entire Markdown bodies.

Do not expose implementation URIs like:

```text
qp://note/...
qp://asset/...
```

in the visible preview.

---

# 105. User Content Is Never Modified for Presentation

Never append:

```md
## Calendar
```

or:

```md
## Journal
```

to the note body.

The All Entries timeline and Calendar are presentation-layer features.

---

# 106. No Separate Journal Data Model

Continue using existing journal/note architecture.

Do not create:

```text
JournalTimelineEntry
```

as another authoritative note representation.

A lightweight summary model is allowed for efficient UI queries, but it remains derived.

---

# 107. Final UX Flow

The finished experience should feel like:

```text
JOURNAL

Today
All Entries
On This Day
```

User opens:

```text
All Entries
```

and sees:

```text
All Entries                      ⌕  Calendar

        September 2026
      ‹               ›

   M    T    W    T    F    S    S

        1    2    3    4    5    6
        ·        ·

   7    8    9   10   11   12   13
                 ·

  14   15   16   17   18   19   20
        ·
```

User taps:

```text
16
```

The date becomes selected.

Below the calendar:

```text
SEPTEMBER 16

The day everything clicked

Tuesday · 9:42 PM

I finally got the scanner working...

Open entry →
Show in All Entries →
```

No immediate navigation occurs.

The user chooses:

```text
Show in All Entries
```

The calendar collapses.

The timeline smoothly moves to:

```text
SEPTEMBER 2026

16
The day everything clicked
...
```

The row receives a subtle temporary highlight.

The user taps it.

The normal Quiet Paper Editor opens.

They press Back.

They return to the same All Entries context.

This is the desired interaction.

---

# 108. Explicitly Do Not Add

Do NOT add:

- a fourth Calendar sidebar item
- a separate Calendar page
- a separate Journal editor
- a separate Journal viewer
- panes
- split views
- graph visualization
- mood tracking
- sleep tracking
- location
- weather
- streaks
- word-count heatmaps
- productivity indicators
- gamification
- calendar heatmaps
- automatic date creation
- automatic journal creation from empty calendar dates
- AI journal features
- arbitrary journaling prompts

---

# 109. Testing Requirements

Add or update tests for:

## Calendar generation

- January
- February
- leap year
- 28/29/30/31-day months
- month boundaries
- year boundaries
- locale week start

## Date indicators

- date with entry
- date without entry
- today
- selected date
- today + selected + entry

## Month navigation

- previous month
- next month
- January ↔ December
- year change

## Selected preview

- entry exists
- no entry
- protected entry
- deleted entry
- restored entry

## Timeline

- grouping
- ordering
- lazy loading
- stable keys
- correct title
- correct date

## Jump behavior

- selected date → timeline
- target correctly located
- target highlight
- correct month preserved

## State preservation

- navigate to historical month
- open entry
- Back
- calendar month preserved
- timeline context preserved

## Reactive changes

- create entry
- edit title
- delete
- restore
- sync

---

# 110. Testing: Duplicate Header

Add a widget test ensuring mobile All Entries renders exactly one page header/title instance.

The test should detect regressions where the application shell and All Entries page both render duplicate headers.

---

# 111. Testing: No Automatic Creation

Verify:

### Opening All Entries

does NOT create today's entry.

### Selecting empty date

does NOT create a journal entry.

### Opening a month

does NOT create a journal entry.

Only:

```text
Today
```

creates today's entry.

---

# 112. Testing: Performance

Test with a realistic dataset:

```text
5,000+ normal notes
1,000+ journal entries
```

Verify:

- All Entries remains responsive
- calendar month lookup is bounded
- timeline is lazy
- opening the page does not load every journal body
- jump-to-date remains reliable

---

# 113. Testing: Protected Notes

Verify protected journal entries do not leak body content through:

- timeline
- calendar preview
- selected date
- year/month navigation

---

# 114. Testing: Trash

Verify:

```text
active journal entry
→ Trash
→ restore
```

and:

```text
active journal entry
→ permanent delete
```

correctly update:

- timeline
- calendar indicator
- selected preview

---

# 115. Testing: Sync

Verify a synced journal note changes:

- timeline
- calendar indicator
- title/preview

without requiring restart.

---

# 116. Testing: Offline

Disable network and verify:

- All Entries works
- calendar works
- timeline works
- historical entry opens
- no network call is required

---

# 117. Testing: Themes

Verify the finished design in every current Quiet Paper theme.

Check:

- today outline
- selected state
- entry indicator
- timeline highlight
- calendar text
- dividers
- month/year selector
- empty states

---

# 118. Testing: Accessibility

Verify:

- calendar date semantics
- selected state
- today state
- timeline row semantics
- month navigation labels
- expand/collapse labels

---

# 119. Testing: Reduced Motion

Verify reduced-motion mode removes/minimizes animation without breaking:

- month navigation
- calendar collapse
- timeline jumping
- selection

---

# 120. Implementation Quality

Do not use hacks such as:

```dart
Future.delayed(...)
```

to hide layout problems.

Do not use:

```dart
Opacity(0)
```

to hide duplicate headers while leaving their layout/navigation side effects.

Do not hard-code screen heights.

Do not hard-code one device's dimensions.

Do not hard-code sample dates.

Do not hard-code sample titles.

Do not use fixed row heights for timeline navigation.

Do not create fake calendar entries.

---

# 121. Code Organization

Use the existing Quiet Paper architecture.

Possible conceptual responsibilities:

```text
JournalRepository
    journal queries

JournalService
    journal use cases

AllEntriesController/Provider
    archive state

CalendarController/State
    visible month / selected date

AllEntriesTimeline
    chronological archive

JournalCalendar
    date navigation

SelectedJournalPreview
    selected-date UI
```

Adapt names to the actual project.

Do not introduce unnecessary abstractions if the current implementation already has suitable equivalents.

---

# 122. No Unrelated Refactors

Do not rewrite:

- normal Notes list
- sidebar
- editor
- scanner
- attachments
- sync
- themes

unless a small integration change is absolutely necessary.

Keep this task focused on:

**Journal → All Entries → Calendar + Timeline**

---

# 123. Final Visual Quality Check

Before declaring completion, inspect the UI specifically at:

### Mobile portrait

The screen must not show duplicate:

```text
All Entries
```

The calendar must not dominate the screen.

### Mobile landscape

Controls must not overflow.

### Tablet

Calendar should have breathing room without becoming oversized.

### Desktop

All Entries must integrate cleanly into the existing 3-pane layout.

---

# 124. Final Acceptance Criteria

The implementation is complete only when:

- [ ] The duplicate mobile All Entries header is completely removed.
- [ ] There is exactly one All Entries header per application context.
- [ ] Calendar is integrated into All Entries.
- [ ] Calendar is not a fourth Journal navigation item.
- [ ] Giant generic calendar card treatment is removed or substantially refined.
- [ ] Calendar is visually lighter and more editorial.
- [ ] Calendar consumes less vertical space.
- [ ] Calendar toggle is located logically in the All Entries header.
- [ ] Month navigation is separate from calendar expansion.
- [ ] Calendar opens to current month.
- [ ] Today is visually identifiable.
- [ ] Today is not automatically selected.
- [ ] Dates with entries receive a subtle indicator.
- [ ] Dates without entries remain visually clean.
- [ ] Selected date is visually distinct.
- [ ] Selected date does not immediately navigate.
- [ ] Selected-date preview works.
- [ ] Empty selected date works.
- [ ] Entry preview opens existing EditorScreen.
- [ ] “Show in All Entries” navigation works.
- [ ] Timeline jump is robust and not fixed-height based.
- [ ] Target entry receives temporary highlight.
- [ ] Calendar can collapse.
- [ ] Calendar can expand.
- [ ] Calendar collapse does not cause major scroll jumps.
- [ ] Month navigation works.
- [ ] Month/year navigation works.
- [ ] Current-month shortcut works.
- [ ] Calendar state is preserved appropriately.
- [ ] Timeline scroll position is preserved appropriately.
- [ ] All Entries is chronological.
- [ ] Entries are grouped by month/year.
- [ ] Only actual entries appear.
- [ ] Missing dates do not become empty rows.
- [ ] Timeline feels editorial rather than card-based.
- [ ] Accent color is less dominant.
- [ ] Accent communicates meaningful states only.
- [ ] Phosphor icons are used.
- [ ] No new Material icons are introduced.
- [ ] Themes are fully respected.
- [ ] Dark mode works.
- [ ] Mobile layout works.
- [ ] Tablet layout works.
- [ ] Desktop 3-pane layout works.
- [ ] Accessibility is implemented.
- [ ] Reduced motion is implemented.
- [ ] Large journal histories remain performant.
- [ ] Calendar does not load full note bodies.
- [ ] Timeline is lazy/efficient.
- [ ] Search remains functional.
- [ ] Note links remain functional.
- [ ] Backlinks remain functional.
- [ ] Attachments remain functional.
- [ ] Scanner remains functional.
- [ ] OCR remains functional.
- [ ] History remains functional.
- [ ] Trash behavior remains correct.
- [ ] Restore behavior remains correct.
- [ ] Permanent deletion removes stale calendar/timeline state.
- [ ] Sync remains functional.
- [ ] Backup/restore remains functional.
- [ ] Protected journal notes remain private.
- [ ] No journal note is created merely by opening All Entries.
- [ ] No journal note is created by selecting an empty calendar date.
- [ ] No placeholder data remains.
- [ ] No hard-coded demo data remains.
- [ ] No TODO implementation remains.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.
- [ ] Release build succeeds.

---

# 125. Required Final Engineering Report

At completion, provide a concise report containing:

### Existing implementation inspected

Which Journal/All Entries components were reused.

### Duplicate-header root cause

What caused the mobile header duplication and exactly how it was fixed.

### Calendar redesign

What changed visually and why.

### Calendar behavior

How selection, month navigation, expansion, and selected previews work.

### Timeline

How entries are grouped, loaded, and navigated to.

### Calendar → timeline jump

How the implementation reliably locates entries without fixed row-height assumptions.

### State preservation

How month, selection, and timeline state are preserved.

### Performance

Provide actual measured results where practical.

### Regression safety

Explain compatibility with:

- editor
- note links
- backlinks
- attachments
- scanner
- OCR
- sync
- trash
- history
- backup/restore

### Tests

Report actual results for:

```bash
flutter analyze
flutter test
flutter build apk --release
```

Do not claim success without running the commands.

### Remaining limitations

Only report genuine limitations discovered during implementation.

---

# Final Design Principle

The final All Entries experience should feel like this:

```text
JOURNAL

Today
All Entries
On This Day
```

Then:

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


SEPTEMBER 2026

01
Tuesday

September 1, 2026
Finally fixed the scanner
This is a note I'm writing...


AUGUST 2026

31
Monday

August 31, 2026
Working on note linking
...
```

The calendar should feel like **a quiet paper calendar**.

The timeline should feel like **a personal archive**.

The date selection should feel like **marking a page**.

And navigating into an entry should simply return the user to the existing Quiet Paper editor.

Do not make Journal feel like another application inside Quiet Paper.

Make it feel like **Quiet Paper has learned how to remember when its pages were written**.