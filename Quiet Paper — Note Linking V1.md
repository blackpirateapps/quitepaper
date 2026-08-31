# Quiet Paper — Note Linking V1
## Production-Ready Implementation Specification

You are implementing **Note Linking V1** in the existing Quiet Paper Flutter application.

This must be implemented as a **complete, production-quality feature**. Do not create mockups, placeholder widgets, fake repositories, TODO implementations, hard-coded demo data, or partially functional flows.

Before changing code, inspect the existing repository and read `HANDOFF.md` in full.

The implementation must integrate with the existing Quiet Paper architecture rather than introducing a parallel note/document system.

---

# 1. Product Goal

Quiet Paper should allow users to connect notes naturally while writing.

The core experience is:

```text
User types [[
        ↓
local note picker appears
        ↓
user searches/selects a note
        ↓
canonical Markdown link is inserted
        ↓
link is rendered as a native internal-note link
        ↓
user taps the link
        ↓
target note opens normally
        ↓
Back returns to the exact previous note/location
```

The experience should feel like a natural extension of the existing Markdown editor, not a separate knowledge-management product.

Do **not** introduce panes, split note views, graph visualization, or a second note editor.

---

# 2. Existing Architecture That Must Be Preserved

Quiet Paper already defines the canonical internal resource scheme:

```text
qp://note/<UUID>
```

and uses a local `QuietPaperResourceResolver` for internal resources.

The codebase already treats internal `qp://` resources separately from external browser URLs.

Use those existing primitives.

Do not invent another URI format.

Do not introduce a proprietary note-link database as the source of truth.

Markdown remains the canonical note body.

A canonical note link should look like:

```md
[Fourier Series](qp://note/550e8400-e29b-41d4-a716-446655440000)
```

The displayed text and target UUID are independent.

For example:

```md
[the paper](qp://note/UUID)
```

must continue displaying:

> the paper

even if the target note's title is later changed.

---

# 3. V1 Scope

Implement all of the following:

## Editor authoring

- `[[` note-link autocomplete
- live local note search
- keyboard navigation in autocomplete
- touch-friendly selection
- note-link insertion
- selection/cursor preservation
- formatting-toolbar “Link to Note”
- selecting existing text and converting it into a note link
- create-new-note action from autocomplete
- escaping/canceling autocomplete cleanly

## Rendering/navigation

- native internal-note link detection
- distinct internal-link styling
- tapping a note link opens the target note
- local UUID-based resolution
- correct back navigation
- broken target handling
- trashed target handling
- protected-note handling

## Relationship layer

- derived outgoing-link index
- backlinks
- outgoing-links metadata
- reactive relationship updates when Markdown changes
- rebuild/index support after sync/import/restore

## Discovery

- backlinks section at the end of the target note
- “Linked from N notes”
- expandable backlinks presentation
- tap backlink → open source note

## Note creation

- create a new note directly from the `[[...` picker
- insert link to the new note
- open new note after explicit creation
- no silent note creation

## Data integrity

- stable UUID relationships
- no duplicate relationship corruption
- no stale relationship records
- deleted/trash lifecycle handling
- sync/conflict compatibility
- backup/restore compatibility
- password-protected note privacy

---

# 4. Explicitly Out of Scope for V1

Do NOT implement:

- split panes
- “open in new pane”
- graph visualization
- graph database
- AI-generated relationships
- automatic semantic recommendations
- automatic linking of arbitrary mentions
- embeddings
- vector search
- collaborative real-time linking
- external-web backlink behavior

The V1 feature is a **native Markdown internal-linking system**.

---

# 5. Architecture

Use three conceptual layers.

```text
Canonical Markdown
        ↓
Note-link parser
        ↓
Derived relationship index
        ↓
Fast backlinks/outgoing-link queries
```

The relationship index is derived state.

It is never authoritative.

If the relationship index is deleted or rebuilt, the note relationships must be recoverable entirely from canonical Markdown.

---

# 6. Canonical Link Representation

Use:

```text
qp://note/<UUID>
```

as the target URI.

Canonical Markdown syntax:

```md
[Display Text](qp://note/<UUID>)
```

Examples:

```md
[Calculus](qp://note/abc123)
[important paper](qp://note/def456)
[Read this later](qp://note/ghi789)
```

Do not canonicalize these into:

```text
[[Title]]
```

inside the database.

`[[Title]]` is an authoring convenience.

The stored Markdown should use the canonical Quiet Paper URI representation.

---

# 7. `[[` Authoring Syntax

When the editor detects a user typing:

```text
[[
```

immediately enter note-link autocomplete mode.

Example:

```text
I should review [[
```

Display the note picker anchored naturally near the editing position.

Typing:

```text
[[four
```

filters the available notes.

Typing:

```text
[[linear eig
```

must be able to discover a note such as:

```text
Linear Algebra — Eigenvalues
```

Use the existing local note-search infrastructure instead of implementing an independent full-database search path.

---

# 8. Autocomplete Detection

The implementation must correctly identify:

- `[[`
- `[[query`
- cursor positioned after an active query
- cursor moving away from the query
- selection replacing the query
- newline
- backspace
- escape/cancel
- completion
- malformed/incomplete input

Do not trigger autocomplete when the user is outside an active link-triggering context.

Do not aggressively rewrite arbitrary existing Markdown.

