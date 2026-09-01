# Quiet Paper — Journal V1
## Production-Ready Implementation Specification

You are working inside the existing **Quiet Paper Flutter application**.

Implement **Journal V1** as a complete, production-quality feature.

This is not a prototype.

Do not create placeholders, mock data, fake screens, TODO implementations, temporary in-memory repositories, or a second “journal editor.”

The journal must integrate deeply and cleanly with the existing Quiet Paper architecture while remaining intentionally small.

Before writing code, read the repository's `HANDOFF.md` in full and inspect the existing implementations for:

- notes
- editor
- Markdown parsing
- frontmatter
- tags
- database/schema/migrations
- navigation
- sync
- note deletion/trash
- note history/versioning
- search
- note creation
- note-linking
- settings/theme system
- sidebar/navigation
- tests

Do not assume the existing architecture is identical to an earlier version of this specification. Inspect the current implementation and adapt to it.

---

# 1. Product Definition

Quiet Paper Journal is deliberately simple.

The product rule is:

> **Journal = at most one Quiet Paper note per calendar day.**

A journal entry is still a normal Quiet Paper note.

It uses:

- the existing editor
- existing Markdown representation
- existing note storage
- existing encryption
- existing sync
- existing search
- existing note-linking
- existing attachments
- existing scanner
- existing history/versioning
- existing export system

Journal does NOT get a separate editor.

Journal does NOT get a separate document model containing duplicated note content.

Journal does NOT become a mood tracker, habit tracker, productivity dashboard, or wellness application.

---

# 2. V1 Scope

Implement exactly these user-facing concepts:

```text
Journal

Today
On This Day
```

## Today

Clicking **Today** must:

1. Determine today's local calendar date.
2. Find the unique journal note for that date.
3. If it exists, open it in the existing note editor.
4. If it does not exist, create it using the existing note-creation infrastructure and open it in the existing editor.

There must never be more than one journal note for a given journal date.

## On This Day

Show previous journal entries that occurred on the same month/day as today.

Example:

```text
ON THIS DAY

September 1, 2025
A year ago

September 1, 2024
Two years ago

September 1, 2023
Three years ago
```

Selecting an entry opens that journal note in the existing note editor.

That is the V1 user-facing journal scope.

---

# 3. Explicitly Out of Scope

Do NOT implement:

- mood tracking
- sleep tracking
- location
- weather
- health data
- productivity scores
- streaks
- gamification
- daily goals
- habits
- journaling prompts
- AI-generated reflections
- AI summaries
- separate journal editor
- special journal viewer
- separate journal Markdown format
- journal-specific rich text
- calendar dashboard
- calendar heatmap
- journal statistics
- social journaling
- shared journals

Do not add features simply because they are common in other journal applications.

The feature must remain minimal.

---

# 4. Core Architectural Principle

A journal entry is a normal note plus journal metadata.

Conceptually:

```text
Note
├── id
├── title
├── body
├── tags
├── timestamps
├── ...
└── journal metadata
      └── journalDate
```

The exact schema must follow the existing database architecture.

Do not create:

```text
JournalEntry
```

that duplicates the entire Note model unless the repository has a compelling architectural requirement.

Prefer extending the existing Note model.

---

# 5. Canonical Journal Date

Introduce a stable journal-date concept.

The journal date is a **calendar date**, not a timestamp.

Conceptually:

```text
2026-09-01
```

not:

```text
2026-09-01T22:45:13+05:30
```

The journal date must represent the user's local calendar day.

Store it in a deterministic normalized representation compatible with the existing database architecture.

Recommended conceptual representation:

```text
journal_date = YYYY-MM-DD
```

or an equivalent strongly typed date representation if the existing database supports one cleanly.

Do not derive the journal date from `created_at`.

Creation timestamp and journal date are different concepts.

---

# 6. One-Entry-Per-Day Invariant

This is a critical invariant.

For journal notes:

```text
at most one journal note per journal date
```

The database must enforce this where practical.

Do not rely exclusively on:

```dart
if (query == null) create()
```

because two creation attempts could race.

For example:

```text
Tap Today
Tap Today again immediately
```

must not create two journal notes.

Use a unique database constraint/index or equivalent transactional mechanism.

The exact implementation should follow the existing database technology and migration conventions.

---

# 7. Creation Must Be Idempotent

Implement a single application-level operation conceptually equivalent to:

```dart
openOrCreateJournalEntry(DateTime date)
```

It should:

1. normalize the requested date
2. query for an existing journal entry
3. return it if found
4. otherwise create it atomically
5. handle a race where another operation created it first
6. return the existing/newly-created note
7. never create duplicates

Do not duplicate this logic inside the UI.

The UI should call one application-level operation.

---

# 8. Existing Editor Must Be Reused

This is mandatory.

When a user taps:

```text
Journal → Today
```

the app must open the **existing `EditorScreen` / existing editor flow**.

Do not create:

```text
JournalEditorScreen
```

Do not duplicate Markdown editing behavior.

Do not create journal-specific formatting.

Do not create another Markdown controller.

The journal entry should behave exactly like a normal note inside the editor.

---

# 9. User-Controlled Title

The user chooses the journal entry's title.

Do NOT force:

```text
September 1, 2026
```

to remain the title.

A newly created entry may receive an initial default title such as:

```text
September 1, 2026
```

but the existing editor must allow the user to change it normally.

Examples:

```text
A surprisingly productive day
Finally fixed the scanner
Tuesday
Thoughts on note linking
```

The journal date remains:

```text
2026-09-01
```

independent of the title.

Renaming the journal entry must never change its journal date.

---

# 10. Journal Frontmatter

Journal entries must contain application-managed frontmatter.

The exact frontmatter format must be aligned with the existing Quiet Paper frontmatter implementation.

Conceptually:

```yaml
---
journal: true
date: 2026-09-01
---
```

Use the existing frontmatter parser/serializer if one already exists.

Do NOT invent a second frontmatter parser.

Do NOT duplicate frontmatter parsing logic.

The application owns the journal-specific frontmatter fields.

The user owns the note's normal editable content and title.

---

# 11. Frontmatter Must Not Become User Friction

The user should not need to type or maintain:

```yaml
journal: true
date: ...
```

manually.

When creating a journal entry:

- the app creates the appropriate frontmatter
- the user immediately gets the normal editor
- the UI should not force the user to understand YAML

The frontmatter should be handled transparently by the application according to the existing frontmatter architecture.

---

# 12. Canonical Frontmatter Semantics

Define the exact journal markers clearly.

Recommended:

```yaml
journal: true
date: YYYY-MM-DD
```

Use a stable field name such as:

```text
journal
```

to identify the note as a journal entry and:

```text
date
```

for the journal date.

However, before finalizing these names, inspect the existing frontmatter specification and reuse its naming conventions if an appropriate equivalent already exists.

Do not introduce multiple competing representations.

---

# 13. Avoid Frontmatter Duplication

If a journal note already contains the application-managed journal metadata:

do not add another copy every time the note is edited.

For example, do not produce:

```yaml
---
journal: true
date: 2026-09-01
journal: true
date: 2026-09-01
---
```

The serializer/parser must be idempotent.

---

# 14. User-Edited Frontmatter

Inspect the existing Quiet Paper frontmatter behavior.

Journal-managed fields must remain authoritative.

If the user manually edits or removes:

```yaml
journal: true
date: ...
```

the application must have deterministic behavior.

Recommended approach:

- journal metadata is application-managed
- journal UI operations restore/maintain canonical values
- malformed journal metadata should not crash parsing
- do not silently create duplicate frontmatter blocks

Choose behavior consistent with the existing frontmatter implementation.

Document the rule.

---

# 15. Do Not Put Journal Metadata in the Title

Do not encode the date into the title as the primary journal identity.

Bad:

```text
title = "2026-09-01"
```

as the only identifier.

Good:

```text
title = user-controlled
journalDate = 2026-09-01
```

The date must remain stable even when the title changes.

---

# 16. Note Type / Journal Identification

Introduce an explicit journal classification only if the current Note architecture requires it.

Do not infer journal-ness from:

- title
- tag
- creation timestamp
- folder
- note text

Journal identity should come from application-managed metadata/frontmatter and/or a properly modeled database field.

Do not require users to add `#journal`.

The Journal navigation must know which notes are journal entries independent of user tags.

---

# 17. Recommended Database Representation

Adapt to the current database design.

One valid architecture is:

```text
notes
 ├── ...
 ├── journal_date nullable
 └── ...

UNIQUE(journal_date)
WHERE journal_date IS NOT NULL
```

Another may be appropriate depending on the existing SQLite/Drift architecture.

The important invariant is:

```text
journal_date = NULL
    → normal note

journal_date = YYYY-MM-DD
    → journal note
```

and:

```text
UNIQUE(journal_date)
for journal notes
```

Do not blindly apply this exact SQL if it conflicts with the existing schema.

Use the architecture that is safest for the current codebase.

---

# 18. Database Migration

Add the smallest necessary migration.

The migration must:

- preserve all existing notes
- preserve all existing tags
- preserve note relationships
- preserve timestamps
- preserve encryption metadata
- preserve sync state
- preserve trash state
- preserve versions
- add journal capability safely

Existing notes must NOT accidentally become journal entries.

After migration:

```text
existing notes → journal_date = null
```

unless they are explicitly identified as journal entries through a pre-existing supported journal format.

---

# 19. Journal Indexing

Add appropriate indexing for:

```text
journal_date
```

Queries must be efficient.

Common operations:

```text
find journal entry for date
find entries matching month/day
```

must not require scanning every note body.

---

# 20. Today Query

Implement a single application-level operation to resolve today's journal entry.

Conceptually:

```text
getJournalEntry(date)
```

The query should use the journal-date field/index.

Do not search Markdown text for the date.

Do not search titles.

Do not use fuzzy search for this.

---

# 21. Today's Date

Use the device's current local date.

Do not use UTC date directly.

Correctly account for local timezone boundaries.

For example, if local time is:

```text
00:15
```

the journal should already represent the new local calendar day.

Normalize the date through one centralized date utility.

Do not scatter:

```dart
DateTime.now()
```

with ad hoc date truncation throughout the application.

---

# 22. Timezone Rule

Journal entries represent local calendar dates.

Once a journal entry is created for:

```text
2026-09-01
```

that journal date must remain that date.

Do not retroactively change it because the user later changes timezone.

However, inspect the application's existing timezone/date semantics and ensure this behavior is compatible with them.

---

# 23. Today UI

The Journal section should be extremely small.

Recommended navigation:

```text
JOURNAL

Today
On This Day
```

Do not introduce a dashboard between Today and the editor.

Clicking Today should take the user directly to the editor.

No “Journal Home” page.

---

# 24. Today Creation Behavior

First-time Today behavior:

```text
Tap Today
↓
No entry exists
↓
Create today's journal note
↓
Open existing editor
↓
Cursor/title focus follows normal note-creation behavior
```

Do not display a separate journal onboarding screen.

Do not make the user confirm:

> “Create today's journal entry?”

The action itself is explicit.

---

# 25. Today Existing Entry Behavior

If today's entry already exists:

```text
Tap Today
↓
Open existing note in EditorScreen
```

Do not create a duplicate.

Do not recreate frontmatter.

Do not reset title.

Do not reset cursor/scroll state unnecessarily.

---

# 26. On This Day

Implement a dedicated Journal → On This Day view.

Its purpose:

> Show journal entries from previous years that share today's month/day.

For:

```text
2026-09-01
```

query:

```text
month = 9
day = 1
year < 2026
```

and exclude today's entry.

---

# 27. On This Day Must Use Journal Date

Do not use:

```text
created_at.month
created_at.day
```

for matching.

Use the journal date.

This matters because the user's journal date is independent of when the note was technically created.

---

# 28. On This Day Ordering

Display entries in reverse chronological order by year/date.

Example:

```text
September 1, 2025
September 1, 2024
September 1, 2023
September 1, 2022
```

Newest previous year first.

Use deterministic ordering.

Do not randomly sort by note modification time.

---

# 29. On This Day Should Not Include Future Dates

Only:

```text
year < current journal year
```

should appear.

Do not include future dates, even if malformed data exists.

---

# 30. Leap-Day Handling

Handle February 29 correctly.

On a non-leap year:

```text
March 1, 2026
```

does not automatically imply an “On This Day February 29” result.

For February 29:

- if today is February 29, show February 29 entries from previous leap years
- otherwise there is no February 29 “today”

Do not invent a Feb 28/Mar 1 fallback unless explicitly chosen later.

Add tests.

---

# 31. On This Day UI

Do not make it a giant calendar.

Prefer a simple editorial list:

```text
ON THIS DAY

September 1, 2025
A year ago

A surprisingly productive day...

────────────────────

September 1, 2024
Two years ago

I finally started...

────────────────────

September 1, 2023
Three years ago

...
```

Use the existing Quiet Paper list/detail patterns.

---

# 32. On This Day Preview

The list may show lightweight existing note metadata and a short preview.

However:

- do not decrypt protected content merely to render a preview if existing security rules prohibit it
- do not load huge note bodies unnecessarily
- do not create a separate journal-preview model that duplicates Note

Use the existing note preview/snippet infrastructure where appropriate.

---

# 33. Protected Journal Entries

Journal entries follow the same security model as ordinary notes.

If a journal entry is password protected:

- On This Day must respect that protection
- do not expose protected body content
- use the existing title/metadata policy
- tapping the entry must use the existing unlock flow

Do not create a special journal bypass.

---

# 34. Trashed Journal Entries

Journal entries can be moved to Trash like ordinary notes.

Decide behavior according to existing Trash semantics.

Recommended:

- Today should not open a trashed entry as the active journal entry
- if today's journal entry is in Trash, Today may offer the normal recovery behavior if the application's current trash architecture supports it
- do not silently create a second active journal entry if a trashed journal entry with today's date still exists unless the data model explicitly permits replacing/restoring it

