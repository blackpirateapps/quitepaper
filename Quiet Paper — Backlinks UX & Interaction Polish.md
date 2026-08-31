# Quiet Paper — Backlinks UX & Interaction Polish

You have already implemented **Note Linking V1** in this repository.

This task is a **polish pass on the existing backlink implementation**.

Do not rebuild the note-linking architecture from scratch.

First inspect the current implementation and understand exactly how backlinks are currently stored, queried, rendered, and navigated. Then improve it to production quality.

The objective is:

> Backlinks should feel like a natural part of a Quiet Paper note, not like a separate “knowledge graph” feature bolted onto the bottom of the editor.

Keep the existing Quiet Paper philosophy:

- calm
- editorial
- content-first
- minimal
- warm
- restrained
- highly usable
- no unnecessary UI

Do not introduce panes, graph visualization, dashboards, or unrelated note-linking features.

---

# 1. First: Inspect the Existing Implementation

Before coding, inspect:

- current backlink/relationship model
- note-link index
- backlink repository/query methods
- Markdown note-link parser
- note-link navigation
- note editor / preview integration
- current backlink UI
- note lifecycle integration
- trash handling
- permanent deletion handling
- password-protected note handling
- sync/import/restore behavior
- tests already added for note links/backlinks

Determine:

1. What currently works.
2. What currently looks visually awkward.
3. What interactions feel excessive or noisy.
4. Whether backlinks are queried efficiently.
5. Whether duplicate source notes are correctly deduplicated.
6. Whether stale/deleted relationships can appear.
7. Whether backlinks cause unnecessary note/content loading.
8. Whether navigation behavior is consistent with normal note navigation.

Do not assume the current implementation matches the original specification perfectly.

---

# 2. Core UX Direction

Backlinks should feel like a quiet continuation of the document.

Avoid:

- large cards
- giant headers
- dashboards
- colorful graph UI
- prominent boxes
- excessive icons
- “knowledge graph” terminology
- unnecessary explanatory text

The preferred visual hierarchy is:

```text
[End of note content]


────────────────────────────────────

LINKED FROM · 4

Calculus
Study Plan
Signal Processing

Show 1 more
```

The section should visually belong to the note itself.

---

# 3. Placement

Backlinks should appear at the **end of the note content**, after the Markdown document itself.

They should not interrupt the document body.

They should not appear as a permanent sidebar.

They should not appear at the top of every note.

They should be visually separated from the note with a subtle divider / spacing treatment consistent with Quiet Paper's existing editorial design.

Recommended structure:

```text
content

                    ↓ generous spacing

────────────────────────────────────

LINKED FROM · 4

...
```

Use the existing theme spacing and divider tokens rather than introducing arbitrary values.

---

# 4. Hide the Entire Section When There Are No Backlinks

If a note has zero backlinks:

Do not render:

```text
LINKED FROM · 0
```

Do not render an empty container.

Do not render a divider that exists only for the backlink feature.

The note should look exactly like a normal note when there are no backlinks.

---

# 5. Backlink Count

When backlinks exist, show the count in the section header.

Examples:

```text
LINKED FROM · 1
LINKED FROM · 4
LINKED FROM · 17
```

Keep this understated.

The count should not visually overpower the note content.

Use the application's existing small uppercase metadata typography.

Do not use a badge/chip unless there is already a consistent Quiet Paper component that makes sense.

---

# 6. Deduplicate by Source Note

If:

```text
Note A → Note B
Note A → Note B
Note A → Note B
Note C → Note B
```

then the backlink section for Note B should show:

```text
LINKED FROM · 2

Note A
Note C
```

not:

```text
Note A
Note A
Note A
Note C
```

The count must represent **source notes**, not raw link occurrences.

Maintain the underlying multiple-link information in the relationship index where needed, but backlink presentation should normally deduplicate by source note.

---

# 7. Backlink Row Design

Each backlink should be a simple, highly readable row.

Recommended:

```text
Calculus
#mathematics · Edited today
```

or:

```text
Calculus
Mathematics · Today
```

Do not show large content previews by default.

