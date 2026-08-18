# Quiet Paper — Editor Redesign

You are working on **Quiet Paper**, a Flutter notes app inspired by the aesthetic and writing experience of Bear Notes.

The existing app is functional, but **the editor currently looks ugly and generic**.

Your job in this task is to redesign the editor so it becomes the visual centerpiece of the application.

Do not add major new product features.

Do not work on sync, AI, accounts, collaboration, or other unrelated functionality.

Focus almost entirely on:

> **Making the editor beautiful, calm, spacious, and genuinely pleasant to write in.**

The desired feeling is:

> Open a note → everything gets quiet → start writing.

---

# 1. Critical Instruction

Do NOT interpret this task as:

> "Make the existing TextFields prettier."

Instead:

> **Redesign the entire editor composition and visual hierarchy.**

The current implementation may have an app bar, text fields, buttons, borders, toolbar, etc.

You are free to restructure the editor UI substantially while preserving the underlying note model, persistence, autosave, navigation, and existing functionality.

The result should no longer feel like a generic Flutter/Material form.

---

# 2. Visual Target

The editor should feel approximately like a beautiful digital writing sheet.

Conceptually:

```text
┌──────────────────────────────────────────────┐
│                                              │
│  ←                                      ⋯   │
│                                              │
│                                              │
│  A quiet place to think                     │
│                                              │
│  Sometimes the best notes app is the one    │
│  that gets out of your way.                 │
│                                              │
│  The writing should dominate the screen.    │
│                                              │
│  #ideas   #writing                           │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

The actual implementation can differ.

The important qualities are:

* lots of breathing room
* beautiful typography
* almost no visual chrome
* no heavy cards
* no ugly input boxes
* no unnecessary borders
* no excessive icons
* no giant toolbar
* no generic Material appearance

---

# 3. First Step: Inspect the Existing Editor

Before changing anything:

1. Find the editor screen.
2. Find its state management.
3. Find title editing.
4. Find body editing.
5. Find Markdown rendering.
6. Find autosave.
7. Find tag editing.
8. Find navigation/back behavior.
9. Find all editor-specific widgets.
10. Run the app and inspect the editor on an actual Android emulator/device.

Identify exactly why the current editor feels ugly.

Look specifically for:

* default TextField styling
* excessive borders
* cramped spacing
* poor typography
* large app bars
* too many controls
* inconsistent colors
* excessive rounded rectangles
* weak hierarchy
* poor keyboard handling
* title/body not feeling like one document
* toolbar taking too much space
* Markdown syntax visually dominating the content

Do not blindly rewrite the data layer.

---

# 4. Design Direction

Use the existing Quiet Paper design system.

The editor should use these visual characteristics.

## Light

```text
Background       #F7F6F2
Surface          #FBFAF7

Primary text     #292824
Secondary text   #77736C
Tertiary text    #A6A29B

Divider          #E8E5DF

Accent           #D65F55
Accent soft      #F1DAD6
```

## Dark

```text
Background       #1D1C1A
Surface          #242320

Primary text     #E8E5DE
Secondary text   #AAA69E
Tertiary text    #77736C

Divider          #37342F

Accent           #E4776D
Accent soft      #3D2926
```

Do not use pure black or pure white as the primary editor background/text.

---

# 5. Editor Should Not Look Like a Form

This is one of the most important requirements.

Avoid:

```text
┌──────────────────────────────┐
│ Title                        │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Body                         │
│                              │
└──────────────────────────────┘
```

The user should instead perceive:

```text
Title

Body
```

as one continuous document.

Text fields should have:

* no border
* no filled container
* no underline
* no visible focus decoration
* no Material outline

The cursor can use the accent color.

---

# 6. Overall Composition

Build the editor around a document surface.

Suggested hierarchy:

```text
Editor
│
├── Top controls
│
└── Scrollable document
    │
    ├── Title
    ├── Body
    └── Tags