The one-entry-per-date invariant must remain carefully defined.

A safe implementation is:

> A journal date can have one journal record regardless of trash state.

Then Today can detect that today's entry is trashed and offer:

```text
Restore today's journal entry
```

rather than creating a duplicate.

Follow the existing Trash UX and lifecycle conventions.

---

# 35. Permanently Deleted Journal Entries

If today's journal entry is permanently deleted:

the journal date becomes available again.

Today may then create a new journal note for that date.

No stale journal-index record may remain.

Existing permanent-deletion cleanup must remain intact.

---

# 36. Journal + Note Linking

Journal entries are normal notes.

Therefore:

- journal entries may link to normal notes
- journal entries may link to other journal entries
- normal notes may link to journal entries
- backlinks should work normally
- the `qp://note/<UUID>` linking system must remain unchanged

Do not build a special journal linking system.

---

# 37. Journal + Tags

Journal entries are ordinary notes.

Users may add/edit/remove tags through the existing editor/tag UI.

Do not automatically add:

```text
#journal
```

unless the existing product specification already requires it.

Journal identity must not depend on tags.

---

# 38. Journal + Search

Journal notes should appear in existing global search because they are ordinary notes.

Do not create a separate journal-only search engine.

Optionally, the search system may expose journal metadata in the future, but V1 should simply make journal notes searchable like normal notes.

Search privacy guarantees remain unchanged.

---

# 39. Journal + History

Journal entries use the existing note history/versioning system.

Do not create:

```text
JournalHistory
```

Use existing note versioning.

Changing the title or body must create normal note revisions according to the current editor/history rules.

Journal date must remain stable across revisions.

---

# 40. Journal + Attachments

Journal entries must support all normal note attachments.

Do not restrict:

- images
- PDFs
- scanned documents
- generic encrypted files
- OCR
- web snapshots
- other existing resources

The existing attachment/document architecture continues to work normally.

---

# 41. Journal + Scanner

A journal note should be able to use the scanner exactly like any other note.

Do not build a journal scanner.

Do not alter document storage simply because the parent note is a journal note.

---

# 42. Journal + Sync

Journal entries must sync using the existing note synchronization architecture.

Do not create a separate journal sync protocol.

The journal classification/date is note metadata and must participate correctly in synchronization.

Because the canonical note body is encrypted, journal metadata must obey the existing privacy rules.

Do not introduce plaintext journal body/date data into the cloud beyond what the current architecture explicitly permits.

---

# 43. Journal Metadata and Zero-Knowledge Architecture

Inspect where note metadata is currently plaintext vs encrypted.

The new journal fields must be handled consistently with existing security design.

Do not accidentally put protected journal content into plaintext server storage.

Do not introduce a server-side plaintext journal index.

If journal date needs synchronization, use the same secure metadata strategy already used by Quiet Paper.

Do not compromise the zero-knowledge architecture.

---

# 44. Journal + Conflict Resolution

Journal entries must continue using the existing note conflict-resolution infrastructure.

A conflict must not result in two journal entries for the same journal date unless the application's conflict system has a formally defined “Keep Both” semantic.

This is important.

For example:

```text
Device A → journal 2026-09-01
Device B → journal 2026-09-01
```

Both devices are editing the same journal entry, not independently creating two legitimate entries.

Use the existing note identity and sync/conflict mechanisms.

Do not create separate journal records merely because edits occurred on different devices.

---

# 45. Conflict “Keep Both” Edge Case

The existing conflict system may support “Keep Both.”

Determine how this interacts with the one-entry-per-day journal invariant.

Recommended behavior:

- preserve the primary journal note for the date
- if the conflict resolver creates a conflict copy, the copy must not silently become a second journal entry with the same journal date
- either clear the journal classification from the conflict copy or follow an explicitly defined conflict-copy policy

Do not allow the database uniqueness invariant to crash conflict resolution.

Choose the safest behavior consistent with the existing conflict architecture and document it.

---

# 46. Import Behavior

Normal Markdown import should NOT automatically turn an arbitrary imported note into a journal entry merely because it contains words resembling journal metadata.

Only valid, explicitly recognized application-managed journal frontmatter should classify a note as a journal entry.

If imported frontmatter uses valid Quiet Paper journal metadata:

- validate it
- normalize it
- enforce one-entry-per-date
- handle collisions deterministically

If two imported files claim the same journal date:

do not silently create duplicate journal entries.

Use the existing import conflict/error semantics.

---

# 47. Export Behavior

Journal entries remain normal notes.

Do not create a special `.journal` format.

For canonical Quiet Paper/full-fidelity export:

preserve the journal metadata/frontmatter according to the existing export architecture.

For ordinary Markdown export:

preserve valid Markdown/frontmatter semantics according to existing exporter behavior.

Do not mutate the original note for export.

---

# 48. Backup and Restore

Journal notes must survive `.qpbackup` backup/restore.

Restore must preserve:

- note UUID
- journal date
- journal classification
- title
- body
- tags
- revisions
- attachments
- documents
- OCR
- encryption metadata
- sync lifecycle metadata as appropriate

After restore:

```text
Today
```

must resolve the correct journal entry.

On This Day must find restored historical entries.

---

# 49. Journal Navigation Location

Integrate Journal into the existing sidebar/navigation architecture.

Recommended:

```text
JOURNAL

Today
On This Day
```

Use the existing sidebar grouping conventions.

Do not create a separate application shell.

Do not add another navigation stack unless the current architecture requires it.

---

# 50. Today Item State

Today can optionally display subtle state.

For example:

```text
Today
```

with a tiny indicator when today's journal entry exists.

But do not turn this into a productivity badge.

A subtle:

```text
•
```

is enough, or omit the indicator entirely.

Do not display:

```text
0/1
```

or word counts unless already part of the normal note UI.

---

# 51. On This Day Empty State

If there are no previous entries for today's date:

do not show a large sad illustration.

Use a quiet message:

```text
ON THIS DAY

Nothing from this date yet.
```

Optionally:

> Your first entry here will appear next year.

Keep this extremely subtle.

---

# 52. On This Day Date Formatting

Use the existing Quiet Paper date-formatting utilities.

Example:

```text
September 1, 2025
```

with:

```text
A year ago
```

if the existing date utilities support it.

Do not introduce inconsistent date formats.

Respect locale where the app already supports locale-aware formatting.

The database representation remains normalized and locale-independent.

---

# 53. Relative-Year Labels

If the current date is September 1, 2026:

```text
September 1, 2025
1 year ago
```

```text
September 1, 2024
2 years ago
```

For older entries:

```text
5 years ago
```

Do not use inaccurate relative timestamps such as:

> 365 days ago

because leap years exist.

Use year difference based on calendar year.

---

# 54. Future-Proof Date Queries

Do not implement On This Day by:

```text
date LIKE "%-09-01"
```

if that prevents index use.

Prefer the most efficient approach supported by the database.

If journal_date is stored as normalized `YYYY-MM-DD`, query based on:

- month/day extraction through indexed strategy where appropriate
- generated columns/indexes if justified
- bounded date ranges per year
- an appropriate auxiliary month/day representation if performance requires it

The implementation should remain fast with thousands or tens of thousands of notes.

Do not overengineer prematurely.

Measure/query-plan where useful.

---

# 55. Recommended On This Day Data Model Optimization

If querying month/day directly from a text date would be inefficient, consider a derived local field such as:

```text
journal_month
journal_day
```

or an indexed normalized lookup representation.

However:

- do not introduce redundant authoritative data without reason
- the canonical journal date remains authoritative
- derived values must be recoverable/rebuilt

Use the simplest efficient design compatible with the existing schema.

---

# 56. Reactive Updates

If the user creates today's journal entry while the Journal navigation remains visible:

the Today state should update appropriately.

If a journal entry is:

- edited
- trashed
- restored
- permanently deleted

the Journal views should react correctly.

Do not require a full application restart.

Use the existing reactive database/provider patterns.

---

# 57. Editor Exit Behavior

After creating today's journal note and returning from the editor:

Today should resolve to the same note.

Do not accidentally create a second note because the first creation was not immediately indexed.

Ensure the journal creation transaction and reactive state are coherent.

---

# 58. Scroll Position

Because Journal uses the existing editor:

do not implement separate journal scroll behavior.

Use existing note editor state preservation.

Returning to a journal entry should behave like returning to any other note.

---

# 59. Journal Entry Titles in On This Day

Show the user-controlled title prominently.

Example:

```text
September 1, 2025
The day everything started
```

Do not assume the title is the date.

If title is empty, use the existing Quiet Paper note title fallback behavior.

Do not manufacture a special journal title.

---

# 60. Do Not Create a Journal Tag

Do not automatically add `#journal`.

Journal identity should remain independent.

Users who want a `#journal` tag can create one themselves.

This prevents the tag system from being polluted by application metadata.

---

# 61. Do Not Create a “Journal Folder”

Do not model Journal as a folder.

Journal is a view over notes.

The same note can still participate in:

- tags
- smart views
- search
- backlinks
- pinned state
- archive
- history
- attachments

without being moved into a special folder.

---

# 62. Interaction With Archive

A journal entry remains a journal entry if archived unless the existing product rules explicitly say otherwise.

However, Today should follow the normal note lifecycle.

If an archived journal entry exists for today:

- decide whether Today opens it directly or offers unarchive based on the current Quiet Paper archive semantics
- do not silently create a duplicate journal entry

Follow the existing archive behavior consistently.

---

# 63. Interaction With Pinning

Journal entries may be pinned normally.

Pinning does not change journal date or classification.

No special journal pin behavior is required.

---

# 64. Interaction With Smart Views

Journal notes should remain eligible for normal Smart View filtering.

If the existing filter system supports note-type metadata, add journal status there only if naturally compatible.

Do not create a separate Smart View implementation.

---

# 65. Interaction With Note Links

Ensure `qp://note/<UUID>` continues to work for journal notes.

Backlinks to journal notes must work.

Journal notes can appear in the note-link picker normally.

No special filtering is needed in V1.

---

# 66. Frontmatter Parsing Must Remain Compatible With Markdown

Do not break:

- headings
- links
- images
- tables
- checklists
- code blocks
- blockquotes
- note links
- document links
- attachment links

because of journal frontmatter.

The parser must preserve existing source/offset semantics.

The editor must continue to work normally.

---

# 67. Frontmatter Visibility in Editor

Inspect the current Quiet Paper editor/frontmatter behavior.

Journal metadata should not become visually intrusive.

If existing frontmatter is treated as metadata rather than normal visible content, follow that behavior.

Do not suddenly place raw YAML in front of the user's journal writing unless the current application intentionally exposes frontmatter.

Integrate with the existing implementation.

---

# 68. Application-Owned Frontmatter Mutation

If the existing editor allows normal body edits independently from frontmatter:

ensure journal operations update only the managed metadata portion.

Do not rewrite the entire note body unnecessarily.

Do not change line endings or unrelated Markdown formatting solely because a journal field changed.

Preserve canonical Markdown as faithfully as possible.

---

# 69. Title Handling With Frontmatter

The user's title remains the actual note title under Quiet Paper's existing model.

Do not duplicate the title into frontmatter just for journaling.

If the current frontmatter system already stores title metadata as part of import/export, follow its existing conventions.

Do not add redundant fields.

---

# 70. Search Privacy

Journal frontmatter must obey existing search indexing/privacy policies.

Do not accidentally expose protected journal content.

If the existing FTS system strips or indexes frontmatter specially, integrate journal metadata appropriately.

Search must continue to behave correctly.

---

# 71. Performance

The Journal feature must remain cheap.

Today:

- one indexed date query
- one note open
- no full journal scan

On This Day:

- one bounded indexed query
- lightweight metadata retrieval
- no loading of every journal body

Do not fetch all journal entries and filter them in Dart when SQLite can perform the query efficiently.

---

# 72. Caching

Do not create an unnecessary global journal cache.

Use the existing reactive database/query layer.

Only add memoization if profiling shows it is useful.

Correctness comes first.

---

# 73. Concurrency

Protect the creation path against:

- rapid repeated taps
- double navigation
- two UI listeners triggering creation
- app lifecycle events
- simultaneous sync pull
- simultaneous restore/import where applicable

The same journal date must resolve to the same note.

Never create duplicates.

---

# 74. Sync Race

Example:

```text
Device A:
Today → creates journal note

Device B:
syncs the same account shortly afterward
```

The existing sync identity/revision model must preserve the unique journal note rather than creating a duplicate.

If the current sync model requires additional deterministic metadata merging, implement it safely.

Do not solve sync duplication by deleting whichever note happens to be newer without understanding ownership/revision semantics.

---

# 75. Journal Date Conflicts

If two records somehow exist with the same journal date due to pre-existing data or migration:

do not crash.

Create a deterministic recovery strategy.

Recommended:

1. identify the canonical record based on stable existing note identity/revision rules
2. preserve content rather than deleting data
3. resolve duplicate journal classification safely
4. leave the other note as a normal note or conflict copy according to the existing architecture
5. log the recovery without logging note content

Do not silently destroy user writing.

---

# 76. Migration/Repair Utility

Because the one-entry-per-day invariant is important, implement an internal consistency check that can detect duplicate journal dates.

Conceptually:

```text
validateJournalIntegrity()
```

This does not need to be a user-facing feature.

It can be used by tests/debug tooling.

---

# 77. Rebuild/Repair Journal Metadata

If appropriate to the existing architecture, add a safe internal utility to:

```text
rebuildJournalIndex()
```

or:

```text
validateAndRepairJournalMetadata()
```

Only do this if it naturally fits the current system.

Do not create unnecessary maintenance tooling.

The key requirement is that journal behavior can recover from stale derived/index data.

---

# 78. UI Consistency

Use existing Quiet Paper:

- typography
- icons
- spacing
- theme tokens
- sidebar groups
- navigation patterns
- note list rows

Do not create a new visual design language for Journal.

Journal should feel like it belongs in Quiet Paper.

---

# 79. Journal Icon

Use the application's new canonical Phosphor icon system.

Choose a restrained, appropriate journal/notebook icon.

Do not use a generic emoji.

Do not create a custom icon unless the existing icon system lacks an appropriate semantic option.

---

# 80. Today Icon

Use one consistent Phosphor icon or no icon, depending on the existing sidebar language.

Do not overload the Journal navigation with multiple decorative icons.

The hierarchy should remain typography-led.

---

# 81. On This Day Icon

Use a restrained historical/time/reference icon from the canonical Phosphor system.

Keep it visually secondary.

---

# 82. Responsive Design

Journal navigation must work correctly on:

- phone
- tablet
- desktop
- portrait
- landscape

The existing navigation architecture should determine whether Journal appears in the sidebar/drawer.

Do not create a separate navigation system.

---

# 83. Accessibility

Journal navigation items need accessible names:

```text
Journal
Today
On This Day
```

On This Day rows should expose:

```text
September 1, 2025, The day everything started, 1 year ago
```

where appropriate.

Do not rely only on visual date formatting.

---

# 84. Keyboard Navigation

On desktop/tablet:

- Tab should reach Journal items.
- Enter/Space should activate them.
- Existing navigation shortcuts must continue to work.

Do not interfere with editor keyboard shortcuts.

---

# 85. On This Day Interaction

Selecting an entry should open the existing note editor.

Do not open a read-only journal viewer.

Do not create a special detail screen.

The user should be able to immediately edit the historical journal entry.

---

# 86. Empty-State Interaction

If today's journal note does not exist:

Today should create it.

If On This Day has no historical entries:

simply explain that there are no matching previous entries.

Do not make the empty state actionable beyond what is naturally useful.

---

# 87. Journal Entry Creation Date vs Journal Date

Test cases must explicitly distinguish:

```text
created_at
updated_at
journal_date
```

A note created on September 2 can theoretically represent September 1 only if the application's creation mechanism/import logic explicitly allows that.

For normal Today flow:

```text
created_at ≈ today's timestamp
journal_date = today's local calendar date
```

However, the data model must not assume they are identical.

---

# 88. Editing Historical Journal Entries

Opening an On This Day entry must not change its journal date.

Editing:

```text
body
title
tags
attachments
```

must not move it to today's date.

Only an explicit application-level journal-date operation should change journal date, and V1 does not need to expose such an operation.

---

# 89. Moving a Normal Note Into Journal

Do NOT add a user-facing “Convert to Journal” action in V1 unless the existing architecture requires it.

Journal creation is driven by:

```text
Today
```

This keeps the initial feature simple.

---

# 90. Moving Journal Entry to Normal Note

Do not add this action in V1.

A journal entry remains a journal entry unless an explicit future feature is designed.

---

# 91. Deletion Semantics

Deleting a journal entry follows normal Quiet Paper note deletion.

Soft delete/trash:

- preserves the note according to existing trash semantics
- preserves necessary journal metadata

Permanent delete:

- permanently removes the note according to existing deletion semantics
- removes associated journal relationships/index entries
- frees the date for future Today creation

Do not create special deletion behavior beyond what is required by the one-entry-per-date invariant.

---

# 92. Frontmatter Security

If journal frontmatter contains a date or classification that is considered sensitive metadata under the existing security model:

follow the application's established encryption/storage architecture.

Do not assume that because it is frontmatter it is safe to persist plaintext on the server.

Inspect the current note encryption model first.

---

# 93. Sync Metadata

If journal date needs to participate in conflict detection or sync identity:

integrate it into the existing note revision/conflict metadata system.

Do not create an independent journal synchronization layer.

---

# 94. Testing — Date Logic

Add unit tests for:

- today's local date
- date normalization
- year/month/day extraction
- On This Day matching
- previous-year filtering
- leap-day behavior
- year boundaries
- timezone boundaries

Use deterministic fixed dates in tests.

Do not use `DateTime.now()` in tests where a fake clock is more appropriate.

---

# 95. Testing — One Entry Per Day

Test:

```text
create today
create today again
```

Expected:

```text
same note ID
```

not two notes.

Test concurrent creation where practical.

Verify database uniqueness prevents duplicate records.

---

# 96. Testing — Title Independence

Create journal note:

```text
journalDate = 2026-09-01
title = "A great day"
```

Rename:

```text
title = "Tuesday"
```

Verify:

```text
journalDate = 2026-09-01
```

unchanged.

---

# 97. Testing — Frontmatter

Test:

- correct creation
- correct parsing
- idempotent serialization
- missing journal fields
- malformed journal fields
- duplicate fields
- existing frontmatter
- unrelated frontmatter preservation

Do not let malformed metadata crash the application.

---

# 98. Testing — Today

Test:

### Existing entry

Today → existing note.

### Missing entry

Today → creates one → opens editor.

### Repeated tap

Today → same note.

### Trashed today's entry

Behavior follows chosen trash strategy.

### Permanently deleted today's entry

Today can create a new one.

---

# 99. Testing — On This Day

Create:

```text
2025-09-01
2024-09-01
2023-09-01
2025-08-31
2026-09-01
```

On September 1, 2026:

Expected:

```text
2025-09-01
2024-09-01
2023-09-01
```

Not:

```text
2025-08-31
2026-09-01
```

---

# 100. Testing — Leap Year

Create:

```text
2024-02-29
2020-02-29
```

On:

```text
2026-02-28
```

no February 29 results should be shown.

On:

```text
2028-02-29
```

previous February 29 entries should be shown.

---

# 101. Testing — Sync

Test:

1. Create journal note on device A.
2. Sync.
3. Pull on device B.
4. Verify B sees the same journal note for Today/history.
5. Edit on B.
6. Sync.
7. Verify A retains the same journal identity/date.

Do not create duplicates.

---

# 102. Testing — Conflict Resolution

Create simultaneous edits to the same journal entry.

Verify existing conflict resolution works.

Verify journal date remains associated with the correct canonical note.

Test the application's Keep Both behavior explicitly.

Do not allow database uniqueness constraints to cause an unhandled conflict failure.

---

# 103. Testing — Backup/Restore

Backup a notebook containing:

- today's journal entry
- several historical journal entries
- ordinary notes

Restore.

Verify:

- journal dates preserved
- titles preserved
- bodies preserved
- Today resolves correctly
- On This Day resolves correctly
- ordinary notes remain ordinary notes

---

# 104. Testing — Search

Verify journal entries appear in normal global search.

Verify protected journal content follows existing search privacy behavior.

Do not build a separate journal search.

---

# 105. Testing — Note Links

Create:

```text
Journal entry A → normal note B
Normal note B → journal entry A
```

Verify:

- links resolve
- backlinks resolve
- journal classification has no effect on linking

---

# 106. Testing — Trash

Test:

```text
Journal entry → Trash → Restore
```

and:

```text
Journal entry → Permanent Delete
```

Verify Today and On This Day behavior.

No duplicate date entries.

No stale journal index rows.

---

# 107. Testing — Import

Import valid journal Markdown.

Verify:

- journal metadata recognized
- correct date
- note opens normally
- On This Day sees it
- duplicate date collisions handled safely

---

# 108. Testing — Large Dataset

Create at least:

```text
5,000+ normal notes
1,000+ journal notes
```

where practical.

Verify:

- Today remains fast
- On This Day remains fast
- navigation does not scan all note bodies
- memory remains reasonable

---

# 109. Testing — UI

Widget tests should cover:

- Journal section visibility
- Today tap
- On This Day tap
- empty state
- historical entry rows
- opening historical notes
- responsive layout
- accessibility labels

Do not only test isolated widgets.

---

# 110. Testing — Editor Integration

Verify that creating/opening a journal entry:

- uses the existing editor
- title editing works
- Markdown editing works
- attachments work
- note links work
- autosave works
- undo/redo works
- history works

No journal-specific editor behavior should be necessary.

---

# 111. Testing — Migration

Test database migration from all currently supported schema versions.

Verify:

- no existing note data changes unexpectedly
- all existing notes remain normal
- journal_date is null for non-journal notes
- unique constraint/index is correctly created
- no duplicate-column errors
- no migration crashes

Follow the existing migration testing style in the repository.

---

# 112. Performance Instrumentation

Measure:

### Today lookup

Target:

```text
single indexed lookup
```

### Today creation

Target:

```text
single transactional lookup/create
```

### On This Day

Target:

```text
bounded database query
```

Do not measure only in a toy notebook.

Test against realistic data volumes.

---

# 113. Date Utility

Create/reuse one date utility responsible for:

- local calendar date normalization
- canonical storage formatting
- parsing
- same month/day comparison
- year difference

Do not duplicate date parsing logic across:

- sidebar
- journal repository
- database queries
- UI

---

# 114. Error Handling

If Today lookup fails:

show the existing application's standard error UI.

Do not create a journal note blindly after a database error.

If creation fails:

- do not navigate to a nonexistent note
- do not insert partial metadata
- preserve application state
- allow retry

If On This Day query fails:

show a non-destructive error/retry state.

The normal notes/editor application must remain usable.

---

# 115. No Fake Loading

Do not show a full-screen loading screen for a simple indexed Today lookup.

If the query is asynchronous, use the smallest appropriate state.

The expected experience is:

```text
Tap Today
→ open note
```

not:

```text
Loading journal…
Loading journal…
Loading journal…
```

---

# 116. Journal Navigation Should Feel Instant

Avoid unnecessary:

- network calls
- sync calls
- full note-list refreshes
- search-index rebuilds
- database scans

Today should be one of the fastest navigation actions in the application.

---

# 117. Existing Note Autosave

Journal notes must use the existing autosave implementation.

Do not create a journal autosave mechanism.

Ensure frontmatter metadata remains stable while autosave changes the body/title.

---

# 118. Existing Note Revision System

Changing a journal entry should use normal revision creation.

Do not create a new revision merely because the Journal navigation is opened.

Opening Today must be read/open behavior, not a content mutation.

---

# 119. Prevent Accidental Mutation on Open

Opening an existing journal note from Today must not:

- change title
- change body
- change journal date
- update content unnecessarily
- create a revision
- mark the note dirty

unless the user actually edits it.

Follow the existing editor dirty-state protections.

---

# 120. Frontmatter and Autosave Race Safety

Ensure application-managed journal frontmatter cannot be lost because of editor lifecycle behavior.

Especially handle:

- open note
- focus editor
- background app
- close editor
- sync update
- autosave

without accidentally stripping or duplicating journal metadata.

---

# 121. Existing Note Sync Retention

The current repository has already experienced issues where unedited editor instances could accidentally flush stale buffers during lifecycle events.

Do not repeat that pattern in Journal.

Opening Today's note must not mark it dirty merely because the editor was mounted.

Only actual edits should mutate it.

---

# 122. Journal and Note Title Preservation

The title is user-controlled.

Do not regenerate it every time Today is opened.

Default title generation happens only during initial creation.

Once the user changes it, it remains unchanged.

---

# 123. Journal Frontmatter Date Preservation

The journal date is immutable through normal editing.

Do not derive a new date during every save.

Do not write:

```text
date: DateTime.now()
```

on autosave.

The original journal date must remain stable.

---

# 124. Application-Owned Metadata API

Create a clean API for journal metadata rather than having UI code manipulate raw YAML strings.

Conceptually:

```text
JournalMetadata
 ├── isJournal
 └── date
```

and:

```text
JournalMetadataService
```

or equivalent.

Use existing frontmatter infrastructure.

The application layer should own serialization rules.

---

# 125. Separation of Concerns

Keep these responsibilities distinct:

```text
JournalRepository / Query
    Find journal notes.

JournalService / Use Cases
    open/create Today.
    query On This Day.

Frontmatter integration
    Encode/decode journal metadata.

Journal UI
    Render navigation/list.

Existing Editor
    Edit note.
```

Adapt names to existing architecture.

Do not put database queries directly in widgets.

---

# 126. Journal Query APIs

At minimum provide application-level operations equivalent to:

```text
getJournalEntry(date)
getOrCreateJournalEntry(date)
getOnThisDayEntries(month, day, beforeYear)
```

These should be testable independently of the UI.

---

# 127. Query Result Shape

For On This Day, load only information required to render:

- note ID
- title
- journal date
- lightweight preview metadata

Do not load unnecessary:

- attachments
- OCR
- large body blobs
- decrypted binary content

unless the existing note query architecture naturally includes them efficiently.

---

# 128. Reactive Provider Design

Use the existing Riverpod/provider architecture.

Potential conceptual providers:

```text
todayJournalProvider
onThisDayJournalProvider
```

or equivalent.

They must invalidate/update correctly when journal notes change.

Do not build a global mutable singleton.

---

# 129. Today Provider Semantics

Today should reflect:

```text
null
```

when no journal note exists.

The navigation action then performs create-if-missing.

Do not automatically create today's note merely because a provider was watched.

This prevents opening the app from silently creating blank journal entries.

---

# 130. No Automatic Empty Journal Creation on App Launch

Opening Quiet Paper must NOT create today's journal note.

Only explicit:

```text
Journal → Today
```

creates today's entry.

This prevents users from accumulating empty journal notes for days they never used the journal.

---

# 131. On This Day Must Not Create Anything

Opening:

```text
Journal → On This Day
```

is read/navigation behavior only.

It must never create a journal note.

---

# 132. Date Navigation Beyond Today

Do not add a full calendar in V1.

Do not add arbitrary date selection.

The only explicit journal navigation actions are:

```text
Today
On This Day
```

Historical entries are accessed from On This Day.

Future “browse by date” functionality can be added later.

---

# 133. Journal List Should Remain Small

On This Day could potentially have many entries.

Use a lazy list if necessary.