Do not create a full NoteListTile inside the backlink section.

The backlink list should be visually lighter than the main note list.

Preferred hierarchy:

```text
Title
small muted metadata
```

The title should be the dominant element.

---

# 8. Metadata

Use only lightweight metadata that is already cheaply available.

Good candidates:

- source note title
- relevant tags
- relative updated date

Do not load full note bodies merely to render backlinks.

Avoid expensive relationship → note → content loading chains.

Protected note content must never be loaded merely to create a backlink preview.

---

# 9. Ordering

Choose a deterministic, useful ordering.

Recommended default:

1. most recently updated source note first
2. stable secondary ordering by title
3. stable UUID as final tie-breaker where necessary

The exact ordering may reuse existing repository conventions if one already exists.

The ordering must not randomly change between rebuilds.

If the current implementation already has a good deterministic ordering, preserve it.

---

# 10. Show Only a Small Number Initially

Do not let a note with 100 backlinks produce a massive wall of content.

Default visible count:

```text
5
```

or another sensible small number based on the current UI.

Example:

```text
LINKED FROM · 12

Calculus
Study Plan
Signal Processing
Physics Notes
Exam Preparation

Show 7 more
```

Do not use pagination.

Do not create a separate screen just for backlinks.

---

# 11. Expand / Collapse

When backlinks exceed the initial visible limit:

Show:

```text
Show 7 more
```

Tapping expands the complete list.

Then change to:

```text
Show less
```

The expansion should be animated subtly.

Recommended behavior:

- height/content transition
- approximately 150–220ms
- ease-out
- no bounce

The expanded/collapsed state is UI state only.

Do not persist it in the note or database.

---

# 12. Backlink Navigation

Every backlink row must be tappable.

Tapping:

```text
Calculus
```

opens that source note using the normal Quiet Paper note navigation mechanism.

Do not introduce any special pane behavior.

Do not open an external browser.

Do not create a second navigation stack.

The normal Back action should return to the target note in the expected way.

---

# 13. Preserve Existing Note Navigation

Do not break existing navigation semantics.

Example:

```text
Note A
  ↓ tap internal link
Note B
  ↓ tap backlink to A
Note A
```

This should remain ordinary navigation-stack behavior.

Do not attempt to intelligently collapse or rewrite navigation history unless the existing application architecture already does this.

Avoid surprising the user.

---

# 14. Optional Exact Source Position

The underlying relationship model may contain the originating Markdown offset.

Do not expose this visually.

However, if the current architecture makes it reliable, a backlink tap may eventually open the source note at the location where the link occurs.

For this polish pass:

### Only implement source-position navigation if:

- the existing editor supports reliable source-offset navigation
- UTF-16 offsets are correct
- Markdown/rendered offsets are handled correctly
- it does not require fragile hacks
- it does not destabilize the editor

Otherwise:

Simply open the source note normally.

Do NOT implement an inaccurate fake scroll-to-link behavior.

---

# 15. Trashed Source Notes

Backlinks from trashed notes need a deliberate treatment.

If:

```text
Trash Note A → Current Note
```

the backlink should generally not clutter the normal active backlink list.

Recommended approach:

- exclude trashed source notes from the default backlink list
- keep their underlying relationship intact
- if the app's existing lifecycle architecture supports it, optionally provide a subtle indication that additional backlinks exist in Trash

Do not permanently delete the relationship merely because the source note entered Trash.

Restoring the source note must make its backlink available again automatically.

Follow the existing Quiet Paper trash semantics.

---

# 16. Permanently Deleted Source Notes

When the source note is permanently deleted:

- its outgoing relationship rows must already be cleaned up by the existing lifecycle
- it must disappear from backlinks
- no stale title should remain visible
- no orphaned backlink row should remain

Do not mutate the target note's Markdown to accomplish this.

---

# 17. Protected Source Notes

If a backlink comes from a password-protected note:

Do not expose protected body content.

Do not fetch protected note body solely for rendering the backlink section.

Show only metadata already permitted by the existing protected-note policy.

