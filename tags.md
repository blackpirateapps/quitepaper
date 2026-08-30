# Production Implementation Prompt — Advanced Tags System for Quiet Paper

You are working on an existing production-oriented Flutter note-taking application with a Bear-inspired UX.

Implement a complete, polished, production-ready **Tag Management & Navigation System** with support for:

- Tag icons
- Optional tag colors
- Pinned tags
- Custom pinned ordering
- Tag search
- Tag sorting
- Tag filtering
- Tag note counts
- Tag detail views
- Tag rename propagation into every associated note
- Tag deletion
- Tag merging
- Search integration
- Keyboard-friendly tag navigation where supported
- Fully sync-aware tag metadata
- Correct interaction with the existing canonical-Markdown note storage model
- Correct interaction with the existing sophisticated sync/conflict-resolution architecture

Do not implement a superficial UI-only solution. Treat tags as first-class synchronized entities with stable identity.

The implementation must fit the application's existing architecture, database layer, repositories, sync engine, search subsystem, note editor, note renderer, navigation, state management, and design system.

Before modifying code, inspect the existing architecture thoroughly and identify:

- Current tag database tables/entities
- Note/tag relationship representation
- How Markdown tags are currently parsed
- How tags are inserted into notes
- How tags are removed from notes
- How tags are displayed
- How tag filtering currently works
- How notes are synchronized
- How conflict resolution currently works
- How database migrations are handled
- How repositories/services/providers are structured
- How search indexing reacts to Markdown changes
- How note updates propagate to the local search index
- How Cloud/sync persistence currently handles related metadata
- Existing navigation patterns
- Existing reusable UI components
- Existing design tokens and typography
- Existing desktop/web keyboard handling if applicable

Do not unnecessarily introduce a new architectural pattern when an existing application pattern should be reused.

---

# 1. Core Product Model

Tags must become first-class entities.

A tag must have a stable immutable identifier independent of its visible name.

Conceptually:

```text
Tag
├── id
├── name
├── icon
├── color
├── isPinned
├── pinnedOrder
├── createdAt
├── updatedAt
└── sync metadata required by the existing sync architecture
```

The exact fields/types must follow the existing project's conventions.

Never use the tag's textual name as its permanent identity.

The note/tag relationship should remain normalized conceptually:

```text
Note
   |
   +---- note_tag ----> Tag
```

Do not encode tag metadata inside the textual tag string.

Do not implement:

```text
#programming|icon=computer|pinned=true
```

or similar schemes.

The visible tag name must remain a clean tag string.

---

# 2. Canonical Markdown Requirement

The note body is currently stored as canonical Markdown.

There is no JSON document model.

Preserve this architecture.

Tags embedded in Markdown must continue to work naturally.

For example:

```markdown
# My Project

Working on #programming today.
```

If the tag is renamed:

```text
#programming -> #development
```

the canonical Markdown must become:

```markdown
# My Project

Working on #development today.
```

The implementation must keep:

1. The Tag entity
2. Note/tag relationships
3. Canonical Markdown content
4. Search indexing

consistent with one another.

Do not introduce a separate JSON representation solely for tag functionality.

---

# 3. Tag Identity and Normalization

Inspect and preserve the application's existing tag parsing rules.

Define and consistently enforce:

- case normalization rules
- whitespace rules
- allowed characters
- duplicate detection
- Unicode handling
- nested tag syntax, if already supported
- Markdown heading disambiguation
- escaped tag handling
- code-block handling
- inline-code handling
- tag parsing inside Markdown constructs

Do not accidentally identify:

```text
#programming
```

inside a fenced code block as a real note tag if the existing application correctly excludes code blocks.

Likewise, do not blindly perform global string replacement during rename operations.

Tag replacement must operate using the application's actual Markdown parsing/tag recognition rules.

---

# 4. Stable Tag Identity

Every tag must have a stable ID.

Example:

```text
tagId = UUID
name = programming
```

Renaming the tag must preserve its ID:

```text
tagId = UUID
name = development
```

Do not delete and recreate the tag during rename.

This is critical for synchronization, conflict resolution, note relationships, history, and cross-device consistency.

---

# 5. Tag Rename Semantics

Implement tag rename as a first-class operation.

Example:

```text
#programming -> #development
```

The rename must:

1. Update the Tag entity name.
2. Preserve the Tag ID.
3. Find all notes associated with the tag.
4. Update the canonical Markdown representation in every affected note.
5. Preserve all other note content exactly.
6. Preserve all other tags.
7. Preserve note metadata unrelated to the tag.
8. Update modification timestamps according to the application's existing conventions.
9. Update local note/tag relationships consistently.
10. Update search indexes.
11. Generate the appropriate sync mutations/change records.
12. Ensure all devices eventually converge on the renamed tag.

The rename must be transactional wherever the application's database architecture permits this.

Do not implement a naïve:

```text
markdown.replace("#programming", "#development")
```

because this can modify text that only resembles a tag.

For example, do not modify:

```markdown
```text
#programming
```
```

or:

```markdown
`#programming`
```

unless the application's existing tag specification explicitly says those are tags.

Use the existing Markdown/tag parser.

---

# 6. Rename Conflict Handling

The existing sync/conflict architecture must treat tag rename as a mutable Tag entity operation.

Example:

Device A:

```text
tagId: abc123
name: development
```

Device B:

```text
tagId: abc123
name: coding
```

Do not infer tag identity from names.

The conflict resolver should operate against the stable tag ID.

Integrate tag rename semantics with the existing conflict resolution strategy.

Do not invent a second independent conflict-resolution system unless absolutely necessary.

If the current synchronization model supports field-level conflict resolution, use it appropriately.

Ensure that conflict resolution does not accidentally recreate duplicate tags.

---

# 7. Pinned Tags

Add support for pinning tags.

Every tag should have:

```text
isPinned
pinnedOrder
```

or the project's equivalent representation.

Pinned tags should have a dedicated section near the top of the tag navigation UI.

Example:

```text
TAGS

Pinned
💻 Programming
📚 Reading
💡 Ideas
📝 Journal

All Tags
#android
#books
#flutter
#recipes
```

Do not redundantly display a pin icon on every pinned item when the "Pinned" section already communicates the state.

Provide:

- Pin
- Unpin
- Reorder pinned tags

---

# 8. Pinned Ordering

Pinned tags must support user-defined ordering.

Do not derive the order from alphabetic sorting.

Provide drag-and-drop/reordering where the platform supports it.

Example:

```text
💡 Ideas
💻 Programming
📚 Reading
📝 Journal
```

Store deterministic ordering through `pinnedOrder` or an equivalent mechanism.

Ordering must synchronize across devices.

Resolve ordering conflicts according to the existing sync strategy.

Avoid fragile floating-point ordering unless that is already an application-wide convention.

---

# 9. Tag Icons

Every tag may optionally have an icon.

Icons must be optional.

A tag with no icon remains completely valid.

Example:

```text
💻 Programming
📚 Reading
💡 Ideas
🏠 Personal
```

Use a consistent vector/icon system appropriate to the application rather than relying primarily on platform-dependent emoji rendering.

The icon system should support:

- light theme
- dark theme
- accessibility
- consistent dimensions
- predictable rendering across platforms
- serialization for sync
- graceful fallback if an icon becomes unavailable in a future version

Store a stable icon identifier rather than a rendered icon object.

Example conceptually:

```text
iconId = "computer"
```

rather than serializing arbitrary widget objects.

---

# 10. Icon Picker

Implement a polished icon picker.

It should provide:

- Search
- Recently used icons
- Curated categories
- Clear/remove icon
- Preview
- Keyboard navigation where supported

Suggested categories include:

- Objects
- Activities
- Places
- Symbols
- Work
- Education
- Technology
- Lifestyle

Do not overwhelm the user with an enormous undifferentiated icon grid.

The picker should feel native and fast.

---

# 11. Suggested Icons

Add a lightweight deterministic suggestion system.

When a user creates or edits a tag, suggest relevant icons based on tag name.

Examples:

```text
#books
Suggested:
📚 Book
📖 Reading
```

```text
#programming
Suggested:
💻 Code
⌨️ Terminal
```

This must be local/deterministic.

Do not introduce an AI dependency for this feature.

Suggestions must never silently overwrite the user's explicit icon choice.

---

# 12. Optional Tag Colors

Tags may optionally have a color.

Color is metadata, not the primary identity of the tag.

Provide a restrained curated palette rather than arbitrary uncontrolled RGB values.

The color implementation must:

- work in light mode
- work in dark mode
- meet reasonable contrast requirements
- degrade gracefully
- sync correctly
- support clearing the color
- remain optional

Do not make the interface visually noisy by displaying excessive saturated colors everywhere.

Use colors primarily as subtle accents.

---

# 13. Tag Browser

Build a proper tag browser rather than a plain static tag list.

The tag browser should contain:

```text
Tags                                   Search

