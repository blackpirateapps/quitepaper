# MASTER IMPLEMENTATION PROMPT
## Quiet Paper — Production-Grade Notes Sorting, Filtering & Cursor-Based Infinite Scroll

You are working inside the existing Quiet Paper Flutter application.

Implement a complete, production-ready **Notes List Query System** providing:

- sorting
- advanced filtering
- existing tag filtering integration
- compound filtering
- deterministic ordering
- cursor/keyset-based incremental loading
- seamless infinite scroll
- query reset behavior
- responsive loading states
- saved filter architecture
- empty states
- filter chips
- result counts
- persistence of UI preferences
- database-level filtering and sorting
- race-condition protection
- large-library performance
- comprehensive tests

This must integrate with the actual existing application architecture.

Do not create a simplistic client-side list filter.

Do not load the entire notebook into Dart and then filter/sort it.

Do not introduce fake metrics such as opened-count or viewed-count.

The final result must be suitable for a library containing tens of thousands of notes.

---

# 1. EXISTING PRODUCT CONSTRAINTS

The current application is:

- offline-first
- backed by SQLite/Drift locally
- zero-knowledge encrypted for cloud synchronization
- Bear-inspired and intentionally restrained in UI
- already equipped with a tag filter bar
- already equipped with search
- already equipped with pinned, archived and trashed note states
- already equipped with attachments/documents/OCR
- already equipped with journal-style metadata where supported by the current schema
- already equipped with sophisticated FTS5-based search infrastructure

The canonical note content remains Markdown.

Do not change the note-content architecture.

Do not introduce a rich-text JSON document model.

The existing tag bar behavior must be preserved:

- `All`
- horizontally scrolling tags
- active tag promoted near `All`
- selecting the active tag toggles it off
- sidebar/tag-browser selection must still move the selected tag into view

This behavior is already implemented and must not regress.

The application's existing search architecture also already uses FTS5 candidate recall, background-isolate ranking, deterministic result handling, and progressive non-blocking UI. Do not duplicate or degrade that architecture.

---

# 2. PRIMARY ARCHITECTURAL DECISION

Create a reusable domain-level `NotesQuery` abstraction.

The Notes screen must not independently understand dozens of booleans and sort conditions.

Conceptually:

```text
NotesQuery
    |
    +-- context
    +-- text/search integration
    +-- tag filter
    +-- tag match mode
    +-- state filters
    +-- content filters
    +-- attachment filters
    +-- date filters
    +-- journal filters
    +-- security filters
    +-- sort specification
    +-- cursor
    +-- batch size
```

The query must be serializable.

The query must be deterministic.

The query must be suitable for:

- Notes screen
- saved filters
- future smart views
- future deep links
- future multi-note operations
- future export selection
- future search/filter combinations

Do not couple the query object to Flutter widgets.

---

# 3. IMPORTANT DISTINCTION

Treat these as separate responsibilities:

```text
Search
    = textual discovery

Filter
    = structured predicates

Sort
    = ordering

Context
    = active / archive / trash

Pagination mechanism
    = cursor-based incremental loading

UI
    = presentation of the query
```

Do not combine these concepts into one giant UI controller.

---

# 4. NOTES CONTEXT

The main Notes navigation already has meaningful lifecycle contexts.

Treat these as separate list contexts:

```text
active
archived
trash
```

Do not make users mix these casually with arbitrary filters.

The default main Notes context should show active, non-trashed notes.

The Archive context should show archived notes.

The Trash context should show trashed notes.

When a context inherently determines a predicate, do not redundantly show that predicate in the filter UI.

Examples:

Inside Archive:

```text
do not show:
Archived / Not Archived
```

Inside Trash:

```text
do not show:
Trashed / Not Trashed
```

This prevents nonsensical filter combinations.

Respect the application's current trash semantics. Trash is persisted indefinitely and deletion/sync behavior is already carefully implemented. Exporting/filtering must never alter that lifecycle.

---

# 5. SORTING

Implement exactly these primary sort choices:

```text
Recently Updated
Recently Created
Title
```

Directions:

```text
Newest First
Oldest First
A → Z
Z → A
```

Do NOT implement:

- most viewed
- least viewed
- most opened
- recently opened
- most edited

There is no opened/view-count telemetry and none should be introduced solely for sorting.

---

# 6. COMPOUND SORTING

Sorting must internally support multiple ordering keys.

Do not represent a sort as only:

```text
SortType = updated
```

Represent it conceptually as:

```text
[
  primary sort,
  deterministic tie breaker,
  unique ID tie breaker
]
```

Examples:

```text
updated DESC,
id ASC
```

```text
created DESC,
id ASC
```

```text
title ASC,
updated DESC,
id ASC
```

The final unique ID tie-breaker guarantees deterministic ordering.

Two refreshes of the same database state must produce the same order.

---

# 7. OPTIONAL "PINNED FIRST" BEHAVIOR

The application already has pinned state.

Where appropriate, support a compound sort mode:

```text
Pinned First
then Recently Updated
```

Do NOT replace the main Recently Updated sort with a different arbitrary pinned metric.

Treat:

```text
Pinned First
```

as a composition:

```text
pinned DESC
updated DESC
id ASC
```

The exact column name must follow the actual database schema.

Pinned filtering must also work independently:

```text
Pinned only
```

---

# 8. FILTER CATEGORIES

Implement these filter categories.

## Tags

Support:

- one tag
- multiple tags
- tag search
- AND mode
- OR mode
- untagged

The existing tag bar remains the fast path for one active tag.

Advanced tag selection lives in the Filter UI.

For example:

```text
Tags:
#programming
#flutter

Match:
All
Any
```

Meaning:

```text
All:
#programming AND #flutter
```

```text
Any:
#programming OR #flutter
```

Use the existing tag normalization/storage rules. Do not create an alternate tag representation.

The existing application already merges and normalizes tags from multiple sources such as frontmatter, folder imports and inline hashtags. The filtering layer must query the canonical stored tag relationships instead of reparsing Markdown.

---

# 9. UNTAgGED

Implement:

```text
Untagged
```

This means a note has zero canonical tag relationships.

Do not determine this by scanning Markdown text for `#`.

Use the database's actual tag relationship.

---

# 10. CONTENT FILTERS

Implement:

```text
Has code
Has checklist
Has incomplete tasks
Has completed tasks
Has links
```

These filters must be based on actual persisted/canonical content where possible.

Do not create permanent per-note database flags merely to support these filters unless the existing architecture already has them or there is a demonstrated performance requirement.

For content-derived predicates that are not directly represented in SQLite, choose the safest production approach after inspecting the repository:

1. use existing structured metadata if available
2. use an indexed derived field only if justified
3. otherwise implement a carefully designed query/cache mechanism

Never run an expensive full Markdown parse across thousands of notes on every UI interaction.

---

# 11. ATTACHMENT FILTERS

Implement:

```text
Has attachments
Has images
Has documents
Has OCR
```

These must use the existing attachment/document/OCR relationships.

Do not use Cloudinary concepts in the UI.

The user should see:

```text
Images
Documents
OCR
```

not:

```text
Cloudinary resources
```

The existing attachment architecture uses canonical `qp://asset/<UUID>` resources and encrypted local/cloud asset handling. Filter against those logical relationships, not provider implementation details.

---

# 12. DATE FILTERS

Support separate:

```text
Created
Modified
```

Each must support:

```text
Today
Yesterday
Last 7 days
Last 30 days
This year
Custom
```

Custom must support:

```text
From
To
```

Date boundaries must respect the user's local calendar semantics while querying the canonical stored timestamps consistently.

Be careful around:

- midnight
- DST where applicable
- inclusive/exclusive end bounds
- device timezone changes

Use half-open intervals where appropriate:

```text
>= start
< endExclusive
```

to avoid end-of-day precision bugs.

---

# 13. JOURNAL FILTERS

If the current note model/database contains first-class journal metadata, expose:

```text
Mood
Sleep
Location
```

Only expose a field if the actual codebase already stores it as meaningful structured note data.

Do not invent a new journal schema solely for this feature.

Support meaningful predicates such as:

```text
Has mood
Mood = ...
Has sleep
Sleep > ...
Has location
```

only where the underlying data model supports them correctly.

---

# 14. SECURITY FILTERS

Support:

```text
Protected
Unprotected
```

Do not expose protected note content while determining filter results.

Respect the current password-protection model.

Protected-note state is already represented distinctly in Quiet Paper and protected notes use encrypted envelopes.

Do not attempt to decrypt note bodies merely to determine whether a note is protected if the existing model already provides that information.

---

# 15. STATE FILTERS

Support pinned filtering.

Do not expose unnecessary inverse choices such as:

```text Not pinned
```

unless required by the query builder's internal semantics.

Use a clean positive predicate UI:

```text Pinned
```

The current navigation context handles:

```text Active
Archive
Trash
```

rather than requiring users to construct these manually.

---

# 16. FILTER UI

Create a Bear/Quiet-Paper-style Filter sheet.

Do not build a Material-style settings wall.

Conceptual UI:

```text
Filters

Tags
  Search tags...
  Selected tags...
  Match: All / Any
  Untagged

State
  Pinned

Date
  Created
  Modified

Content
  Code
  Checklists
  Incomplete tasks
  Completed tasks
  Links

Attachments
  Images
  Documents
  OCR

Journal
  Mood
  Sleep
  Location

Security
  Protected
```

Only show sections relevant to available data.

Keep the interaction compact.

Use existing Quiet Paper typography, spacing, colors, radii and grouped-row conventions.

The Settings screen already establishes the application's grouped, restrained Bear/iOS-table visual language. Follow those existing design tokens rather than creating a new visual style.

---

# 17. FILTER SHEET BEHAVIOR

The filter sheet must:

- show current selections
- support clearing individual selections
- support Clear All
- preserve state when navigating deeper into a filter
- return the complete query state on confirmation
- cancel without mutating the active query

If live filter application is cheap enough, it may update immediately.

Otherwise:

```text
Cancel
Apply
```

Use the existing application interaction conventions.

On small phones the sheet must remain vertically scrollable.

Do not create horizontal overflow.

---

# 18. ACTIVE FILTER CHIPS

When filters are active, show them above the note list.

Example:

```text
[#programming ×] [Has Code ×] [+2]
```

Do not render 12 chips and force the user to horizontally scroll indefinitely.

The display should prioritize:

1. active tag
2. a few most useful filters
3. aggregate `+N`

Tapping an individual chip removes that predicate.

Tapping `+N` opens the complete Filter sheet.

Provide:

```text
Clear all
```

when at least one filter is active.

---

# 19. DO NOT REPLACE THE EXISTING TAG BAR

The existing tag bar remains.

The final notes screen should conceptually look like:

```text
Notes                                  [Sort] [Filter]

All   #work   #ideas   #programming
──────────────────────────────────────

[Has Code ×] [Last 30 days ×] [+1]

24 notes

Note
Note
Note
...
```

On a screen where no advanced filters are active, don't add an unnecessary empty filter-chip row.

---

# 20. SORT UI

Create a compact sort sheet/menu.

Example:

```text
Sort by

Recently Updated             ✓
Recently Created
Title

Direction
Newest First                 ✓
Oldest First
```

For Title:

```text
A → Z
Z → A
```

Avoid presenting irrelevant direction options.

The UI should immediately communicate the current ordering.

---

# 21. RESULT COUNT

Show the number of matching notes.

Examples:

```text
24 notes
```

With a filtered result:

```text
24 notes
```

Do not make users understand internal batch size.

For a query currently loading:

```text
Loading notes…
```

or retain the previous visible result count until the new query has produced its first batch.

Avoid visually jumping between states unnecessarily.

---

# 22. INFINITE SCROLL

The user must experience a continuously expanding list.

There must be no:

```text
Page 1
Page 2
Next
Previous
```

Use incremental loading.

Recommended default:

```text
initial batch = 40
subsequent batch = 40
```

These should be centralized constants/configuration.

Do not hard-code `40` in multiple widgets.

---

# 23. PREFETCH THRESHOLD

Do not wait until the final list item is physically displayed.

Begin loading the next batch when the user is approximately:

```text
800dp
```

from the bottom.

Use the actual scroll metrics to calculate the threshold.

Make the threshold configurable internally.

Avoid triggering multiple loads during rapid scroll.

---

# 24. CURSOR/KEYSET PAGINATION

Although the UX is infinite scroll, the database implementation must use **keyset/cursor-based pagination**, not large OFFSET values.

For example:

```text
ORDER BY
    updated_at DESC,
    id ASC
```

The cursor contains:

```text
lastUpdatedAt
lastId
```

The next query must express:

```text
updated_at < lastUpdatedAt
OR (
    updated_at = lastUpdatedAt
    AND id > lastId
)
```

for descending ordering with the selected tie-breaker.

Generate the correct cursor condition for every supported compound sort.

Do not implement a generic cursor by simply storing a list index.

---

# 25. CURSOR MODEL

Create a typed cursor model.

Conceptually:

```text
NotesCursor
    sortValues
    lastNoteId
```

It must be serializable.

The cursor must contain enough information to reconstruct the exact continuation position.

Examples:

```text
UpdatedCursor(
    updatedAt,
    id
)
```

```text
TitleCursor(
    normalizedTitle,
    updatedAt,
    id
)
```

Do not use only the title if title sorting can contain duplicates.

---

# 26. TITLE SORTING

Title sorting deserves special handling.

Define a consistent normalization rule.

It must be stable for:

- uppercase/lowercase
- whitespace
- empty titles
- Unicode
- duplicate titles

Use the database's appropriate collation where practical.

If the existing schema stores a display title that is safe to query, use it.

If title normalization requires a derived column, inspect the actual schema and implement it only when justified.

The sorting behavior must be deterministic across devices.

---

# 27. EMPTY / UNTITLED NOTES

Empty titles must sort consistently.

Use the existing application concept of `Untitled`.

Do not mutate note data simply to make sorting easier.

Do not write `"Untitled"` into the database unless the existing model already does that.

---

# 28. QUERY EXECUTION

The query engine must build SQL/Drift expressions.

Do not:

```text
SELECT all notes
→ convert to Dart objects
→ filter in Dart
→ sort in Dart
```

For relational filters use:

- joins
- EXISTS
- NOT EXISTS
- indexed predicates
- subqueries

as appropriate.

The exact implementation must follow the existing Drift schema.

---

# 29. TAG FILTER QUERY

For multiple selected tags:

### ALL

A note must have every selected tag.

Use an efficient relational strategy, for example:

```sql
EXISTS(...)
AND EXISTS(...)
```

or an equivalent grouped query.

Do not load every note and test its tag list in Dart.

### ANY

A note must have at least one selected tag.

Use an indexed relational query.

### UNTAGGED

Use:

```text
NOT EXISTS(note-tag relationship)
```

or the appropriate equivalent.

---

# 30. ATTACHMENT/DAta FILTERS

Use database relationships.

Examples:

```text
Has attachments
= EXISTS attachment for note

Has images
= EXISTS image attachment for note

Has documents
= EXISTS document for note

Has OCR
= EXISTS available OCR associated with note/attachment/document
```

Respect the application's current document/OCR state model.

The existing document system has explicit processing states such as `not_requested`, `queued`, `processing`, `available`, and `failed`.

For `Has OCR`, define the predicate as **usable OCR available**, not merely "an OCR job was requested", unless the existing product semantics dictate otherwise.

---

# 31. CONTENT-DERIVED FILTERS

For:

```text
Has code
Has checklist
Has links
Has tasks
```

first inspect whether the current codebase already exposes structured indexing/metadata.

The Markdown editor has a defined parser/tokenization system and supports fenced code blocks, lists, checklists, links, highlights, etc.

Do not create a second incompatible Markdown parser.

If SQL-level detection can be performed safely using indexed/local derived metadata, use it.

If not, design a cache/index mechanism that does not block the UI.

Do not parse every full note synchronously when the user opens the Filter sheet.

---

# 32. SEARCH INTEGRATION

The notes list should be capable of combining:

```text search
+
filters
+
sort
```

However, do not destroy the existing FTS5 ranking semantics.

The conceptual pipeline is:

```text search query
        +
structured filters
        +
list/context constraints
        +
ordering
```

For ordinary no-search browsing:

```text SQLite structured query
```

For text search:

```text FTS5 candidate retrieval
→ apply compatible structured constraints
→ background ranking
→ deterministic result ordering
```

Reuse existing search infrastructure.

Do not create a second fuzzy-search implementation.

Do not make filter logic perform full-text searching.

---

# 33. IMPORTANT SEARCH/SORT DISTINCTION

When a text query is active, relevance ranking may be the primary ordering.

Do not blindly apply:

```text ORDER BY updated_at
```

to ranked search results if doing so would destroy relevance.

Instead, inspect the existing SearchResult semantics and preserve the current search ranking contract.

The standard Notes browser and Global Search may therefore have different primary ordering strategies while sharing the same filter predicates.

---

# 34. OCR PRIVACY

Do not decrypt OCR content merely to answer structural filters such as:

```text Has OCR
```

The current OCR subsystem keeps plaintext OCR out of persistent unencrypted FTS storage and uses authenticated in-memory access.

The filter should depend on OCR existence/state metadata wherever possible.

Never write decrypted OCR into a new unencrypted persistent filter cache.

---

# 35. PASSWORD-PROTECTED NOTES

Do not decrypt a protected note to determine:

```text
Pinned
Created
Modified
Protected
Has attachments
```

when existing metadata/relationships already answer the question.

If a content-derived filter cannot safely operate without decrypting protected content, either:

1. use an existing safe metadata/index mechanism
2. or omit protected notes from that content-derived predicate with an explicit internal rule

Do not weaken note security to make filtering convenient.

---

# 36. QUERY STATE

Create an immutable query state.

Conceptually:

```text
NotesQuery {
    context
    tagIds
    tagMatchMode
    pinned
    untagged
    createdRange
    modifiedRange
    contentPredicates
    attachmentPredicates
    journalPredicates
    securityPredicates
    searchQuery
    sort
    cursor
    limit
}
```

Do not let UI widgets directly mutate individual fields in a shared mutable singleton.

Use immutable copy/update semantics.

---

# 37. QUERY GENERATION / RACE PROTECTION

The existing search system already protects against stale asynchronous responses using generation IDs. Reuse the same principle for note browsing.

Every query state gets a monotonically increasing generation ID.

When a query changes:

```text
generation++
cancel/invalidate old loading operation
clear current continuation state
load first batch
```

When a response arrives:

```text
if response.generation != currentGeneration:
    discard it
```

An old request must never append notes to a newly filtered list.

---

# 38. QUERY RESET RULES

Any of these changes must reset the infinite-scroll cursor:

- context changes
- tag changes
- tag AND/OR change
- adding/removing a filter
- date change
- content filter change
- attachment filter change
- journal filter change
- security filter change
- sort change
- search query change

Reset:

```text
items = []
cursor = null
hasMore = true
```

Then load the first batch.

Do not append new-query results onto the old list.

---

# 39. PRESERVE VISIBLE RESULTS WHILE LOADING MORE

When loading the next batch:

```text
existing notes remain visible
```

Do not replace the entire list with a full-screen spinner.

The current search implementation already follows this non-blocking philosophy, keeping previous results visible and using a subtle progress indicator. Follow that established UX.

---

# 40. INITIAL LOADING

On a completely new query:

```text
show appropriate first-load placeholder
```

