# Flutter Markdown Editor V2

## Role

You are a senior Flutter/Dart engineer working on an existing Android-first note-taking application.

The application already has a functioning **V1 Markdown-aware editor**.

Your task is to implement the next major editor update consisting of four features:

1. Smart Markdown editing
2. Keyboard shortcuts
3. Selection-aware formatting toolbar
4. Interactive Markdown checkboxes

The existing V1 architecture must be preserved.

This is an Android-first Flutter application, but the implementation should also behave correctly with physical keyboards and tablets.

---

# 1. Existing V1 Architecture

The current editor has already been implemented.

It has:

* A plaintext/Markdown source string as the source of truth.
* A custom Markdown-aware editing controller.
* Markdown parsing/tokenization.
* Styled TextSpans.
* Markdown syntax styling.
* Headings.
* Bold.
* Italic.
* Bold + italic.
* Strikethrough.
* Inline code.
* Code blocks.
* Unordered lists.
* Ordered lists.
* Blockquotes.
* Links.
* Horizontal rules.
* Markdown escaping.
* Markdown preview mode.
* Existing note persistence.
* Normal Flutter cursor/selection behavior.
* Undo/redo.
* Android keyboard/IME support.

The important existing architecture is:

```
Markdown String
      |
      v
Markdown parser/tokenizer
      |
      v
Styled TextSpans
      |
      v
Editable Flutter text widget
```

The Markdown string remains the canonical document representation.

---

# 2. Critical Architectural Rule

Continue treating:

```
Markdown = data
TextSpan styling = presentation
```

Do NOT introduce a rich-text JSON document model.

Do NOT migrate notes to HTML.

Do NOT replace Markdown with a proprietary format.

Do NOT make the editor's visual representation the source of truth.

All four new features must ultimately operate by manipulating the underlying Markdown string.

---

# 3. Scope

Implement exactly these four areas:

## Feature A — Smart Markdown Editing

Improve typing behavior for Markdown.

## Feature B — Keyboard Shortcuts

Support keyboard-based formatting and navigation.

## Feature C — Selection-Aware Formatting Toolbar

Provide formatting controls when the user selects text.

## Feature D — Interactive Markdown Checklists

Support:

```
- [ ] Task
- [x] Completed task
```

with interactive checkbox behavior.

Do NOT implement:

* Markdown syntax hiding
* cursor-dependent syntax hiding
* images
* attachments
* tables
* slash commands
* backlinks
* collaborative editing
* sync
* rich-text JSON
* block-level editor architecture

Those are future features.

---

# 4. Feature A — Smart Markdown Editing

The editor should become aware of common Markdown editing patterns.

The objective is to make Markdown feel natural to write rather than requiring the user to manually repeat syntax.

The behavior must remain predictable and must never fight the user.

---

# 5. Automatic List Continuation

When the user presses Enter at the end of a list item, continue the list.

Example:

```
- First item|
```

Press Enter:

```
- First item
- |
```

The cursor should be placed after the newly inserted list marker.

---

# 6. Empty List Termination

If the current list item contains no content:

```
- |
```

and the user presses Enter, terminate the list.

Result:

```
- First item
|
```

The same behavior should work for ordered lists.

Example:

```
1. First
2. |
```

Press Enter:

```
1. First
|
```

Do NOT leave an endless sequence of list markers.

---

# 7. Ordered List Continuation

Support:

```
1. First
2. Second
```

Pressing Enter after the second item should produce:

```
1. First
2. Second
3. |
```

Preserve the list's existing numbering style where practical.

At minimum support normal decimal numbering.

Do not aggressively renumber the entire document.

Only insert the next number when creating the new list item.

---

# 8. Nested List Continuation

Support basic nested lists.

Example:

```
- Parent
  - Child|
```

Press Enter:

```
- Parent
  - Child
  - |
```

Preserve the existing indentation.

Do not implement complex list normalization in this version.

---

# 9. Blockquote Continuation

If the user writes:

```
> This is a quote|
```

Press Enter:

```
> This is a quote
> |
```

Press Enter again on an empty quote:

```
> This is a quote
|
```

The second Enter should terminate the blockquote.

---

