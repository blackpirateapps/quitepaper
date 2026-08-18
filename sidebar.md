# Quiet Paper — Flagship Sidebar, Archive & Trash System

You are an expert Flutter engineer and product designer continuing development of **Quiet Paper**, a premium offline-first notes application inspired by the calm, editorial philosophy of Bear.

The editor is already being refined separately.

Your task now is to build the **flagship navigation/sidebar experience**, including:

* responsive sidebar
* navigation hierarchy
* search entry point
* All Notes
* Pinned
* Archive
* Trash
* Tags
* tag filtering
* note counts where appropriate
* archive/unarchive
* trash/restore
* permanent deletion
* multi-selection where appropriate
* sidebar state
* responsive phone/tablet behavior
* polished animations
* accessibility
* persistence
* empty states
* correct interaction between sidebar and editor

This should feel like a **real, polished notes product**, not a generic Flutter drawer.

---

# 1. Product Principle

The sidebar answers one question:

> **Where are my notes?**

It should remain calm and focused.

Do NOT turn it into a dashboard.

Do not add:

* analytics
* word counts
* productivity metrics
* calendars
* AI
* templates
* account sections
* unnecessary shortcuts

The sidebar is navigation, organization, and note lifecycle management.

---

# 2. Core Navigation Model

The application should have these primary destinations:

```text
All Notes
Pinned
Archive
Trash
Tags
Settings
```

Search should be prominently accessible from the sidebar/header.

Conceptually:

```text
Quiet Paper

⌕  Search


LIBRARY

   All Notes
   Pinned
   Archive
   Trash


TAGS

   #ideas
   #flutter
   #work
   #books


              

⚙ Settings
```

The exact typography and icons should be refined visually.

Do not blindly reproduce this ASCII layout.

---

# 3. Navigation Semantics

Define these destinations clearly.

## All Notes

Contains:

* active notes
* pinned notes
* unpinned notes

Does NOT contain:

* archived notes
* trashed notes

Sorting:

1. pinned first
2. modified date descending

---

## Pinned

Contains:

* active notes with `isPinned == true`

Does NOT contain:

* archived notes
* trashed notes

If an archived note was previously pinned, archiving it should remove it from the active Pinned view.

Preserve the underlying pin state only if that makes restoration behavior sensible.

Prefer the simplest predictable behavior.

---

## Archive

Contains:

* notes explicitly archived by the user

Archived notes are NOT deleted.

Archived notes:

* disappear from All Notes
* disappear from Pinned
* remain searchable only if the search UX clearly indicates archived results, otherwise exclude them from default search
* remain recoverable
* remain persisted indefinitely

Users can:

* open an archived note
* unarchive it
* move it to Trash
* permanently delete it if explicitly requested

---

## Trash

Contains:

* notes explicitly moved to Trash

Trash is a permanent holding area.

**IMPORTANT: Trash must NEVER automatically delete notes.**

No:

* 30-day deletion
* 7-day deletion
* background cleanup
* scheduled purge
* startup cleanup
* automatic database deletion

A note remains in Trash until the user explicitly chooses:

* Restore
* Delete Permanently

This requirement is strict.

---

# 4. Trash Lifecycle

The lifecycle should be:

```text
Active
  │
  ├── Archive → Archived
  │
  └── Trash → Trash
                  │
                  ├── Restore → Active
                  │
                  └── Delete Permanently → Deleted
```

Archived:

```text
Archived
  │
  ├── Unarchive → Active
  │
  └── Trash → Trash
```

Trash:

```text
Trash
  │
  ├── Restore → Active
  │
  └── Delete Permanently → Deleted
```

There must be no automatic path:

```text
Trash → Deleted
```

---

# 5. Database Changes

Inspect the existing Drift schema before modifying it.

Add the minimum required fields.

Prefer explicit lifecycle state.

A reasonable model is:

```text
notes
-----
id
title
content
created_at
updated_at
is_pinned
is_archived
deleted_at
```