A trigger should be represented internally with:

```text
triggerStart
queryStart
queryEnd
```

using UTF-16 offsets compatible with Flutter's text editing APIs.

The editor already has strict character/source-offset invariants.

Do not violate them.

---

# 9. Handling `[[Title]]`

The user experience may accept:

```text
[[Fourier Series]]
```

as the authoring interaction.

On selection, convert it into:

```md
[Fourier Series](qp://note/<UUID>)
```

Do not preserve the literal `[[...]]` as canonical storage.

The visible editor presentation should make the result look like a normal internal note link rather than exposing the implementation URI unnecessarily.

---

# 10. Replacing Existing Selected Text

If the user selects:

```text
Fourier notes
```

and chooses:

```text
Link to Note
```

then selects:

```text
Fourier Series
```

the result must be:

```md
[Fourier notes](qp://note/<UUID>)
```

The original selected display text must be preserved.

Do not replace it with the target note title unless the user explicitly chose the title.

---

# 11. Toolbar Integration

Add a **Link to Note** action to the existing editor formatting toolbar/context menu.

It must:

- work with no selection
- work with a selection
- work from touch
- work with hardware keyboards
- preserve existing selection behavior

Suggested semantics:

### No selection

Open note picker.

After selecting a note, insert:

```md
[Note Title](qp://note/<UUID>)
```

### Selection exists

Open note picker.

After selecting a note, wrap the selection:

```md
[selected text](qp://note/<UUID>)
```

Use the existing editor formatting architecture.

Do not duplicate link insertion logic in multiple widgets.

Create one canonical application-level note-link insertion utility.

---

# 12. Keyboard Support

Support the existing platform keyboard conventions.

At minimum:

- Arrow Up → previous result
- Arrow Down → next result
- Enter → select highlighted result
- Escape → close picker
- Tab may move through picker controls where appropriate

Do not break native:

- Cmd/Ctrl+C
- Cmd/Ctrl+V
- Cmd/Ctrl+X
- Cmd/Ctrl+A
- Cmd/Ctrl+Z
- Cmd/Ctrl+Shift+Z

The note-link implementation must coexist with the existing Markdown editor shortcuts.

---

# 13. Autocomplete UI

Do not use a generic large Material dialog.

The picker should visually match Quiet Paper.

Recommended structure:

```text
┌──────────────────────────────────┐
│ Link to a note                    │
│                                   │
│ 🔎 Fourier                        │
├───────────────────────────────────┤
│ Fourier Series                    │
│ #mathematics · Edited today       │
│ Periodic functions...             │
│                                   │
│ Fourier Transform                 │
│ #physics · Edited yesterday       │
│ Frequency-domain notes...         │
├───────────────────────────────────┤
│ + Create “Fourier”                │
└───────────────────────────────────┘
```

Use:

- restrained warm surface
- subtle border
- compact metadata
- accessible touch targets
- no oversized cards
- no visual noise

On mobile, prefer a keyboard-friendly bottom-sheet/popover presentation as appropriate to the existing editor architecture.

On desktop/tablet, anchor the picker near the cursor when practical.

---

# 14. Search Ranking

Use the existing local search/index infrastructure.

For note-link autocomplete, prioritize:

1. exact title match
2. title prefix match
3. title token match
4. title substring
5. fuzzy title
6. relevant tags
7. recent notes

Title matching should dominate.

Do not rank a weak tag match above a strong title match.

The picker is for **finding notes**, not performing arbitrary full-text search.

---

# 15. Current Note Exclusion

The note currently being edited should be excluded from normal autocomplete results.

This prevents accidental self-link creation.

If necessary for a specific search, it may still be represented explicitly, but it must not be a default top result.

---

# 16. Search Result Privacy

Respect note-level password protection.

The existing application supports individual password-protected notes.

The picker must never leak protected content through:

- body previews
- backlinks
- autocomplete snippets
- search context
- hover previews

Use the existing protected-note metadata policy.

Do not invent a new protection mechanism.

The current codebase preserves protected note titles while protecting their body/tags, so use the existing semantics consistently.

---

# 17. Create a New Note from the Picker

When the user enters a query for which no suitable note exists:

```text
[[Quantum Mechanics
```

show:

```text
+ Create “Quantum Mechanics”
```

This must be explicit.

Do NOT automatically create a note merely because the user pressed Enter.

When the user explicitly selects Create:

1. Create the new note through the existing notes repository/application layer.
2. Generate the normal UUID through the existing note creation mechanism.
3. Use the entered text as the initial title where appropriate.
4. Persist the note normally.
5. Insert the canonical note link into the original note.
6. Maintain undo/redo semantics.
7. Navigate to the newly created note only after successful creation and link insertion.
8. Do not create duplicates if the operation is retried.

The operation must be transactional from the user's perspective.

---

# 18. New Note Defaults

Use existing Quiet Paper note-creation defaults.

Do not duplicate title-generation or note initialization rules.

If the query is:

```text
Quantum Mechanics
```

the created note should have:

```text
title = Quantum Mechanics
```

with normal Quiet Paper empty-note behavior.

---

# 19. Navigation

Tapping:

```md
[Fourier Series](qp://note/<UUID>)
```

must resolve entirely through the internal resource mechanism.

Never send:

```text
qp://note/...
```

to the system browser.

