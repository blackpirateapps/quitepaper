
# Production Implementation Prompt — Quiet Paper “Editorial” Notes List

## Objective

Implement a new alternative notes-list presentation for Quiet Paper called **Editorial**.

The existing **Quiet Paper** notes-list design must remain intact and must remain the default. Do not redesign, refactor, restyle, or otherwise alter its appearance or behavior unless absolutely required to share underlying infrastructure.

The new **Editorial** style should closely reproduce the visual language, hierarchy, proportions, spacing, attachment previews, selection treatment, typography, and interaction model shown in the **reference screenshot provided with this task**.

The reference screenshot is the visual source of truth for the Editorial presentation.

The result should feel like a polished, production-quality native notes application, not a rough approximation.

Do not use the name “Bear” anywhere in user-facing UI, settings, code comments intended for users, documentation visible in-app, or feature naming. The feature is called **Editorial**.

---

# 1. Existing Application Context

Quiet Paper is a three-pane notes application:

```text
┌──────────────────┬────────────────────┬─────────────────────────────┐
│                  │                    │                             │
│     Sidebar      │     Note List      │        Note Editor          │
│                  │                    │                             │
│                  │                    │                             │
└──────────────────┴────────────────────┴─────────────────────────────┘
```

The current notes list already exists and must continue functioning exactly as it currently does.

The application already supports concepts including:

* notes
* tags
* pinned notes
* archive
* trash
* journal-related views
* images
* PDFs/documents
* note previews
* searching
* sorting
* filtering
* three-pane navigation
* themes
* editor/preview functionality

The note body is stored canonically as Markdown. Do not introduce JSON as a replacement for the canonical note format.

Do not change the persistence model merely to implement Editorial.

---

# 2. Core Requirement

Add:

```text
Settings
└── Appearance
    └── Notes List Style
        ├── Quiet Paper
        └── Editorial
```

The existing Quiet Paper style remains the default.

The user can switch between:

```text
Quiet Paper
Editorial
```

The selected style must persist across application restarts and sessions.

Changing the list style must **not** alter:

* notes
* note ordering
* sort settings
* filters
* selected tag
* search query
* note contents
* attachment associations
* selected note
* pinned state
* archive state
* trash state

Only the presentation changes.

---

# 3. Architectural Requirement

Do not implement Editorial by modifying the existing Quiet Paper row component with dozens of conditionals.

Create a distinct presentation layer.

Use an architecture conceptually equivalent to:

```text
NotesList
├── QuietPaperNotesList
└── EditorialNotesList
```

Both render from the same underlying notes-list state/data.

Conceptually:

```text
NotesListContainer
    ↓
shared query / filtering / sorting / selection state
    ↓
selected presentation style
    ↓
QuietPaperNotesList
or
EditorialNotesList
```

The exact class/component names may follow the project's existing architecture, but the separation must remain clear.

Editorial must be independently maintainable.

---

# 4. Settings UI

Add the new setting under the application's existing:

```text
Settings → Appearance
```

Create a section titled:

**Notes List**

Inside it:

### List Style

Provide two selectable options:

```text
Quiet Paper
Editorial
```

Use the existing Quiet Paper settings design language and controls rather than introducing an unrelated settings component.

The selected option must be visually obvious.

Where the existing application supports descriptions beneath settings, use:

```text
Quiet Paper
Your current card-based notes list.

Editorial
A content-focused list with inline previews and attachments.
```

Do not expose implementation terminology such as renderer, component, layout engine, etc.

---

# 5. Visual Source of Truth

Use the supplied reference screenshot as the primary visual reference for Editorial.

Reproduce the following characteristics faithfully:

* three-pane desktop/tablet notes application
* dark sidebar aesthetic shown in the reference, subject to the application's active theme system
* narrow middle notes column
* large editor pane
* lightweight middle-column rows
* selected note receiving a distinct background
* colored vertical selection/accent indicator
* title-first hierarchy
* preview text beneath title
* attachments appearing inside the note preview
* date/metadata beneath note content
* extremely subtle separators
* strong typography hierarchy
* very restrained use of borders
* no heavy card around every note
* large whitespace between content groups
* inline attachment previews
* minimal visual noise