Do not show a spinner if the cached/previous query results can be retained safely while a new query is running.

Avoid visual flicker.

---

# 41. LOAD-MORE STATE

The state must distinguish:

```text
initialLoading
loadingMore
refreshing
error
success
```

At minimum.

Do not represent all of these as a single boolean.

---

# 42. END OF LIST

If the last database query returns fewer than the requested batch size:

```text
hasMore = false
```

If it returns zero while loading more:

```text
hasMore = false
```

Do not continue issuing requests.

No unnecessary "End of notes" label is required.

Let the list end naturally.

---

# 43. ERROR WHILE LOADING MORE

If the first batch fails:

```text
show full appropriate error state
retry action
```

If a later batch fails:

```text
keep all existing notes
show compact retry affordance at the bottom
```

Do not erase the already loaded notes.

Example:

```text
Note 39
Note 40

Couldn't load more notes
Retry
```

Retry must use the same cursor and query generation safely.

---

# 44. PULL-TO-REFRESH / REFRESH BEHAVIOR

If the existing Notes screen has refresh behavior, integrate it cleanly.

On refresh:

1. re-evaluate the same query
2. reset the cursor
3. fetch from the beginning
4. replace the visible collection atomically

Do not reset the user's active filters or sort merely because they refreshed.

---

# 45. LIVE DATABASE CHANGES

The Notes database is reactive and notes may change due to:

- user edits
- sync pull
- archive
- trash
- restore
- pin/unpin
- tag changes
- attachment changes

The list must respond safely.

Avoid naively re-running the entire infinite collection for every database event.

Define a coherent strategy:

- local mutation affecting visible items → update/remove appropriate item
- mutation affecting ordering → reposition safely or invalidate the relevant query
- sync causing broad changes → refresh from the top when appropriate
- stale cursor detection → restart query rather than producing duplicates

Do not allow duplicate notes.

Do not allow missing notes silently.

---

# 46. IMPORTANT: EDITING A NOTE WHILE BROWSING

Suppose the list is sorted:

```text Recently Updated
```

and the user edits a visible note.

Its `updatedAt` changes.

The list must not end up with the note appearing in the wrong position indefinitely.

Use the existing reactive architecture and choose a safe behavior.

Recommended:

- update the visible note
- if its ordering position materially changes, reconcile/reload the current query safely
- preserve the user's scroll experience where practical
- never duplicate the note

Do not introduce a second copy of a note just because its sort key changed.

---

# 47. INFINITE SCROLL DUPLICATE PROTECTION

Before appending a batch:

- deduplicate by note ID
- preserve deterministic order
- update cursor from the actual final item in the accepted batch

Do not deduplicate by title.

Two notes are allowed to have identical titles.

---

# 48. CURSOR ROBUSTNESS DURING MUTATIONS

Because notes can change while the user scrolls, cursor-based queries must be designed around immutable ordering tuples.

For descending updated sort:

```text
(updatedAt, id)
```

For title:

```text
(normalizedTitle, updatedAt, id)
```

The query should use the complete tuple.

If a note's ordering key changes after it has been loaded, it can move outside the continuation window.

Do not attempt to patch this with an OFFSET.

When necessary, restart the collection query.

---

# 49. INDEXING

Inspect the existing Drift schema before modifying it.

Add indexes only where the actual query planner benefits.

Likely candidates may include:

```text
updated_at
created_at
archived
trashed
pinned
```

and relationship indexes for:

```text
note_tags
attachments
documents
OCR relationships
```

Do not blindly add an index on every column.

Use SQLite query plans where practical.

---

# 50. DATABASE MIGRATION

If a new index or derived filter field is necessary:

- increment the Drift schema correctly
- add a safe migration
- preserve existing data
- test historical migration paths
- regenerate Drift code
- ensure idempotent migration behavior consistent with the project's existing migration hardening

The project has already experienced duplicate-column migration failures and now uses defensive migration patterns. Do not repeat those mistakes.

---

# 51. PERSIST SORT PREFERENCE

Persist:

```text default notes sort
direction
```

using the application's existing local preferences infrastructure.

Do not sync this as note content.

Do not store it in the note database unless the existing architecture specifically uses that database for application preferences.

---

# 52. PERSIST ACTIVE FILTERS

Do NOT blindly persist every temporary filter forever.

Recommended behavior:

- remember the selected sort
- optionally remember the last filter state for the current list context during the session
- when appropriate, persist lightweight filter preferences

Use product judgment based on the existing Notes navigation behavior.

The active filter should not mysteriously survive logout/account changes if that would expose state belonging to another user.

At logout, clear account-scoped query state where appropriate.

---

# 53. NO SYNC OF FILTER SETTINGS

Sort/filter state is UI/application state.

Do not send it through:

- SyncEngine
- encrypted note payload
- sync queue
- server API
- Turso
- conflict resolver

unless a future explicit smart-view synchronization feature is introduced.

---

# 54. SAVED FILTERS / SMART VIEWS

Implement the architecture required for saved filters.

A saved filter should conceptually contain:

```text
SavedFilter
    id
    name
    queryDefinition
    createdAt
    updatedAt
```

The `queryDefinition` must be serializable.

Do not save the current cursor.

Do not save temporary loading state.

Do not save result items.

A saved filter represents a query, not a snapshot.

---

# 55. SAVED FILTER UI

Provide the underlying capability and user interface to:

- create saved filter
- name saved filter
- open saved filter
- rename saved filter
- delete saved filter

Use a restrained UI.

Do not make saved filters look like folders.

Use terminology such as:

```text
Saved Filters
```

or:

```text
Smart Views
```

according to the existing application's language.

---

# 56. SAVED FILTER VALIDATION

A saved filter must validate when loaded.

If the app evolves and a previously saved predicate becomes unsupported:

- ignore only the unsupported optional predicate when safe
- otherwise mark the saved filter invalid and present a recoverable error

Never silently change a saved query into a materially different query.

---

# 57. SAVED FILTER ACCOUNT BOUNDARY

If the app currently has local-only saved UI state, keep it local.

If implementing persistence that belongs to an authenticated notebook/account, ensure one account's saved filters cannot appear under another account.

Never sync saved filters by putting them into encrypted note content.

---

# 58. SERIALIZATION

Create versioned query serialization.

Example concept:

```json
{
  "version": 1,
  "context": "active",
  "tags": ["..."],
  "tagMatchMode": "all",
  "pinned": true,
  "modifiedRange": {
    "start": "...",
    "end": "..."
  },
  "sort": {
    "field": "updated",
    "direction": "desc"
  }
}
```

