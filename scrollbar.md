# Quiet Paper — Intelligent Heading-Aware Scrollbar
## Production Implementation Specification for AI Coding Agents

You are working on **Quiet Paper**, a Flutter-based Bear-style notes application.

Implement a new **intelligent scrollbar system** for long-form note reading and editing.

The application currently has **no visible scrollbar** in the note editor or preview mode.

The desired result is the interaction demonstrated in the reference concept:

- The scrollbar behaves like a normal scrollbar.
- There is **NO separate Table of Contents panel, drawer, popover, modal, or side panel**.
- When the user interacts with the scrollbar, nearby Markdown headings appear alongside the scrollbar.
- The heading labels are visually integrated using a **soft gradient**, not opaque cards or pill-shaped backgrounds.
- Only headings near the current scroll position are displayed.
- As the user scrolls through a long note, the displayed heading window automatically advances to reveal the next headings.
- When the user stops touching/hovering the scrollbar, the heading labels fade away.
- The underlying scrollbar remains simple and minimal.
- The feature must work in both **Editor mode and Preview mode**.
- The implementation must be production-ready, performant, accessible, responsive, and maintainable.

Do not blindly implement this specification before understanding the existing codebase.

---

# 1. FIRST: ANALYZE THE EXISTING CODEBASE

Before modifying code:

1. Identify the current architecture for:
   - Note editor
   - Markdown editing
   - Preview/rendering
   - Note scrolling
   - Markdown parsing
   - Editor/preview mode switching
   - Heading rendering
   - Layout
   - Three-pane layout
   - Responsive layouts
   - State management

2. Identify exactly which widgets/controllers currently own scrolling.

3. Determine whether Editor and Preview currently use:
   - The same `ScrollController`
   - Different `ScrollController`s
   - A third-party editor controller
   - Scrollable widgets that expose positions
   - Custom document/layout abstractions

4. Identify the current Markdown parser/renderer.

5. Identify how canonical Markdown is currently represented.

Important existing architectural constraint:

**The canonical note body is Markdown. There is currently no JSON document representation.**

Do NOT introduce a JSON document model merely to implement this feature.

6. Search the entire project for:
   - Existing `ScrollController`s
   - `Scrollbar`
   - `RawScrollbar`
   - scroll physics
   - editor scrolling
   - preview scrolling
   - heading parsing
   - Markdown AST/document parsing
   - anchor/link systems
   - section navigation
   - responsive editor layout

7. Identify all relevant files before implementation.

8. Determine whether a shared scrolling abstraction already exists. Reuse it where appropriate.

9. Determine the minimum number of files/classes that should be changed.

10. Do not replace the existing editor or Markdown renderer unless there is no viable way to integrate the feature.

Before implementation, produce a concise internal implementation plan based on the actual repository architecture.

Do not make assumptions such as "the app uses X editor package" until verified in the codebase.

---

# 2. CORE UX REQUIREMENT

The scrollbar must feel like a natural part of Quiet Paper.

It should NOT look like a traditional large desktop application scrollbar.

Desired behavior:

### Idle

The note is being read/edited.

The scrollbar is either invisible or extremely subtle depending on the platform and existing app conventions.

No heading labels are visible.

Example:

```text
                                    ▌
                                    │
                                    │
                                    █
                                    │
                                    │
```

### User scrolls

The scrollbar becomes visible.

It should be:

- thin
- unobtrusive
- visually aligned with the content pane
- overlayed rather than consuming significant content width where practical

### User hovers/touches/interacts with scrollbar

The scrollbar becomes the navigation surface.

Nearby headings appear beside it.

Example:

```text
                         Introduction
                              ●
                         Architecture
                         Sync Engine
                           Upload
                           Download
                         Conflict Handling
                              █
                         Search
```

There is NO panel.

There is NO rectangular TOC container.

There are NO individual opaque heading cards.

The headings should appear as lightweight text next to the scrollbar.

