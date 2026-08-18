# Build Quiet Paper — A Bear-Inspired Android Notes App

You are an expert Flutter engineer and product designer.

Build the first working version of **Quiet Paper**, a beautiful, offline-first Android notes application inspired by the design philosophy and writing experience of Bear Notes.

This is **not** a pixel-for-pixel clone of Bear. Do not copy Bear's proprietary assets, source code, logos, icons, or exact UI. Instead, reproduce the qualities we want: minimalism, warm editorial aesthetics, excellent typography, frictionless writing, Markdown, tags, and a calm interface.

The goal of this task is a **working, runnable MVP**, not a mockup.

---

# 1. Product Vision

Quiet Paper should feel like:

> "A quiet place to think."

It is a writing-first notes application.

The user should be able to:

1. Open the app.
2. See their notes.
3. Create a note.
4. Write/edit the note.
5. Add tags.
6. Search notes.
7. Pin notes.
8. Delete notes.
9. Close the app.
10. Reopen it and find everything exactly as they left it.

Everything should work offline.

Do not build cloud sync yet.

Do not build authentication.

Do not build a backend.

Do not over-engineer the first version.

---

# 2. Primary Platform

Target:

* Android
* Phones first
* Tablets should work reasonably well
* Portrait and landscape
* Android dark mode support

Use Flutter.

The application must run using:

```bash
flutter run
```

and compile successfully for Android.

---

# 3. Technology Choices

Use:

* Flutter
* Dart
* Material 3 infrastructure only where useful
* Riverpod for application state
* Drift + SQLite for local persistence
* Flutter's standard navigation infrastructure unless there is a compelling reason otherwise
* A Markdown package compatible with Flutter for Markdown parsing/rendering

Prefer stable, well-maintained packages.

Do not introduce unnecessary dependencies.

Before adding a package, ask whether the functionality can reasonably be implemented with Flutter itself.

---

# 4. Architecture

Use a clean but pragmatic feature-oriented architecture.

Suggested structure:

```text
lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│       ├── app_colors.dart
│       ├── app_spacing.dart
│       ├── app_radii.dart
│       ├── app_typography.dart
│       └── app_theme.dart
│
├── core/
│   ├── database/
│   ├── markdown/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── notes/
│   │   ├── data/
│   │   ├── domain/
│   │   ├── application/
│   │   └── presentation/
│   │
│   ├── editor/
│   │   ├── application/
│   │   └── presentation/
│   │
│   ├── search/
│   │   └── presentation/
│   │
│   └── settings/
│       └── presentation/
│
└── shared/
    └── widgets/
```

Do not create unnecessary layers for trivial functionality.

The architecture should make it easy to add sync later.

---

# 5. Data Model

Use SQLite through Drift.

Create a notes table with approximately:

```text
Note
----
id
title
content
createdAt
updatedAt
isPinned
```

Store the note body as Markdown/plain text.

Do not store rendered Markdown as the source of truth.

The Markdown source is the canonical content.

Tags should be represented separately rather than parsed permanently into the note.

Suggested schema:

```text
notes
tags
note_tags
```

Where:

```text
notes
-----
id
title
content
created_at
updated_at
is_pinned
```

```text
tags
----
id
name
```

```text
note_tags
---------
note_id
tag_id
```

Use foreign keys where appropriate.

---

# 6. Note Semantics

A note should support:

* title
* Markdown content
* tags
* created date
* modified date
* pinned state

The title can be stored independently from the Markdown body.

Do not require a title.

If the user creates a note and starts typing immediately, the app should feel frictionless.

If the title is empty, use a subtle fallback in the list such as:

```text
Untitled
```

Do not save `"Untitled"` as the actual title unless necessary.

---

# 7. Automatic Saving

Notes must autosave.

Do not require the user to press Save.

Implement sensible debouncing.

For example:

```text
User types
    ↓
wait ~500ms–1000ms after last change
    ↓
persist to SQLite
```

Also save when the editor loses focus or the screen is disposed.