Use local note lookup.

The destination should open in the existing normal note/editor flow.

---

# 20. Back Navigation

Navigation must preserve the user's original context.

Example:

1. User is inside Note A.
2. User is scrolled halfway through the document.
3. User taps a link to Note B.
4. Note B opens.
5. User presses Back.
6. Note A returns at approximately the previous scroll position.

Preserve where practical:

- note identity
- scroll position
- editor mode
- cursor position
- selection state

Do not reload Note A into a fresh unrelated navigation instance unnecessarily.

Use the application's existing navigation architecture.

Do NOT introduce panes.

---

# 21. Link Styling

Internal links should look different from external links but remain understated.

Recommended:

- theme accent text
- subtle underline or no underline depending on existing Markdown styling
- no large icon
- optional tiny internal-link glyph only where it improves clarity

Do not use a bright blue browser-style hyperlink everywhere.

The styling must work across:

- Classic Paper
- Warm Paper
- light
- dark
- future theme families

Consume semantic theme tokens rather than hard-coded colors.

---

# 22. Editor Link Rendering

When parsing:

```md
[Fourier Series](qp://note/<UUID>)
```

the Markdown editor should:

- recognize it as an internal note link
- style it appropriately
- preserve source length
- preserve cursor offsets
- keep the underlying URI unchanged
- remain compatible with composing text/IME behavior

Do not render the UUID in the visible text.

The implementation must respect the existing Markdown parser's 1:1 source-offset invariant.

---

# 23. Preview Link Rendering

In rendered Markdown preview mode:

```md
[Fourier Series](qp://note/<UUID>)
```

must render as an interactive internal link.

Tap:

→ open the target note.

Do not pass it into generic external URL handling.

The existing URI-routing/security architecture must remain respected.

---

# 24. Broken Links

A target note may no longer exist.

Example:

```md
[Old Project](qp://note/<deleted UUID>)
```

The link must not crash.

Render it using a subtle unavailable/broken-link treatment.

Tapping it should show an appropriate Quiet Paper message such as:

```text
This note is no longer available.
```

Provide:

```text
Remove link
```

where appropriate.

Do not silently delete the Markdown.

---

# 25. Trashed Notes

Trash is persistent in Quiet Paper.

If a linked note is in Trash:

- the URI remains valid
- opening the link should resolve the trashed note if the application already permits viewing trashed notes
- show a subtle “In Trash” state where useful
- do not treat a trashed note as the same thing as a permanently deleted note

Do not automatically rewrite links to trashed notes.

Only permanent deletion should produce a missing target.

---

# 26. Permanently Deleted Notes

When a target note is permanently deleted:

- do not rewrite every source note's Markdown
- do not silently remove links
- leave the canonical URI intact
- derived relationship index should remove the relationship if appropriate
- the UI should render the link as unavailable

This avoids destructive mutation of unrelated notes.

---

# 27. Backlinks

Implement backlinks as a first-class derived relationship.

If:

```text
Calculus Notes → Fourier Series
Study Plan → Fourier Series
Physics Revision → Fourier Series
```

then opening Fourier Series should show:

```text
LINKED FROM · 3

Calculus Notes
Study Plan
Physics Revision
```

Each backlink is clickable.

Clicking it opens the source note through the same normal navigation flow.

---

# 28. Backlink Presentation

Do not put backlinks in a large permanent sidebar.

Place them near the end of the note content.

Recommended presentation:

```text
────────────────────────────

LINKED FROM · 3

Calculus Notes
Study Plan
Physics Revision
```

Use the existing Quiet Paper editorial visual language.

If there are many backlinks:

```text
LINKED FROM · 12

Calculus Notes
Study Plan
Physics Revision

Show all 9 more
```

The expanded state can be local UI state.

Do not store UI expansion state inside the note.

---

# 29. Backlink Counts

Show count only when meaningful.

Examples:

```text
LINKED FROM · 1
LINKED FROM · 4
```

Do not show:

```text
LINKED FROM · 0
```

When there are no backlinks, the entire section should disappear.

Do not leave an empty heading.

---

# 30. Outgoing Link Information

The derived relationship layer should know:

```text
sourceNoteId
targetNoteId
displayText
sourceOffset
```

This supports:

- outgoing-link count
- backlinks
- future graph capability
- future navigation utilities

But do not build graph UI in V1.

---

# 31. Derived Relationship Table

Add an appropriate Drift table, for example conceptually:

```text
note_links

source_note_id
target_note_id
display_text
source_offset
created_at / updated_at as appropriate
```

Use the project's existing database conventions and migration patterns.

The exact schema may be adapted to the current architecture.

At minimum, optimize queries by:

```text
source_note_id
target_note_id
```

so both directions are fast.

---

# 32. Do Not Treat the Table as Canonical

The table can always be rebuilt from Markdown.

For example:

```text
DELETE note_links
REBUILD FROM ALL NOTE MARKDOWN
```

must produce the same relationship set.

This is essential for:

- migrations
- recovery
- imports
- backup restore
- sync
- conflict resolution

---

# 33. Incremental Index Maintenance

Do not rebuild every note's relationships every time one note changes.

When Note A changes:

1. Parse Note A for internal-note links.
2. Remove existing outgoing relationships for Note A.
3. Insert the new outgoing relationships.
4. Ensure backlinks now reflect the new source state.