Pinned
────────────────────────────
💻 Programming              124
📚 Reading                   68
💡 Ideas                     42

All Tags
────────────────────────────
#android                     24
#books                       68
#flutter                     52
#journal                     31
#recipes                     14
```

Each tag row should support:

- icon
- name
- note count
- optional color accent
- context menu
- pin/unpin
- rename
- change icon
- change color
- delete
- merge where applicable

Keep the list visually clean.

---

# 14. Tag Search

Add searching within the tag browser.

Search must be fast and support the application's existing text matching expectations.

It should search tag names, not merely filter currently visible rows.

Consider:

- prefix matching
- case-insensitive matching
- Unicode normalization according to existing app rules
- recent/relevant ordering

Do not unnecessarily reuse the full note-content fuzzy search engine if a simpler tag lookup is more appropriate.

---

# 15. Tag Sorting

Provide user-selectable sorting.

At minimum:

```text
Name
Note count
Recently used
Recently created
Custom
```

"Custom" applies primarily to pinned tags.

Sorting should not mutate persisted order unless the user explicitly performs a reorder.

---

# 16. Tag Filtering

Provide useful filters such as:

```text
Pinned
Has icon
Has color
Has notes
Unused
```

Avoid overloading the initial interface with too many visible controls.

Secondary filters can live in a sheet/menu.

---

# 17. Note Counts

Each tag should show how many notes currently reference it.

Counts must be accurate and update after:

- creating a tag
- adding a tag
- removing a tag
- renaming a tag
- deleting a tag
- merging tags
- trashing a note
- restoring a note
- permanently deleting a note
- syncing changes
- conflict resolution

Respect the application's existing semantics for whether:

- archived notes
- trashed notes
- password-protected notes

are included in displayed counts.

Do not invent new semantics without inspecting the existing product behavior.

---

# 18. Tag Detail Screen

Create a dedicated tag detail experience.

Example:

```text
💻 Programming

124 notes
```

Then display the notes associated with the tag using the existing note-list UI where possible.

Provide:

- note list
- search/filter within tag if the existing app supports this naturally
- sorting consistent with the note browser
- tag management actions
- rename
- icon
- color
- pin/unpin

Do not duplicate the entire note-list implementation unnecessarily.

Reuse existing components and providers.

---

# 19. Tag Management Menu

Provide a context menu or bottom sheet appropriate to platform.

For a tag:

```text
Rename
Change icon
Change color
Pin / Unpin
Merge into...
Delete
```

Where useful, also expose note count and metadata.

Ensure destructive actions use appropriate confirmation UI.

---

# 20. Delete Tag Semantics

Deleting a tag must never delete its notes.

When deleting:

```text
#programming
```

the operation should:

1. Remove the tag association from every affected note.
2. Update canonical Markdown so the tag is removed from those notes.
3. Update search indexes.
4. Update local relationships.
5. Record the appropriate sync changes.
6. Delete the tag entity according to the application's retention/sync model.

Confirmation should explain scope, for example:

```text
Delete #programming?