Do not interpret the screenshot as a generic card/list layout.

The defining characteristic is:

> **Unselected notes visually flow together as an editorial document list; the selected note becomes the visually emphasized item.**

---

# 6. Editorial List Header

The middle pane should have its own compact header.

Use this structure:

```text
[Current collection name] ▾                         [Search]
```

Examples:

```text
Notes ▾                                      Search
journal ▾                                    Search
Pinned ▾                                     Search
Archive ▾                                    Search
Trash ▾                                      Search
```

The collection title must be dynamic based on the current sidebar/context selection.

Do not hard-code “Notes” for every state.

The dropdown affordance should be subtle and visually integrated into the title.

Existing sorting/filtering functionality must remain accessible, but do not permanently crowd the header with every control.

Place secondary actions behind the existing overflow / filter mechanism where appropriate.

Do not break existing functionality merely to imitate the screenshot.

---

# 7. Remove the Existing Top Filter-Chip Strip Only in Editorial Mode

The existing Quiet Paper presentation may continue displaying its current top chips exactly as it does today.

Editorial should **not** replicate that horizontal strip of large filter chips.

For example, do not show:

```text
[All] [#journal] [#simplenote]
```

above the Editorial list.

Instead, the selected collection/tag/filter should be represented by the Editorial list header and normal application navigation.

Filtering must still be available through the application's existing filter functionality.

This is presentation-only behavior.

---

# 8. Editorial Note Row Structure

Every note should follow this hierarchy:

```text
Title
Preview text
Optional attachment preview
Optional metadata/tags
Date
```

Not every element is mandatory.

A text-only note should remain visually simple.

Example:

```text
Coding 101 — Swift

#code Swift is a programming
language for iOS, macOS, and iPad...

July 10
```

Do not force empty attachment areas, empty metadata containers, or artificial placeholders.

---

# 9. Typography

Typography must be carefully tuned.

Use the application's existing typography/font system wherever possible.

Do not introduce an unrelated font solely to imitate the screenshot.

Relative hierarchy:

### Note title

* semibold
* approximately 15–17 px in desktop/tablet presentation
* strong contrast
* natural wrapping
* maximum of approximately 2 lines before truncation

### Preview

* regular weight
* approximately 14–15 px
* muted relative to title
* approximately 2–3 lines
* line height around 1.35–1.5

### Metadata

* approximately 12–13 px
* muted
* visually subordinate

### Date

* approximately 12–13 px
* subdued
* never visually competing with the title

Tune these values to match the application's existing platform scale.

Do not blindly use hard-coded px values where the application already has design tokens.

---

# 10. Text Preview Rules

Generate previews from the canonical Markdown note content.

The preview must be plain readable text.

Do not expose Markdown syntax such as:

```text
# Heading
**bold**
*italic*
[link](...)
```

as raw Markdown syntax in the list preview.

Instead:

```text
# Project Notes
```

should preview as:

```text
Project Notes
```

and:

```text
**Important deadline**
```

should preview as:

```text
Important deadline
```

Strip or normalize formatting appropriately.

Do not render the entire note editor inside the list.

Do not use a full WYSIWYG editor for the preview.

Do not produce malformed text from Markdown parsing.

Do not include invisible syntax characters in the preview.

---

# 11. Preview Selection

Use meaningful content from the note rather than blindly displaying arbitrary raw Markdown characters.

Prefer:

1. first meaningful paragraph
2. otherwise first meaningful text block
3. otherwise a useful attachment indicator
4. otherwise no preview

Do not allow the note title to be redundantly repeated as the entire preview.

For heading-heavy notes, avoid producing ugly previews such as:

```text
# # #
```

Normalize content before display.

---

# 12. Title Handling

If the note has an explicit title, display it.

If the note is untitled, preserve the application's existing untitled-note behavior.

Do not invent titles from attachments unless the existing application already has that concept.

Titles must wrap naturally.

Do not horizontally scroll note titles.

Do not allow extremely long titles to expand the middle pane.

---

# 13. Selected Note Appearance

