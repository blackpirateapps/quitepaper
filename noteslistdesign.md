
# Production Implementation Prompt — Redesign Quiet Paper Notes List

## Role

You are a senior Flutter engineer and product/UI engineer working on **Quiet Paper**, a production note-taking application.

Implement a complete redesign of the **notes-list experience** so it adopts the information hierarchy, density, visual rhythm, and calm editorial feel of the Bear notes list shown in the provided reference screenshots, while remaining unmistakably **Quiet Paper**.

This is **not** a request to clone Bear's UI. Borrow the underlying design principles:

* strong content hierarchy
* lightweight note rows
* date-based grouping
* restrained metadata
* minimal visual chrome
* subtle selected states
* efficient use of vertical space
* content-first presentation

Preserve Quiet Paper's existing visual identity, functionality, architecture, themes, routing, database behavior, and 3-pane layout.

Do not introduce placeholders, mock data, hardcoded note content, or a parallel UI implementation.

---

# 1. First: Inspect the Existing Codebase

Before making changes:

1. Identify the current notes-list screen/widget.
2. Identify the current note-list item/tile component.
3. Identify how notes are queried and paginated/streamed.
4. Identify how:

   * pinned notes
   * archived notes
   * trashed notes
   * tags
   * attachments
   * images
   * PDFs
   * note timestamps
   * selection state
   * sorting
   * filtering
   * search
     are currently represented.
5. Identify the existing theme system and the two currently supported themes:

   * **Light Paper**
   * **Dark Paper**
6. Identify the existing desktop/tablet 3-pane navigation architecture.
7. Identify the existing mobile navigation behavior.
8. Identify existing reusable typography, spacing, icon, surface, divider, chip, and animation primitives.
9. Identify whether the current notes list is already virtualized/lazy-rendered.
10. Identify existing accessibility and touch-target conventions.

Do not unnecessarily create new architecture when existing abstractions can be reused.

Do not modify database schemas unless absolutely required.

Do not duplicate business logic inside UI widgets.

---

# 2. Primary Design Goal

Redesign the middle **Notes List** pane so it feels like a calm personal notebook rather than a collection of cards.

The intended structure is:

```text
Notes                                      Sort  Filter  Search  +

All    #simplenote 183    #clippings 72    #blog 53

429 notes

Pinned

📌 Bug Fixes
The markdown preview does not if there is one...
                                      Yesterday

────────────────────────────────────────

Yesterday

30th Aug 2026

im so tired right now. I want to sleep...
#journal
                                      Yesterday

The Hugging Face attack surprised me
A clean excerpt from the clipped article...
#clipped
                                      Yesterday

The Rise and Fall of Agent Civilizations
A clean excerpt from the clipped article...
#clipped
                                      Yesterday

Research Paper
Interesting findings about...
PDF · 12 pages
```

This is the visual target in terms of hierarchy, **not a literal pixel copy**.

---

# 3. Remove the Heavy Card-Based Feel

The current Quiet Paper notes list uses comparatively strong card/list boundaries.

Replace that visual treatment with a much lighter editorial list.

## Do

* Use the existing paper background as the primary list background.
* Make note rows visually belong to the same continuous surface.
* Use extremely subtle separators where needed.
* Make selection a soft surface tint rather than a large card.
* Keep rounded corners restrained.
* Avoid unnecessary borders.
* Avoid shadows on individual notes.
* Avoid making every note look like an isolated Material card.

## Do not

Create a UI like:

```text
╭──────────────────────╮
│ Note                 │
│ Preview              │
│ #tag                 │
╰──────────────────────╯
```

for every note.

The list should visually read as a **continuous stream of notes**.

---

# 4. Preserve the Quiet Paper 3-Pane Architecture

On desktop/tablet, preserve the existing architecture:

```text
┌─────────────────┬────────────────────┬────────────────────────┐
│                 │                    │                        │
│ Sidebar         │ Notes List         │ Note Editor             │
│                 │                    │                        │
│                 │                    │                        │
└─────────────────┴────────────────────┴────────────────────────┘
```

The redesign applies primarily to the **middle Notes List pane**.

Do not redesign the editor or sidebar as part of this task except where existing spacing/interaction requires minimal integration.