This will remove the tag from 124 notes.
Your notes will not be deleted.

Cancel     Delete
```

Use the application's existing trash/deletion policy where appropriate.

Do not silently delete associated notes.

---

# 21. Tag Merge

Implement tag merging.

Example:

```text
#flutter-dev
```

merged into:

```text
#flutter
```

The surviving tag should retain its stable identity.

All note associations from the source tag must be transferred to the destination tag.

Duplicate note/tag associations must be avoided.

The source tag should then be removed according to the application's standard entity deletion semantics.

Canonical Markdown must be updated correctly:

```text
#flutter-dev
```

becomes:

```text
#flutter
```

only where it is actually a recognized tag.

Do not create duplicate `#flutter` associations.

Define deterministic behavior for metadata during merges:

- destination icon wins
- destination color wins
- destination pin state/order wins

unless the existing application has a stronger established rule.

Document and implement that behavior consistently.

---

# 22. Tag Creation

Tag creation must remain extremely fast.

A normal user flow should be able to create:

```text
#programming
```

without being forced through an elaborate configuration screen.

After creation, optional customization should be available:

```text
Name
programming

Icon
[ Choose ]

Color
[ Choose ]

☐ Pin this tag
```

Do not make icons or colors mandatory.

---

# 23. Tag Editing Inside Notes

When the user edits tags directly within a note:

- update tag entities appropriately
- reuse existing tag IDs when possible
- avoid duplicate tags
- preserve normalized naming
- update note/tag relationships
- maintain canonical Markdown
- update search indexes
- trigger sync changes correctly

Adding or removing a tag from the editor must remain fast and reliable.

---

# 24. Tag Rename From the Tag Browser

A rename initiated from the tag browser must use the same domain/service operation as any other rename path.

Do not duplicate rename logic in the UI.

Create or reuse a central domain-level operation such as:

```text
renameTag(tagId, newName)
```

The UI should not directly manipulate Markdown or database tables.

The domain/repository layer must own the operation.

---

# 25. Search Integration

Integrate pinned tags into the application's search experience.

When the global search field is focused and there is no active query, expose useful navigation shortcuts such as:

```text
Pinned Tags

💻 Programming
📚 Reading
💡 Ideas

Recent Tags

#flutter
#books
#journal
```

Selecting a tag should immediately navigate/filter to that tag.

Do not bypass the application's existing search architecture unnecessarily.

Where appropriate, support tag-qualified queries such as:

```text
tag:programming
```

only if this integrates naturally with the existing search syntax.

Do not create a second incompatible search grammar.

---

# 26. Search Index Updates

Because canonical Markdown is searchable, any tag rename/removal/merge that modifies note Markdown must correctly update the existing search index.

This includes:

- normal note search
- tag search
- FTS index
- snippet/highlight generation
- any derived token tables
- any cached search data

Respect the application's existing search architecture and avoid introducing synchronous expensive work on the Flutter UI isolate.

Use the existing indexing pipeline.

---

# 27. Sync Architecture

Tags and tag metadata are synchronized entities.

Synchronize at minimum:

- stable tag ID
- name
- icon
- color
- pinned state
- pinned ordering
- timestamps/versions required by the current sync system
- deletion state if applicable

Do not treat tags as purely local UI metadata.

Changes must propagate across devices.

Example:

Device A:

```text
#programming
Pinned
Icon: computer
```

Device B must eventually receive the same state.

---

# 28. Sync Independence

Tag metadata should not require a note to be re-uploaded merely because someone changes the tag icon or pins the tag.