This is one of the most important requirements.

The selected Editorial note must visually stand apart from all other notes.

Use:

* subtle rounded corners
* soft selected background
* narrow vertical accent bar on the leading edge
* slightly stronger text contrast
* appropriate internal padding
* no heavy border
* no drop shadow

Conceptually:

```text
┌─────────────────────────────────────┐
│▌ My green friends                   │
│▌ Plant tracker 🌱 Plant...          │
│▌                                    │
│▌ [ image ] [ PDF ]                 │
│▌                                    │
│▌ Just now                           │
└─────────────────────────────────────┘
```

The selection indicator must follow the application's text direction and platform conventions.

For LTR:

```text
│▌
```

For RTL it should move appropriately.

The accent color should come from the active application theme/design tokens, not be hard-coded.

---

# 14. Unselected Notes

Unselected notes must have:

* no heavy card
* no permanent rounded container
* no strong border
* no drop shadow
* no large background block

They should appear as a continuous vertical flow.

Example:

```text
My productivity app is a never-ending .txt file

Over 14 years of todos recorded in text...
#clippings

Sep 1
────────────────────────

Untitled

#newspaper

Sep 1
────────────────────────

math

[image]

Sep 1
```

Dividers must be subtle.

The notes should feel like one document list rather than a stack of independent cards.

---

# 15. Spacing

Match the reference screenshot's restrained spacing.

Use approximately:

* 12–16 px horizontal internal padding
* 8–12 px between title and preview
* 6–10 px between preview and metadata
* 8–12 px between metadata and date
* approximately 10–16 px vertical content spacing between unselected notes
* 1 px subtle separator when needed

Do not make the list excessively dense.

Do not make it excessively spacious.

The middle pane should show multiple notes simultaneously while maintaining the editorial feel.

---

# 16. Attachment Preview System

This is a major part of Editorial.

Attachments must become part of the note preview instead of always appearing as a tiny thumbnail pinned to the far right.

Support:

* images
* PDFs
* documents
* multiple attachments
* mixed image/document attachments

Use the application's existing attachment system and storage model.

Do not duplicate uploaded files.

Do not create new copies merely for rendering previews.

---

# 17. Single Image

For a note containing a single image:

```text
Title

Preview text...

┌──────────────────────────┐
│                          │
│       IMAGE PREVIEW      │
│                          │
└──────────────────────────┘

Date
```

The image should:

* preserve aspect ratio
* use object-fit/cover behavior appropriate to the design
* have subtle corner rounding
* remain within a strict maximum height
* not cause the row to become enormous

Do not stretch images.

Do not distort aspect ratios.

Do not allow a portrait image to make the list unusably tall.

---

# 18. Multiple Images

For multiple images, show a compact horizontal preview grid.

Example:

```text
┌───────────┐ ┌───────────┐ ┌───────────┐
│           │ │           │ │           │
│   IMAGE   │ │   IMAGE   │ │   IMAGE   │
│           │ │           │ │           │
└───────────┘ └───────────┘ └───────────┘
```

Use a maximum number of simultaneously visible previews appropriate to the available list width.

For additional attachments, show a compact indicator such as:

```text
+3
```

Do not render unlimited attachment previews.

---

# 19. PDF Preview

A PDF must not be represented solely by a generic text label when a preview thumbnail is available.

Display an actual first-page thumbnail or existing PDF preview asset where the application already supports this.

Conceptually:

```text
┌──────────────────────┐
│                      │
│   PDF FIRST PAGE     │
│                      │
├──────────────────────┤
│ Ultimate guide       │
│ PDF                  │
└──────────────────────┘
```

If a valid thumbnail cannot be generated, fall back gracefully to a polished PDF attachment card.

Never show a broken-image icon.

Never show empty preview containers.

Never block the entire note list because one PDF preview fails.

---

# 20. Mixed Attachments

For a note containing an image and PDF:

```text
┌──────────────┐ ┌──────────────┐
│              │ │              │
│    IMAGE     │ │    PDF       │
│              │ │              │
└──────────────┘ └──────────────┘
```

Attachments should form a cohesive preview group.