The three panes must retain independent scrolling behavior where currently supported.

The notes list must remain independently scrollable.

Do not make the entire application scroll as one page.

---

# 5. Notes List Header

Redesign the header to be minimal and content-focused.

It should retain the existing Quiet Paper functionality for:

* sort
* filter
* search
* create note
* overflow/more actions where currently available

The visual hierarchy should be approximately:

```text
Notes                              Sort   Filter   Search   +
```

Use existing icons/components where possible.

Do not make the controls visually louder than the note content.

Controls should:

* have appropriate touch targets
* expose tooltips on desktop where appropriate
* expose semantic labels for accessibility
* preserve existing keyboard navigation

---

# 6. Tag Filter Chips

Retain the existing horizontal tag-filter concept.

Example:

```text
All    #simplenote 183    #clippings 72    #blog 53
```

Requirements:

* preserve actual tag counts from the data layer
* support horizontal scrolling
* do not wrap into multiple rows
* preserve touch interaction
* clearly indicate the active chip
* use the current theme's semantic colors
* keep chips visually restrained
* avoid excessive pill styling

The `All` chip should remain the primary/default state.

Do not hardcode example tag names or counts.

---

# 7. Notes Count

Keep the total-note count beneath the filter row.

Example:

```text
429 notes
```

Requirements:

* derive from actual filtered result count
* update automatically when filtering/searching
* use secondary/tertiary typography
* do not make it compete with the date headings
* retain correct pluralization

Examples:

```text
1 note
2 notes
```

---

# 8. Pinned Section

Pinned notes must appear in a dedicated section at the top when applicable.

Structure:

```text
Pinned

📌 Bug Fixes
The markdown preview does not if there is one...
                                  Yesterday

📌 Another Note
Preview...
                                  Monday
```

Requirements:

* only show the section when pinned notes exist
* preserve existing pinned sorting semantics
* preserve existing note selection behavior
* preserve existing pin/unpin behavior
* retain a subtle pin indicator
* use a small pin icon, not a large decorative illustration
* keep the pinned area visually distinct without turning each note into a card
* separate the pinned section from chronological content with a subtle divider/spacing transition

The pinned section must not duplicate notes elsewhere in the list.

Respect all current filtering/sorting semantics.

---

# 9. Date-Based Grouping

This is a major part of the redesign.

Organize chronological notes into human-friendly date groups.

Examples:

```text
Today

August 31, 2026
```

and:

```text
Yesterday

30th Aug 2026
```

and older dates as appropriate.

Use the application's existing date/time localization infrastructure.

Do not hardcode English-only date logic if the app already supports localization.

Possible grouping categories may include:

* Today
* Yesterday
* This Week
* Older dates

However, inspect existing product behavior before changing semantics.

The exact grouping logic must be deterministic and consistent.

---

# 10. Note Row Design

Each note row should contain these conceptual layers:

### Primary line

The note title.

Example:

```text
The Hugging Face attack surprised me
```

### Preview

A short clean content preview.

Example:

```text
A clean excerpt from the clipped article...
```

### Metadata

Tags and/or attachment information.

Example:

```text
#clipped
```

or:

```text
PDF · 12 pages
```

The row may also contain a small timestamp aligned appropriately.

---

# 11. Typography Hierarchy

Establish a clear hierarchy.

## Title

* approximately 16–18 logical px depending on existing responsive typography
* medium/semibold
* primary text color
* maximum sensible number of lines
* ellipsis when constrained

## Preview

* approximately 14–16 logical px
* regular weight
* secondary text color
* lower contrast than title
* line-clamped
* never allowed to dominate the title

## Metadata

* approximately 12–13 logical px
* tertiary/secondary color
* visually subordinate

## Date headings

* stronger than metadata
* approximately 17–19 logical px
* medium/semibold
* sufficient spacing above and below

Do not introduce an entirely new typography system if Quiet Paper already has one.

Integrate this into existing typography tokens.

---

# 12. Preview Generation

This is important.

The list preview must show **clean note content**, not raw Markdown noise whenever possible.

The preview-generation logic should:

* respect the canonical Markdown representation
* remove or appropriately hide Markdown syntax that should not appear in previews
* avoid displaying raw frontmatter when a better title/content representation exists
* avoid showing YAML/frontmatter such as:

```text
--- title: "The Hugging Face attack surprised me"
```

when a clean title is already available

* avoid broken Markdown syntax in previews
* preserve useful textual content
* normalize excessive whitespace
* avoid producing large empty gaps
* remain performant for long notes

Do not create a second canonical note representation just to generate previews.

Use the existing Markdown/parser infrastructure where possible.

---

# 13. Web Clipped / Frontmatter Notes

Quiet Paper currently has clipped notes whose Markdown can contain frontmatter such as:

```markdown
---
title: "The Hugging Face attack surprised me"
---
```

Do not let this raw representation become the primary list preview.

Instead, derive a clean presentation:

```text
The Hugging Face attack surprised me

A short meaningful excerpt from the clipped article...
#clipped
```

Use existing note metadata/title information when available.

Do not mutate the stored canonical Markdown just to solve this UI problem.

---

# 14. Attachment Metadata — TEXT, NOT ICONS

This is a specific requirement.

For PDFs, use **text metadata rather than a PDF icon**.

Example:

```text
PDF · 12 pages
```

For multiple PDF/document attachments:

```text
2 PDFs · 31 pages
```

Where page count is available.

For images:

```text
2 images
```

For generic attachment combinations:

```text
3 attachments
```

Use real attachment information from the existing data model.

Do not use decorative file-type icons as the primary attachment indicator.

Do not show fake metadata.

Do not calculate expensive attachment information repeatedly during every list rebuild if it can reasonably be derived/cached.

### Metadata ordering

When both tags and attachment metadata exist, use:

```text
#research · #paper

PDF · 12 pages
```

or an equivalent compact arrangement appropriate to the existing layout.

Tags should remain visually primary among metadata.

Attachment information should remain subordinate.

---

# 15. Image Thumbnails

Preserve support for image thumbnails where the existing note contains images.

Only show thumbnails when they provide useful information.

Do not force a thumbnail onto every note.

A note may look like:

```text
My Green Friends

Plant tracker 🌱 Plant watered...
Last Spider Plant...

[thumbnail]

Just now
```

Requirements:

* use existing attachment/image infrastructure
* use cached/network-aware image loading
* avoid blocking the UI thread
* preserve placeholders/error states already used by the app
* maintain rounded-corner treatment consistent with Quiet Paper
* avoid making thumbnails dominate the list
* preserve performance with many notes containing images

For non-image attachments such as PDF, prefer textual metadata instead of an icon.

---

# 16. Tags

Retain the current tag pills.

Example:

```text
#journal
```

But visually reduce their dominance.

Tags should:

* remain recognizable
* remain tappable
* use current theme tokens
* maintain adequate touch targets
* not dominate the row
* wrap only when necessary within the row layout
* never cause title truncation problems unnecessarily

Do not redesign tag functionality in this task.

---

# 17. Selected Note State

The selected note should be unmistakable but subtle.

### Light Paper

Use a soft warm/darker paper-like surface.

### Dark Paper

Use a slightly lighter dark-paper surface.

Selection should feel like:

> "this piece of paper is currently active"

rather than:

> "this card is selected."

Do not use a large blue Material highlight unless the existing Quiet Paper design system explicitly requires it.

Pinned + selected should still communicate both states.

---

# 18. Hover State — Desktop

For pointer devices:

Normal:

```text
transparent / base paper
```

Hover:

```text
very subtle surface tint
```

Selected:

```text
persistent selected surface tint
```

Hover must not produce layout shifts.

Do not rely on hover for critical information.

Touch devices must behave identically without requiring hover.

---

# 19. Touch Friendliness

The notes list must remain excellent on phones and tablets.

Requirements:

* minimum comfortable touch targets
* no hover-only interaction
* horizontal tag chips must respond naturally to touch scrolling
* note rows must have generous enough vertical spacing
* avoid tiny metadata controls
* support swipe/gesture behavior already present in the application
* preserve long-press behavior if currently supported
* avoid nested gesture conflicts

Do not simply shrink the desktop UI for mobile.

---

# 20. Responsive Layout