Use a transaction.

Conceptually:

```text
transaction:
  delete links where source = A
  insert parsed links from A
commit
```

Do not leave the relationship index half-updated.

---

# 34. Parsing Note Links

Implement a dedicated parser/extractor for canonical internal links.

It must recognize:

```md
[title](qp://note/UUID)
```

correctly.

It must tolerate:

- whitespace
- URL encoding where appropriate
- nested Markdown formatting in display text where the existing parser allows it
- escaped characters
- multiple links
- links adjacent to punctuation
- links inside normal prose

It must not mistake:

```text
qp://asset/<UUID>
qp://document/<UUID>
```

for note links.

Only:

```text
qp://note/<UUID>
```

belongs in the note-link relationship index.

---

# 35. Internal Note URI Validation

Do not trust arbitrary Markdown text.

Validate:

- URI scheme
- host/path format according to the existing `qp://` conventions
- UUID format
- malformed IDs

Invalid note URIs should not crash rendering or indexing.

They may remain ordinary link-like text or receive the application's unavailable-link handling.

---

# 36. Duplicate Relationship Handling

If a note links to another note multiple times:

```md
See [Calculus](qp://note/A).

Later: [Calculus](qp://note/A).
```

do not lose either source position.

The relationship model may have multiple link rows differentiated by source offset.

Backlinks should deduplicate the displayed source note:

```text
Calculus Notes
```

rather than displaying it twice merely because there are two links.

Opening the backlink should have a deterministic destination.

---

# 37. Source Offset Handling

Where possible, store the source Markdown offset for each link.

This creates future support for:

- jumping directly to a specific link
- contextual backlink navigation
- future editor tooling

The offset must use the same UTF-16 indexing conventions as Flutter text editing.

Do not use byte offsets.

Do not use rendered-text offsets.

---

# 38. Updating Backlinks After Sync

When encrypted note content is pulled from sync and decrypted locally:

- persist the canonical note content normally
- update the derived note-link index
- do not depend on a user opening the note for indexing to occur

Similarly update relationships after:

- conflict merge
- restore
- import
- local edit

This should happen through the existing note lifecycle/application layer rather than scattered widget callbacks.

---

# 39. Conflict Resolution

The existing sync conflict system performs Markdown merges.

Note links are part of Markdown.

Therefore:

- merged `qp://note/...` links remain canonical Markdown
- derived relationships are rebuilt/updated from the merged Markdown
- relationship table should never participate as a separate conflict source

If a conflict produces:

```md
[Foo](qp://note/A)
```

the link index must reflect it after the merge.

Do not merge relationship-table rows independently.

---

# 40. Backup/Restore

When restoring notes:

- restore canonical Markdown first
- derive note links from restored Markdown
- rebuild relationships for restored notes

Do not treat `note_links` as authoritative backup content unless the existing database architecture has a compelling reason to serialize it.

It should be safely rebuildable.

---

# 41. Import

When importing Markdown files:

- preserve canonical `qp://note/...` links if they already exist
- derive relationships after imported notes are committed
- do not break the existing recursive Markdown import behavior

If imported Markdown contains ordinary relative links, do not automatically convert them into Quiet Paper note links unless explicitly supported by the existing importer.

V1 should only create native links through explicit Quiet Paper linking behavior.

---

# 42. Link Navigation Through Existing Resolver

Extend the existing `QuietPaperResourceResolver`/navigation system where appropriate.

Do not create:

```text
NoteLinkService
that bypasses
QuietPaperResourceResolver
```

if an existing generic resource-resolution path can safely support note targets.

The implementation should centralize:

```text
qp://note/<UUID>
```

resolution.

---

# 43. Security Boundary

A `qp://note/<UUID>` URI is an internal resource identifier.

It must never:

- invoke `url_launcher`
- become an external web URL
- be sent to the system browser
- trigger network navigation

Resolve locally.

---

# 44. Password-Protected Target Notes

If a note link points to a protected note:

```text
Note A
  ↓
qp://note/B
```

tapping it should open the normal protected-note unlock flow.

Do not bypass the protection.

Do not expose:

- body preview
- decrypted title/body information not already permitted by existing metadata policy
- protected backlink snippets

Reuse the existing `PasswordUnlockView` / note security mechanisms.

---

# 45. Backlinks to Protected Notes

If the source note itself is password-protected:

- do not expose its protected body in backlink previews
- the backlink title should follow existing metadata policy
- tapping it should go through the normal unlock flow

Do not introduce a secondary access path.

---

# 46. Note-Link Context Menu

Long-press/right-clicking an internal note link should provide useful actions.

At minimum:

```text
Open Note
Copy Link
Remove Link
```

Where supported by the existing editor/platform interaction model.

“Copy Link” should copy the canonical Markdown link where appropriate, not merely the UUID.

Do not add pane actions.

---

# 47. Editing an Existing Note Link

If the user invokes the regular link-editing action on an internal note link, the system should recognize it as a note link.

Provide:

```text
Change linked note
```

rather than forcing the user to manually edit the `qp://` URI.

Preserve display text unless the user explicitly changes it.

---

# 48. Note Picker Selection Behavior

When the picker opens for:

```text
[[four
```

selecting:

```text
Fourier Series
```

should replace only:

```text
[[four
```