Keep dimensions visually consistent.

Do not allow one attachment type to dominate the entire row.

---

# 21. Attachment Loading

Do not introduce blur-up loading.

The application explicitly does not want blur loading.

Use one of:

* existing cached thumbnail
* immediate image
* neutral lightweight loading state
* clean empty-safe fallback

The loading experience must be subtle and must not create layout jumps.

Reserve the expected attachment dimensions before the asset loads.

---

# 22. Attachment Errors

If an image/PDF thumbnail fails:

* keep the row usable
* display a clean fallback representation
* preserve attachment metadata
* do not throw an unhandled exception
* do not collapse/reorder the entire row unexpectedly

Example fallback:

```text
[ Image unavailable ]
```

or an appropriate document card using the application's iconography.

Follow the existing design language.

---

# 23. Tags and Metadata

Tags should remain available in Editorial.

Display them below the preview rather than surrounding the title.

Example:

```text
My productivity app is a never-ending .txt file

Over 14 years of todos recorded in text...

#clippings

Sep 1
```

Keep tags subtle.

Avoid oversized pill styling.

Use the existing tag representation where possible, but visually reduce its prominence for Editorial.

Do not turn every metadata item into a large rounded badge.

---

# 24. Attachment Metadata

When a note has attachments, metadata can communicate their existence.

Examples:

```text
PDF
2 PDFs
1 image
3 images
```

Use the existing application's terminology.

Don't duplicate the information excessively.

For example, do not show:

```text
[PDF preview]

[PDF] 1 PDF attachment document
```

Instead choose one coherent representation.

---

# 25. Dates

Show the note date in the same general location used by the reference:

beneath note content/metadata.

Examples:

```text
Just now
Yesterday
Sep 1
July 10
```

Use the application's existing date formatting rules wherever available.

Do not introduce a second inconsistent date formatter.

Ensure dates respond correctly to locale and user settings.

---

# 26. Responsive Behavior

Editorial must work across:

* desktop
* laptop
* tablet
* touch interfaces
* narrow application windows
* different scaling/display densities

Do not hard-code the screenshot's exact pixel dimensions.

Reproduce its **visual proportions**, not merely its coordinates.

The note-list pane should have a sensible minimum width.

When space becomes constrained:

1. attachment previews reduce
2. preview text truncates earlier
3. metadata compresses
4. list remains usable

Do not allow horizontal scrolling in the note list.

---

# 27. Three-Pane Integration

Editorial must integrate with the existing three-pane navigation.

The sidebar continues to control the current collection.

Selecting:

```text
All Notes
```

renders all notes.

Selecting:

```text
Pinned
```

renders pinned notes.

Selecting:

```text
Archive
```

renders archived notes.

Selecting:

```text
Trash
```

renders trash.

Selecting:

```text
journal
```

renders that tag.

The Editorial renderer must consume the exact same filtered/sorted dataset as the existing Quiet Paper list.

Do not implement a separate query system.

---

# 28. Search Integration

Existing search functionality must continue working.

When the user searches:

```text
machine learning
```

Editorial should display the exact same search results that the Quiet Paper layout would display.

Only presentation changes.

Search highlighting may be implemented if the current application already supports it, but do not introduce inconsistent highlighting solely for Editorial.

---

# 29. Sorting Integration

Use the application's existing sorting behavior.

Editorial must not alter:

* newest
* oldest
* title A–Z
* title Z–A
* any custom sorting currently supported

No sorting logic should be duplicated inside the presentation component.

---

# 30. Filtering Integration

Use the existing filter state.

Editorial must respect:

* selected tags
* attachment filters
* date filters
* journal filters
* pinned filters
* archive/trash state
* any existing advanced filters

Do not create an Editorial-only filter engine.

---

# 31. Selection and Interaction

Single click/tap:

> select/open note

Preserve current application's behavior.

Keyboard:

* Arrow Up/Down should continue navigating notes where currently supported.
* Enter should continue opening the selected note where currently supported.
* Existing keyboard shortcuts must remain functional.

Do not break keyboard navigation when introducing the new row renderer.

---