A user changing:

```text
#programming icon: computer -> terminal
```

should update the Tag entity/change record rather than unnecessarily rewriting every associated note.

However, operations that genuinely change canonical Markdown, such as rename or removal, must update affected notes according to the existing synchronization architecture.

---

# 29. Rename Synchronization

Tag rename is special because it has two dimensions:

```text
Tag entity:
#programming -> #development
```

and:

```text
Note Markdown:
#programming -> #development
```

Both must converge consistently.

Do not allow a state where the Tag entity says:

```text
development
```

while notes still permanently contain:

```text
#programming
```

unless the application is temporarily in a well-defined transactional/syncing intermediate state.

After synchronization completes, all devices must converge.

---

# 30. Offline Behavior

All tag operations should function correctly offline whenever the existing application supports offline editing.

Examples:

- create tag offline
- rename tag offline
- pin tag offline
- change icon offline
- change color offline
- merge tags offline
- delete tag offline

Queue appropriate changes through the existing sync mechanism.

Do not invent a second queue.

---

# 31. Concurrency

Handle concurrent edits safely.

Examples:

- Device A renames a tag.
- Device B changes its icon.
- Device C pins the tag.

Where the existing sync system supports field-level convergence, preserve non-conflicting fields.

Do not let a simple tag rename overwrite an unrelated icon change.

Likewise, changing an icon must not overwrite a newer name.

---

# 32. Trash Semantics

Integrate tag behavior with the application's note-trash model.

When a note enters trash:

- decide inclusion in tag counts according to existing product semantics
- do not accidentally destroy the tag entity
- do not accidentally remove the note's historical tag relationships unless existing deletion semantics require it

When a note is restored, its tag relationships should behave correctly.

When a note is permanently deleted, clean up its tag relationships according to the existing permanent-deletion policy.

Remember that the application already treats trash as synchronized state. Preserve that model.

---

# 33. Password-Protected Notes

Respect the application's password-protected-note security model.

Do not accidentally expose sensitive tag information through surfaces where the existing security model says it should remain hidden.

Inspect how password-protected notes currently participate in:

- tag counts
- tag lists
- search
- synchronization
- previews

Then implement tag behavior consistently with those established rules.

Do not weaken the application's security guarantees.

---

# 34. Accessibility

Provide:

- semantic labels
- sufficient contrast
- minimum reasonable touch targets
- screen-reader-friendly actions
- meaningful labels for icon-only buttons
- keyboard navigation where supported
- focus management for dialogs/sheets
- accessible drag/reorder behavior or an alternative reorder action

Never make the icon itself the only way the user can understand a tag.

The tag name remains primary.

---

# 35. Empty States

Design polished states for:

No tags:

```text
No tags yet

Add tags to your notes to organize them here.
```

No pinned tags:

```text
No pinned tags

Pin the tags you use most often for quick access.
```

No matching tags:

```text
No matching tags
```

Unused tags:

```text
No unused tags
```

Do not display broken/empty containers.

---

# 36. Performance Requirements

The implementation must scale to large note collections.

Do not:

- load every note into memory merely to display tag counts
- repeatedly scan every Markdown document on the UI isolate
- recalculate all tag metadata on every frame
- perform full-database work synchronously during widget builds

Use database-level aggregation/querying where appropriate.

Example conceptual query:

```sql
SELECT tag_id, COUNT(...)
FROM note_tags
...
```

Use caching/reactive streams consistent with the application's existing architecture.

Large tag collections must remain responsive.

---

# 37. Database and Migration Safety

Add the minimum necessary schema changes.

Use the project's existing migration mechanism.

Migrations must:

- preserve existing tags
- preserve existing note/tag associations
- generate stable IDs for legacy tags
- initialize icon as null/default
- initialize color as null/default
- initialize pin state as false
- initialize deterministic pinned ordering
- remain backward-safe according to the existing app architecture