not surrounding text.

Example:

```text
Review [[four before the exam
```

becomes:

```md
Review [Fourier Series](qp://note/UUID) before the exam
```

Do not consume surrounding spaces unnecessarily.

---

# 49. Undo/Redo

Insertion of a note link must be a single logical editing operation.

For example:

```text
type [[four
select result
```

should produce one undoable insertion.

Pressing Undo should restore:

```text
[[four
```

or the original selected text state.

It should not require five undo presses for:

- deleting trigger
- inserting Markdown
- replacing selection
- moving cursor

Use the existing editor undo/redo system.

---

# 50. Cursor Placement After Insertion

After completing a note link:

```md
[Fourier Series](qp://note/UUID)
```

place the caret immediately after the inserted Markdown link.

The editor's visual representation may hide parts of the URI, but the underlying selection must remain source-accurate.

Do not leave the cursor inside the URI unless that matches the existing Markdown link editing behavior.

---

# 51. IME and Composition Safety

The existing Markdown editor has careful behavior around:

- Android IMEs
- composing ranges
- source offsets
- custom fonts
- whitespace preservation

The note-link autocomplete implementation must not interfere with:

- composing text
- predictive keyboards
- hardware keyboards
- selection handles

Do not mutate text during active IME composition unless the operation is explicitly initiated by the user.

---

# 52. Autocomplete Dismissal

Dismiss the picker when:

- user presses Escape
- user taps outside, according to platform conventions
- cursor leaves the active `[[query` region
- user deletes the opening trigger
- a note is selected
- note editor is disposed
- another modal flow begins

Do not leave an orphaned overlay behind.

---

# 53. Search Debouncing

Use the existing debounce utilities where appropriate.

Do not perform full searches on every individual character if the existing search subsystem is expensive.

However, UI input must still feel responsive.

Recommended:

- immediate local state update
- approximately 100–150ms search debounce where needed
- cancel stale search generations
- only display results for the current query

Do not let an older search overwrite newer results.

---

# 54. Empty Results

When no result matches:

```text
No matching notes
```

Then show:

```text
+ Create “query”
```

provided the query is non-empty and valid.

Do not show an empty blank popup.

---

# 55. Special Queries

Handle:

- empty query
- whitespace-only query
- very long query
- punctuation
- Unicode
- emoji
- mixed case
- multiple spaces

Normalize only for search.

Do not mutate the user's actual text unexpectedly.

---

# 56. Performance

The autocomplete must not load all note bodies into memory for every keystroke.

Prefer:

- title-focused indexed retrieval
- bounded result count
- existing FTS/search infrastructure
- local query execution
- lightweight result DTOs

Only load full note data when needed for navigation or creation.

The note picker should remain responsive with thousands of notes.

---

# 57. Link Index Performance

Backlink queries must be indexed.

Queries needed frequently:

```sql
SELECT source_note_id ...
WHERE target_note_id = ?

SELECT target_note_id ...
WHERE source_note_id = ?
```

Create appropriate indexes.

Do not scan every note's Markdown whenever backlinks are displayed.

---

# 58. Relationship Consistency

Implement one centralized relationship synchronization method.

For example conceptually:

```text
reindexOutgoingLinks(noteId, markdown)
```

All relevant note mutation paths should use it.

Do not put relationship updates only in `EditorScreen`.

That would miss:

- imports
- restores
- sync pulls
- conflict resolution
- programmatic note edits

---

# 59. Transactional Note Update

When a note's Markdown is changed locally, ensure the following do not become inconsistent:

```text
note content
note revision/dirty state
note_links
```

Use a database transaction where appropriate.

If relationship extraction fails unexpectedly:

- do not corrupt the note
- report the error appropriately
- preserve the canonical Markdown
- ensure the system can rebuild the relationship index later

---

# 60. Migration

Introduce the minimum required Drift schema migration for the relationship table.

Do not modify existing schema casually.

Follow the repository's established migration conventions.

Migration must be safe for:

- fresh installs
- existing installs
- upgrade from historical schema versions

Add explicit migration tests.

---

# 61. Rebuild Tooling

Implement an internal application/database utility to rebuild all note links from canonical Markdown.

Conceptually:

```text
rebuildNoteLinkIndex()
```

This should:

1. clear derived relationships
2. iterate active note Markdown
3. parse `qp://note/...` links
4. write relationships transactionally in batches
5. report completion/failure safely

This is useful for:

- migrations
- recovery
- debugging
- backup restore
- future schema changes

Do not expose this as a prominent user feature unless the existing settings architecture benefits from it.

---

# 62. Trash and Indexing

Decide relationship-index behavior consistently with existing search/trash architecture.

Recommended:

- preserve links originating from active notes
- do not use trashed notes as ordinary backlink results by default
- preserve their canonical relationships while they remain recoverable
- permanently deleting a note removes its own outgoing link rows and incoming relationship rows

Do not silently mutate active Markdown because a target note was deleted.

---

# 63. Permanent Deletion Cleanup

When permanently deleting note B:

```text
delete note B
delete note_links where source = B
delete note_links where target = B
```

This cleanup must be included in the existing permanent-deletion lifecycle.

Do not leave dangling relationship rows.

Attachments/documents already associated with note deletion must continue following the existing deletion architecture.

Note linking must not interfere with unrelated resource cleanup.