Avoid excessive database writes on every keystroke.

The user should never lose their writing.

---

# 8. Main Screen

The main screen is the most important visual surface.

It should feel editorial rather than like a generic Material application.

Conceptually:

```text
Notes                              Search

Today

Project ideas
Things I want to build
#ideas #flutter

Reading list
Books I want to read
#books


Yesterday

Morning thoughts
A few thoughts from this morning...
```

Bottom-right:

```text
+
```

or a subtle equivalent.

Do not use a large generic Material FAB unless it fits the aesthetic.

---

# 9. Note List Behavior

Sort notes by:

1. pinned notes first
2. updated date descending

Group notes by date when appropriate:

```text
Today
Yesterday
Monday
Previous week
Older
```

Do not make grouping overly complicated.

Each note row should display:

* title
* short content preview
* tags if present
* optionally relative modification time

Example:

```text
Ideas for the new app
I think the editor should feel more like...
#design #flutter
```

The list must support:

* tap → open note
* long press → contextual actions
* swipe actions where appropriate

Contextual actions:

```text
Pin / Unpin
Delete
```

Avoid clutter.

---

# 10. Empty State

When there are no notes:

```text
No notes yet

Start writing something.
```

Keep the empty state extremely minimal.

No large illustration.

No onboarding carousel.

No unnecessary marketing copy.

Provide an obvious way to create the first note.

---

# 11. Note Editor

The editor is the heart of the product.

When a note opens, the interface should largely disappear.

Conceptually:

```text
                         ⋯

A quiet place to think

Sometimes the best notes app
is the one that lets you forget
you're using an app.

#ideas #writing
```

The editor should provide:

* title field
* body editor
* Markdown support
* tag support
* autosave
* keyboard-friendly behavior
* scrolling
* cursor preservation
* text selection
* copy/paste
* undo/redo where Flutter supports it naturally

Do not build a complicated rich text editor for v1 unless required.

A Markdown-first editor is acceptable.

---

# 12. Markdown Experience

The source format should be Markdown.

Support at minimum:

````text
# Heading 1
## Heading 2
### Heading 3

**bold**
*italic*
~~strikethrough~~

- unordered lists
1. ordered lists

> blockquote

`inline code`

```text
code block
````

[links](https://example.com)

````

The rendered visual hierarchy should be beautiful.

The exact editing model can be simple for v1.

Prioritize reliable editing over advanced WYSIWYG behavior.

If implementing a live Markdown editor is complex, use a well-designed Markdown source editor first rather than introducing an unstable custom editor.

---

# 13. Tags

Tags should work naturally.

Example:

```text
#ideas
#flutter
#books
#work/project
````

Support:

* adding tags
* removing tags
* searching/filtering by tag
* displaying tags on notes

Tags should look like lightweight metadata.

Do NOT make them huge colorful Material chips.

Preferred visual treatment:

```text
#ideas   #flutter   #design
```

Use subtle background pills only when useful.

---

# 14. Tag Parsing

When the user writes:

```text
#ideas
```

the application may recognize it as a tag.

However, do not make tag parsing so aggressive that normal writing becomes frustrating.

At minimum, provide a reliable way to add tags manually.

A sensible v1 approach:

* detect tags from note content
* normalize them
* persist them
* display them in the note list
* allow tag filtering

Avoid complicated natural-language parsing.

---

# 15. Search

Implement local search.

The search screen should allow searching:

* note title
* note content
* tag name

Search should feel instant.

For v1, SQLite text search is sufficient.

If practical, use SQLite FTS for better search performance.

Do not introduce a remote search service.

Search UI:

```text
←  Search notes...
```

Results should look like the normal note list.

Highlighting matches is desirable but not mandatory if it complicates implementation.

---

# 16. Pinning

Users can pin/unpin notes.

Pinned notes appear before regular notes.

Show a subtle visual indication.

Do not use a giant pin icon.

---

# 17. Delete

Support deleting notes.

Use a confirmation only where appropriate.