# 32. Touch Interaction

Editorial must be touch-friendly.

Rows must have an appropriate touch target.

Do not depend on hover for essential functionality.

Do not introduce tiny action buttons that are difficult to tap.

Long press / existing multi-select behavior must continue functioning where supported.

If the current application supports swipe interactions, Editorial should not interfere with them.

---

# 33. Hover Behavior

Desktop hover may provide subtle feedback:

* very light background change
* cursor change
* optional contextual actions

Do not turn every row into a dark/bright card on hover.

Hover must remain visually quieter than selection.

Selection always has priority over hover.

---

# 34. Context Menus

The existing context menu behavior must remain intact.

Right-click / contextual action should continue to expose existing functionality such as:

* Open
* Pin
* Archive
* Move
* Add/remove tag
* Export
* Delete
* Restore
* other existing note actions

Do not remove functionality merely to simplify the Editorial appearance.

---

# 35. Multi-Select

Existing multi-select must work exactly as before.

When multiple notes are selected:

* selection visuals must be clear
* normal Editorial styling may temporarily switch into selection mode
* bulk action toolbar must remain usable

Do not make multi-select depend on the visual card style of the default list.

---

# 36. Empty State

Editorial needs a polished empty state consistent with the application's current empty-state system.

Examples:

```text
No notes yet
Create your first note.
```

or:

```text
No notes found
Try changing your filters or search.
```

Do not render empty rows.

Do not render attachment placeholders in the empty state.

---

# 37. Very Long Notes

Very long notes must not make the list unusable.

Limit preview text.

Never render entire note bodies in the note list.

Recommended behavior:

* title: max 2 lines
* preview: max 2–3 lines
* attachments: constrained height
* metadata: one compact row
* date: one line

Use consistent truncation.

Prefer CSS/layout truncation where possible rather than destructively modifying stored content.

---

# 38. Notes With No Preview Text

For notes containing only:

* an image
* a PDF
* attachments
* an unsupported/empty content block

show the attachment preview directly.

Example:

```text
math

┌──────────────────────┐
│                      │
│        IMAGE         │
│                      │
└──────────────────────┘

Sep 1
```

Do not insert fake preview text.

---

# 39. Notes With Code

For notes containing code:

Do not dump huge code blocks into the list.

Use a clean readable text preview.

If the application already identifies that a note contains code, a subtle metadata indicator is acceptable.

Do not perform expensive syntax highlighting for entire note previews if that would degrade scrolling performance.

---

# 40. Notes With Tables

Do not attempt to render full interactive tables in the list preview.

Use a text representation or first meaningful paragraph.

The full table remains inside the editor.

---

# 41. Notes With Markdown Headings

Strip Markdown syntax from list previews.

Example:

Stored:

```markdown
# Project Aurora

## Tasks

- Finish sync
- Fix attachments
```

Preview:

```text
Project Aurora

Tasks
Finish sync
Fix attachments
```

or, preferably, a natural extracted preview based on the existing Markdown parser.

Do not expose `#`, `##`, `-`, `**`, etc. unless they are genuinely literal content.

---

# 42. Theme Compatibility

Editorial must respect **all existing Quiet Paper themes**.

The application currently has theme support including the existing light/dark/system behavior.

Editorial must not hard-code its own global colors.

Use theme tokens for:

* background
* selected background
* primary text
* secondary text
* divider
* accent
* attachment background
* metadata
* hover
* icons
* borders

When the user changes theme, Editorial should update immediately.

Do not create a separate Editorial-only theme.

---

# 43. Light Theme

In light themes:

* background should remain clean
* selected item should use a subtle tinted surface
* text should remain high contrast
* dividers should remain extremely subtle
* attachment cards should blend into the design
* no harsh black borders

Do not copy raw screenshot colors if they conflict with the active theme.

The screenshot determines hierarchy and visual treatment; the application's theme system determines actual colors.

---

# 44. Dark Theme

In dark themes:

* retain the same hierarchy
* selected item should use a subtly lighter/different surface
* accent indicator should remain visible
* dividers should remain restrained
* thumbnails/cards must not become excessively bright
* text hierarchy must remain clear