---

# 3. GRADIENT-BASED VISUAL DESIGN

Use the visual concept from the approved demo.

Do NOT put an opaque background behind every heading.

Instead create a subtle **gradient reading/navigation zone** behind or around the heading labels.

Conceptually:

```text
              white
                ↓
        ─────────────────
        soft gradient
        ─────────────────
            Introduction
          Architecture
            Sync Engine
              Upload
                █
            Search
        ─────────────────
        soft gradient
                ↓
              white
```

The gradient should:

- be subtle
- preserve the clean Bear-like appearance
- avoid looking like a floating panel
- fade naturally into the editor/preview background
- prevent underlying document text from making the heading labels difficult to read
- not create a hard rectangular boundary

The gradient must NOT create the visual impression of a drawer.

Prefer one continuous gradient layer rather than individual backgrounds behind each heading.

---

# 4. HEADING LABEL STYLE

Heading labels should be derived from actual Markdown headings.

Support at minimum:

- H1
- H2
- H3
- H4
- H5
- H6

Use the actual heading hierarchy that the current Markdown parser recognizes.

Recommended visual hierarchy:

### Major headings

More prominent.

### Subheadings

Slightly smaller and/or indented.

For example:

```text
Architecture Overview
  Sync Engine
    Upload
    Download
  Conflict Resolution
Search
  FTS5
  Fuzzy Ranking
```

Do not make the hierarchy excessively strong.

The scrollbar navigation should remain visually lightweight.

---

# 5. DYNAMIC HEADING WINDOW

This is one of the most important requirements.

Do NOT render every heading in a long note simultaneously.

A note could contain:

- 5 headings
- 20 headings
- 50 headings
- 100+ headings

The scrollbar must remain useful and visually uncluttered.

Use a **moving heading window** around the current scroll position.

For example, if the note has many headings:

```text
Current position:

      Architecture
        Sync Engine
          Upload
          Download
      Conflict Handling
      Search
```

After scrolling further:

```text
      Conflict Handling
      Search
        FTS5
        Fuzzy Ranking
      OCR
        Indexing
      Attachments
```

The displayed heading set should move continuously with the document position.

Do NOT require the user to open a separate TOC.

---

# 6. HEADING WINDOW ALGORITHM

Implement this robustly.

The system should determine:

1. Current scroll position.
2. Current document section.
3. Heading nearest the viewport position.
4. Nearby headings before and after the current heading.
5. Which headings can fit visually in the available scrollbar navigation area.

Do not hardcode a fixed number of headings without considering available vertical space.

Prefer an algorithm based on actual available height.

For example:

- Begin with the current heading.
- Add preceding headings.
- Add following headings.
- Continue until the label region reaches a sensible maximum density.
- Give priority to headings closest to the current location.
- Preserve parent/child hierarchy where reasonable.

On extremely heading-dense documents:

- show fewer labels
- prioritize the current heading and nearest sections
- dynamically replace headings as the user scrolls

On notes with very few headings:

- show all relevant headings.

---

# 7. HEADING POSITIONING

Heading labels need to correspond approximately to their actual location in the note.

The vertical position of a heading label should represent where the heading occurs in the scrollable document.

However, do NOT simply assume that:

```text
characterOffset == visualPixelOffset
```

That will break with:

- wrapped paragraphs
- images
- code blocks
- tables
- lists
- large headings
- different font sizes
- dynamic layout
- Markdown formatting
- mobile layouts

Use the actual rendered/layout information available from the current editor/preview architecture.

---

# 8. EDITOR MODE

This needs special attention.

Quiet Paper stores the canonical note body as Markdown.

The editor must continue using that canonical Markdown architecture.

Do NOT convert the note permanently into JSON.

Do NOT introduce a duplicate document storage format.

The scrollbar navigation should derive heading information from the existing Markdown/document representation.

The editor implementation must support:

- scrolling
- scrollbar dragging
- heading navigation
- current-section detection
- dynamic heading display
- cursor/editing interactions

If the editor has a document model internally, use it only as a runtime representation if that is already how the editor works.

The persisted source of truth remains Markdown.

---

# 9. PREVIEW MODE

Preview mode must use the same interaction concept.

Requirements:

- Same scrollbar visual language
- Same heading hierarchy
- Same dynamic heading-window logic
- Same gradient treatment
- Same interaction behavior
- Same fade timing
- Same accessibility principles

The implementation should maximize shared code between Editor and Preview.

Do not duplicate the entire feature.

Prefer architecture such as:

```text
IntelligentScrollbar
        |
        +-- HeadingNavigationModel
        |
        +-- ScrollState
        |
        +-- Editor integration
        |
        +-- Preview integration
```

Adapt the implementation to the actual project architecture rather than blindly following this exact class hierarchy.

---

# 10. SCROLLBAR INTERACTION

The scrollbar itself should remain the primary navigation control.

### Pointer / desktop

When the pointer enters the scrollbar hit area:

- scrollbar becomes active
- heading labels appear
- gradient becomes visible
- heading labels become interactive

When the pointer leaves:

- heading labels fade out
- gradient fades out
- scrollbar eventually returns to idle

### Dragging

When the user drags the scrollbar thumb:

- heading labels remain visible
- heading positions update continuously
- the current section remains visually emphasized
- the heading window moves as necessary
- releasing the scrollbar triggers the normal fade behavior

### Clicking the scrollbar track

Support standard scrollbar behavior where reasonable.

Clicking/tapping the track should move the scroll position rather than doing something unexpected.

### Touch

The scrollbar must work on touch devices.

Because the scrollbar thumb is intentionally thin, provide an invisible larger hit target.

The visible scrollbar can remain thin.

Touch interaction should:

- reveal the scrollbar
- reveal the heading labels
- permit dragging
- allow heading labels to be tapped
- hide labels when touch interaction ends

Do not require extremely precise finger placement.

---

# 11. HEADING TAP / CLICK

When the user clicks/taps a visible heading:

- scroll directly to that heading
- use smooth scrolling when appropriate
- keep the appropriate editor/preview scroll behavior
- update current-heading state
- keep the heading navigation active briefly
- allow the UI to fade afterward

The heading should behave like a navigation anchor.

Do not open another view.

Do not open a TOC.

Do not change notes.

Do not modify Markdown.

---

# 12. CURRENT HEADING

The currently visible document section should be visually distinguished.

Recommended:

```text
Architecture
  Sync Engine
    Upload
    Download
  Conflict Handling
```

Where the current heading is subtly emphasized.

Use typography/color/weight rather than a filled card.

For example:

```text
Conflict Handling
```

could become slightly darker/bolder or use the application's accent color.

Do not use a large badge.

Do not introduce distracting UI.

---

# 13. FADE BEHAVIOR

The interaction should feel polished.

Recommended lifecycle:

### Scroll interaction

Scrollbar:

```text
visible → scrolling → briefly visible → fade
```

### Hovering scrollbar

While hovered:

```text
scrollbar visible
headings visible
gradient visible
```

When leaving:

```text
headings fade out
gradient fades out
scrollbar eventually fades
```

### Dragging

While dragging:

```text
scrollbar visible
headings visible
gradient visible
heading navigation updates live
```

After release:

```text
hold briefly
then fade
```

Avoid abrupt disappearing.

Use short, subtle animations.

Do not use excessive animation.

---

# 14. DO NOT SHOW HEADINGS WHEN NOT NEEDED

For a note with no headings:

There should be no empty TOC/navigation UI.

Only the normal scrollbar behavior should exist.

For one or two headings:

Show them normally when the scrollbar is interacted with.

For many headings:

Use the dynamic heading-window system.

---

# 15. LONG DOCUMENT PERFORMANCE