---

# 64. Navigation Stack Safety

Prevent navigation loops such as:

```text
A → B → A → B → A
```

from corrupting navigation state.

Normal navigation history is acceptable.

Do not invent an aggressive deduplication system that surprises the user.

The expected behavior is standard stack navigation.

---

# 65. Link Preview

For V1, add a lightweight link preview only where it improves usability.

Recommended interaction:

- desktop hover or right click
- long press on mobile where practical

Show:

```text
Fourier Series

#mathematics #analysis

Short existing note preview...
```

However:

- use only data already permitted to be exposed
- do not decrypt protected note content merely to show a preview
- do not perform network requests
- do not create a giant floating card

If implementing this would compromise editor stability, prioritize core linking/backlinks over previews.

The final implementation should favor reliability over feature count.

---

# 66. Backlink Navigation

When a backlink is tapped:

- open the source note normally
- do not use panes
- preserve standard back navigation
- where source offset is available, optionally scroll to the originating link if this can be implemented reliably without destabilizing the editor

If exact link-target scrolling is not reliable with the current editor architecture, open the source note normally rather than implementing a fragile approximation.

Do not fake the scroll location.

---

# 67. Search Integration

The note picker should use existing search infrastructure.

Do not create a new database-wide title search system just for links.

Where the existing search engine supports:

- FTS5
- prefix matching
- fuzzy ranking

reuse it.

The picker can apply additional title-focused ranking after candidate retrieval.

Respect existing privacy rules.

---

# 68. Export Compatibility

The existing export system supports:

- Markdown
- PDF
- HTML
- plain text
- Word
- `.qpnote`

Keep note-link semantics stable.

For Quiet Paper's own full-fidelity formats:

```text
qp://note/<UUID>
```

can remain canonical.

For ordinary Markdown export, implement behavior consistent with the existing export philosophy.

Do not silently produce misleading external URLs.

Where conversion to relative Markdown files is appropriate, do it in the exporter rather than changing the stored note.

Do not modify canonical Markdown merely for export.

---

# 69. HTML/PDF Export

Internal note links should not become broken external links without intentional handling.

Implement or preserve existing exporter behavior so that:

- HTML export has sensible internal link representation
- PDF export does not attempt to launch `qp://`
- plain text export produces readable display text

Do not add exporter logic that mutates the original note.

---

# 70. Backup Compatibility

Because relationships are derived:

- backups do not need to treat the relationship index as canonical
- restored note Markdown must reconstruct the relationship graph
- verify that restored note links produce the same backlinks

Add restore regression tests.

---

# 71. Sync Compatibility

Because the actual relationship is encoded inside encrypted Markdown:

- no plaintext relationship content should be sent separately merely to support backlinks
- no new cloud plaintext table is required
- no plaintext note titles/bodies should be uploaded for link resolution

Backlinks are derived locally from decrypted note content.

Respect the existing zero-knowledge architecture.

---

# 72. Zero-Knowledge Considerations

Do not add backend APIs that accept:

```text
sourceNoteTitle
targetNoteTitle
linkGraph
```

in plaintext.

The cloud must not gain a plaintext graph of the user's notebook.

The relationship index is a local derived convenience.

The existing cloud architecture already keeps note content encrypted and the backend crypto-blind.

Maintain that invariant.

---

# 73. Theme Integration

Internal links and backlinks must use semantic Quiet Paper theme colors.

Do not hard-code:

```dart
Colors.blue
Colors.black
Colors.white
```

Use the existing:

- theme extension
- app colors
- typography
- spacing
- radii

systems.

Ensure the feature works in all existing theme families and appearances.

---

# 74. Accessibility

Autocomplete items must provide:

- semantic labels
- keyboard focus
- screen-reader-friendly names
- sufficient touch target sizes
- meaningful action descriptions

Backlinks must also be accessible.

Do not rely on color alone to indicate internal links.

---

# 75. Responsive Behavior

Support:

- phone portrait
- phone landscape
- tablet portrait
- tablet landscape
- desktop

The picker must not overflow the viewport.

The picker should handle:

- long note titles
- long search strings
- large result sets
- keyboard appearing
- keyboard disappearing
- orientation changes

No clipped content or inaccessible controls.

---

# 76. Error Handling

Every link operation must have a graceful failure path.

Examples:

### Target missing

Show unavailable note state.

### Note creation fails

Do not insert a dead URI.

### Database index update fails

Do not corrupt the canonical note body.

### Navigation fails

Show a user-friendly error rather than crashing.

### Parser encounters malformed Markdown

Continue safely.

Never crash because a note contains malformed note-link syntax.

---

# 77. Testing — Unit

Add comprehensive unit tests for:

## URI parsing

- valid `qp://note/UUID`
- invalid UUID
- wrong scheme
- wrong resource type
- asset URI
- document URI
- malformed URI

## Markdown extraction

- one link
- many links
- repeated links to same target
- links next to punctuation
- links surrounded by Markdown formatting
- invalid links
- escaped text
- Unicode display text
- source offsets

## `[[` detection

- `[[`
- `[[query`
- cursor in middle
- selection present
- malformed trigger
- trigger deleted
- newline
- whitespace
- Unicode

## Search ranking

- exact title
- prefix
- substring
- fuzzy
- tag
- recency
- current-note exclusion