A deleted note should disappear immediately from the UI.

The database operation must be reliable.

For v1, permanent deletion is acceptable.

---

# 18. Undo Delete

If reasonably easy, provide a Snackbar-style undo after deletion.

Example:

```text
Note deleted                         Undo
```

This should be subtle and match the design system.

---

# 19. Design System

Do not build the UI directly from arbitrary Material defaults.

Create a custom design system.

The visual direction is:

**warm + editorial + minimal + calm + writing-first**

---

# 20. Light Colors

Use approximately:

```dart
background       #F7F6F2
surface          #FBFAF7
elevated         #FFFFFF

textPrimary      #292824
textSecondary    #77736C
textTertiary     #A6A29B

divider          #E8E5DF

accent           #D65F55
accentDark       #B94B43
accentSoft       #F1DAD6

tagBackground    #ECE9E3
tagText          #68645D
```

These are starting tokens, not immutable values.

Tune them visually as implementation progresses.

Avoid:

* pure white everywhere
* pure black backgrounds
* highly saturated accent colors
* excessive colored components

---

# 21. Dark Colors

Use:

```dart
background       #1D1C1A
surface          #242320
elevated         #2B2926

textPrimary      #E8E5DE
textSecondary    #AAA69E
textTertiary     #77736C

divider          #37342F

accent           #E4776D
accentDark       #D26259
accentSoft       #3D2926

tagBackground    #302E2A
tagText          #B8B3AA
```

Do not simply invert the light theme.

Dark mode should feel intentionally designed.

---

# 22. Typography

Typography is critical.

Use the platform system sans-serif rather than introducing a decorative typeface.

General UI:

```text
Title:          24–32sp
Headline:       20sp
Body:           16–18sp
Secondary:      14–15sp
Caption:        12–13sp
```

Editor:

```text
Title:          ~30sp
H1:             ~26sp
H2:             ~22sp
H3:             ~19sp
Body:           ~18sp
Line height:    ~1.55–1.65
Code:           ~15sp
```

The editor should prioritize readability.

Do not make body text too small.

---

# 23. Editor Width

On phones:

```text
horizontal padding: 24dp
```

On larger screens:

```text
max content width: ~720–760dp
```

Center the content on tablets.

The note should feel like a readable document rather than a stretched webpage.

---

# 24. Spacing

Use a 4dp base unit.

Primary tokens:

```text
4
8
12
16
20
24
32
40
48
64
```

Prefer generous whitespace.

Do not cram controls together.

---

# 25. Shapes

Use:

```text
8dp   small controls
12dp  menus/buttons
16dp  sheets
18dp  larger surfaces
```

Avoid putting every element into a rounded rectangle.

In particular:

**Note rows should not look like cards.**

---

# 26. Elevation

Use very little elevation.

Prefer surface color differences over shadows.

Approximate:

```text
normal UI:       0dp
popup:           4–8dp
bottom sheet:    8–16dp
```

No heavy shadows.

---

# 27. Icons

Use a simple, consistent icon set.

Prefer:

* 20–24dp
* monochrome
* restrained stroke weight
* rounded/simple geometry

Icons should usually be secondary text color.

Active controls can use the accent color.

---

# 28. Navigation

Phone:

```text
Notes
Search
Tags
Settings
```

Do not necessarily expose all four as a permanent bottom navigation bar.

A quieter approach is preferred.

Use navigation appropriate to the screen:

* notes list as the primary screen
* search as an overlay/screen
* tags as a secondary navigation surface
* settings as a secondary screen

On tablets, use a sidebar where appropriate.

---

# 29. Responsive Design

Support:

### Phone

Single-column list/editor.

### Large phone

Single-column with increased margins.

### Tablet

Potential split view:

```text
┌─────────────┬──────────────────────────────┐
│ Notes       │ Note                         │
│             │                              │
│ Note 1      │ Title                        │
│ Note 2      │                              │
│ Note 3      │ Content                      │
└─────────────┴──────────────────────────────┘
```