This feature must be designed for very long notes.

Assume notes may contain:

- thousands of words
- dozens or hundreds of headings
- large code blocks
- images
- tables
- nested lists
- embedded documents

Do NOT perform expensive work on every scroll event.

Avoid:

- reparsing the entire Markdown document on every scroll tick
- rebuilding every heading widget on every scroll event
- O(N) work over all headings on every frame when N can become large
- synchronous expensive layout calculations on the UI isolate
- repeated Markdown parsing during drag

Precompute/cache a lightweight heading navigation model.

For example:

```text
HeadingNavigationEntry
    title
    level
    source position / anchor
    runtime layout position
    parent information if needed
```

Update the model only when the note content changes or when layout information changes.

Use efficient lookup for the current heading.

Binary search or indexed lookup is preferable when appropriate.

Do not prematurely overengineer this if the actual project architecture makes a simpler approach more appropriate, but the implementation must remain smooth for large documents.

---

# 16. LIVE EDITING

The editor can change while the user is interacting with it.

Examples:

- adding a heading
- deleting a heading
- changing heading level
- renaming a heading
- inserting content above a heading
- removing a section

The heading navigation must update correctly.

Requirements:

- Adding a heading updates navigation.
- Removing a heading removes it.
- Renaming updates the label.
- Changing heading level updates hierarchy styling.
- Moving content updates heading positions.
- The current heading remains correct after edits.

Do not require reopening the note to update navigation.

Use debouncing or incremental updates where appropriate.

---

# 17. DUPLICATE HEADINGS

Markdown notes can contain:

```markdown
## Introduction

...

## Introduction
```

Do not assume heading titles are unique.

Navigation must distinguish them internally.

Use stable runtime/source identity rather than title strings as the unique identifier.

Clicking the second "Introduction" must go to the second section.

---

# 18. SPECIAL MARKDOWN CASES

Test heading extraction against:

```markdown
# Heading

## Heading

### Heading

#### Heading
```

Also test:

- headings containing emoji
- headings containing punctuation
- headings containing Markdown emphasis
- headings containing links
- headings containing inline code
- very long headings
- Unicode text
- duplicate headings
- empty/invalid heading forms if supported by the current parser

Heading labels should use the appropriate visible/plain text representation rather than displaying raw Markdown syntax unnecessarily.

---

# 19. RENDERING POSITION ROBUSTNESS

Pay particular attention to documents containing:

```text
large images
code blocks
tables
nested lists
block quotes
different heading sizes
wide content
very long paragraphs
embedded attachments
```

The heading navigation must continue to point to the correct visual location.

Do not rely on simplistic percentage-of-character-count calculations.

Where the existing renderer provides layout/anchor information, reuse it.

---

# 20. THREE-PANE LAYOUT

Quiet Paper uses a three-pane-style desktop layout.

The scrollbar belongs ONLY to the active note content/editor/preview pane.

Do not place the intelligent heading scrollbar:

- over the sidebar
- over the note list
- across the entire application
- between panes

It should visually belong to the note content area.

The scrollbar must not accidentally become associated with the sidebar or note list.

---

# 21. RESPONSIVE BEHAVIOR

The feature must work across:

- desktop
- laptop
- tablet
- phone

### Desktop

Show the full intelligent scrollbar interaction.

### Tablet

Keep the scrollbar narrow and touch-friendly through an enlarged invisible hit target.

### Phone

Be conservative with heading labels because horizontal space is limited.

Possible behavior:

- smaller labels
- reduced number of visible headings
- slightly wider temporary navigation area
- stronger gradient fade
- preserve the actual content width

Do not allow headings to permanently cover readable note content.

The feature should adapt dynamically rather than using desktop-only fixed dimensions.

---

# 22. ACCESSIBILITY

This is production software.

The feature must support:

- keyboard navigation where relevant
- semantic accessibility labels
- screen-reader-friendly heading navigation
- sufficient contrast
- touch target requirements
- reduced-motion settings where the platform exposes them

Do not make the visual scrollbar the only way to navigate headings.

The underlying document must remain accessible normally.

When a heading label is exposed as an interactive control, it should have an accessibility label such as:

```text
Jump to Architecture
```

or an equivalent semantically appropriate label.

---

# 23. KEYBOARD / DESKTOP UX

Do not break normal keyboard scrolling.

Existing functionality must continue to work:

- mouse wheel
- trackpad
- Page Up
- Page Down
- Home
- End
- editor cursor navigation
- keyboard selection
- native scrolling behavior

The intelligent scrollbar is additive.

It must not hijack normal document input.

---

# 24. VISUAL DESIGN REQUIREMENTS

The visual direction is:

**Minimal, refined, Bear-like, quiet, unobtrusive, premium.**

Avoid:

- oversized scrollbar
- bright colors
- chunky cards
- visible TOC panel
- floating drawer
- modal navigation
- excessive borders
- excessive shadows
- permanent labels
- heavy gradients
- animation that draws attention away from writing

Prefer:

- very thin scrollbar
- soft neutral thumb
- subtle accent for current heading
- typography-driven hierarchy
- translucent/soft gradient
- short fade animations
- no unnecessary decoration

The heading navigation should look like it naturally belongs to the document.

---

# 25. THE VISUAL TARGET

The final result should conceptually behave like this:

### Idle

```text
Note content


Long paragraph...


                              ▌
                              │
                              │
                              │
```

### Scrollbar hovered

```text
Note content


Long paragraph...

                    Introduction
                  Architecture
                    Sync Engine
                      Upload
                      Download
                    Conflict Handling
                              █
                    Search
```

### Further down the note

```text
Note content


Search section...


                      Conflict Handling
                      Search
                        FTS5
                        Fuzzy Ranking
                      OCR
                        Indexing
                      Attachments
                              █
                      Security
```

### Pointer leaves

```text
Note content


Search section...


                              ▌
```

The labels and gradient should disappear.

There should NEVER be a separate TOC window.

---

# 26. SHARED COMPONENT ARCHITECTURE

Create a reusable abstraction rather than implementing separate independent scrollbar systems for editor and preview.

A possible architecture is:

```text
IntelligentScrollbar
    ├── ScrollbarVisual
    ├── HeadingNavigationOverlay
    ├── HeadingNavigationModel
    ├── ScrollInteractionController
    └── HeadingPositionResolver
```

But adapt naming and structure to Quiet Paper's actual conventions.

The implementation should:

- minimize coupling
- avoid unnecessary global state
- avoid embedding note-specific business logic into UI widgets
- keep Markdown parsing independent from scrollbar rendering
- make testing possible without rendering the entire app

---

# 27. STATE MANAGEMENT

Do not put this state into a global provider/state store unless the existing application architecture genuinely requires it.

Prefer localized state for:

- scrollbar visibility
- hover state
- dragging state
- active heading
- temporary fade timers

The heading model itself may be derived/cached from the note document.

Follow the project's existing state-management conventions.

Do not introduce an entirely new state-management pattern for this feature.

---

# 28. NO UNNECESSARY DEPENDENCIES

Before adding a package:

1. Inspect existing dependencies.
2. Determine whether Flutter's built-in scrolling/gesture/layout capabilities are sufficient.
3. Prefer existing dependencies already used by Quiet Paper.

Only add a dependency when:

- it materially improves reliability
- it is actively maintained
- it is compatible with the project's Flutter/Dart versions
- there is no reasonable built-in solution

Do not introduce a large third-party scrollbar library for a feature that can be implemented cleanly in the existing stack.

---

# 29. PLATFORM-SPECIFIC CHECKS

Verify behavior on the platforms Quiet Paper supports.

Pay attention to:

- Flutter desktop pointer hover
- Android touch
- iOS touch
- macOS trackpads
- web if supported
- high DPI displays

Do not assume desktop hover exists on touch devices.

---

# 30. TESTING REQUIREMENTS

Add automated tests appropriate to the existing repository.

At minimum cover:

### Heading extraction

- H1-H6
- nested hierarchy
- duplicate headings
- Unicode
- long heading
- special characters

### Dynamic window

- few headings
- many headings
- 50+ headings
- 100+ headings
- current heading changes while scrolling
- correct headings enter/leave the visible window

### Scroll mapping

- heading navigation jumps to correct section
- first heading
- middle heading
- final heading
- duplicate heading
- headings separated by large images/code blocks

### Editing

- add heading
- remove heading
- rename heading
- change heading level
- insert content above heading

### Interaction

- hover
- pointer exit
- drag
- touch
- click/tap heading
- fade behavior
- repeated interaction

### Regression

Ensure existing:

- editing
- preview
- scrolling
- note switching
- note loading
- three-pane layout
- search
- selection
- keyboard shortcuts

continue to work.

---

# 31. PERFORMANCE TESTING

Test with synthetic long notes such as:

```text
10 headings
50 headings
100 headings
250 headings
500 headings
```

and long content between headings.

Confirm:

- no visible frame drops while dragging
- no repeated full Markdown parsing during scroll
- no growing memory usage from navigation widgets
- no excessive widget creation
- no timers accumulating
- no scroll listener leaks

Use profiling if necessary.

---

# 32. ERROR HANDLING

The scrollbar/navigation feature must fail gracefully.

If heading parsing or layout mapping temporarily fails:

- normal scrolling must still work
- the scrollbar must still work
- heading labels may temporarily disappear
- the editor must remain usable

Never allow an error in heading navigation to break note editing.

---

# 33. LIFECYCLE / RESOURCE SAFETY

Ensure:

- `ScrollController`s are disposed appropriately
- listeners are removed
- animation controllers are disposed
- timers are cancelled
- pointer/gesture state resets correctly
- note switching cannot leave stale references
- changing editor/preview mode cannot leak controllers
- navigation state cannot reference a disposed document

Pay particular attention to switching rapidly between notes.

---

# 34. NOTE SWITCHING

When the user switches from one note to another:

- destroy/rebind navigation state as appropriate
- clear stale heading entries
- recalculate scroll state
- do not show headings from the previous note
- reset the correct active section

Do not retain a heading model from an old note.

---

# 35. SCROLL CONTROLLER OWNERSHIP

This is critical.

Determine exactly which widget owns the scroll controller.

Do not create competing scroll controllers that can drift apart.

There must be one authoritative scroll position for each visible document surface.

The intelligent scrollbar must control that same scroll position.

In other words:

```text
User
  ↓
Intelligent Scrollbar
  ↓
Authoritative Scroll Position
  ↓
Editor / Preview
```

NOT:

```text
Scrollbar → controller A
Editor     → controller B
```

unless the existing editor architecture explicitly requires that and there is a robust synchronization mechanism.

---

# 36. EDITOR + PREVIEW MODE TRANSITION

If Quiet Paper allows switching between Editor and Preview without leaving the note:

Do not cause unexpected jumps.

Where technically appropriate:

- preserve approximate scroll position
- preserve current section
- rebuild heading layout for the active renderer
- rebind the intelligent scrollbar to the active scrollable

Avoid a visual flash.

---

# 37. PRODUCTION LOGGING

Do not add noisy debug logs to production behavior.

If diagnostics are necessary, use the application's existing logging conventions and keep them behind the appropriate debug/development mechanism.

Do not continuously log:

```text
scroll position
heading index
pointer position
```

during scrolling.

---

# 38. IMPLEMENTATION QUALITY

Follow the existing project's:

- architecture
- naming conventions
- formatting
- linting
- null-safety
- state-management patterns
- dependency injection patterns
- testing style