## Link insertion

- no selection
- selected text
- cursor placement
- UTF-16 offsets
- undo/redo

## Relationship index

- insert
- update
- delete
- rebuild
- duplicate links
- source/target indexes
- permanent deletion cleanup

---

# 78. Testing — Widget

Test:

### Autocomplete

1. Open editor.
2. Type `[[`.
3. Verify picker appears.
4. Type search query.
5. Verify results update.
6. Select result.
7. Verify canonical Markdown inserted.
8. Verify caret placement.

### Existing selection

1. Select text.
2. Tap Link to Note.
3. Select target.
4. Verify display text preserved.

### Cancel

1. Trigger picker.
2. Escape/tap outside.
3. Verify editor remains intact.

### Create note

1. Type unknown note title.
2. Choose Create.
3. Verify new note is created.
4. Verify link is inserted.
5. Verify navigation to new note works.

### Link navigation

1. Create A.
2. Create B.
3. Link A → B.
4. Tap link.
5. Verify B opens.
6. Back.
7. Verify A returns.

---

# 79. Testing — Backlinks

Create:

```text
A → C
B → C
D → C
```

Verify C shows:

```text
A
B
D
```

Then remove B's link.

Verify:

```text
A
D
```

Then permanently delete D.

Verify:

```text
A
```

No stale relationship rows may remain.

---

# 80. Testing — Trash

Create:

```text
A → B
```

Move B to Trash.

Verify:

- A's link remains
- backlink lifecycle behaves correctly
- no crash
- no automatic Markdown mutation

Restore B.

Verify relationships recover without manual re-linking.

---

# 81. Testing — Protected Notes

Create protected B.

Link A → B.

Verify:

- A can link to B
- picker does not leak protected body
- tapping A → B invokes normal unlock behavior
- failed unlock does not expose content

---

# 82. Testing — Sync

Verify:

1. Device A creates A → B.
2. Sync.
3. Device B receives/decrypts notes.
4. Backlinks are derived locally.
5. Device B edits the relationship.
6. Sync.
7. Device A derives updated relationships.

Do not rely on relationship-table cloud synchronization.

---

# 83. Testing — Conflict Resolution

Create conflicting Markdown edits containing note links.

Verify merged Markdown remains canonical.

Verify the derived relationship index reflects the final merged content.

---

# 84. Testing — Backup/Restore

Backup a notebook containing:

```text
A → B
C → B
```

Restore it.

Verify backlinks are reconstructed.

Then compare the relationship set before/after restore.

---

# 85. Testing — Import

Import Markdown containing valid native Quiet Paper note links.

Verify relationships are derived correctly after import.

Do not modify unrelated imported content.

---

# 86. Testing — Performance

Create a realistic dataset of at least several thousand notes.

Measure:

- autocomplete latency
- picker result latency
- backlink query latency
- note navigation latency
- relationship indexing time for a changed note
- full relationship-index rebuild time

Autocomplete should remain responsive.

Do not load every note body for every keystroke.

---

# 87. Testing — Migration

Test migration from all supported previous database schema versions into the new schema.

Verify:

- no duplicate-column errors
- no missing-table errors
- no data loss
- relationship table exists
- existing notes remain intact

Follow the repository's established migration regression style.

---

# 88. Production Logging

Add useful debug instrumentation where appropriate, but do not log:

- note contents
- protected note bodies
- encryption keys
- plaintext sensitive metadata unnecessarily

Useful logs may include:

```text
note-link index updated
source note UUID
number of outgoing links
index duration
stale link target resolution
```

Avoid logging display text if it could contain sensitive user content.

---

# 89. Memory and Lifecycle

Autocomplete overlays, subscriptions and controllers must be disposed correctly.

Do not leak:

- search streams
- timers
- focus listeners
- keyboard listeners
- overlay entries
- animation controllers

When the editor is disposed, all note-link autocomplete state must be disposed.

---

# 90. Architecture Quality

Avoid putting significant note-link logic inside:

- `build()`
- individual button callbacks
- Markdown preview widgets
- `NoteListTile`

Business logic should live in appropriate domain/application services.

The implementation should be testable without rendering the entire UI.

---

# 91. Suggested Component Responsibilities

Adapt names to the repository's actual architecture.

Conceptually:

```text
NoteLinkParser
    Parses canonical qp://note links.

NoteLinkComposer
    Creates canonical Markdown links.

NoteLinkAutocompleteController
    Manages [[ query state.

NoteLinkSearchService
    Uses existing local search infrastructure.

NoteLinkIndexService
    Maintains derived note_links table.

NoteLinkResolver
    Resolves qp://note/<UUID> locally.

BacklinkRepository
    Queries relationships by target/source.

NoteLinkPicker
    Presentation widget.

BacklinksSection
    Presentation widget.
```

Do not create all of these if the existing architecture already has equivalent abstractions.

Prefer integration over unnecessary class proliferation.

---

# 92. Important Source-of-Truth Rule

The complete system must obey:

```text
Markdown
   ↓
authoritative note content

note_links
   ↓
derived index

resolver
   ↓
navigation convenience
```

Never:

```text
note_links
   ↓
authoritative note relationships
```

If the relationship database disappears, Quiet Paper must still know the true relationships by parsing canonical Markdown.

---

# 93. UX Details That Must Feel Premium