# 10. Code Block Behavior

For fenced code blocks:

````
```
hello|
````

Press Enter:

````
```
hello
|
````

Do not automatically add Markdown list/quote syntax inside code blocks.

If the current cursor is inside a fenced code block, normal Enter behavior should remain active.

---

# 11. Automatic Markdown Pairing

Implement sensible automatic closing syntax.

When the user types an opening delimiter in a context where pairing is appropriate, insert its matching closing delimiter and place the cursor between them.

Examples:

Typing:

```
**
```

should produce:

```
**|
```

where the cursor is between the opening and closing delimiters.

The intended underlying result is:

```
**|**
```

Similarly support where practical:

```
*
_
__
~~
`
[
```

For links, typing `[` may produce:

```
[]()
```

with the cursor positioned appropriately.

However, do not implement aggressive auto-pairing that interferes with normal typing.

---

# 12. Avoid Duplicate Closing Characters

If the user types a closing delimiter that already exists immediately after the cursor, do not insert another one.

Example:

```
**hello|**
```

If the user types `*`, the editor should move over/use the existing delimiter rather than producing:

```
**hello***
```

Avoid common auto-pairing bugs.

---

# 13. Smart Markdown Shortcuts

Recognize common Markdown prefixes while the user is typing.

Examples:

```
# 
## 
### 
- 
* 
+ 
1. 
> 
```

These should automatically receive the appropriate styling through the existing parser.

Do not remove the Markdown prefix.

The underlying text must remain Markdown.

---

# 14. Enter Behavior Must Be Implemented Separately From Parsing

Do not put editing mutations inside `buildTextSpan()` or the Markdown rendering pipeline.

The parser must remain a pure representation layer.

Smart editing should operate in an editing layer such as:

```
MarkdownEditingController
      |
      +-- parser/rendering
      |
      +-- editing commands
      |
      +-- smart Enter behavior
      |
      +-- formatting operations
```

Never mutate the text merely because the parser is rebuilding spans.

---

# 15. Feature B — Keyboard Shortcuts

Support physical keyboards and Android hardware keyboards.

The implementation should use Flutter's keyboard shortcut/action system where appropriate.

Do not rely only on raw key event handling if Flutter's modern shortcut/action APIs provide a better abstraction.

---

# 16. Required Keyboard Shortcuts

Implement:

| Shortcut     | Action        |
| ------------ | ------------- |
| Ctrl+B       | Bold          |
| Ctrl+I       | Italic        |
| Ctrl+Shift+X | Strikethrough |
| Ctrl+K       | Link          |
| Ctrl+`       | Inline code   |

Use platform-appropriate modifier handling where possible.

On Android/Windows/Linux, Ctrl should work.

Do not break normal text editing shortcuts.

---

# 17. Bold Shortcut

When text is selected:

```
important text
```

Press:

```
Ctrl+B
```

Convert it to:

```
**important text**
```

If the selected text is already bold:

```
**important text**
```

Ctrl+B should remove the bold formatting:

```
important text
```

The operation must preserve the rest of the Markdown.

---

# 18. Italic Shortcut

Selection:

```
important text
```

Ctrl+I:

```
*important text*
```

If already italic, pressing Ctrl+I again should remove the Markdown emphasis where practical.

Do not blindly add nested Markdown:

```
***
```

unless nesting is actually intended.

---

# 19. Strikethrough Shortcut

Ctrl+Shift+X should transform:

```
deleted text
```

into:

```
~~deleted text~~
```

If already strikethrough, toggle it off.

---

# 20. Link Shortcut

Ctrl+K should provide a way to create a Markdown link.

For selected text:

```
OpenAI
```

Ctrl+K should produce something like:

```
[OpenAI](URL)
```

with the URL portion ready for entry.

Use an appropriate UI for entering the URL.

For Android, a small dialog/bottom sheet is acceptable.

The interaction should be:

```
Select text
    ↓
Ctrl+K
    ↓
Enter URL
    ↓
Markdown inserted
```

Do not require the user to manually type Markdown syntax.

---

# 21. Inline Code Shortcut

Ctrl+` should toggle:

```
code
```

into:

```
`code`
```

and vice versa where practical.

---

# 22. Keyboard Shortcut Safety

Shortcuts must not interfere with:

* normal typing
* Ctrl+C
* Ctrl+V
* Ctrl+X
* Ctrl+A
* Ctrl+Z
* Ctrl+Shift+Z
* Android IME behavior

Do not override standard editing commands unnecessarily.

---

# 23. Formatting Operations Must Preserve Selection

When applying formatting to a selection:

1. Identify the actual Markdown selection.
2. Modify the Markdown.
3. Update the controller value.
4. Restore a sensible selection.

Example:

Before:

```
This is important text
```

Selection:

```
important text
```

Apply bold:

```
This is **important text**
```

The selection should remain around the logically formatted content where possible.

Do not leave the cursor unexpectedly at the beginning/end of the document.

---

# 24. Formatting With No Selection

If there is no selection and the user presses Ctrl+B, implement sensible behavior.

Preferred behavior:

* Insert a pair of `**`
* Place the cursor between them.

Example:

```
This is |
```

Ctrl+B:

```
This is **|**
```

Same concept for:

* italic
* strikethrough
* inline code

Do not perform an operation that results in an unusable cursor position.

---

# 25. Feature C — Selection-Aware Formatting Toolbar

Implement a formatting toolbar that appears when the user selects text.

The toolbar should be optimized for touch.

Do not permanently occupy large amounts of editor space.

Possible controls:

```
B
I
S
Code
Link
• List
☐ Checklist
```

Only show controls that are appropriate for the current selection/context.

---

# 26. Toolbar Behavior

When the user selects text:

```
important text
```

show the formatting toolbar.

Example:

```
┌─────────────────────────────┐
│ B   I   S   Code   Link     │
└─────────────────────────────┘
```

The toolbar may use:

* Flutter selection toolbar customization
* a contextual overlay
* a custom selection toolbar
* another appropriate Flutter mechanism

Choose the approach that integrates correctly with the existing editor.

Do not create a second independent editor surface.

---

# 27. Toolbar Bold

Tap B:

```
important text
```

becomes:

```
**important text**
```

If the selection is already bold, tapping B should toggle it off.

---

# 28. Toolbar Italic

Tap I:

```
important text
```

becomes:

```
*important text*
```

Toggle off if already italic.

---

# 29. Toolbar Strikethrough

Tap S:

```
important text
```

becomes:

```
~~important text~~
```

Toggle off when appropriate.

---

# 30. Toolbar Code

Tap Code:

```
important text
```

becomes:

```
`important text`
```

Toggle off if already inline code.

---

# 31. Toolbar Link

Tap Link:

Open a small URL-entry interface.

Example:

```
Text: OpenAI
URL: https://openai.com
```

Result:

```
[OpenAI](https://openai.com)
```

The UI should be mobile friendly.

---

# 32. Toolbar Checklist

If the selection is a line or set of lines, provide a checklist option where appropriate.

Example:

```
Buy milk
```

Tap checklist:

```
- [ ] Buy milk
```

If applied to multiple selected lines:

```
Buy milk
Finish project
```

produce:

```
- [ ] Buy milk
- [ ] Finish project
```

Do not duplicate list markers if the lines already contain them.

---

# 33. Toolbar Positioning

The toolbar must not cover the selected text unnecessarily.

It should:

* remain inside the screen
* avoid keyboard overlap
* reposition when necessary
* work in portrait mode
* work in landscape mode
* work on tablets
* respect safe areas

Do not assume a fixed screen size.

---

# 34. Toolbar and Android Selection

Ensure that the custom toolbar does not break:

* selection handles
* text selection
* copy
* cut
* paste
* Select All
* Android's native selection behavior

If Flutter's selection system allows native actions and custom actions to coexist, preserve the standard actions.

---

# 35. Feature D — Interactive Markdown Checklists

Implement Markdown checkboxes using standard Markdown task-list syntax:

```
- [ ] Task
- [x] Completed task
```

Also recognize uppercase:

```
- [X] Completed task
```

The underlying Markdown remains unchanged except when the user explicitly toggles a checkbox.

---

# 36. Visual Checkbox

In the editor, render:

```
- [ ] Task
```

as a visually recognizable checkbox + text.

For example:

```
☐ Task
```

And:

```
- [x] Completed task
```

as:

```
☑ Completed task
```

Do not rely solely on Unicode checkbox characters if that would interfere with the actual editor.

The actual Markdown source must remain:

```
- [ ] Task
```

or:

```
- [x] Task
```

The visual checkbox is presentation only.

---

# 37. Interactive Checkbox Behavior

When the user taps the visual checkbox:

```
- [ ] Task
```

change the underlying Markdown to:

```
- [x] Task
```

When tapped again:

```
- [x] Task
```

change it back to:

```
- [ ] Task
```

This is the only case where clicking the visual representation intentionally modifies the Markdown source.

---

# 38. Checkbox Hit Testing

The checkbox should have a sufficiently large touch target.

Target approximately 40–48 logical pixels where practical.

Do not require the user to tap exactly on a tiny character.

Tapping the task text should continue behaving like normal text selection/editing.

Only the checkbox area should toggle completion.

---

# 39. Checkbox Cursor Behavior

The actual Markdown markers:

```
- [ ]
```

must remain part of the source text.

However, if a visual checkbox is overlaid/replaced in the UI, ensure that:

* cursor offsets remain correct
* text selection remains correct
* typing remains correct
* deletion remains correct
* copy/paste remains correct

Do not create a visual widget that changes the underlying text layout in a way that breaks selection.

---

# 40. Checkbox Implementation Constraint

The existing editor is based on editable text and TextSpans.

Do not completely rewrite it into a block editor just to implement checkboxes.

Prefer the least invasive solution compatible with the current architecture.

If Flutter's standard editable TextSpan mechanism makes true inline interactive widgets impossible, implement a carefully designed gesture/coordinate mapping layer.

For example:

```
tap location
    ↓
determine line
    ↓
determine whether tap is inside checkbox marker region
    ↓
toggle Markdown source
    ↓
preserve selection/cursor
```

Do not compromise normal text editing.

---

# 41. Checkbox Lists

Support:

```
- [ ] First
- [x] Second
- [ ] Third
```

Mixed states should work.

Also support nested checklists where the existing parser already supports nested lists:

```
- [ ] Parent
  - [x] Child
```

Do not build advanced task-management functionality yet.

This is still just Markdown.

---

# 42. Checklist + Smart Enter

Integrate checklists with smart Enter behavior.

Example:

```
- [ ] Task one|
```

Press Enter:

```
- [ ] Task one
- [ ] |
```

Press Enter on an empty task:

```
- [ ] Task one
|
```

This behavior should be consistent with normal list continuation.

---

# 43. Checklist + Formatting

Checklist text should still support inline Markdown:

```
- [ ] Read **important** document
```

The existing parser should style:

* checkbox
* list marker
* bold text

independently.

Do not let checklist detection prevent inline formatting.

---

# 44. Formatting Multiple Lines

The formatting system should support selections spanning multiple lines where reasonable.

For example selecting:

```
First
Second
Third
```

and choosing checklist should produce:

```
- [ ] First
- [ ] Second
- [ ] Third
```

For bold/italic/code, avoid automatically applying inline syntax across arbitrary block boundaries unless the operation is well-defined.

It is acceptable for multi-line inline formatting to be limited in V2.

---

# 45. Markdown Formatting Utilities

Create reusable formatting functions rather than duplicating Markdown manipulation logic.

Conceptually:

```
MarkdownFormatter
```

could expose operations such as:

```
toggleBold()
toggleItalic()
toggleStrikethrough()
toggleInlineCode()
createLink()
toggleChecklist()
toggleBulletList()
toggleOrderedList()
```

The exact API is up to you.

These functions should operate on:

* Markdown string
* selection range

and return:

* new Markdown
* new selection

where appropriate.

---

# 46. Formatting Must Be Context-Aware

Do not blindly wrap selected Markdown.

Example:

Selecting:

```
**important**
```

and pressing Bold should not produce:

```
****important****
```

Instead recognize that it is already bold.

Likewise:

```
`code`
```

should not become:

```
`` `code` ``
```

when toggling inline code.

Implement basic detection of whether the selection is already wrapped.

---

# 47. Preserve Existing Markdown

Formatting commands must not corrupt surrounding Markdown.

Example:

```
This is **important** and useful.
```

Selecting:

```
useful
```

and applying italic should produce:

```
This is **important** and *useful*.
```

Not:

```
This is ***important** and useful*
```

or any other malformed result.

Add unit tests for operations near existing formatting.

---

# 48. Selection Mapping

Because formatting changes the text length, selection offsets may need to change.

Example:

Before:

```
important
```

selection:

```
[0..9]
```

After:

```
**important**
```

logical content selection should preferably correspond to:

```
[2..11]
```

Implement robust selection mapping.

Do not simply restore the old integer offsets.

---

# 49. Undo/Redo

Every formatting operation must participate in the existing undo/redo system.

For example:

```
text
  ↓
Ctrl+B
  ↓
**text**
  ↓
Ctrl+Z
  ↓
text
```

The same applies to:

* toolbar formatting
* checklist toggles
* smart list insertion where supported

Do not implement a separate undo stack unless absolutely necessary.

Use Flutter's existing editing/undo infrastructure where possible.

---

# 50. Autosave

Formatting operations and checkbox toggles must trigger the existing note change/autosave mechanism.

Do not bypass the existing `onChanged` or persistence pathway.

The database should receive the updated Markdown string.

---

# 51. Preview Compatibility

After applying any feature, preview mode must render the expected Markdown.

Examples:

Editor:

```
- [x] Finish project
```

Preview:

```
☑ Finish project
```

Editor:

```
**Important**
```

Preview:

```
Important
```

The editor and preview must always consume the same Markdown source.

---

# 52. Android UX

This is an Android-first app.

Test on:

* touch-only phone
* phone with software keyboard
* tablet
* tablet with physical keyboard
* dark mode
* light mode
* portrait
* landscape

Pay special attention to:

* selection toolbar placement
* keyboard overlap
* scrolling
* checkbox touch targets
* cursor placement
* selection handles
* back button behavior

---

# 53. Avoid Unnecessary Dependencies

Before adding a package:

1. Check whether Flutter already provides the required functionality.
2. Check whether the existing project already has a suitable dependency.
3. Prefer small, well-maintained dependencies if one is genuinely necessary.

Do not introduce a large rich-text editor package.

The current Markdown-aware editor architecture should remain the foundation.

---

# 54. Testing Requirements

Create comprehensive tests.

## Parser tests

Verify:

* checkboxes
* nested checkboxes
* lists
* headings
* existing inline formatting
* mixed checklist + formatting

Example:

```
- [ ] Read **this**
- [x] Finish *that*
```

---

# 55. Smart Editing Tests

Test:

### Bullet continuation

```
- First|
```

Enter:

```
- First
- |
```

### Empty bullet

```
- First
- |
```

Enter:

```
- First
|
```

### Ordered list

```
1. First|
```

Enter:

```
1. First
2. |
```

### Quote

```
> Quote|
```

Enter:

```
> Quote
> |
```

### Empty quote

```
> Quote
> |
```

Enter:

```
> Quote
|
```

### Nested list

```
- Parent
  - Child|
```

Enter:

```
- Parent
  - Child
  - |
```

---

# 56. Formatting Tests

Test:

```
text
```

→ Bold:

```
**text**
```

→ Bold again:

```
text
```

Test the same for:

* italic
* strikethrough
* inline code

Test formatting adjacent to existing Markdown.

---

# 57. Link Tests

Test:

```
OpenAI
```

→ link:

```
[OpenAI](https://openai.com)
```

Test links next to formatted text.

Test editing existing links.

---

# 58. Checklist Tests

Test:

```
Task
```

→ checklist:

```
- [ ] Task
```

Toggle:

```
- [x] Task
```

Toggle again:

```
- [ ] Task
```

Test:

```
- [ ] Task one
- [x] Task two
```

and nested lists.

---

# 59. Keyboard Tests

Verify:

* Ctrl+B
* Ctrl+I
* Ctrl+Shift+X
* Ctrl+K
* Ctrl+`
* Ctrl+C
* Ctrl+V
* Ctrl+X
* Ctrl+A
* Ctrl+Z
* Ctrl+Shift+Z

Existing standard shortcuts must remain functional.

---

# 60. Widget Tests

Test:

* editor rendering
* selection
* toolbar visibility
* toolbar formatting
* checkbox interaction
* smart Enter
* keyboard shortcuts
* cursor preservation
* selection preservation
* undo/redo
* autosave callback
* theme switching

---

# 61. Regression Testing

Before considering the task complete, verify that V1 functionality has not regressed.

Specifically:

* Markdown parser
* Markdown styling
* headings
* bold
* italic
* strikethrough
* code
* links
* lists
* blockquotes
* preview mode
* note loading
* note saving
* cursor behavior
* selection
* copy/paste
* undo/redo
* Android keyboard behavior

---

# 62. Performance Requirements

The editor should remain responsive while typing.

Do not rebuild the entire Flutter widget tree unnecessarily after every keystroke.

Do not recreate expensive objects repeatedly.

Keep the Markdown parser as lightweight as possible.

If profiling shows parsing is expensive, optimize the parser before introducing architectural complexity.

The following should remain usable:

* 10 KB note
* 50 KB note
* 100 KB note

---

# 63. Code Quality

Follow the existing project's:

* Dart style
* naming conventions
* architecture
* state management
* dependency injection
* error handling
* testing conventions

Do not rewrite unrelated code.

Keep the implementation modular.

Avoid huge editor classes.

Separate:

* parsing
* Markdown manipulation
* keyboard commands
* selection formatting
* toolbar UI
* checkbox hit testing
* persistence

where practical.

---

# 64. Implementation Order

Implement in this order.

## Phase 1 — Markdown formatting utilities

Create reusable functions for:

* bold
* italic
* strikethrough
* inline code
* links
* checklist
* list handling

Ensure they correctly update selections.

## Phase 2 — Smart Enter

Implement:

* bullet continuation
* ordered list continuation
* checklist continuation
* blockquote continuation
* empty-list termination
* empty-quote termination

## Phase 3 — Keyboard shortcuts

Add:

* Ctrl+B
* Ctrl+I
* Ctrl+Shift+X
* Ctrl+K
* Ctrl+`

## Phase 4 — Selection toolbar

Add:

* Bold
* Italic
* Strikethrough
* Code
* Link
* Checklist

## Phase 5 — Interactive checkboxes

Implement:

* checkbox rendering
* hit testing
* toggling
* selection preservation
* undo/redo
* autosave

## Phase 6 — Testing

Run the complete test suite and add regression tests.

## Phase 7 — Performance and UX polish

Test on Android devices and fix:

* cursor issues
* keyboard issues
* selection issues
* toolbar positioning
* scrolling
* touch targets
* performance

---

# 65. Definition of Done

The implementation is complete when a user can comfortably write Markdown without manually repeating common syntax.

For example, this workflow should feel natural:

```
Write:

# Shopping List

- Buy milk
- Buy eggs

Press Enter after "Buy eggs":

- Buy eggs
- |

Select "milk", tap Bold:

- Buy **milk**

Select "Buy eggs", tap Checklist:

- [ ] Buy **milk**
- [ ] Buy eggs

Tap the checkbox:

- [x] Buy eggs

Connect a physical keyboard:

Select text → Ctrl+B

Result:

**selected text**
```

All of these operations must continue storing ordinary Markdown.

---

# 66. Final Principle

The editor should remain fundamentally a Markdown editor.

Do not turn it into a rich-text editor that happens to export Markdown.

The desired architecture is:

```
User interaction
      |
      v
Markdown manipulation
      |
      v
Markdown source
      |
      v
Markdown parser
      |
      v
Visual editor
```

The Markdown string is the canonical state.

The goal of this version is to make Markdown **pleasant and fast to write**, especially on Android, while preserving the simplicity and portability of Markdown.

Do not implement future features merely because the architecture could support them.

Focus on making these four features extremely reliable:

1. Smart Markdown editing
2. Keyboard shortcuts
3. Selection-aware formatting toolbar
4. Interactive Markdown checkboxes