Do not build all historical rows eagerly.

However, for a typical journal history of a few decades, the number remains small; do not overengineer.

---

# 134. On This Day Entry Preview

Example:

```text
September 1, 2025
A surprisingly productive day

Finally got the scanner working...
```

Use the existing note-preview derivation rather than creating an unrelated preview format.

Ensure preview extraction does not expose internal `qp://` URIs or implementation details.

The existing app already has protections for rendering note snippets around image/document links; reuse those utilities where applicable.

---

# 135. Typography

Use the existing note/list typography.

The date should be visually secondary.

The title should be primary.

Example hierarchy:

```text
September 1, 2025
A surprisingly productive day
```

rather than:

```text
A surprisingly productive day
September 1, 2025
```

Choose the final hierarchy based on existing Quiet Paper list conventions.

---

# 136. Visual Design

Journal should feel like a **quiet timeline**, not a productivity dashboard.

Use:

- whitespace
- typography
- subtle dividers
- restrained Phosphor icons
- existing theme surfaces

Avoid:

- colorful calendar cells
- giant cards
- gradients
- progress bars
- streak badges
- gamification

---

# 137. “On This Day” Emotional Tone

The feature should communicate memory without becoming sentimental or gimmicky.

Good:

```text
ON THIS DAY

September 1, 2025
A surprisingly productive day

September 1, 2024
The week everything changed
```

Avoid:

> Look how much you've grown! 🎉

Keep Quiet Paper's voice understated.

---

# 138. Journal + Theme Engine

Ensure Journal uses:

- existing theme family
- existing appearance mode
- semantic colors
- semantic typography

Do not introduce journal-specific color palettes.

All existing themes must look coherent.

---

# 139. Journal + Phosphor

Use the newly established Phosphor icon system.

Do not mix Material Icons into the Journal feature.

Use stable application icon definitions rather than ad hoc direct package calls wherever the existing icon architecture provides a registry.

---

# 140. Desktop/Tablet

The same Journal navigation should work on:

- phone drawer/sidebar
- tablet sidebar
- desktop sidebar

On This Day should use the existing content area.

Do not create a separate window or pane.

---

# 141. No Pane Architecture

Explicitly do not implement:

- split panes
- side-by-side journal entries
- secondary journal viewer pane

Historical entries open normally in the existing editor.

---

# 142. No Dedicated Journal Viewer

There is exactly one editor experience.

Normal note:

```text
Note → EditorScreen
```

Journal note:

```text
Journal → Note → EditorScreen
```

Do not create journal-specific read-only UI.

---

# 143. Note List Interaction

Journal notes may appear in the normal notes list unless the existing product design deliberately filters them.

Do not automatically hide journal notes from All Notes without an explicit existing rule.

Journal is a view, not necessarily a separate storage area.

---

# 144. Journal View and Normal Notes View

A journal entry should remain discoverable through:

- All Notes
- Search
- Tags
- Note links
- Backlinks
- Journal

Do not trap journal entries inside Journal.

---

# 145. Smart View Compatibility

If the app's Smart Views support note metadata filtering, ensure journal metadata does not break them.

Do not automatically add journal-specific filters unless easy and natural.

---

# 146. Existing Note Deletion Cleanup

Integrate journal-date cleanup into the existing note deletion lifecycle.

Permanent delete must remove:

- note
- journal metadata/index
- normal relationships
- attachments/documents according to existing deletion rules

Do not leave a journal date reservation after permanent deletion.

---

# 147. Existing Sync Pull

When a journal note is pulled from another device:

- save it normally
- preserve journal metadata
- update local journal indexes
- trigger Journal view updates

Do not require the note to be opened first.

---

# 148. Existing Restore

When a journal note is restored:

- restore journal status/date
- update Journal views
- preserve note UUID

Do not create a new note for the historical entry.

---

# 149. Journal Date Integrity

Once stored, `journal_date` must be validated.

Valid:

```text
2026-09-01
```

Invalid:

```text
2026-13-55
foo
empty
```

Malformed data must not crash Journal.

Follow existing parsing/error semantics.

---

# 150. User-Facing Date Selection

Do not expose editing of journal date in V1.

The date is assigned by:

```text
Today
```

and historical entries retain their existing dates.

This prevents accidental duplicate-date complexity.

---

# 151. Import Duplicate Handling

If importing a journal note for a date that already exists:

do not create a second journal entry.

Use the existing import collision/conflict behavior.

Possible safe outcomes:

- import as normal note
- surface a conflict
- merge according to supported semantics

Choose based on the current import architecture.

Never silently overwrite the existing journal entry.

---

# 152. Frontmatter Migration

If Quiet Paper already has notes containing frontmatter, ensure introducing journal metadata does not break them.

The serializer must preserve unrelated fields.

Example:

```yaml
---
title: Example
tags:
  - reading
journal: true
date: 2026-09-01
custom: value
---
```

Existing fields must survive.

Do not discard user/application metadata.

---

# 153. Frontmatter Order

Use a deterministic field order for application-managed journal fields.

For example:

```yaml
journal: true
date: 2026-09-01
```

Keep formatting stable to avoid unnecessary note revisions.

Follow existing frontmatter serialization conventions.

---

# 154. Avoid Unnecessary Full-Body Rewrites

When creating a journal note, initialize the body/frontmatter using the existing note creation path.

When reading/editing existing journal notes, do not rewrite the entire Markdown document just to normalize metadata unless necessary.

This reduces revision noise and sync conflicts.

---

# 155. Sync Conflict Sensitivity

Because frontmatter is part of canonical Markdown in the existing model, avoid rewriting it on every open/save.

Otherwise merely opening Today's note could create a content revision/conflict.

Journal metadata should be inserted once during creation and thereafter remain stable.

---

# 156. Journal Metadata Changes

V1 does not need a user-facing operation to change the journal date.

Therefore, treat journal date as stable application metadata.

If future versions allow moving a journal entry to another date, design the schema so this can be added safely later.

---

# 157. Database Authoritative vs Frontmatter

If journal metadata exists both:

- in database columns
- in Markdown frontmatter

define which one is canonical for each purpose.

Recommended:

```text
database journal_date
→ efficient querying/invariant enforcement

Markdown frontmatter
→ portable/export-visible representation
```

But they must not drift.

Whenever one is created/restored/imported, ensure the other is consistent.

Do NOT casually duplicate state without reconciliation logic.

If the existing architecture has a better pattern, use it.

---

# 158. Reconciliation

Implement a deterministic consistency rule between database journal metadata and frontmatter.

For example:

### Normal local journal creation

Create both in one logical operation.

### Markdown import

Parse frontmatter → derive DB journal metadata.

### Database restore

Restore DB metadata and canonical Markdown consistently.

### Sync

Use the existing encrypted canonical note representation and ensure database projections remain synchronized.

Do not leave two competing values.

---

# 159. Journaling and Encryption

If the body is encrypted using the existing Quiet Paper note encryption architecture, journal frontmatter must not accidentally bypass that model.

The note must continue using the same encryption/storage pipeline as ordinary notes.