Do not serialize widget state.

Do not serialize cursor.

Do not serialize arbitrary SQL.

The query definition must remain application-level structured data.

---

# 59. CONTEXT-AWARE FILTER OPTIONS

Filter UI should hide redundant options.

Examples:

Active notes:

```text
show Pinned
```

Archive:

```text
do not show Archived
```

Trash:

```text
do not show Trashed
```

If a predicate is permanently implied by the current context, don't present it.

---

# 60. FILTER COUNT

When the Filter sheet is open, optionally show how many filters are active:

```text
Filters
3 active
```

Do not count each tag as a separate "filter" if the UI would become confusing.

Use a consistent definition.

---

# 61. QUERY SUMMARY

Provide a concise summary above the list where useful.

Examples:

```text
24 notes
```

or:

```text
24 notes · #programming · Has Code
```

Do not expose enormous predicate dumps.

---

# 62. EMPTY STATES

Differentiate:

### Completely empty notebook

```text
No notes yet
```

### Filters produce no results

```text
No notes match these filters.

Clear filters
```

### Search + filter produces no results

```text
No notes match your search and filters.

Clear filters
```

### Archive empty

```text
No archived notes
```

### Trash empty

```text
Trash is empty
```

Do not use one generic empty state for every situation.

---

# 63. FILTER CLEARING

Individual chips must be removable without opening the sheet.

Example:

```text
[Has Code ×]
```

removes only `Has Code`.

`Clear All` removes all advanced predicates but preserves the current list context.

Decide whether it preserves the active tag based on how the existing tag bar behaves; recommended behavior:

- `Clear All` clears advanced filters
- active tag can be cleared by tapping its existing tag chip / All chip

Do not unexpectedly mutate tag state through a generic filter action unless that is clearly communicated.

---

# 64. EXISTING TAG BAR COMPATIBILITY

The current selected-tag provider and tag-bar behavior must continue to work.

If the advanced query model subsumes `selectedTagFilterProvider`, do not create two competing sources of truth.

Recommended:

```text
NotesQuery
     ↑
selectedTagFilterProvider adapter
```

or migrate the provider to derive from `NotesQuery`.

There must be one authoritative active tag state.

---

# 65. SIDEBAR INTEGRATION

Selecting a tag from:

- sidebar
- tag browser
- tag bar

must update the same NotesQuery.

The result list must reset to the first batch.

The active tag must continue to receive the existing tag-bar priority/scroll behavior.

---

# 66. TABLET / SPLIT VIEW

Quiet Paper has tablet layouts and an embedded editor pane.

The Notes list query/filter implementation must not break split-view behavior.

Filter/sort sheets should adapt to:

- phone
- narrow landscape
- tablet
- wide tablet

On tablets, favor a comfortably constrained content width consistent with the app's existing design language.

Do not allow giant full-width filter panels on desktop-sized screens.

---

# 67. ACCESSIBILITY

Every control must have:

- semantic label
- sensible focus order
- keyboard accessibility where relevant
- adequate touch target
- accessible selected/unselected state

Examples:

```text
Sort
Filters
Clear filter
Pinned
Tags
Match all
Match any
```

Do not rely solely on iconography.

---

# 68. KEYBOARD SUPPORT

On platforms with hardware keyboards:

Provide sensible shortcuts where they fit the existing interaction model.

At minimum consider:

```text
keyboard-accessible Sort
keyboard-accessible Filter
Escape to dismiss the active sheet
```

Do not introduce arbitrary shortcuts that conflict with editor shortcuts.

---

# 69. SCROLL PERFORMANCE

The list must remain fluid at 60/120 FPS.

Do not:

- run Markdown parsing per visible item solely for filtering
- run fuzzy search for each tile
- decrypt OCR while scrolling
- perform huge synchronous list transformations on the UI isolate
- rebuild the entire list unnecessarily

The existing search system was explicitly designed to prevent these kinds of UI-thread bottlenecks. Follow the same performance discipline.

---

# 70. NOTE TILE PERFORMANCE

`NoteListTile` should receive already-available note data.

Do not make each tile perform its own database filter query.

Avoid N+1 database queries.

If filter/result metadata is needed, fetch it in the query or batch-hydrate it efficiently.

---

# 71. RESULT DTO

Use an appropriate lightweight NotesList DTO/view model rather than passing giant database graphs through the widget tree.

Conceptually:

```text
NoteListItemDto
    id
    title
    preview
    tags
    createdAt
    updatedAt
    pinned
    archived
    trashed
    protected
    attachmentSummary
```

Only include fields actually needed by the Notes list.

Do not load entire attachment contents merely to render an item.

---

# 72. BATCH HYDRATION

If additional metadata requires relationships:

- fetch in batches
- avoid one query per item
- use targeted IDs
- keep memory bounded

Follow the existing search subsystem's selective hydration approach.

---

# 73. INFINITE SCROLL TRIGGER IMPLEMENTATION

Use the existing scroll controller/scrollable rather than introducing a second competing scroll system.

The listener must:

1. detect near-bottom threshold
2. ensure current generation is valid
3. ensure not already loading
4. ensure `hasMore == true`
5. capture current cursor
6. issue next query
7. append result safely

If the user scrolls extremely fast, multiple scroll events must not cause duplicate requests.

---

# 74. LOAD-MORE LOCK

The application must guarantee:

```text
at most one active load-more operation per query generation
```

Equivalent protection:

```text
if loadingMore:
    return
```

But ensure the flag is reset correctly on:

- success
- empty result
- failure
- cancellation
- stale response

---

# 75. PRE-FETCH BEHAVIOR

If a batch is small and the viewport can display most of it immediately, the screen may need to automatically fetch another batch because the user is already within the prefetch threshold.

Prevent infinite loops.

Example:

```text
40 notes loaded
viewport needs 60 notes to reach the threshold
→ load more
```

Continue only until:

- the viewport is adequately filled
- no more results
- an error occurs

Keep safeguards against unbounded automatic fetching.

---

# 76. LARGE LIBRARIES

Design specifically for:

```text
100 notes
1,000 notes
10,000 notes
50,000+ notes
```

The first batch should not become slower simply because the total notebook size increases significantly.

Structured filters must use indexed SQL relationships where possible.

---

# 77. DATABASE QUERY PLANS

For representative queries, inspect SQLite query plans where feasible.

Verify indexes are actually used for high-frequency paths.

Do not assume an index helps just because it exists.

Avoid unnecessary scans.

---

# 78. QUERY CACHING

Do not immediately add an elaborate query-result cache.

First optimize:

- SQL
- indexes
- DTO hydration
- infinite scroll
- deterministic ordering

A small memoization layer may be added later if profiling demonstrates a need.

Do not cache stale note lists indefinitely.

Database mutations must invalidate any cache correctly.

---

# 79. SEARCH + FILTER PERFORMANCE

Because FTS5 search already has its own candidate pipeline, do not force advanced filters to run inside a background isolate after fetching thousands of candidates if SQLite can apply them earlier.

Prefer:

```text
FTS candidate IDs
+
SQL structural filtering
→ reduced candidate set
→ existing background ranker
```

when compatible with the existing implementation.

Do not alter the existing fuzzy ranking algorithm merely to add filtering.

---

# 80. NO OCR CONTENT FILTER SCANS

Never implement:

```text
for every note:
    decrypt OCR
    inspect it
    decide filter
```

for normal notes-list filtering.

The app's OCR pipeline already takes care to keep decrypted OCR in memory and out of unsafe persistent indexes.

Use OCR existence/state metadata instead.

---

# 81. QUERY INVALIDATION

Define explicit query invalidation triggers for:

- note create
- note update
- note delete
- note restore
- note archive
- note unarchive
- note pin/unpin
- tag attach/detach
- attachment add/remove
- document add/remove
- OCR state changes
- sync pulls that materially alter note metadata

Do not rely on arbitrary widget rebuilds to make the query correct.

---

# 82. SYNC SAFETY

Sorting/filtering is read-only.

It must never:

- mark notes dirty
- modify revision
- modify updatedAt
- enqueue sync
- mutate sync queues
- create conflict records
- alter deletion tombstones
- change Cloudinary data

The application's sync system is revision-sensitive and already has extensive protections around deletion and fresh-device synchronization. The Notes Query System must remain entirely outside that mutation path.

---

# 83. BACKUP SAFETY

Do not modify local backup behavior.

Do not add query settings to note backup snapshots.

Saved filters may be backed up separately in the future, but do not inject UI query state into the existing note backup format unless explicitly designed and documented.

---

# 84. SEARCH STATE SAFETY

Do not make NotesQuery depend on a particular SearchScreen widget instance.

Search query text may be incorporated into the query abstraction as an optional field, but the Notes screen must continue to operate independently.

---

# 85. SAVED FILTER FUTURE-PROOFING

Even if saved-filter syncing is not implemented immediately, structure the query definition so a future synchronization layer could serialize it.

Do not serialize:

- provider references
- Dart object hashes
- closures
- SQL
- widget state
- BuildContext
- database objects

---

# 86. FILE ORGANIZATION

Inspect the existing architecture first.

Prefer a structure roughly like:

```text
lib/features/notes/
    domain/
        notes_query.dart
        notes_sort.dart
        notes_filter.dart
        notes_cursor.dart
        saved_filter.dart

    application/
        notes_query_provider.dart
        notes_query_service.dart
        saved_filter_service.dart

    data/
        ...
        
    presentation/
        widgets/
            notes_sort_sheet.dart
            notes_filter_sheet.dart
            active_filter_chips.dart
            notes_list_loading_more.dart
```

Do not blindly create this exact hierarchy if the existing feature architecture uses another convention.

Reuse existing Notes models/providers/repository patterns.

---

# 87. NO GOD CLASS

Do not put:

- SQL generation
- filter UI
- cursor management
- saved-filter persistence
- scroll handling
- sort UI

into a single class.

Keep domain, application, data and presentation responsibilities separated.

---

# 88. RIVERPOD INTEGRATION

Use the existing Riverpod architecture.

Do not introduce another state management package.

Prefer providers for:

- NotesQuery state
- current sort
- current filters
- saved filters
- paged note collection state

Ensure provider disposal/invalidation does not leave stale scroll/load state behind.

---

# 89. ACCOUNT / LOGOUT RESET

When the authenticated notebook changes:

- invalidate NotesQuery state
- clear stale loaded items
- reset cursors
- reset account-bound saved-filter state as appropriate
- prevent previous-account notes from appearing under the new account

Follow the application's existing sign-out/reset conventions.

The app already explicitly resets sync cursors during account transitions. Query state must respect the same account boundary.

---

# 90. SORT PREFERENCE DEFAULT

Default:

```text
Recently Updated
Newest First
```

Do not introduce an unfamiliar default.

This matches the natural notes workflow and keeps recent work visible.

---

# 91. FILTER DEFAULT

Default:

```text
Active context
No advanced filters
```

The existing tag selection remains independent.

---

# 92. UX MICRO-POLISH

Implement:

- subtle sheet transitions
- clean selected states
- no Material-card clutter
- compact dividers
- consistent icon sizing
- smooth chip insertion/removal
- no abrupt list flashing
- retain scroll position where logically possible
- no full-screen loading spinner for incremental loading
- clear error recovery

Match the existing warm editorial aesthetic.

---

# 93. FILTER SHEET RESPONSIVENESS

The filter sheet must support small screens.

Use:

```text
SingleChildScrollView
ConstrainedBox
LayoutBuilder
```

or existing application equivalents.

The project already fixed narrow dialogs using responsive layout and `SingleChildScrollView`; follow those lessons here.

No action row may overflow on:

- narrow Android phones
- landscape phones
- tablets

---

# 94. ANIMATION RULE

Animations should be restrained.

Use existing Quiet Paper animation conventions.

Do not introduce bouncy consumer-app animation everywhere.

The visual language should remain calm and editorial.

---

# 95. TESTING — DOMAIN

Write unit tests for:

- `NotesQuery` equality
- serialization/deserialization
- defaults
- filter composition
- AND tag logic
- OR tag logic
- untagged
- sort definitions
- compound ordering
- cursor generation
- cursor serialization
- cursor continuation logic
- title normalization
- date-range boundaries
- context constraints

---

# 96. TESTING — DATABASE

Test actual SQLite queries for:

- updated sort
- created sort
- title sort
- pinned first
- active context
- archive context
- trash context
- pinned filter
- untagged
- single tag
- multiple tags AND
- multiple tags OR
- has attachment
- has image
- has document
- has OCR
- created ranges
- modified ranges
- protected/unprotected
- combined predicates
- cursor continuation

Verify correct ordering across duplicate sort values.

---

# 97. DATABASE TEST DATA

Create realistic fixtures containing:

```text
duplicate titles
duplicate timestamps
many tags
notes with no tags
notes with multiple tags
pinned/unpinned
archived
trashed
attachments
images
documents
OCR
protected notes
empty notes
very old notes
recent notes
```

Make sure tests include more than one batch.

For example:

```text
125 notes
```