The feature should feel extremely polished.

Autocomplete should:

- appear quickly
- animate subtly
- never flash
- preserve the keyboard
- preserve cursor position
- select the most likely result
- feel stable while results update

Link insertion should:

- be immediate
- animate nothing unnecessarily
- not cause the editor to jump
- not lose focus
- not move the scroll position unexpectedly

Navigation should:

- feel native
- preserve back behavior
- never flash a blank editor
- never open a browser
- never require a network connection

Backlinks should:

- quietly appear where useful
- disappear when empty
- feel like part of the note rather than an external dashboard

---

# 94. Animation Guidelines

Use subtle animations only where they communicate state.

Good:

- autocomplete fade/slide in: ~120–180ms
- selected result state transition
- backlink expansion
- internal-link press feedback

Avoid:

- bouncing note cards
- exaggerated page transitions
- continuous decorative animation
- excessive parallax

Quiet Paper is a writing application.

Motion should support the content rather than compete with it.

Respect reduced-motion preferences.

---

# 95. Do Not Redesign Unrelated UI

Do not rewrite:

- note list
- sidebar
- settings
- sync screens
- scanner
- attachment viewer
- document viewer
- theme engine

unless a small integration change is objectively required.

Keep the implementation focused on Note Linking V1.

---

# 96. Acceptance Criteria

The implementation is complete only when:

- [ ] `[[` triggers note autocomplete.
- [ ] Autocomplete searches locally.
- [ ] Search results are fast and ranked sensibly.
- [ ] Current note is excluded from normal results.
- [ ] Selecting a result inserts canonical `[Text](qp://note/UUID)` Markdown.
- [ ] Selected text can be converted into a note link.
- [ ] Toolbar provides Link to Note.
- [ ] Keyboard interaction works.
- [ ] Touch interaction works.
- [ ] Cursor/selection offsets remain accurate.
- [ ] Undo/redo treats link insertion as one logical operation.
- [ ] New note can be explicitly created from the picker.
- [ ] New-note creation does not create duplicates on retry.
- [ ] The new link is inserted only after successful note creation.
- [ ] Internal links receive distinct theme-aware styling.
- [ ] Internal links open locally.
- [ ] `qp://note/...` never opens the external browser.
- [ ] Back navigation returns to the previous note correctly.
- [ ] Broken note targets are handled gracefully.
- [ ] Trashed note targets are handled correctly.
- [ ] Password-protected targets respect existing security.
- [ ] Backlinks are implemented.
- [ ] Backlinks are derived from Markdown.
- [ ] Duplicate links do not duplicate backlink note entries.
- [ ] Relationship queries are indexed.
- [ ] Relationships update when Markdown changes.
- [ ] Relationships update after sync.
- [ ] Relationships update after conflict resolution.
- [ ] Relationships update after import.
- [ ] Relationships update after restore.
- [ ] Permanent note deletion cleans relationship rows.
- [ ] Relationship index can be rebuilt.
- [ ] No plaintext relationship graph is sent to the backend.
- [ ] Backup/restore remains correct.
- [ ] Export behavior remains correct.
- [ ] Existing zero-knowledge guarantees remain intact.
- [ ] Existing Markdown source-of-truth architecture remains intact.
- [ ] No panes are introduced.
- [ ] No graph UI is introduced.
- [ ] No AI linking is introduced.
- [ ] No placeholder implementation remains.
- [ ] All new unit tests pass.
- [ ] All new widget tests pass.
- [ ] Integration tests pass.
- [ ] Migration tests pass.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.

---

# 97. Required Final Verification

After implementation:

```bash
flutter analyze
flutter test
```

Run any project-specific code-generation commands required by Drift.

Verify generated files are updated correctly.

Inspect the final diff for:

- unintended schema changes
- duplicated logic
- hard-coded theme colors
- debug logging that leaks user content
- TODOs/placeholders
- dead code
- unused dependencies
- navigation regressions

Do not declare completion while known test failures remain.

---

# 98. Final Implementation Report

At the end, provide a concise engineering summary containing:

### Root implementation

What classes/services/components were added or modified.

### Data model

How canonical Markdown and derived link relationships interact.

### Editor UX

How `[[` autocomplete works, how selection insertion works, and how keyboard/touch behavior works.

### Navigation

How `qp://note/<UUID>` resolves and how back navigation is preserved.

### Backlinks

How they're derived, stored, queried and updated.

### Lifecycle

How sync/import/restore/conflict/deletion interact with the relationship index.

### Security

How protected notes and zero-knowledge constraints are respected.

### Testing

What tests were added and final `flutter analyze` / `flutter test` results.

### Remaining limitations

Only list genuine limitations discovered during implementation. Do not invent caveats simply to fill the section.

---

# Final Design Principle

Do not build a “knowledge graph feature.”

Build a **beautiful native linking system for a Markdown notebook**.

The user should be able to write:

```text
I need to revisit [[Fourier Series]]
```

find the note instantly, insert the link without thinking about Markdown syntax, follow it naturally, return exactly where they were, and later discover that:

```text
Fourier Series
```

is also connected to:

```text
Calculus
Physics Revision
Signal Processing
Study Plan
```

All of that should emerge naturally from the canonical Markdown already stored in Quiet Paper.

The feature should feel almost invisible when used correctly.

That is the goal.