However, choose the cleanest model compatible with the existing schema.

An alternative is:

```text
note_status
-----------
active
archived
trashed
```

Choose one approach and use it consistently.

Do not maintain contradictory states such as:

```text
isArchived = true
isDeleted = true
status = active
```

The state model must have clear invariants.

---

# 6. Recommended State Invariants

Prefer:

```text
Active:
archived = false
trashed = false

Archived:
archived = true
trashed = false

Trash:
archived = false
trashed = true
```

Pinned:

```text
isPinned = true
```

should only affect active notes.

Do not allow a note to appear simultaneously in:

* All Notes
* Archive
* Trash

---

# 7. Migration

If the database already exists:

* create a proper Drift migration
* do not destroy user data
* preserve existing notes
* default all existing notes to Active
* verify migration on a real existing database

Do NOT simply delete/recreate the database during development if the application already has persisted user data.

---

# 8. Repository API

Create clear repository operations.

At minimum:

```dart
createNote()
getActiveNotes()
getPinnedNotes()
getArchivedNotes()
getTrashedNotes()

archiveNote(id)
unarchiveNote(id)

trashNote(id)
restoreFromTrash(id)

deletePermanently(id)

pinNote(id)
unpinNote(id)
```

Also support:

```text
getNotesByTag(tag)
getAllTags()
```

Keep lifecycle operations centralized.

Do not let UI widgets manipulate database state directly.

---

# 9. Sidebar Architecture

Create a reusable sidebar component.

Conceptually:

```text
AppShell
├── Sidebar
└── Content
```

For large screens:

```text
Row(
  children: [
    Sidebar(),
    VerticalDivider(),
    Expanded(Content()),
  ],
)
```

For phones:

```text
Scaffold(
  drawer: Sidebar(),
  body: Content(),
)
```

However, don't blindly use the default Drawer styling.

The sidebar needs its own Quiet Paper visual treatment.

---

# 10. Responsive Behavior

Use adaptive layout.

Recommended starting breakpoint:

```text
< 900dp
    phone/compact layout

>= 900dp
    persistent sidebar
```

Do not treat 900dp as an absolute rule.

Use actual available width.

---

# 11. Phone Sidebar

On phones, the sidebar should appear as a drawer or equivalent navigation surface.

It should:

* open smoothly
* occupy a comfortable width
* not feel like a full-screen settings page
* close after selecting a destination
* preserve navigation state

Suggested width:

```text
280–320dp
```

Do not make it unnecessarily wide.

---

# 12. Tablet Sidebar

On tablets and larger screens, the sidebar should remain visible.

Suggested width:

```text
260–320dp
```

Start around:

```text
280dp
```

and tune visually.

The editor/content area should receive the majority of the screen.

---

# 13. Sidebar Visual Design

The sidebar should use the Quiet Paper palette.

Light:

```text
background: #F7F6F2
surface: #FBFAF7
text: #292824
secondary: #77736C
accent: #D65F55
```

Dark:

```text
background: #1D1C1A
surface: #242320
text: #E8E5DE
secondary: #AAA69E
accent: #E4776D
```

Avoid:

* bright colored navigation buttons
* heavy shadows
* excessive cards
* giant icons
* thick dividers
* excessive borders

The sidebar should feel like part of the paper/editor environment.

---

# 14. Sidebar Header

At the top:

```text
Quiet Paper
```

or the application's actual product name.

Keep it subtle.

Do not create a giant logo header.

If a logo exists, keep it small and tasteful.

Do not copy Bear's logo.

---

# 15. Search

Search should be immediately discoverable.

Preferred:

```text
⌕  Search
```

It can be:

* a sidebar row
* a compact search field
* a button that opens the search screen

Do not create a huge permanent search input.

When activated:

```text
Search notes...
```

should provide:

* title search
* content search
* tag search
* active/archive/trash filtering according to product rules

---

# 16. Search Behavior