Do not simply invert light-mode colors.

---

# 45. Accessibility

Editorial must remain accessible.

Ensure:

* sufficient text contrast
* visible keyboard focus
* screen-reader appropriate labels
* semantic buttons
* accessible list items
* meaningful attachment labels
* no information conveyed solely through color
* selection state exposed semantically
* touch targets meet platform expectations

Do not sacrifice accessibility to visually match the screenshot.

---

# 46. Performance

This list may eventually contain hundreds or thousands of notes.

Optimize accordingly.

Do not:

* render full note editors for every row
* parse the entire Markdown body repeatedly on every frame
* regenerate attachment thumbnails during scrolling
* perform expensive synchronous work while scrolling
* create unnecessary copies of note data
* cause layout thrashing

Use:

* memoization/caching where appropriate
* existing thumbnail cache
* virtualization/lazy rendering if the current application architecture supports it
* stable row identity
* efficient Markdown preview extraction

Scrolling must remain smooth.

---

# 47. Stable Row Heights and Layout

Rows can have variable heights because attachments are optional, but avoid uncontrolled variation.

Reserve attachment dimensions where possible.

Avoid:

```text
image appears
↓
row suddenly expands
↓
user loses scroll position
```

Layout should remain stable.

---

# 48. Animation

Animations should be subtle.

Allowed:

* selection transition
* hover transition
* settings style transition
* small attachment appearance transition

Avoid:

* large card expansion
* bounce animations
* exaggerated scaling
* flashy transitions

The application should feel calm.

---

# 49. Style Switching

When switching:

```text
Quiet Paper → Editorial
```

the notes should remain in the same:

* order
* selection
* collection
* search state
* scroll context where reasonably possible

Do not navigate the user away from the current collection.

Do not reload the entire application unnecessarily.

The style should change smoothly.

---

# 50. Persistence

Persist the chosen style using the application's existing preferences/settings system.

The value should conceptually be:

```text
notesListStyle = quietPaper | editorial
```

Use the application's actual settings architecture rather than introducing an unrelated storage mechanism.

Default:

```text
quietPaper
```

For existing users, upgrading the application must preserve the current appearance automatically.

No existing user's list should suddenly switch to Editorial after an update.

---

# 51. Backward Compatibility

Existing users must see exactly the same current list after upgrading unless they explicitly select Editorial.

Existing note data must remain unchanged.

Existing attachments must remain unchanged.

Existing tags must remain unchanged.

Existing database migrations must not be affected unnecessarily.

Do not alter the Markdown storage format.

Do not migrate notes purely for this feature.

---

# 52. Do Not Copy Unnecessary Behavior From the Reference

The reference screenshot is the visual reference for Editorial.

Do not blindly copy unrelated application behavior from the screenshot.

Quiet Paper's existing architecture and functionality remain authoritative for:

* persistence
* note model
* synchronization
* attachments
* commands
* search
* filters
* sorting
* navigation
* editor
* exports
* trash
* tags

Editorial is a presentation option.

---

# 53. Important Visual Details to Match From the Reference

The implementation should specifically reproduce these visual qualities:

### Sidebar/list relationship

The middle pane begins after a clear vertical boundary from the sidebar.

### Middle pane width

Keep a compact notes column similar to the supplied screenshot.

It must be wide enough for:

* title
* 2–3 lines of preview
* meaningful attachments

but narrow enough that the editor pane remains dominant.

### Header

Compact title aligned near the top-left.

Small dropdown indicator.

Simple search/new-note controls.

### Rows

Text-centric.

No permanent heavy cards.

Selected row is the visual exception.

### Attachments

Inside the note's vertical content flow.

Not permanently pinned as tiny right-edge thumbnails.

### Dates

At the bottom of the note content.

### Dividers

Subtle and thin.

### Typography

Strong title.

Muted preview.

Very subdued metadata.

### Overall feeling

Calm.

Editorial.

Content-oriented.

Minimal.

Polished.

Do not accidentally make it look like a generic Material Design list.

---

# 54. Do Not Change the Existing Quiet Paper Style

This is a hard requirement.