```

The document should be the dominant element.

Do not put the entire editor inside a Card.

Do not create a large rounded container around the note.

---

# 7. Top Controls

The top controls should be minimal.

Suggested:

```text
←                                      ⋯
```

Use approximately:

```text
height: 52–60dp
horizontal padding: 16–20dp
```

The back button should be:

* 48dp touch target
* visually quiet
* secondary text color

The overflow icon should be:

* 48dp touch target
* visually quiet
* secondary text color

Do not use a huge Material AppBar.

Prefer a transparent background matching the editor.

---

# 8. Optional Note Metadata

If useful, you may place very subtle metadata below the title or near the tags:

```text
Edited just now
```

But this is optional.

If metadata makes the editor busier, remove it.

The writing takes priority.

---

# 9. Document Width

Use responsive content width.

Phone:

```text
horizontal padding: 24dp
```

Large phone:

```text
horizontal padding: 28–32dp
```

Tablet:

```text
max content width: 720–760dp
```

Center the document on larger screens.

Do not let lines become excessively long.

---

# 10. Title Design

The title should be beautiful.

Use approximately:

```text
30sp
font weight: 700
line height: 1.2
```

Color:

```text
#292824
```

or dark-theme equivalent.

The title field should have:

```text
background: transparent
border: none
padding: 0
```

It should visually resemble a heading, not a TextField.

Example:

```text
A quiet place to think
```

There should be generous space below it.

Suggested:

```text
title → body = 20–28dp
```

---

# 11. Body Design

Body text is the most important visual element.

Use:

```text
font size: 18sp
line height: 1.55–1.65
font weight: 400
```

Use comfortable paragraph spacing.

Body text should not be too dark in light mode.

Use:

```text
#292824
```

with a slightly softer visual feel.

In dark mode:

```text
#E8E5DE
```

---

# 12. Editor Padding

The editor should breathe.

Use:

```text
top content padding: 24–40dp
bottom content padding: 120dp+
```

The large bottom padding is important because the keyboard should never make the final line feel trapped against the bottom edge.

The exact value should be responsive to keyboard/toolbars.

---

# 13. Cursor

The cursor should use the accent color.

Light:

```text
#D65F55
```

Dark:

```text
#E4776D
```

Do not make the cursor visually thick or distracting.

---

# 14. Text Selection

Keep native Android text selection behavior wherever possible.

Do not replace native selection handles with custom graphics unless absolutely necessary.

Use a warm, subtle selection color if Flutter allows it cleanly.

Do not compromise text editing reliability for visual customization.

---

# 15. Focus States

Do not show:

```text
blue outline
border
glowing container
Material focus ring
```

when the body receives focus.

The editor should look almost identical focused/unfocused.

The cursor is enough.

---

# 16. Markdown

Markdown should feel integrated into the document.

If the existing editor is a Markdown source editor, improve its typography rather than attempting a risky full WYSIWYG rewrite.

Raw Markdown should not make the editor ugly.

For example:

```text
# Heading
```

should have enough visual hierarchy to be pleasant.

If feasible, style Markdown syntax subtly.

Do not make syntax colors loud.

Avoid colorful syntax highlighting throughout ordinary prose.

---

# 17. Headings

Use approximately:

```text
H1: 26sp / bold
H2: 22sp / bold
H3: 19sp / semibold
```

Spacing:

```text
before heading: 24–32dp
after heading: 12–16dp
```

Headings should feel like part of the same document.

---

# 18. Paragraphs

Do not create visible boxes around paragraphs.

Use whitespace.

Example:

```text
This is the first paragraph. It should feel
comfortable and effortless to read.

This is the second paragraph. The separation
comes from whitespace rather than borders.
```

---

# 19. Lists

Lists should have proper indentation.

Example:

```text
Things I want to build