Default search should search active notes.

Consider allowing archived notes in search if the UX clearly communicates that they are archived.

Trash should NOT appear in normal search unless the user is explicitly searching inside Trash.

A dedicated Trash screen should be authoritative for trashed notes.

Do not surprise users by showing deleted notes in normal search.

---

# 17. Library Section

Create a visually subtle section label:

```text
LIBRARY
```

Use:

```text
12sp
medium
letter spacing
secondary color
```

Do not make section headers loud.

---

# 18. All Notes

Sidebar row:

```text
All Notes
```

Optionally show a subtle count.

Example:

```text
All Notes                         42
```

Do not show a count if it creates clutter.

Selecting All Notes displays active, non-trashed, non-archived notes.

---

# 19. Pinned

Sidebar row:

```text
Pinned
```

Only show it prominently if there are pinned notes, or always show it if the navigation hierarchy benefits from consistency.

Decide based on visual polish.

Selecting it displays active pinned notes.

---

# 20. Archive

Sidebar row:

```text
Archive
```

Use a quiet archive icon.

Show count only if useful.

Selecting Archive displays archived notes.

The archive should not feel like a destructive area.

---

# 21. Trash

Sidebar row:

```text
Trash
```

Use a subtle trash icon.

If Trash contains notes, optionally show a count.

Example:

```text
Trash                            3
```

Do not make Trash bright red in the normal sidebar.

The destructive color should only appear for destructive actions.

---

# 22. Trash Empty State

When empty:

```text
Trash is empty
```

Optional:

```text
Notes you move to Trash will stay here
until you delete them permanently.
```

This is useful because the no-auto-delete behavior is an intentional product decision.

Keep the illustration optional and minimal.

---

# 23. Trash List

A trashed note should look visually similar to a normal note but clearly belong to Trash.

Do not completely gray everything out.

Each note can show:

```text
Note title
Preview
Moved to Trash · Today
```

Actions:

```text
Restore
Delete Permanently
```

Do not expose Delete Permanently as an accidental one-tap action without confirmation.

---

# 24. Permanent Deletion

Permanent deletion MUST require explicit confirmation.

Dialog:

```text
Delete permanently?

This note will be permanently deleted.
This action cannot be undone.

Cancel
Delete Permanently
```

The destructive button should use the error color.

Never permanently delete without explicit user intent.

---

# 25. Restore From Trash

Restore should return the note to Active.

After restore:

```text
Trash
→ Restore
→ All Notes
```

The note should return to the appropriate location.

If it was pinned before trashing and the application preserved its pin state, restore should restore that state appropriately.

Choose predictable behavior and test it.

---

# 26. Archive Behavior

Archiving should not require confirmation.

It is reversible.

Action:

```text
Archive
```

After archive:

```text
Active
→ Archive
```

The note disappears from All Notes.

Provide an unobtrusive undo option if practical:

```text
Note archived                  Undo
```

Undo should restore the note to Active.

---

# 27. Unarchive

From Archive:

```text
Unarchive
```

returns the note to All Notes.

No confirmation required.

Provide Undo where appropriate.

---

# 28. Trash Behavior

Moving a note to Trash should be reversible.

No confirmation is strictly required if Undo is provided.

Recommended:

```text
Move to Trash
```

followed by:

```text
Note moved to Trash           Undo
```

The note disappears from the active list immediately.

---

# 29. No Automatic Deletion

This is a hard product requirement.

Do not implement:

```text
delete after 7 days
delete after 30 days
delete after 90 days
cleanup on app launch
cleanup on database migration
background purge
scheduled purge
```

Do not add a retention preference.

Trash is indefinite.

Only explicit user action may permanently delete a note.

---

# 30. Tags Section

The sidebar should display tags.

Example:

```text
TAGS

#ideas
#flutter
#work
#books
```

Tags should be sorted predictably.

Recommended default:

1. most-used first
2. alphabetical tie-breaker