Do not force split view on small screens.

---

# 30. Motion

Keep animation subtle.

Approximate durations:

```text
fast:      120ms
normal:    180ms
major:     240ms
```

Prefer:

* fade
* subtle slide
* ease-out

Avoid:

* bouncing
* excessive spring animations
* large transitions
* decorative motion

The application should feel calm.

---

# 31. Interaction Details

Important UX behaviors:

### Creating a note

When the user taps New Note:

1. Create the note.
2. Open the editor.
3. Focus the title or body appropriately.
4. Open the keyboard if appropriate.
5. Allow immediate typing.

Do not make the user navigate through a creation form.

### Back

When leaving an editor:

* ensure changes are persisted
* return to the note list
* maintain scroll position if reasonably possible

### Keyboard

The editor must work correctly with:

* Android software keyboard
* keyboard resize behavior
* landscape keyboard
* text selection
* copy/paste

Do not let the keyboard permanently obscure the last lines of the note.

---

# 32. Settings

Keep v1 settings small.

Implement:

```text
Appearance
    System
    Light
    Dark
```

Potentially:

```text
About
```

Nothing more is required.

Do not build a huge settings screen.

Persist the selected theme locally.

---

# 33. Persistence

Everything important must survive:

* app restart
* process death
* Android backgrounding

At minimum persist:

* notes
* content
* titles
* tags
* pinned state
* timestamps
* theme preference

---

# 34. Sample Data

For development, provide a simple way to populate sample notes in debug mode.

Example notes:

```text
A quiet place to think

Ideas for the new app

Books I want to read

Things to remember

Morning thoughts
```

These should demonstrate:

* headings
* paragraphs
* tags
* lists
* Markdown
* different timestamps

Do not ship unwanted demo content in the production build.

---

# 35. Accessibility

Do not sacrifice accessibility for aesthetics.

Requirements:

* minimum ~48dp touch targets
* semantic labels for icon-only controls
* readable contrast
* Android font scaling support
* keyboard navigation where appropriate
* accessible dialogs
* accessible menus

Do not rely on color alone to communicate state.

---

# 36. Error Handling

The app should fail gracefully.

If database operations fail:

* don't crash silently
* show a useful error
* keep the editor content in memory where possible
* retry where reasonable

Avoid generic error messages such as:

```text
Something went wrong.
```

when a more useful message is possible.

---

# 37. Performance

The app should feel instantaneous.

Avoid:

* rebuilding the entire note list on every keystroke
* expensive Markdown rendering on every frame
* unnecessary database queries
* unnecessary animations
* loading all data repeatedly

Use Riverpod providers carefully.

Use debounced persistence.

Use efficient list rendering.

---

# 38. Security / Privacy

This is a local-first notes app.

Do not transmit note content anywhere.

Do not add analytics in v1 unless explicitly requested.

Do not add advertising.

Do not require an account.

Do not request unnecessary Android permissions.

The app should be usable entirely offline.

---

# 39. What NOT to Build

Do not build these in v1:

* cloud sync
* accounts
* login
* collaboration
* sharing infrastructure
* AI features
* subscriptions
* payments
* widgets
* OCR
* handwriting
* drawing
* reminders
* calendar integration
* complex attachments
* end-to-end sync
* web application

Keep the MVP focused.

---

# 40. Development Process

Work in this order.

## Phase 1 — Project foundation

Create:

* Flutter project
* Android configuration
* dependency setup
* folder structure
* app entry point
* theme infrastructure

Confirm:

```bash
flutter analyze
flutter test
flutter run
```

works.

---

## Phase 2 — Design system

Implement:

* colors
* typography
* spacing
* radii
* icon conventions
* light theme
* dark theme
* reusable buttons
* reusable list rows
* tags
* empty states

Do not start with complicated screens.

Make the design tokens reusable.

---

## Phase 3 — Database

Implement Drift:

* notes
* tags
* note_tags
* CRUD operations
* timestamps
* pinning