Do not destroy or rewrite valid existing note content during migration.

Before migrating legacy tag data, inspect how tags are currently represented and write the migration around the real schema.

---

# 38. Backward Compatibility

Existing notes containing tags must continue to work.

A user upgrading the application must not need to manually recreate tags.

Existing tag references must automatically map to the new stable Tag entities.

Do not create duplicate tag entities for the same normalized tag.

---

# 39. UI Design Requirements

The UI should feel like a polished Bear-style note application:

- minimal
- calm
- content-first
- fast
- visually restrained
- excellent spacing
- subtle hierarchy
- no unnecessary decoration

Avoid turning the tag browser into an administrative dashboard.

Use icons/colors to improve scanning, not to create visual noise.

Reuse the application's current design language.

---

# 40. Desktop / Mobile Behavior

Adapt the experience to platform.

Mobile:

- bottom sheets
- context menus
- drag gestures
- touch-friendly controls

Desktop:

- hover actions
- context menus
- keyboard navigation
- drag-and-drop
- compact management controls

Do not create separate business logic for each platform.

Share domain/state/data logic.

---

# 41. Keyboard Interaction

Where desktop/web keyboard behavior is already supported, provide useful shortcuts for tag navigation.

Examples:

```text
Ctrl/Cmd + Shift + T
```

can open a tag-jump/search surface if this does not conflict with an existing shortcut.

Enter selects the highlighted tag.

Escape closes the picker/search surface.

Arrow keys navigate results.

Do not introduce a shortcut that conflicts with existing application behavior.

Inspect current shortcuts first.

---

# 42. State Management

Follow the application's existing state-management architecture.

Do not introduce a competing state management library.

Tag state should reactively update when:

- a tag is created
- renamed
- deleted
- merged
- pinned
- reordered
- recolored
- re-iconed
- affected notes change
- sync applies incoming changes

Avoid stale UI.

---

# 43. Centralized Domain Operations

Centralize important tag operations.

Conceptually:

```text
createTag()
renameTag()
deleteTag()
mergeTags()
pinTag()
unpinTag()
reorderPinnedTags()
setTagIcon()
setTagColor()
```

Do not scatter business logic through widgets.

Operations must be reusable from:

- tag browser
- note editor
- context menus
- sync application
- tests
- future features

---

# 44. Transaction Boundaries

Where an operation changes multiple related records, use an appropriate database transaction.

Particularly:

### Rename

```text
Tag rename
+
Affected note Markdown updates
+
Relationship consistency
+
Required index updates/change records
```

### Merge

```text
Move relationships
+
Rewrite note Markdown
+
Remove source tag
+
Update derived data
```

### Delete

```text
Remove relationships
+
Rewrite note Markdown
+
Remove tag entity
+
Update derived data
```

Use the existing database transaction conventions.

Avoid partial state.

---

# 45. Markdown Rename Algorithm

Implement a safe tag replacement algorithm.

The algorithm must:

1. Parse canonical Markdown using the application's actual tag parser.
2. Identify real tag occurrences.
3. Match occurrences associated with the target stable tag identity/name.
4. Rewrite only those occurrences.
5. Preserve all unrelated Markdown.
6. Preserve formatting and line endings.
7. Preserve code blocks and inline code according to current parsing rules.
8. Preserve Unicode correctly.
9. Recalculate affected derived metadata.
10. Persist the resulting canonical Markdown.

Do not use a naïve global string substitution.

For example, given:

```markdown
# Notes

#programming is useful.

```dart
final value = "#programming";
```

`#programming` inside the code block must remain untouched if code blocks are excluded from tags.

---

# 46. Duplicate Associations

Prevent duplicate relationships.

For example, after a merge:

```text
Note A
#flutter
#flutter-dev
```

becoming:

```text
Note A
#flutter
```

must result in one logical relationship:

```text
note A -> tag flutter
```