Do not:

* remove existing note cards
* change existing thumbnail placement
* remove existing chips
* change current spacing
* change current metadata presentation
* change current selection appearance
* rename current style
* alter current list logic unnecessarily

The existing style must remain available as a first-class option.

The user is intentionally choosing between two distinct presentations.

---

# 55. Suggested Component Structure

Adapt this to the application's framework, but maintain equivalent separation:

```text
NotesListContainer
│
├── deriveNotesListState()
│
└── switch (notesListStyle)
      │
      ├── QuietPaperNotesList
      │     └── Existing implementation
      │
      └── EditorialNotesList
            │
            ├── EditorialListHeader
            ├── EditorialNoteRow
            ├── EditorialAttachmentPreview
            ├── EditorialMetadata
            └── EditorialEmptyState
```

Shared infrastructure:

```text
NoteQueryState
SortState
FilterState
SearchState
SelectionState
AttachmentResolver
PreviewExtractor
ThemeTokens
```

Do not duplicate these unnecessarily.

---

# 56. Acceptance Criteria

The feature is complete only when all of the following are true.

### Settings

* Editorial appears under Settings → Appearance.
* Quiet Paper and Editorial are selectable.
* Quiet Paper remains the default.
* Selection persists after restart.
* Existing users retain Quiet Paper automatically.

### Current list

* Existing Quiet Paper list remains visually and behaviorally intact.

### Editorial list

* Continuous content-focused list.
* No heavy card around every unselected note.
* Selected note receives a subtle card/highlight treatment.
* Selected note has a narrow accent indicator.
* Titles have strong hierarchy.
* Previews are clean text.
* Markdown syntax does not leak into previews.
* Dates appear below content.
* Tags remain available but subdued.
* Attachments appear inline within rows.
* Images use proper thumbnails.
* PDFs use actual preview thumbnails when available.
* Mixed attachments work.
* Empty states work.
* Long notes truncate properly.
* Notes without text but with attachments still look correct.

### Functionality

* Search works.
* Sort works.
* Filters work.
* Tag selection works.
* Pinned/Archive/Trash work.
* Multi-select works.
* Context menus work.
* Keyboard navigation works.
* Touch works.
* Three-pane navigation works.
* Existing note selection behavior remains intact.

### Theming

* Light themes work.
* Dark themes work.
* System theme works.
* No hard-coded global colors.
* Editorial automatically follows active theme.

### Performance

* Smooth scrolling with large note collections.
* No full editor instance per row.
* No repeated expensive Markdown parsing during scrolling.
* No attachment thumbnail storm.
* No obvious layout jumping.

### Data safety

* No note data changes.
* No Markdown migration.
* No attachment duplication.
* No synchronization changes.
* No destructive database migration.

---

# 57. Final Implementation Standard

Do not stop at a visually approximate prototype.

The implementation must be:

* production ready
* fully functional
* responsive
* accessible
* theme aware
* persistent
* performant
* integrated with existing search/filter/sort/navigation
* compatible with existing note/attachment data
* free of placeholders
* free of TODOs for required functionality
* free of mock data
* free of hard-coded sample notes
* free of temporary UI

Do not ask the user to manually finish missing pieces.

Inspect the existing project architecture before modifying it and reuse established components, theme tokens, settings infrastructure, note queries, attachment handling, and interaction patterns wherever possible.

Do not introduce a new dependency unless it is genuinely required and there is no suitable existing implementation.

Before considering the work complete, manually verify both modes:

```text
Quiet Paper
Editorial
```

with:

* text-only notes
* notes with images
* notes with PDFs
* multiple attachments
* mixed attachments
* tags
* long titles
* long previews
* untitled notes
* empty notes
* pinned notes
* archived notes
* trash notes
* search results
* filtered results
* multiple themes
* large collections

The final result should make the Editorial option feel like **an intentional second design language built into Quiet Paper**, while the existing Quiet Paper list remains completely intact.

**The provided reference screenshot is the visual authority for the Editorial list's appearance and hierarchy. Reproduce its visual structure closely rather than interpreting Editorial as a generic compact list.**