Alternatively, alphabetical sorting is acceptable if simpler.

Do not make tags randomly ordered.

---

# 31. Tag Counts

Counts are optional.

If implemented:

```text
#ideas                         12
#flutter                        8
```

Keep them subtle.

Do not turn the sidebar into a statistical dashboard.

---

# 32. Tag Overflow

If there are many tags, do not allow the sidebar to become unusable.

Initially show a reasonable number.

Example:

```text
TAGS

#ideas
#flutter
#work
#books
#design

Show all tags
```

"Show all tags" can open a tag browser.

Do not cram 100 tags into the main sidebar.

---

# 33. Tag Browser

If implementing a full tag browser, make it searchable.

It should support:

* search tags
* select tag
* show notes using tag
* navigate back

Keep the design consistent with the sidebar.

---

# 34. Tag Selection

When a tag is selected:

```text
#flutter
```

the content area should display only notes associated with that tag.

The active navigation state should make it clear that a tag filter is active.

Do not hide the filter context.

---

# 35. Sidebar Selection State

The currently selected destination should be obvious but subtle.

Avoid:

```text
████████████████
ALL NOTES
████████████████
```

Prefer:

```text
╭──────────────────────╮
│ All Notes            │
╰──────────────────────╯
```

or a subtle tonal background.

Example selected background:

```text
Light:
#ECE9E3

Dark:
#302E2A
```

Selected icon/text can use the accent color.

Do not make the entire sidebar red.

---

# 36. Sidebar Icons

Use a consistent icon family.

Recommended:

```text
Search
Notes
Push Pin
Archive
Trash
Tag
Settings
```

Keep icons around:

```text
20–22dp
```

Touch targets:

```text
48dp minimum
```

Icons should be visually quiet.

---

# 37. Sidebar Spacing

Use generous but compact spacing.

Suggested:

```text
Header:
24dp horizontal

Section:
20–24dp top margin

Navigation row:
44–48dp height

Row horizontal padding:
12–16dp

Icon → label:
12dp

Section spacing:
20–28dp
```

The sidebar should feel refined, not sparse to the point of awkwardness.

---

# 38. Sidebar Scrolling

The sidebar itself must scroll if tags become numerous.

However:

* header remains visible if appropriate
* settings stays near the bottom when possible
* tag list can scroll
* no nested-scroll glitches

A practical structure:

```text
Column
├── Header
├── Search
├── Expanded(
│     SingleChildScrollView(
│       Library
│       Tags
│     )
│   )
└── Settings
```

This keeps Settings anchored.

---

# 39. Sidebar Collapse

On large screens, consider a collapsed sidebar state.

Collapsed:

```text
┌────┐
│ ◉  │
│ ⌕  │
│ ▤  │
│ ★  │
│ □  │
│ 🗑 │
│    │
│ ⚙  │
└────┘
```

Expanded:

```text
┌────────────────┐
│ Quiet Paper    │
│                │
│ Search         │
│ All Notes      │
│ Pinned         │
│ Archive        │
│ Trash          │
│                │
│ #ideas         │
│ #flutter       │
│                │
│ Settings       │
└────────────────┘
```

This is a **secondary enhancement**.

Only implement it if the primary sidebar is already excellent.

Do not sacrifice core functionality to build collapsing behavior.

---

# 40. Sidebar Animation

Transitions should be quiet.

Phone drawer:

```text
180–240ms
```

Selection:

```text
120–180ms
```

Collapsed/expanded:

```text
180–240ms
```

Use ease-out.

Avoid dramatic animations.

---

# 41. Navigation State

Navigation state should be represented explicitly.

Example:

```dart
enum AppDestination {
  allNotes,
  pinned,
  archive,
  trash,
  tag,
}
```

For tags, store the selected tag ID/name.

Do not rely on string comparisons scattered throughout widgets.

---

# 42. URL/Deep Link Support

Do NOT implement deep links unless the existing app already has routing infrastructure that makes this trivial.