Tapping the backlink must open the source note and invoke the normal protection/unlock flow.

Never bypass note-level security.

---

# 18. Link Preview Interaction

Add a subtle optional preview interaction where it is appropriate to the existing platform behavior.

For desktop:

- hover can show a small preview

For touch:

- long press can show a lightweight preview if this integrates naturally with the current UI

Preview should contain:

```text
Calculus

#mathematics

Short existing note excerpt...
```

But keep this secondary.

Do not turn backlinks into giant interactive cards.

Do not load sensitive protected content.

Do not make network requests.

If implementing previews causes complexity or performance problems, omit them rather than compromising the backlink experience.

---

# 19. Backlink Preview Security

For protected notes:

Never show:

- decrypted body preview
- protected tags if the existing policy does not allow them
- hidden content
- encrypted payloads
- OCR content
- attachment content

Reuse existing note-security behavior.

A backlink must never become a side-channel around note protection.

---

# 20. Internal Link Styling Consistency

Ensure backlink titles and internal note links use the same conceptual visual language.

There should be a recognizable but subtle relationship between:

```text
internal link inside note
```

and:

```text
backlink title at bottom of note
```

Do not create a second unrelated accent color.

Use existing theme semantic tokens.

Must work across:

- existing light themes
- existing dark themes
- existing theme families
- future theme additions

No hard-coded colors.

---

# 21. Responsive Design

The backlink section must work correctly on:

- small phones
- large phones
- tablets
- desktop

It should respect the same content width as the note.

Do not let backlink rows stretch far wider than the note's reading width.

Do not create a separate arbitrary max-width.

Reuse the note/editor typography and layout constraints.

---

# 22. Touch Behavior

Backlink rows need comfortable touch targets.

Do not make them tiny text-only tap targets.

Use a sufficiently large vertical hit area while keeping the visual design compact.

Tap feedback should be subtle and consistent with other Quiet Paper list interactions.

Do not add large ripple effects unless that already matches the app's interaction language.

---

# 23. Accessibility

Each backlink must have an accessible semantic description.

For example:

```text
Open linked note: Calculus
```

The expand/collapse action must also be accessible:

```text
Show 7 more backlinks
```

and:

```text
Show fewer backlinks
```

Do not rely only on visual hierarchy.

---

# 24. Loading Behavior

Backlinks should not make the note feel like it is waiting on a large data fetch.

Prefer:

- local database queries
- small result sets
- reactive updates
- cached metadata where already available

Avoid a large blocking spinner at the bottom of a note.

If the backlink query is asynchronous and requires a loading state, make it extremely subtle.

Do not block note editing.

---

# 25. Reactive Updates

When another note creates/removes a link to the current note:

the backlink section should update automatically when the underlying relationship index changes.

Example:

```text
Note B is open

Note A adds link → B

Backlinks should update:
A appears
```

Do not require the user to leave and reopen B.

Do not require manual refresh.

Use the existing reactive architecture appropriately.

---

# 26. Editor Performance

The backlink widget must not cause unnecessary rebuilds of the entire note editor.

A backlink update should not:

- rebuild the Markdown editor
- reset cursor position
- reset selection
- jump scroll position
- reload note content
- interrupt typing

Keep the backlink section's rebuild boundary localized.

This is particularly important because Quiet Paper's editor has strict Markdown/source selection behavior.

---

# 27. Preview Mode vs Edit Mode

Backlinks should be treated as a document-level companion section.

They should not interfere with editing the canonical Markdown source.

Do not inject backlink UI into the actual Markdown string.

The note content must remain unchanged.

Backlinks are presentation/application state.

---

# 28. Markdown Integrity

Do not change canonical Markdown merely to make backlinks work.

If a note contains:

```md
[Calculus](qp://note/UUID)
```

the Markdown remains exactly that.

The backlink section is derived separately.

Do not append:

```md
## Backlinks
```

to the stored note.

Do not write backlink metadata into the note body.

---

# 29. Relationship Index Integrity

Verify that the existing derived relationship table continues to behave as:

```text
Markdown = source of truth
note_links = derived index
```