not two identical database rows.

Use proper uniqueness constraints where supported.

---

# 47. Error Handling

Every tag operation must have clear failure behavior.

Handle:

- duplicate names
- invalid names
- database failure
- sync failure
- malformed legacy data
- missing tag IDs
- concurrent modifications
- invalid icon metadata
- invalid color metadata
- partial migration failures

Do not silently swallow failures.

Display user-facing errors through the application's existing error-handling UX.

Log enough diagnostic context for debugging without leaking sensitive note content.

---

# 48. Testing Requirements

Implement comprehensive automated tests.

At minimum:

## Tag entity tests

- create
- update
- rename
- delete
- pin
- unpin
- reorder
- icon
- color

## Markdown tests

- rename normal tag
- rename multiple occurrences
- rename tag adjacent to punctuation
- rename Unicode tags
- ignore code blocks where appropriate
- ignore inline code where appropriate
- preserve headings
- preserve unrelated content
- remove deleted tags safely
- merge tags safely

## Relationship tests

- add tag
- remove tag
- duplicate prevention
- merge relationships
- correct counts

## Sync tests

- tag creation sync
- tag rename sync
- icon sync
- color sync
- pin sync
- ordering sync
- deletion sync
- offline operations
- concurrent tag changes
- rename conflicts
- merge conflicts

## Search tests

- renamed tags become searchable correctly
- removed tags disappear from search
- pinned tags appear in search/navigation
- note index reflects Markdown changes

## Migration tests

- legacy tags migrate correctly
- existing notes preserve tags
- duplicates collapse correctly where required
- no content corruption

## UI tests

- tag browser
- pinned section
- pin/unpin
- reorder
- icon picker
- color picker
- rename
- delete confirmation
- merge flow
- empty states
- accessibility semantics

---

# 49. Performance Testing

Test with realistic large datasets.

At minimum validate behavior with:

- thousands of notes
- hundreds of tags
- many notes per tag
- many pinned tags
- large Markdown documents

Ensure:

- tag list remains responsive
- counts do not trigger N+1 queries
- rename operations do not freeze the UI
- merge operations are handled off the UI isolate when necessary
- search remains responsive
- indexing follows the application's existing background architecture

---

# 50. Observability

Add useful structured logging around major operations where the application already supports logging.

Examples:

```text
TagCreated
TagRenamed
TagDeleted
TagMerged
TagPinned
TagUnpinned
TagReordered
TagIconChanged
TagColorChanged
```

For rename/merge operations record:

- tag ID
- operation type
- number of affected notes
- duration
- success/failure

Do not log full note contents or sensitive note text.

---

# 51. Product Rules to Enforce

The final behavior must obey these rules:

### Rename

```text
Rename tag
=
rename the Tag entity
+
rename real occurrences inside all associated notes
+
preserve stable Tag ID
```

### Delete

```text
Delete tag
=
remove tag from notes
+
remove real Markdown occurrences
+
delete tag entity
+
never delete notes
```

### Merge

```text
Merge source tag into destination tag
=
move relationships
+
replace source tag occurrences in Markdown
+
avoid duplicates
+
remove source tag
+
preserve destination identity
```

### Pin

```text
Pin
=
Tag remains the same tag
+
isPinned = true
+
persistent custom order
```

### Icon

```text
Icon
=
optional metadata on Tag
```

### Color

```text
Color
=
optional metadata on Tag
```

---

# 52. Implementation Strategy

Before coding:

1. Inspect the complete existing tag architecture.
2. Identify all files/services/tables involved.
3. Identify all note-editing and Markdown parsing paths.
4. Identify all direct database writes that bypass repositories.
5. Identify all sync serialization/deserialization paths.
6. Identify all conflict-resolution code touching notes/tags.
7. Identify all search-index update paths.
8. Identify all migration infrastructure.
9. Identify existing reusable UI components.