Do not add complexity just for this feature.

The priority is local navigation.

---

# 43. Routing

If the app already uses a router:

Integrate the sidebar into it.

If not, use a simple predictable navigation model.

The selected sidebar destination should remain consistent with the displayed content.

Avoid multiple independent navigation systems fighting each other.

---

# 44. Editor Integration

The sidebar must work naturally with the editor.

On tablet:

```text
Sidebar
   ↓
select note
   ↓
editor updates
```

On phone:

```text
Sidebar
   ↓
select note/list
   ↓
drawer closes
   ↓
editor opens
```

When editing a note and navigating elsewhere:

* autosave first
* preserve content
* do not lose edits

---

# 45. Archive/Trash From Editor

The editor's overflow menu should support:

```text
Pin / Unpin
Archive
Move to Trash
```

If the current note is archived:

```text
Unarchive
Move to Trash
```

If the current note is in Trash:

```text
Restore
Delete Permanently
```

The editor should not expose contradictory actions.

For example, a trashed note should not offer:

```text
Archive
```

---

# 46. Note List Context Menus

On active notes:

```text
Pin
Archive
Move to Trash
Delete
```

Do NOT expose permanent delete for active notes unless product behavior explicitly requires it.

Recommended:

```text
Move to Trash
```

as the deletion action.

Permanent deletion should primarily exist inside Trash.

---

# 47. Archive Context Menu

For archived notes:

```text
Unarchive
Move to Trash
```

---

# 48. Trash Context Menu

For trashed notes:

```text
Restore
Delete Permanently
```

Permanent deletion requires confirmation.

---

# 49. Multi-Selection

If practical, implement multi-selection for list screens.

Example:

Long press note:

```text
2 selected

Restore
Archive
Trash
Delete Permanently
```

However, be careful with destructive operations.

For Trash:

```text
3 selected

Restore
Delete Permanently
```

Permanent deletion requires confirmation.

If multi-selection introduces significant complexity, implement it only after single-note lifecycle operations are stable.

---

# 50. Empty States

Create distinct empty states.

## All Notes

```text
No notes yet

Start writing something.
```

## Pinned

```text
No pinned notes

Pin notes to keep them close.
```

## Archive

```text
Archive is empty

Archived notes will appear here.
```

## Trash

```text
Trash is empty

Notes stay here until you delete them
permanently.
```

## Tag

```text
No notes with #flutter
```

Keep all empty states minimal and typography-driven.

---

# 51. Note Counts

If showing counts, ensure they update immediately after:

* create
* archive
* unarchive
* trash
* restore
* permanent deletion
* pin/unpin

Do not allow stale counts.

Counts should not be required for functionality.

---

# 52. Database Reactivity

Use Riverpod/Drift streams or the existing reactive architecture.

The UI should update automatically.

Example:

```text
All Notes: 42

User archives one note

All Notes: 41
Archive: +1
```

No manual refresh.

---

# 53. Performance

The sidebar should remain fast with:

* 10 notes
* 100 notes
* 1,000 notes
* hundreds of tags

Do not load entire note bodies just to calculate sidebar counts.

Use efficient queries.

For counts, use database count queries.

For tag lists, avoid repeatedly loading the same data.

---

# 54. Accessibility

Sidebar rows must have:

* semantic labels
* adequate touch targets
* selected state exposed to accessibility
* readable text
* sufficient contrast

For example:

```text
All Notes, selected
```

should be communicated to screen readers.

Do not rely only on background color to indicate selection.

---

# 55. Keyboard / Desktop Compatibility

Although Android is the primary target, keep the navigation reasonably compatible with:

* hardware keyboards
* tablets
* ChromeOS where Flutter supports it

Do not add a desktop-specific navigation architecture.

---

# 56. Android Back Behavior

On phone:

If sidebar/drawer is open:

```text
Back
→ close sidebar
```

If editor is open:

```text
Back
→ editor navigation behavior
```

If neither is open:

```text
Back
→ normal app navigation/exit behavior
```

Ensure these states don't conflict.

---

# 57. Persistence of UI State

Persist only useful state.

Potentially remember:

* selected theme
* selected sidebar destination
* sidebar expanded/collapsed state on large screens

Do not persist transient states unnecessarily.

For example, don't persist:

* temporary drawer animation
* temporary search focus
* temporary selection

---

# 58. Sidebar and Search

Search should be globally accessible.

When search opens from the sidebar:

```text
Sidebar
→ Search
→ Search screen
```

When search is closed:

```text
Search
→ previous destination
```

Preserve the user's navigation context where reasonable.

---

# 59. Trash Safety

This deserves explicit emphasis.

Implement tests proving:

```text
Move note to Trash
↓
Wait / restart app
↓
Note remains in Trash
```

Also:

```text
Move note to Trash
↓
Close app
↓
Open app days later
↓
Note remains in Trash
```

No background process or startup routine should delete it.

Only:

```text
Delete Permanently
```

can remove it.

---

# 60. Permanent Delete Safety

Require explicit confirmation.

For one note:

```text
Delete permanently?

This note will be permanently deleted.
This cannot be undone.

Cancel
Delete Permanently
```

For multiple notes:

```text
Delete 5 notes permanently?

These notes will be permanently deleted.
This cannot be undone.

Cancel
Delete Permanently
```

The destructive action must be clearly distinguished.

---

# 61. Undo

Recommended:

### Archive

```text
Note archived                 Undo
```

### Move to Trash

```text
Note moved to Trash           Undo
```

### Restore

```text
Note restored                 Undo
```

Undo should restore the previous lifecycle state.

Do not offer Undo after permanent deletion.

---

# 62. Error Handling

If an archive/trash/restore operation fails:

* don't change the visible state optimistically unless rollback is reliable
* show an understandable error
* preserve the note
* allow retry

Never silently lose a note.

---

# 63. Testing Requirements

Add database/repository tests for:

```text
create active note
pin note
archive note
unarchive note
trash note
restore note
permanently delete note
```

Verify state invariants.

---

# 64. Critical Trash Tests

Explicitly test:

### Test 1

```text
Create
→ Trash
→ Read Trash
→ note exists
```

### Test 2

```text
Create
→ Trash
→ restart database/app
→ note still exists
```

### Test 3

```text
Create
→ Trash
→ Restore
→ note appears in All Notes
```

### Test 4

```text
Create
→ Trash
→ Delete Permanently
→ note no longer exists
```

### Test 5

```text
Create
→ Trash
→ Delete Permanently
→ restart
→ note does not exist
```

---

# 65. Archive Tests

Verify:

```text
Active
→ Archive
→ absent from All Notes
→ present in Archive
```

Then:

```text
Archive
→ Unarchive
→ present in All Notes
→ absent from Archive
```

---

# 66. Pin Tests

Verify:

```text
Active
→ Pin
→ appears in Pinned
```

and:

```text
Pinned
→ Archive
→ absent from Pinned
→ present in Archive
```

Make the behavior predictable.

---

# 67. Tag Tests

Verify:

```text
Create note
→ #flutter
→ tag appears
→ select #flutter
→ note appears
```

When a note is trashed:

It should not appear in normal active tag results unless explicitly viewing Trash.

---

# 68. Visual QA

Test the sidebar in:

### Light mode

Check:

* warm background
* muted selection
* readable labels
* subtle icons

### Dark mode

Check:

* no pure black
* no harsh white
* selected state remains visible
* Trash isn't unnecessarily red

### Phone

Check:

* drawer width
* opening animation
* closing after selection
* Android back button

### Tablet

Check:

* persistent sidebar
* editor width
* sidebar/content relationship

---

# 69. Design Quality Bar

The sidebar must NOT look like:

* default Flutter NavigationDrawer
* generic Material dashboard
* enterprise settings panel
* a file manager

It should feel like:

> **A quiet library for your thoughts.**

Use:

* typography
* whitespace
* subtle tonal surfaces
* restrained icons
* minimal separators

to create hierarchy.

---

# 70. What NOT to Build

Do not add:

* cloud sync
* authentication
* accounts
* AI
* collaboration
* subscriptions
* analytics
* advertisements
* automatic trash deletion
* retention policies
* complicated folder systems
* nested folder hierarchies
* calendar views
* productivity dashboards

Folders are especially important:

**Do not introduce folders just because the sidebar needs more content.**

Tags are the primary organizational mechanism.

---

# 71. Implementation Order

Work in this order.

## Phase 1 — Inspect

Understand:

* current database
* note model
* repository
* navigation
* note list
* editor

Run:

```bash
flutter analyze
flutter test
```

---

## Phase 2 — Lifecycle Model

Implement:

* active
* archived
* trashed

with correct persistence.

Add migrations if necessary.

---

## Phase 3 — Repository

Implement lifecycle operations and tests.

---

## Phase 4 — Navigation State

Implement:

```text
All Notes
Pinned
Archive
Trash
Tag
```

and selected destination state.

---

## Phase 5 — Sidebar

Build the visual sidebar.

Make it excellent on tablet first.

---

## Phase 6 — Phone Drawer

Adapt the sidebar to compact screens.

---

## Phase 7 — Archive / Trash Screens

Implement:

* list
* empty states
* actions
* restore
* permanent deletion
* confirmation

---

## Phase 8 — Editor Integration

Add:

* archive
* trash
* restore
* permanent deletion

to editor overflow menus.

---

## Phase 9 — Tags

Integrate tag filtering with the sidebar.

---

## Phase 10 — Polish

Refine:

* animation
* spacing
* icons
* counts
* selection state
* dark mode
* accessibility

---

# 72. Definition of Done

The feature is complete when a user can:

### Navigation

* open sidebar
* navigate All Notes
* navigate Pinned
* navigate Archive
* navigate Trash
* select tags
* open Search
* open Settings

### Archive

* archive note
* find it in Archive
* unarchive it
* find it back in All Notes

### Trash

* move note to Trash
* find it in Trash
* close/reopen app
* note remains in Trash
* restore it
* find it back in All Notes
* permanently delete it
* confirm it is actually gone

### Responsive

* sidebar works on phone
* persistent sidebar works on tablet
* navigation feels natural in both modes

### Editor

* lifecycle actions work from editor
* autosave still works
* no content is lost
* navigation state remains correct

---

# 73. Final Quality Standard

Do not stop when the sidebar is technically functional.

Evaluate it as a product designer.

Ask:

> Does the sidebar feel like it belongs to Quiet Paper?

> Is it too busy?

> Are there too many sections?

> Is the selected state too loud?

> Does Trash feel appropriately separate without looking scary?

> Does Archive feel reversible?

> Are tags easy to understand?

> Does the sidebar disappear into the background when the user is writing?

The final relationship should be:

```text
Sidebar = navigation
Editor  = focus
Notes   = content
Tags    = organization
Archive = storage
Trash   = recovery
```

The editor remains the star of the product.

The sidebar should support it, never compete with it.

---

# 74. Final Engineering Report

After implementation, report:

1. Current navigation architecture.
2. Sidebar architecture.
3. Responsive breakpoint behavior.
4. Database changes.
5. Migration details.
6. Archive implementation.
7. Trash implementation.
8. Permanent deletion implementation.
9. Tag filtering implementation.
10. Editor integration.
11. Files changed.
12. Dependencies changed.
13. Tests added.
14. Tests executed.
15. `flutter analyze` result.
16. Known limitations.

Do not claim tests passed unless they were actually executed.

Start by inspecting the existing application and database. Preserve working functionality and implement this as a production-quality feature rather than a visual prototype.