• Beautiful editor
• Offline-first database
• Excellent search
```

Use subtle bullets.

Avoid oversized bullets.

Nested lists should indent naturally.

---

# 20. Blockquotes

Style blockquotes subtly.

Example:

```text
│ The best notes app gets out of your way.
```

Use:

* muted text
* thin accent line
* normal body typography

No giant quotation marks.

---

# 21. Code

Code should have a quiet contrasting surface.

Example:

```text
┌───────────────────────────────┐
│ const note = await getNote(); │
└───────────────────────────────┘
```

Use:

* monospace
* subtle warm surface
* 8–12dp radius
* comfortable padding

Don't make code blocks visually louder than headings.

---

# 22. Links

Links should use the accent color.

Avoid excessive underlining.

Links should look interactive but remain part of the document.

---

# 23. Tags

Tags should be lightweight.

Preferred:

```text
#ideas   #flutter   #writing
```

Avoid giant Material Chips.

If pill backgrounds are used, keep them subtle:

```text
background: accentSoft or tagBackground
radius: 8dp
```

Tags should not dominate the bottom of the note.

---

# 24. Formatting Toolbar

If there is a toolbar, redesign it.

The toolbar should not look like:

```text
[B] [I] [U] [A] [H1] [H2] [H3] [LINK] [IMAGE] [CODE] ...
```

That is too much visual noise.

Instead, use a compact toolbar with only the most useful actions:

```text
B   I   S   •   H   "   `   🔗
```

Use 20–24dp icons.

Toolbar surface:

* same background or subtly elevated surface
* no thick border
* minimal shadow
* no bright accent background

If the toolbar is shown above the keyboard, ensure it does not interfere with text input.

---

# 25. Consider a Floating Formatting Bar

If appropriate, implement a compact formatting bar above the keyboard.

Conceptually:

```text
┌────────────────────────────────────────┐
│  B   I   S   •   1.   "   `   🔗      │
└────────────────────────────────────────┘
┌────────────────────────────────────────┐
│ Android keyboard                       │
└────────────────────────────────────────┘
```

The formatting bar should be visually quiet.

Do not implement this if it destabilizes the editor.

Reliability comes first.

---

# 26. Keyboard Behavior

This must be tested carefully.

When the keyboard opens:

* editor resizes correctly
* active cursor remains visible
* final lines remain accessible
* toolbar doesn't cover content
* scrolling remains smooth

When keyboard closes:

* editor returns smoothly
* no layout jump
* scroll position remains sensible

The user should never feel like the keyboard is fighting the app.

---

# 27. Scroll Behavior

The editor should scroll like a document.

Requirements:

* smooth vertical scrolling
* no nested-scroll glitches
* no sudden jumps
* no accidental reset to top
* preserve scroll position during rebuilds
* enough bottom space for keyboard

Do not recreate the ScrollController unnecessarily.

---

# 28. State Management

Do not allow editor state to rebuild excessively.

Especially avoid recreating:

* TextEditingController
* ScrollController
* FocusNode

on every state change.

These should have stable lifecycles.

The editor should remain responsive even in a note containing thousands of words.

---

# 29. Autosave Must Remain Invisible

Keep the existing autosave behavior if it is reliable.

If necessary, improve it.

Use debouncing approximately:

```text
700ms after last edit
```

Do not show a visible "Saving..." state during normal operation.

Do not rebuild the editor when the database updates.

The database is persistence—not the live editor state.

---

# 30. Important Architecture Rule

Separate:

```text
Live editing state
```

from:

```text
Persisted note state
```

Conceptually:

```text
TextEditingController
        ↓
Live editor state
        ↓
debounced save
        ↓
Repository
        ↓
SQLite
```

Do not do:

```text
TextEditingController
        ↓
SQLite
        ↓
provider update
        ↓
rebuild editor
        ↓
replace controller text
```

That will cause cursor and performance problems.

---

# 31. New Note Experience

Creating a note should feel immediate.

When the user taps `+`:

```text
New note
    ↓
Editor
    ↓
Title/body ready
```

Do not display a creation dialog.

Do not ask for a title first.

Do not show a save button.

---

# 32. Empty Note

For a completely empty note:

The editor should feel like a blank page.

Do not display:

```text
Start typing...
```

inside the body unless it is extremely subtle and disappears naturally.

Prefer simply:

```text
Title

|
```

with the cursor ready.

---

# 33. Delete / Pin

Keep these actions in the overflow menu.

Example:

```text
⋯

Pin
Duplicate
Delete
```

Use destructive styling only for Delete.

Do not permanently show these actions around the editor.

---

# 34. Animation

Use minimal motion.

Suggested:

```text
fast: 120ms
normal: 180ms
```

Use subtle:

* fade
* slide
* focus transitions

Avoid:

* bounce
* large scale effects
* exaggerated spring animations

The editor should feel calm.

---

# 35. Responsive Design

On phones:

```text
←                            ⋯

Title