Do not create giant monolithic widgets.

Do not introduce magic numbers everywhere.

Centralize visual constants where appropriate.

Make timing/density values configurable constants where useful.

---

# 39. IMPLEMENTATION PHASES

Implement in this order:

### Phase 1 — Architecture integration

Identify actual editor/preview scroll owners.

### Phase 2 — Heading navigation model

Build heading extraction and navigation metadata.

### Phase 3 — Heading-to-layout mapping

Connect headings to their actual visual positions.

### Phase 4 — Base scrollbar

Add the minimal scrollbar.

### Phase 5 — Interaction

Add hover, touch, drag, click/tap.

### Phase 6 — Heading overlay

Add gradient and dynamic heading labels.

### Phase 7 — Editor integration

Integrate correctly with editing.

### Phase 8 — Preview integration

Integrate correctly with preview.

### Phase 9 — Responsive/accessibility polish

Desktop, tablet, mobile, keyboard, accessibility.

### Phase 10 — Testing/performance

Run the full relevant test suite and performance checks.

---

# 40. IMPORTANT: DO NOT OVERWRITE THE EXISTING UX

Do not use this feature as an excuse to redesign the editor.

Do not change:

- typography
- editor layout
- note list
- toolbar
- navigation
- Markdown behavior
- note storage
- sync
- search

unless a minimal change is genuinely required for this feature.

The task is specifically to add the intelligent scrollbar.

---

# 41. DEFINITION OF DONE

The feature is complete only when ALL of the following are true:

1. Editor has a working scrollbar.
2. Preview has a working scrollbar.
3. Scrollbar is visually minimal.
4. Scrollbar does not permanently waste content width.
5. No separate TOC panel exists.
6. Headings appear next to the scrollbar during interaction.
7. Heading labels use the soft gradient visual treatment.
8. Heading labels disappear after scrollbar interaction ends.
9. Dynamic heading window works for long notes.
10. Hundreds of headings do not visually overwhelm the UI.
11. Heading labels move/repopulate as the user scrolls.
12. Current section is subtly highlighted.
13. Clicking/tapping a heading jumps to it.
14. Duplicate heading names work correctly.
15. Long paragraphs do not break mapping.
16. Images do not break mapping.
17. Code blocks do not break mapping.
18. Tables/lists do not break mapping.
19. Editor and Preview both work.
20. Switching notes does not retain stale headings.
21. Switching editor/preview does not break the scrollbar.
22. Touch interaction works.
23. Desktop hover works.
24. Dragging works.
25. Keyboard scrolling continues to work.
26. Accessibility is addressed.
27. No expensive full-document work occurs per scroll frame.
28. Controllers/listeners/timers are disposed correctly.
29. Automated tests cover the feature.
30. Existing Quiet Paper functionality continues to pass.

---

# 42. FINAL AGENT BEHAVIOR

Do not make broad architectural changes without justification.

Do not guess at the existing editor implementation.

Do not replace working infrastructure unnecessarily.

Inspect first.

Then implement the smallest robust architecture that satisfies this specification.

After implementation:

1. Run formatting.
2. Run static analysis.
3. Run relevant unit/widget tests.
4. Run the application where possible.
5. Test Editor.
6. Test Preview.
7. Test a short note.
8. Test a very long note.
9. Test a note with many headings.
10. Test a heading-heavy note with images/code blocks/tables.
11. Test desktop pointer interaction.
12. Test touch interaction.
13. Test switching notes.
14. Test switching editor/preview.
15. Fix all regressions found.

Finally, provide an implementation summary containing:

- files changed
- architectural approach
- how heading positions are calculated
- how the dynamic heading window works
- how Editor and Preview are integrated
- performance considerations
- accessibility considerations
- tests added
- any limitations or edge cases discovered

Do not claim the feature is complete unless the implementation and tests actually support the claims.