The design should adapt to available width.

## Desktop

Three-pane layout.

## Tablet

Three-pane where current architecture supports it, otherwise existing adaptive behavior.

## Phone

One-pane note list → note editor navigation.

The same visual language must remain intact across all form factors.

Do not introduce a separate unrelated mobile list design.

---

# 21. Density

The target is approximately Bear-like information density.

Avoid excessive vertical padding.

However, do not make the rows cramped.

The design should feel:

* calm
* readable
* information-dense
* elegant
* fast to scan

Implement spacing using existing design tokens where possible.

If tokens are insufficient, establish a small, documented spacing scale rather than scattering magic numbers throughout widgets.

---

# 22. Light Paper Theme

The entire redesigned list must work correctly with the existing **Light Paper** theme.

Do not hardcode light-theme colors inside individual widgets.

Use semantic theme tokens.

At minimum, the list needs semantic values for:

```text
background
surface
selectedSurface
hoverSurface
divider
primaryText
secondaryText
tertiaryText
tagBackground
tagText
accent
```

Light Paper should visually feel:

* warm
* paper-like
* soft
* calm
* low-glare
* editorial

Do not make it pure white unless that is already part of the existing Light Paper design.

---

# 23. Dark Paper Theme

The same exact component hierarchy must work with the existing **Dark Paper** theme.

Do not create a separate dark widget implementation.

Map the same semantic roles:

```text
background
surface
selectedSurface
hoverSurface
divider
primaryText
secondaryText
tertiaryText
tagBackground
tagText
accent
```

Dark Paper should preserve:

* readable contrast
* restrained highlights
* subtle separation
* clear selected state
* comfortable long-session readability

Ensure there are no remaining hardcoded light colors such as:

```dart
Colors.white
Colors.black
Colors.grey
```

where semantic theme values should be used.

Audit the entire redesigned notes-list subtree for theme leakage.

---

# 24. Sort and Filter Integration

Quiet Paper already has/needs note list sorting and filtering.

Do not create a disconnected sort/filter implementation.

Integrate the redesigned UI with the existing note-query architecture.

The visible list must accurately reflect active:

* sort mode
* filters
* tag filters
* archive state
* trash state
* pinned state
* search query
* any other existing note-list constraints

The header should remain understandable when filters are active.

Do not silently alter existing sorting semantics.

---

# 25. Search Interaction

When the notes list is being driven by search results:

* preserve the current search architecture
* do not perform expensive fuzzy search inside individual note tiles
* do not introduce O(N) or O(N × token-distance) work into list rendering
* do not decrypt protected content merely to display a preview unless existing security architecture already permits it
* preserve search highlighting behavior if currently supported

The UI redesign must not regress the previously implemented search architecture.

---

# 26. Performance Requirements

This is a production app.

The redesign must not introduce scrolling jank.

Requirements:

* use `ListView.builder`, slivers, or existing virtualization mechanism
* do not construct the entire notes collection widget tree at once
* do not repeatedly parse complete Markdown documents during every build
* do not repeatedly compute attachment statistics inside `build()`
* do not repeatedly evaluate expensive fuzzy search logic inside note tiles
* avoid unnecessary rebuilds
* use stable keys
* preserve efficient image loading
* avoid synchronous filesystem/network/database work during widget builds

Profile long lists.

Test with:

* 100 notes
* 500 notes
* 1,000 notes
* several thousand notes

The list should remain responsive.

---

# 27. Stable State and Selection

Preserve existing note-selection semantics.

When:

* opening a note
* switching notes
* deleting a note
* archiving a note
* pinning/unpinning
* changing filters
* changing sort order
* returning from editor

the selected row must update correctly.

Avoid:

* stale selection
* incorrect highlighted row
* scroll position jumping unnecessarily
* full-list rebuilds when only one note changes

---

# 28. Animation

Keep motion subtle.

Use short transitions for:

* selected-state changes
* hover-state changes
* chip selection
* pinned-state changes
* note insertion/removal where already supported

Avoid:

* bouncy animations
* large scale effects
* dramatic card movement
* unnecessary animation on every list build

Target roughly 120–200 ms for lightweight UI-state transitions unless existing project conventions specify otherwise.