Then produce an internal implementation map.

Do not ask the developer to manually provide information that can be discovered from the repository.

Resolve architecture questions by inspecting the code first.

---

# 53. Implementation Constraints

Do not:

- replace the Markdown storage architecture
- introduce a JSON editor model
- introduce a second synchronization system
- introduce a second state-management library
- use naïve string replacement for tag renaming
- load the entire note database on every tag UI update
- perform expensive operations synchronously on the UI isolate
- break existing note behavior
- break existing synchronization
- break existing search
- silently change existing tag semantics without compatibility handling

Prefer small, composable domain operations and reuse existing infrastructure.

---

# 54. Final Acceptance Criteria

The implementation is complete only when all of the following are true:

A user can create a tag.

A user can optionally assign:

- an icon
- a color

A user can pin the tag.

A user can reorder pinned tags.

Pinned tags appear prominently in the tag browser.

A user can search tags.

A user can sort tags.

A user can filter tags.

Each tag shows an accurate note count according to existing product semantics.

A user can open a tag detail view and browse its notes.

A user can rename a tag.

Renaming a tag preserves its stable ID and updates every real occurrence in associated canonical Markdown notes.

Renaming does not modify false-positive occurrences inside excluded Markdown constructs.

Search indexes update correctly after rename.

Sync propagates the rename correctly.

A user can delete a tag without deleting notes.

Deleting a tag updates associated Markdown correctly.

A user can merge one tag into another.

Merge operations preserve stable destination identity and prevent duplicate relationships.

Icon changes synchronize.

Color changes synchronize.

Pin state synchronizes.

Pinned ordering synchronizes.

Offline operations behave correctly through the existing sync system.

Conflicting tag edits are resolved through the existing conflict architecture without silently discarding unrelated fields.

Existing tags migrate correctly.

Existing notes remain intact.

Large datasets remain responsive.

All relevant unit, integration, migration, sync, search, and UI tests pass.

No regressions are introduced in note editing, rendering, search, synchronization, trash, restore, or permanent deletion behavior.

---

# 55. Required Agent Workflow

Follow this workflow strictly.

### Phase A — Repository Analysis

Inspect the repository and map the existing architecture.

Identify:

- tag models
- tag tables
- note/tag relationships
- Markdown parser
- editor
- repository
- providers
- sync
- conflict resolution
- search
- migrations
- UI/navigation

Do not modify code in this phase.

### Phase B — Design Validation

Determine exactly how the new tag entity metadata and operations fit into the existing architecture.

Pay particular attention to:

- stable tag IDs
- canonical Markdown
- sync records
- conflict resolution
- FTS/search indexing
- trash semantics
- password-protected notes

### Phase C — Implementation

Implement:

1. schema/model changes
2. migration
3. repository/domain operations
4. Markdown-safe rename/remove/merge logic
5. sync serialization/deserialization
6. conflict handling
7. search index integration
8. state management
9. tag browser
10. pinned tags
11. icon picker
12. color picker
13. tag detail view
14. rename/delete/merge flows
15. search integration
16. accessibility
17. tests

### Phase D — Verification

Run:

- formatting
- static analysis
- unit tests
- integration tests
- migration tests
- sync tests
- search tests
- widget tests
- relevant platform builds

Inspect for:

- race conditions
- stale state
- N+1 queries
- UI-thread blocking
- duplicate relationships
- sync loops
- Markdown corruption
- migration data loss

### Phase E — Final Report

Return:

1. Files changed
2. Database/schema changes
3. Migration details
4. New domain operations
5. Markdown rename/remove/merge algorithm
6. Sync changes
7. Conflict-resolution changes
8. Search/index changes
9. UI changes
10. Test coverage
11. Performance considerations
12. Any remaining risks

Do not claim success unless the repository has actually been validated.

The implementation must be production-ready, maintainable, testable, and consistent with the existing application architecture rather than being a standalone prototype.