Backlink polish must not change that invariant.

If there are stale relationships due to previous implementation bugs, fix the underlying index logic rather than merely hiding bad rows in the UI.

---

# 30. Data Query Efficiency

Backlink queries should return only what the UI needs.

Avoid:

```text
target note
→ load every source note
→ decrypt every source body
→ build entire note models
→ render three fields
```

Prefer:

```text
target UUID
→ relationship rows
→ lightweight source-note metadata
```

Use efficient indexed queries.

Ensure both relationship directions remain indexed.

---

# 31. Database Consistency

If a source note is:

- edited
- trashed
- restored
- permanently deleted
- restored from backup
- changed by sync
- changed by conflict resolution

the backlink display must eventually reflect the current canonical Markdown and note lifecycle.

Do not maintain a separate UI-only backlink cache that can drift from the database.

---

# 32. Sync

Do not add plaintext backlink data to cloud sync.

Backlinks remain derived locally from decrypted Markdown.

When synced Markdown changes:

```text
decrypt
→ save canonical note
→ update derived relationship index
→ backlink UI reacts
```

Preserve the zero-knowledge architecture.

---

# 33. Import / Restore

After Markdown notes are imported or restored:

- relationship index must reflect the imported/restored canonical content
- backlinks must work without requiring manual note editing
- no plaintext relationship graph should be uploaded to the cloud

Reuse the existing note-link indexing mechanism.

---

# 34. Visual Details

Recommended backlink section:

```text
                                   ↓

────────────────────────────────────────

LINKED FROM · 4

Calculus
#mathematics · edited today

Study Plan
#planning · yesterday

Signal Processing
#engineering · Aug 27

Show 1 more
```

Visual characteristics:

- small uppercase section label
- modest letter spacing
- muted metadata
- title uses normal note/list typography
- generous vertical rhythm
- subtle divider
- no card background
- no large border box
- no giant icons

The goal is editorial, not dashboard-like.

---

# 35. Avoid Redundant Icons

Do not put a chain-link icon on every backlink row.

Do not put arrows everywhere.

Use text hierarchy to communicate the relationship.

An icon may be used in a contextual action menu if useful, but the default backlink list should remain visually quiet.

---

# 36. “Show More” Behavior

If there are 6+ backlinks:

```text
LINKED FROM · 12

First 5…

Show 7 more
```

After tapping:

```text
LINKED FROM · 12

All 12…

Show less
```

The transition must not cause the entire editor to jump unexpectedly.

The user's reading position should remain stable as much as reasonably possible.

---

# 37. Backlink Section and Infinite/Long Notes

Ensure the backlink section works when:

- the note has very little content
- the note is thousands of lines long
- the note contains large code blocks
- the note contains images/documents
- the note is scrolled near the bottom
- the note uses custom typography
- the note uses narrow/medium/full paragraph width

Do not force the backlink section to rebuild large Markdown content unnecessarily.

---

# 38. Empty / Error States

If a backlink query fails unexpectedly:

Do not show raw database exceptions.

Prefer the application’s existing error-handling conventions.

If the failure is non-fatal:

- keep the note usable
- optionally show a subtle retry action

Do not make backlinks capable of breaking the editor.

---

# 39. Tests to Add or Update

Do not rely only on manual inspection.

Add tests for:

### Rendering

- zero backlinks → section absent
- one backlink → count = 1
- multiple backlinks → correct count
- many backlinks → collapsed state
- expand → all visible
- collapse → first N visible

### Deduplication

One source with multiple links to the same target → one backlink row.

### Ordering

Verify deterministic ordering.

### Navigation

Backlink opens correct source note.

### Reactive update

Adding/removing a relationship updates the visible backlink list without reopening the note.

### Trash

Trashed sources are handled according to the chosen behavior.

### Restore

Restoring source note restores its backlink.

### Permanent delete

Permanently deleted source disappears.

### Protected notes

No protected content leaks through backlink UI or preview.

### Responsive layout

Test narrow device widths and tablet layouts.

### Accessibility