Write tests for the repository/database layer.

---

## Phase 4 — Notes list

Implement:

* note list
* date grouping
* pinned notes
* previews
* tags
* create note
* delete
* pin/unpin
* empty state

Make this screen polished before proceeding.

---

## Phase 5 — Editor

Implement:

* title
* Markdown content
* scrolling
* autosave
* keyboard handling
* tag display/input
* back navigation
* delete
* pin

This is the highest-priority screen.

Spend extra effort making it feel good.

---

## Phase 6 — Search

Implement:

* search UI
* title search
* content search
* tag search
* result list
* empty results

---

## Phase 7 — Settings

Implement:

* system/light/dark theme
* persistence
* about/version

---

## Phase 8 — Polish

Test:

* fresh install
* empty database
* 1 note
* 100+ notes
* long notes
* Markdown-heavy notes
* many tags
* keyboard open
* rotation
* dark mode
* Android back button
* process death
* tablet layout

Fix visual inconsistencies.

---

# 41. Testing

At minimum create tests for:

### Database

* create note
* update note
* delete note
* pin note
* create tag
* attach tag
* retrieve notes

### Application

* note creation
* autosave
* search
* pinning
* deletion

### UI

Test critical flows:

```text
Launch
→ Create note
→ Type
→ Leave
→ Reopen
→ Verify content
```

and:

```text
Create note
→ Add tag
→ Search tag
→ Open result
```

and:

```text
Create note
→ Delete
→ Undo
```

if undo is implemented.

---

# 42. Visual Quality Standard

Do not stop when the application merely works.

After functionality is complete, inspect every major screen.

Ask:

* Is the UI too busy?
* Are there too many borders?
* Are there too many cards?
* Are the colors too saturated?
* Is the text too small?
* Is the editor comfortable?
* Does the UI disappear when writing?
* Does dark mode feel intentional?
* Does anything look like a generic Flutter/Material template?

If something looks like a default Flutter demo, replace it.

---

# 43. Important Design Constraint

Do not blindly use standard Material widgets with their default styling.

Material 3 can provide:

* accessibility
* interaction behavior
* platform conventions
* foundations

But the final visual result should belong to **Quiet Paper**.

Customize:

* colors
* typography
* shapes
* padding
* elevation
* navigation
* buttons
* text fields
* menus
* dialogs
* snackbars
* FAB-equivalent actions

---

# 44. Product Personality

The application should communicate:

```text
quiet
warm
focused
private
fast
thoughtful
editorial
```

It should NOT communicate:

```text
corporate
busy
gamified
dashboard-like
overly colorful
over-engineered
```

---

# 45. Definition of Done

The first version is complete when a user can:

1. Install the Android app.
2. Launch it.
3. See a polished empty state.
4. Create a note.
5. Immediately start writing.
6. Enter a title.
7. Enter Markdown content.
8. Add tags.
9. Leave the note.
10. Reopen it.
11. See the content preserved.
12. Search for the note.
13. Pin it.
14. Delete it.
15. Use the app in dark mode.
16. Restart the application.
17. Confirm the data is still there.

The UI should feel cohesive and deliberately designed.

There should be no obvious placeholder screens.

There should be no TODOs in critical functionality.

There should be no fake backend.

There should be no hardcoded sample data in release builds.

---

# 46. Final Implementation Rule

When forced to choose between:

**more features**

and

**better writing experience**

choose the better writing experience.

When forced to choose between:

**more UI**

and

**less UI**

choose less UI.

When forced to choose between:

**a clever architecture**

and

**a reliable simple implementation**

choose the reliable simple implementation.

Build the smallest version that feels like a **real, polished notes application**, not a collection of demo screens.

Start implementing now.

Do not ask for confirmation unless a decision is genuinely blocking implementation.

At the end, report:

1. What you built.
2. Important architectural decisions.
3. Files created/modified.
4. Dependencies added.
5. Tests run and their results.
6. Any known limitations.
7. Exact command(s) needed to run the application.