Respect reduced-motion/accessibility settings if the project already supports them.

---

# 29. Empty States

Do not leave the new list looking broken when there are no notes.

Support the existing empty-state architecture.

Examples:

```text
No notes yet
```

or:

```text
No notes match your filters
```

The empty state should use the same Paper theme and typography system.

Do not invent a large illustration unless one already exists in Quiet Paper's design language.

---

# 30. Error / Loading States

Preserve existing loading and error behavior.

Do not replace robust states with arbitrary shimmer placeholders unless the app already uses them.

Loading UI should visually belong to the new list.

Errors should remain actionable where applicable.

---

# 31. Accessibility

The redesign must maintain or improve accessibility.

Ensure:

* adequate contrast in both themes
* semantic labels for icon buttons
* correct heading semantics where supported
* keyboard navigation on desktop
* focus states
* screen-reader understandable note rows
* tag semantics
* selected-state semantics
* appropriate button labels
* adequate touch targets

A note row should communicate something equivalent to:

> "Bug Fixes, pinned, modified yesterday, preview..."

rather than exposing meaningless widget structure.

---

# 32. Keyboard and Desktop Navigation

Preserve existing keyboard behavior.

Ensure users can:

* move through notes
* select notes
* open notes
* search
* use existing shortcuts
* navigate filters where currently supported

Do not break existing keyboard shortcuts while refactoring the UI.

---

# 33. Data and Architecture Rules

The notes-list redesign must remain a presentation-layer change wherever possible.

Do not:

* duplicate note entities
* introduce a second source of truth
* store derived preview strings unnecessarily
* modify canonical Markdown merely for rendering
* bypass repositories/services
* query the database individually for every visible note
* add direct database calls inside UI tiles
* duplicate attachment-fetching logic

Use:

```text
Database
   ↓
Repository / provider
   ↓
View model / existing presentation model
   ↓
Notes list
   ↓
Note row
```

or the project's existing equivalent.

---

# 34. Preview/Metadata Preparation

Where derived UI data is expensive, prepare it outside the widget's `build()` method.

A note-row presentation model may contain derived values such as:

```text
title
preview
tags
isPinned
timestamp
attachmentSummary
thumbnail
isSelected
```

Only introduce such a model if it fits the existing architecture.

The canonical note remains the source of truth.

---

# 35. No Hardcoded Content

All content must come from the real application.

Do not hardcode:

```text
429 notes
#simplenote 183
Bug Fixes
Yesterday
PDF · 12 pages
```

Those examples exist only to communicate layout.

Use real data.

---

# 36. Preserve Existing Features

The redesign must not regress:

* note creation
* note opening
* note selection
* editing
* deletion
* pinning
* archiving
* trash
* tags
* tag filtering
* searching
* sorting
* filtering
* attachments
* images
* PDFs
* sync
* offline behavior
* protected notes
* encrypted content
* existing navigation
* existing theme switching

Any feature already working must continue working.

---

# 37. Visual Polish

After implementing the structure, perform a dedicated visual-polish pass.

Evaluate:

* vertical rhythm
* title/preview spacing
* date spacing
* divider visibility
* chip spacing
* selected-state subtlety
* pinned-state visibility
* timestamp alignment
* metadata density
* long-title truncation
* long-preview truncation
* attachment metadata
* thumbnail proportions
* scrollbar interaction
* desktop pane boundaries
* tablet behavior
* mobile behavior

The result should feel intentional down to individual pixels.

---

# 38. Important Design Principle

Do not make Quiet Paper look like:

> "Bear recreated in Flutter."

Make it look like:

> **Quiet Paper evolved into a refined, Bear-inspired paper notebook.**

Borrow:

* content-first design
* list density
* date hierarchy
* subtle selection
* restrained metadata
* lightweight separators

Retain Quiet Paper's:

* Paper aesthetic
* branding
* themes
* 3-pane layout
* typography personality
* existing controls
* existing feature set
* existing interaction model

---

# 39. Testing Requirements

Before considering the task complete, test the redesigned list with:

### Data