Verify semantic labels for backlink rows and expand/collapse actions.

---

# 40. Performance Regression Tests

Verify that rendering backlinks does not cause large note-body fetches.

Where possible, use repository/provider tests to ensure backlink queries remain bounded.

Test with at least:

- 100 notes
- 1,000 notes
- 5,000 notes

and realistic backlink counts.

The UI must not become sluggish merely because the notebook is large.

---

# 41. Do Not Rebuild the Note-Link System

This task is polish.

Do not:

- replace the existing `qp://note/<UUID>` scheme
- replace canonical Markdown storage
- replace the existing relationship index unnecessarily
- create a graph database
- introduce a graph UI
- add panes
- add AI linking
- rewrite the entire navigation architecture

Make the smallest robust changes necessary.

---

# 42. Final Acceptance Criteria

The backlink implementation is complete only when:

- [ ] Backlinks appear naturally at the end of the note.
- [ ] The section is invisible when no backlinks exist.
- [ ] Count reflects unique source notes.
- [ ] Multiple links from one source note are deduplicated visually.
- [ ] Initial list is limited when there are many backlinks.
- [ ] “Show more” / “Show less” works smoothly.
- [ ] Ordering is deterministic.
- [ ] Rows are compact but comfortably tappable.
- [ ] Titles are easy to scan.
- [ ] Metadata is subtle and useful.
- [ ] No giant cards are used.
- [ ] No redundant icon clutter exists.
- [ ] Navigation opens the correct source note.
- [ ] Normal Back behavior works.
- [ ] Trashed-note behavior is correct.
- [ ] Permanently deleted notes do not remain as stale backlinks.
- [ ] Protected-note privacy is preserved.
- [ ] No protected body content leaks through previews.
- [ ] Backlinks update reactively.
- [ ] Backlink updates do not reset editor cursor/selection.
- [ ] Backlink updates do not cause editor scroll jumps.
- [ ] Backlink queries remain local and efficient.
- [ ] Full note bodies are not unnecessarily loaded for backlink display.
- [ ] No plaintext backlink graph is sent to the backend.
- [ ] Markdown remains completely untouched by the UI feature.
- [ ] Sync/import/restore/conflict flows continue to update backlinks correctly.
- [ ] Theme colors are semantic and theme-aware.
- [ ] Light/dark/theme-family variants all look correct.
- [ ] Phone layouts are correct.
- [ ] Tablet layouts are correct.
- [ ] Accessibility labels are present.
- [ ] Reduced-motion behavior is respected.
- [ ] Tests are added/updated for all meaningful behavior.
- [ ] No placeholder behavior remains.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.

---

# 43. Final Quality Check

After implementation, manually inspect these exact scenarios:

### Scenario A — One backlink

```text
A → B
```

Open B.

Backlink section should be nearly invisible in complexity.

### Scenario B — Many backlinks

```text
A → B
C → B
D → B
E → B
F → B
G → B
H → B
```

Verify the collapsed/expanded experience feels elegant.

### Scenario C — Duplicate links

```text
A → B
A → B
A → B
C → B
```

Verify B shows:

```text
LINKED FROM · 2
A
C
```

### Scenario D — Trash

Move A to Trash.

Verify B's backlink behavior is correct.

Restore A.

Verify it returns automatically.

### Scenario E — Protected source

Protect A.

Verify B does not leak A's private content.

### Scenario F — Live update

Leave B open.

Edit A so it links/unlinks B.

Verify B's backlink section updates without reopening B.

### Scenario G — Long note

Open a very large Markdown note with backlinks.

Verify typing and scrolling remain unaffected.

---

# Final Design Principle

Backlinks should answer one quiet question:

> **“What else in my notebook led me here?”**

They should not announce themselves as a feature.

A user should finish reading a note, reach the bottom, and naturally discover:

```text
LINKED FROM · 4

Calculus
Study Plan
Signal Processing
Physics Revision
```

and think:

> “Oh. These notes are connected.”

That is the desired experience.

Do not turn the backlink system into a dashboard.

Make it feel like the notebook itself has quietly developed memory.