Body
```

On tablets:

```text
┌─────────────┬─────────────────────────────┐
│ Notes       │                             │
│             │      Title                  │
│ Note 1      │                             │
│ Note 2      │      Body                   │
│ Note 3      │                             │
└─────────────┴─────────────────────────────┘
```

If the application already has split-view behavior, make the editor work beautifully within it.

Do not force a split view on narrow devices.

---

# 36. Design Details That Matter

Pay special attention to:

### Typography

The title and body should feel like they belong together.

### Spacing

Whitespace should create hierarchy.

### Color

Use muted neutrals.

### Touch targets

Keep them at least 48dp.

### Icons

Use simple monochrome icons.

### Shadows

Almost none.

### Borders

Almost none.

### Cards

Almost none.

---

# 37. Things to Remove

If the current editor contains unnecessary visual elements, remove them.

Potential candidates:

* large app bar
* title TextField border
* body TextField border
* permanent save button
* oversized formatting toolbar
* excessive metadata
* giant tag chips
* card containers
* strong shadows
* unnecessary dividers
* redundant labels
* decorative icons

The goal is subtraction.

---

# 38. Things to Preserve

Do not break:

* SQLite persistence
* Drift
* Riverpod
* autosave
* note creation
* note deletion
* pinning
* tags
* search
* Markdown source
* Android navigation
* dark mode
* existing tests

If something must change, preserve the behavior even if the UI is rewritten.

---

# 39. Visual QA

After implementing the redesign, run the app and inspect these states:

### State 1 — Empty note

```text
Title
|
```

### State 2 — Short note

```text
Title

One paragraph.
```

### State 3 — Long note

Several screens of text.

### State 4 — Markdown-heavy

Headings, lists, quotes, code.

### State 5 — Tags

Multiple tags.

### State 6 — Keyboard open

Cursor near bottom of long note.

### State 7 — Dark mode

All of the above.

### State 8 — Tablet

Editor centered and readable.

---

# 40. Visual Evaluation

After each major implementation step, ask:

### Does this look like a generic Flutter app?

If yes, keep refining.

### Does the editor feel like a form?

If yes, remove input chrome.

### Is there too much UI?

If yes, remove it.

### Is the writing area visually dominant?

It should be.

### Does the typography feel premium?

If not, tune it.

### Does the screen feel calm?

It should.

---

# 41. Important Constraint: Do Not Copy Bear

Use Bear only as aesthetic inspiration.

Do not copy:

* Bear logo
* Bear assets
* proprietary illustrations
* exact icons
* exact screens
* exact layouts
* source code
* proprietary text

Create an original visual identity based on:

* editorial minimalism
* warm colors
* typography
* whitespace
* writing-first interaction

---

# 42. Performance Requirement

The editor must remain responsive with a note containing at least:

```text
10,000+ words
```

If the current Markdown rendering approach cannot handle this smoothly, prioritize a reliable source editor.

Do not sacrifice typing performance for live rendering.

---

# 43. Final Acceptance Test

The final editor should pass this subjective test:

Open the application.

Create a note.

Look at the screen.

There should be almost nothing competing with:

> **the words.**

Start typing.

The UI should disappear into the background.

Continue typing.

There should be no lag.

Scroll.

The document should feel natural.

Close the note.

Reopen it.

Nothing should have moved unexpectedly.

Switch to dark mode.

It should still feel beautiful.

---

# 44. Engineering Acceptance Criteria

Before declaring completion:

```text
flutter analyze
```

must pass with no new errors.

Run:

```text
flutter test
```

and ensure existing tests pass.

Manually verify:

* note creation
* note editing
* autosave
* reopen
* Markdown
* tags
* delete
* pin
* search
* dark mode
* Android keyboard
* long note
* tablet if available

Do not claim tests passed unless they were actually run.

---

# 45. Final Report

At the end, report:

1. What was wrong with the previous editor.
2. What was redesigned.
3. New editor layout.
4. Typography decisions.
5. Keyboard behavior.
6. Autosave behavior.
7. Markdown handling.
8. Files changed.
9. Dependencies changed.
10. Tests run.
11. `flutter analyze` result.
12. Known limitations.

Do not spend the response describing hypothetical future features.

The goal of this task is simple:

> **Make the editor beautiful enough that writing in Quiet Paper feels good.**

Start by inspecting the current editor implementation and running the application. Then redesign it.