so that at least four incremental loads occur.

---

# 98. INFINITE-SCROLL WIDGET TESTS

Test:

1. first 40 notes load
2. scrolling near bottom triggers second batch
3. second batch appends
4. third batch appends
5. final short batch sets `hasMore = false`
6. additional scrolling does not query again
7. rapid scroll does not create duplicate requests
8. loading indicator appears during load-more
9. previous notes remain visible
10. load-more failure preserves previous items
11. retry works
12. changing filters resets list
13. changing sort resets list
14. stale response is discarded

---

# 99. TAG UI REGRESSION TESTS

Ensure existing behavior remains correct:

- active tag moves near `All`
- horizontal bar scrolls appropriately
- tapping active tag removes selection
- selecting from sidebar updates list
- selecting from tag browser updates list
- advanced filtering does not break the tag bar

The existing implementation specifically guarantees active-tag promotion and auto-scroll. Preserve that contract.

---

# 100. FILTER UI TESTS

Test:

- open filter
- select filter
- deselect filter
- tag search
- AND/OR toggle
- date range
- content filters
- attachment filters
- clear individual chip
- clear all
- cancel
- apply
- small-screen layout
- keyboard navigation where applicable

---

# 101. SAVED FILTER TESTS

Test:

- create
- save
- load
- rename
- delete
- serialization
- invalid schema version
- unsupported predicate behavior
- account separation
- query restoration

---

# 102. PERFORMANCE TESTS

Measure representative workloads:

```text
1,000 notes
10,000 notes
50,000 notes
```

Verify that:

- initial query remains reasonable
- next-batch queries remain reasonable
- no entire-library object hydration occurs
- scrolling remains smooth
- memory remains bounded
- no O(total-notes) Dart processing occurs for standard indexed filters

Use profiling/query plans where practical.

---

# 103. SECURITY TESTS

Verify filtering cannot expose protected content.

Verify protected content is not written into logs.

Verify no OCR plaintext is persisted merely because a filter was used.

Verify no sensitive content crosses the sync/network boundary because of filters.

Verify saved filters contain only metadata/query definitions, not note contents.

---

# 104. MIGRATION TESTS

If the implementation adds indexes or columns, test:

```text current schema
old supported schema versions
upgrade to new schema
```

Do not ship an untested migration.

---

# 105. NO PLACEHOLDERS

Every visible option implemented by this feature must be functional.

Do NOT add UI entries such as:

```text
Mood >
Location >
Has OCR >
Saved Filters >
```

unless selecting them actually performs the operation.

There must be no:

- TODO buttons
- disabled fake menu entries
- placeholder dialogs
- "coming soon"
- hardcoded fake result counts
- static filter chips
- mock data

If a feature cannot be implemented correctly from the existing data model, do not put a misleading option in the production UI.

---

# 106. NO FAKE DATA

Never fabricate:

- note counts
- journal properties
- attachment counts
- OCR status
- viewed/open counts

All visible information must come from actual application state.

---

# 107. ANALYSIS BEFORE MODIFYING SCHEMA

Before changing database code, inspect:

- `notes_table.dart`
- `tags_table.dart`
- `note_tags_table.dart`
- attachment tables
- document tables
- OCR tables
- `AppDatabase`
- migrations
- NotesRepository
- existing Notes providers
- `notes_screen.dart`
- `TagsFilterBar`
- search providers

Use the actual schema instead of assumptions.

---

# 108. EXISTING LARGE-DOCUMENT PERFORMANCE CONSTRAINT

The editor already contains specific large-document performance protections because very large notes can reach megabytes and millions of words.

Do not make the Notes browser parse these entire note bodies just to construct filters.

A Notes list query must remain lightweight even if one note is enormous.

---

# 109. SEARCH / NOTES CONSISTENCY

The Notes list preview and Search result architecture already contains precomputed snippets/highlights to avoid expensive work in tiles. Preserve that performance model.

Do not make filtering cause every `NoteListTile` to re-run Markdown parsing or fuzzy scoring.

---

# 110. INFINITE SCROLL + SEARCH

If the Notes screen already supports navigating to Global Search, do not accidentally intercept the existing swipe-down-to-search behavior.

The project already uses scroll notifications for this interaction. Preserve it carefully when adding bottom-of-list infinite-scroll detection.

Top overscroll must continue working as before.

Near-bottom detection must not interfere with top overscroll detection.

---

# 111. QUERY RESULT ORDER CONTRACT

Define and document an explicit ordering contract.

For example:

```text
Recently Updated DESC:
updatedAt DESC
id ASC
```

```text
Recently Created DESC:
createdAt DESC
id ASC
```

```text
Title A-Z:
normalizedTitle ASC
updatedAt DESC
id ASC
```

The exact secondary ordering can be chosen based on existing product semantics, but it must be deterministic and documented.

---

# 112. CURSOR CONTRACT

Document how every sort maps to a cursor.

Do not implement cursor logic ad hoc inside widgets.

The cursor generator and query builder should share the same ordering definition so they cannot disagree.

Conceptually:

```text
SortDefinition
    |
    +-- orderBy expressions
    +-- cursor extraction
    +-- cursor continuation predicate
```

This is one of the most important architectural pieces.

---

# 113. QUERY BUILDER

Create a reusable query builder/service responsible for translating:

```text NotesQuery
```

into:

```text Drift query
```

The UI must never construct raw SQL fragments.

The builder should handle:

- base context
- filters
- joins/subqueries
- search integration
- ordering
- cursor continuation
- limit

---

# 114. SECURITY OF SAVED QUERY DATA

Saved queries must be treated as untrusted serialized data during future upgrades.

Validate:

- version
- enum values
- dates
- IDs
- sort definitions
- limits

Never deserialize a saved query into executable SQL.

---

# 115. QUERY LIMITS

Internally enforce sane maximum batch size.

Even if a bug requests:

```text
100000
```

do not load 100,000 notes accidentally.

Recommended:

```text default = 40
maximum = 100
```

Use centralized constants.

---

# 116. ACCESSIBLE LOADING STATES

The incremental loading state must be understandable to screen readers.

Expose an accessible semantic status such as:

```text Loading more notes
```

and:

```text Finished loading notes
```

only when appropriate.

Do not rely solely on visual spinners.

---

# 117. RESULT APPENDING

Append batches atomically.

Do not expose partially inserted batches to the list unless intentionally supported.

The order of appended notes must exactly match the database query.

---

# 118. SCROLL POSITION

When applying a new filter:

- reset to a sensible top position
- do not leave the scroll controller at an offset that makes the new first result appear halfway through the list