Do not introduce plaintext journal bodies or plaintext copies.

---

# 160. Production Error Recovery

If the application detects inconsistent journal metadata:

- do not crash
- do not delete note content
- log sanitized diagnostics
- prefer preserving the note
- repair/reconcile metadata deterministically where safe

User writing takes precedence over cosmetic metadata repair.

---

# 161. Code Quality

Production-quality requirements:

- null-safe
- typed
- immutable models where appropriate
- deterministic behavior
- clear repository/application boundaries
- no hidden global state
- no duplicated business rules
- proper disposal
- proper async lifecycle handling
- no raw SQL scattered through UI code
- no hard-coded date assumptions

Follow the existing project's architecture and style.

---

# 162. No Placeholder Implementation

Do not submit:

```dart
throw UnimplementedError();
```

or:

```dart
// TODO
```

for required functionality.

Do not use fake journal entries.

Do not use static demo dates.

Do not use hard-coded historical examples in production UI.

---

# 163. Test the Real Flow

The final implementation must support the complete real lifecycle:

```text
Journal
   ↓
Today
   ↓
create today's note if missing
   ↓
existing EditorScreen
   ↓
user edits title/body
   ↓
autosave
   ↓
leave editor
   ↓
Today resolves same note
   ↓
On This Day next year sees it
```

This is the core acceptance journey.

---

# 164. Full Regression Testing

Run:

```bash
flutter analyze
flutter test
```

and any required:

```bash
dart run build_runner build --delete-conflicting-outputs
```

or equivalent project code-generation commands.

Run the project's release build as well.

Do not stop when only Journal-specific tests pass.

---

# 165. Acceptance Criteria

The feature is complete only when:

- [ ] Journal appears in existing navigation.
- [ ] Journal contains Today.
- [ ] Journal contains On This Day.
- [ ] Today opens today's journal entry.
- [ ] Today creates today's entry only when explicitly opened.
- [ ] Opening Today twice returns the same note.
- [ ] There can never be two active journal notes for the same date.
- [ ] Database/schema enforces the date uniqueness invariant appropriately.
- [ ] Journal entries have application-managed journal metadata.
- [ ] Journal metadata integrates with existing frontmatter.
- [ ] Journal frontmatter is not duplicated.
- [ ] User can freely choose/change the note title.
- [ ] Changing title does not change journal date.
- [ ] Journal date is a local calendar date.
- [ ] Journal date does not depend on note title.
- [ ] Journal date does not change on ordinary edits.
- [ ] Existing EditorScreen is reused.
- [ ] No JournalEditorScreen exists.
- [ ] No dedicated JournalViewer exists.
- [ ] No panes are introduced.
- [ ] No journal dashboard is introduced.
- [ ] No location is added.
- [ ] No mood tracking is added.
- [ ] No sleep tracking is added.
- [ ] No gamification is added.
- [ ] No AI journaling is added.
- [ ] On This Day finds previous entries sharing today's month/day.
- [ ] Today's entry is excluded from On This Day.
- [ ] Future entries are excluded.
- [ ] Results are reverse chronological.
- [ ] Leap-day behavior is correct.
- [ ] Empty On This Day state is calm and useful.
- [ ] Historical entries open in the existing editor.
- [ ] Journal entries remain ordinary notes.
- [ ] Journal entries work with existing tags.
- [ ] Journal entries work with existing attachments.
- [ ] Journal entries work with scanner/documents.
- [ ] Journal entries work with OCR.
- [ ] Journal entries work with note links/backlinks.
- [ ] Journal entries work with search.
- [ ] Journal entries work with note history.
- [ ] Journal entries work with sync.
- [ ] Journal entries work with backup/restore.
- [ ] Journal entries work with trash.
- [ ] Permanent deletion frees the journal date.
- [ ] Protected journal entries preserve existing privacy behavior.
- [ ] No plaintext journal body is introduced into cloud storage.
- [ ] Existing security architecture remains intact.
- [ ] Existing navigation behavior remains intact.
- [ ] No note is marked dirty merely by opening Today.
- [ ] Opening a journal entry does not create a revision.
- [ ] Autosave works normally.
- [ ] Frontmatter survives sync/autosave/editor lifecycle correctly.
- [ ] Import behavior is deterministic.
- [ ] Duplicate journal dates from import/legacy data do not crash.
- [ ] Conflict resolution does not break the unique-date invariant.
- [ ] Existing note data is preserved through migration.
- [ ] Tests cover date logic.
- [ ] Tests cover duplicate prevention.
- [ ] Tests cover frontmatter.
- [ ] Tests cover Today.
- [ ] Tests cover On This Day.
- [ ] Tests cover leap years.
- [ ] Tests cover trash/delete.
- [ ] Tests cover sync.
- [ ] Tests cover conflict behavior.
- [ ] Tests cover backup/restore.
- [ ] Tests cover note links.
- [ ] Tests cover protected notes.
- [ ] Tests cover import.
- [ ] Tests cover migrations.
- [ ] Tests cover UI.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.
- [ ] Release build succeeds.
- [ ] No placeholder code remains.

---

# 166. Required Final Engineering Report

After implementation, provide a concise report containing:

## Architecture

Explain how Journal integrates with the existing Note model.

## Journal identity

Explain exactly how a note is recognized as a journal entry.

## Journal date

Explain how the calendar date is stored and queried.

## Frontmatter

Show the exact application-managed frontmatter format used.

## Uniqueness

Explain how the one-entry-per-day invariant is enforced.

## Today

Explain the open-or-create flow and race protection.

## On This Day

Explain the query and ordering.

## Trash/delete

Explain behavior for trashed and permanently deleted journal entries.

## Sync/conflicts

Explain how journal metadata behaves across devices and conflicts.

## Backup/restore

Explain preservation/reconstruction behavior.

## Security

Explain how journal metadata/content respects Quiet Paper's existing encryption architecture.

## Tests

Report actual results for:

```bash
flutter analyze
flutter test
flutter build apk --release
```

and any required code generation.

## Schema/migrations

List database changes and migration coverage.

## Performance

Report measured query behavior for Today and On This Day where practical.

## Remaining limitations

Only mention genuine limitations found during implementation.

---

# Final Product Principle

Journal should feel almost invisible.

The user should see:

```text
JOURNAL

Today
On This Day
```

They tap:

```text
Today
```

and immediately they're back in the same Quiet Paper editor they already know.

No journal dashboard.

No special editor.

No mood questionnaire.

No location tracker.

No streak.

No gimmicks.

Just today's page.

The application quietly knows:

```text
journal_date = 2026-09-01
```

while the user is free to title the page:

```text
Finally fixed the scanner
```

or:

```text
Tuesday
```

or anything else.

Then, eventually, they open:

```text
On This Day
```

and Quiet Paper quietly brings back:

```text
September 1, 2025
A year ago

September 1, 2024
Two years ago

September 1, 2023
Three years ago
```

That is the entire point of Journal V1:

> **Your existing notebook, organized by the days you wrote.**