* empty list
* one note
* 10 notes
* 100 notes
* 500+ notes
* pinned notes
* multiple pinned notes
* notes without titles
* very long titles
* very long previews
* Markdown-heavy notes
* clipped notes with frontmatter
* notes with tags
* notes with many tags
* image attachments
* PDFs
* multiple PDFs
* mixed attachments
* protected notes
* archived notes
* trashed notes

### State

* selected note
* hover state
* keyboard focus
* active tag
* active filter
* active sort
* active search
* changing theme
* orientation/size changes
* switching notes rapidly

### Themes

Test **both existing themes** thoroughly:

1. Light Paper
2. Dark Paper

No visual component of the redesigned list should break when switching themes.

### Devices

Test:

* phone
* tablet
* desktop

and both touch and pointer interaction where applicable.

---

# 40. Regression Testing

Verify that the redesign does not cause:

* incorrect note ordering
* missing notes
* duplicated notes
* broken pinned section
* stale selected state
* incorrect note counts
* tag count regressions
* incorrect date grouping
* broken navigation
* image loading regressions
* PDF metadata errors
* search regressions
* increased main-isolate work
* scrolling performance degradation

---

# 41. Implementation Quality

Follow the project's existing:

* lint rules
* formatting rules
* naming conventions
* architecture
* dependency versions
* state-management conventions

Avoid introducing new third-party dependencies for purely visual behavior unless there is a compelling architectural reason.

Prefer existing Flutter primitives and existing project components.

Keep widgets composable and testable.

Do not leave dead code behind.

Do not leave commented-out old implementations.

Do not create duplicate versions of the notes list.

---

# 42. Required Deliverables

Implement the feature fully, then provide:

1. Summary of files changed.
2. Explanation of the final architecture.
3. Explanation of how Light Paper and Dark Paper are handled.
4. Explanation of preview generation.
5. Explanation of PDF/image/attachment metadata handling.
6. Explanation of date grouping.
7. Explanation of performance considerations.
8. Tests added or updated.
9. Any regressions discovered and fixed.

Do not stop after making only the visual changes.

---

# 43. Acceptance Criteria

The implementation is complete only when all of the following are true:

* [ ] Notes are presented as a lightweight continuous list rather than heavy cards.
* [ ] Pinned notes have a dedicated section.
* [ ] Notes are grouped by date.
* [ ] Titles have clear visual priority.
* [ ] Previews are visually subordinate.
* [ ] Raw Markdown/frontmatter is not unnecessarily exposed in previews.
* [ ] Tags remain available but visually restrained.
* [ ] PDF information is represented using text such as `PDF · 12 pages`, not an icon.
* [ ] Image/attachment metadata is derived from real data.
* [ ] Image thumbnails remain supported.
* [ ] Selected-note state is subtle and obvious.
* [ ] Hover/focus states work on desktop.
* [ ] Touch interaction remains excellent.
* [ ] The list remains responsive with hundreds/thousands of notes.
* [ ] No expensive work is introduced into individual list-item builds.
* [ ] Existing sorting and filtering continue to work.
* [ ] Search behavior is not regressed.
* [ ] Existing 3-pane architecture remains intact.
* [ ] Mobile navigation remains intact.
* [ ] Light Paper is fully supported.
* [ ] Dark Paper is fully supported.
* [ ] No hardcoded theme colors leak through.
* [ ] No hardcoded sample data exists.
* [ ] Existing note functionality remains intact.
* [ ] Accessibility is preserved/improved.
* [ ] Existing project architecture is respected.
* [ ] Production-quality tests pass.

---

# Final Instruction to the Coding Agent

**Do not begin by writing code immediately.**

First inspect the existing Quiet Paper implementation and identify the actual widgets, providers/repositories, theme tokens, note models, attachment models, and navigation structure responsible for the current notes list.

Then produce a short implementation plan based on the real codebase.

After that, implement the redesign end-to-end.

Do not ask for clarification for details that can be determined by inspecting the existing implementation.

When there is a conflict between this specification and an existing Quiet Paper behavior, **preserve existing functional behavior and adapt the visual implementation around it**.

The final result should feel like a polished production note application: **quiet, paper-like, dense enough for serious note taking, visually calm, fast, touch-friendly, and unmistakably Quiet Paper.**