When loading more:

- preserve current scroll position

When refreshing the same query:

- choose a stable refresh behavior compatible with the existing UX

---

# 119. FILTER CHIP ANIMATION

Adding/removing filters may animate the chip row, but the animation must not cause large layout shifts in the Notes list.

Keep the transition compact.

---

# 120. NO NETWORK DEPENDENCY

The Notes Query System must function fully offline.

It must never call:

- Vercel
- Turso
- Cloudinary
- Firebase

just to sort/filter notes.

All standard Notes list queries must use local state/database.

---

# 121. BACKGROUND SYNC INTERACTION

If sync pulls new notes while the user is at the top:

The query may naturally update.

If sync pulls many records while the user is deep in the list:

Do not unexpectedly yank the user's scroll position to the top.

Prefer a calm update strategy.

For example:

```text
New notes available
```

or a deferred refresh when appropriate.

Do not invent a loud UI if the existing product has another convention.

---

# 122. QUERY OBSERVABILITY

For developer diagnostics only, optionally capture:

```text query type
filter count
batch size
query duration
rows returned
```

Do not log note content.

Do not log sensitive filter values where they could reveal sensitive metadata.

---

# 123. ERROR MESSAGES

Use user-friendly errors.

Never surface raw:

```text SqliteException(...)
```

to the user.

The application already has structured error handling in other subsystems. Follow that convention.

---

# 124. DEPENDENCY POLICY

Do not add a new package merely to implement:

- basic sorting
- filtering
- infinite scroll

These should use Flutter/Drift/Riverpod and existing application infrastructure.

Only add a dependency if the codebase genuinely lacks a required capability.

Do not perform unrelated upgrades.

---

# 125. IMPLEMENTATION PHASES

Implement in this order.

### Phase 1 — Repository analysis

Inspect all relevant Notes/database/search/tag code.

### Phase 2 — Domain model

Implement:

```text
NotesQuery
Filter definitions
Sort definitions
Cursor
SavedFilter
```

### Phase 3 — Database query engine

Implement real SQLite/Drift filtering, ordering and cursor continuation.

### Phase 4 — Provider/state layer

Implement query generation and incremental collection state.

### Phase 5 — Infinite scrolling

Implement first batch, prefetch, load-more, duplicate protection, stale-response protection and errors.

### Phase 6 — Sort UI

Implement real sort UI.

### Phase 7 — Filter UI

Implement all supported filters.

### Phase 8 — Existing tag-bar integration

Unify tag selection with NotesQuery.

### Phase 9 — Saved filters

Implement actual persistence and management.

### Phase 10 — Empty/loading/error states

Polish the full UX.

### Phase 11 — Testing/performance

Run comprehensive test and profiling suite.

---

# 126. VERIFICATION COMMANDS

After implementation:

```bash
flutter analyze
flutter test
```

If Drift code changed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Run all existing tests, not merely the new tests.

The current project has a substantial regression suite covering crypto, sync, database, editor, search, OCR and UI behavior, so the Notes Query feature must not regress unrelated areas.

---

# 127. REGRESSION VERIFICATION

Explicitly verify:

- sync
- fresh-device sync
- trash
- archive/restore
- pin/unpin
- tag changes
- editor autosave
- search
- OCR search
- attachments
- protected notes
- tablet split view
- top swipe-to-search
- existing tag bar
- note list rendering

The query system must be read-only and must not interfere with these systems.

---

# 128. DEFINITION OF DONE

The implementation is complete only when all of the following are true:

### Sorting

- Recently Updated works
- Recently Created works
- Title works
- ascending/descending directions work
- duplicate values remain deterministically ordered
- pinned-first works if implemented

### Filtering

- tag filtering works
- multiple-tag AND works
- multiple-tag OR works
- untagged works
- pinned works
- created-date filters work
- modified-date filters work
- custom date range works
- content filters work
- attachment filters work
- OCR filter works
- journal filters work where supported by actual data
- protected/unprotected works

### Existing tag UX

- tag bar remains functional
- active tag promotion remains functional
- active tag auto-scroll remains functional
- sidebar selection remains functional
- tag browser remains functional

### Infinite scroll

- first batch loads
- next batch loads near bottom
- multiple batches work
- final batch stops further querying
- rapid scrolling cannot produce duplicate loads
- duplicate notes cannot appear
- stale requests cannot corrupt the current list
- failed load-more keeps existing notes
- retry works
- changing query resets the cursor

### Performance

- no full-library Dart filtering
- no full-library Dart sorting
- no N+1 item queries
- no unnecessary OCR decryption
- no UI-thread heavy processing
- large libraries remain usable

### Persistence

- sort preference behaves correctly
- query state has correct account boundaries
- saved filters work if implemented
- no filter state enters note sync payloads

### Security

- protected note content remains protected
- OCR plaintext is not persisted as a filtering side effect
- no network dependency is introduced
- no sensitive note content enters diagnostics/logs

### UX

- no overflowing filter sheets
- no fake UI
- no placeholder options
- clear empty states
- clear loading states
- responsive tablet/mobile layouts
- calm Quiet Paper visual language

---

# 129. FINAL IMPLEMENTATION REPORT

After coding and verification, report:

```text
Implementation summary

Architecture:
- ...

Files added:
- ...

Files modified:
- ...

Database changes:
- ...

Indexes added:
- ...

Query model:
- ...

Supported sort options:
- ...

Supported filters:
- ...

Infinite-scroll behavior:
- ...

Cursor strategy:
- ...

Saved-filter implementation:
- ...

Tests added:
- ...

Performance verification:
- ...

flutter analyze:
- ...

flutter test:
- ...

Known limitations:
- ...
```

Do not claim success if tests fail.

Do not hide unsupported features.

Do not describe a UI option as implemented unless the underlying behavior is fully functional.

---

# 130. FINAL PRODUCT PRINCIPLE

The end result should feel like a natural evolution of Quiet Paper:

```text
Simple on the surface
        ↓
Powerful underneath
```

The user should be able to casually browse notes as:

```text
Notes
All   #work   #ideas   #programming
```

and tap:

```text
Sort
```

or:

```text
Filter
```

without encountering a complex database interface.

At the same time, the underlying implementation must be capable of handling:

```text
Search
+
Tags
+
Multiple filters
+
Sort
+
Pinned
+
Date ranges
+
Attachments
+
OCR presence
+
Journal metadata
+
Protected notes
+
Cursor
+
Infinite scroll
+
Saved smart views
```

without loading the entire notebook into memory.

The UI should feel effortless.

The database/query layer should be sophisticated.

That is the intended architecture.