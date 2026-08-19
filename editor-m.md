# Flutter Markdown-Aware WYSIWYG Editor — V1

## Role

You are a senior Flutter/Dart engineer implementing a Markdown-aware editing experience for an existing Android note-taking application.

The application currently has:

* A plaintext editor.
* Notes stored as Markdown/plaintext strings.
* A separate Markdown preview mode that renders the note.
* An Android-first Flutter codebase.

The goal is to replace the current visually plain editing experience with a **Markdown-aware editable editor**.

This is NOT a request to build a traditional rich-text editor.

The underlying note content must remain **Markdown text**. The editor should simply make Markdown syntax visually meaningful while the user is editing it.

---

# 1. Core Objective

Implement V1 of a Markdown-aware editor where:

1. The underlying document remains a normal Markdown string.
2. The user can freely type and edit Markdown.
3. Markdown syntax is visually styled while editing.
4. Formatting such as headings, bold, italic, strikethrough, code, lists, quotes, links, etc. is visually represented inside the editor.
5. The Markdown syntax itself remains present and editable.
6. Existing notes remain compatible.
7. Existing Markdown preview functionality continues to work.
8. The editor behaves like a normal Flutter text editor from the user's perspective.
9. Do NOT attempt to hide/remove Markdown characters in V1.
10. Do NOT introduce a separate rich-text document model in V1.

The result should feel substantially closer to Bear/Typora-style Markdown editing than to a plain TextField, while keeping Markdown as the source of truth.

---

# 2. Important Architectural Decision

Use this architecture:

```
Markdown String
      |
      v
Markdown tokenizer/parser
      |
      v
Styled TextSpan tree
      |
      v
Editable Flutter text widget
      |
      v
User edits Markdown String
      |
      v
Re-parse and rebuild styling
```

The Markdown string is always authoritative.

Do NOT store the note as:

* HTML
* Delta
* ProseMirror JSON
* Lexical JSON
* Tiptap JSON
* arbitrary rich-text JSON

for V1.

The existing Markdown/plaintext storage format must remain unchanged.

---

# 3. Recommended Flutter Architecture

Create a dedicated editor component rather than putting all Markdown logic directly into the screen.

Suggested structure:

```
lib/
  editor/
    markdown_editor.dart
    markdown_editing_controller.dart
    markdown_tokenizer.dart
    markdown_token.dart
    markdown_styles.dart
    markdown_parser.dart
    markdown_editing_helpers.dart
```

Adapt the exact structure to the existing project conventions.

The important requirement is separation of concerns.

## Responsibilities

### MarkdownEditingController

Subclass or otherwise build upon Flutter's text editing infrastructure.

Responsibilities:

* Hold the Markdown source string.
* Track selection/cursor position.
* Produce styled TextSpans for the editor.
* Rebuild styling when the text changes.
* Preserve selection.
* Preserve composing/IME behavior.
* Avoid modifying the underlying text merely for styling.

Conceptually:

```
MarkdownEditingController
    |
    +-- value.text = Markdown source
    |
    +-- selection
    |
    +-- buildTextSpan()
             |
             +-- tokenizer/parser
             |
             +-- styled spans
```

Use Flutter's `TextEditingController.buildTextSpan()` mechanism if appropriate.

---

# 4. Do Not Build a Full Markdown Compiler

V1 does not need to support the entire CommonMark/GFM specification.

Implement a deliberately scoped Markdown tokenizer/parser designed for an editor.

The parser should identify formatting ranges rather than producing a completely rendered document.

The important distinction is:

```
Markdown renderer:
    Markdown -> rendered document
```

versus:

```
Editor tokenizer:
    Markdown -> text + formatting metadata
```

The original characters must remain in the editable text.

---

# 5. Markdown Features Required in V1

Implement the following.

## 5.1 Headings

Support:

```
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

Visual behavior:

* Heading text should be larger/bolder according to heading level.
* The `#` markers should remain editable.
* Heading markers may use a visually subdued syntax style.
* Heading styling should continue until the end of the line.
* Do not remove the `#` characters.

Example:

```
# My Note
```

The underlying text remains exactly:

```
# My Note
```

but "My Note" is rendered with heading styling.

---

# 6. Bold

Support:

```
**bold text**
```

and, if practical:

```
__bold text__
```

Apply bold styling to the content.

The Markdown markers remain visible and editable.

Prefer making the markers visually subtle rather than deleting them.

Example:

```
This is **important**.
```

The underlying string must remain unchanged.

---

# 7. Italic

Support:

```
*italic text*
```

and:

```
_italic text_
```

Apply italic styling.

Do not modify the Markdown source.

---

# 8. Bold + Italic

Support:

```
***bold italic***
```

and:

```
___bold italic___
```

Apply both styles.

Correctly handle nesting where reasonably possible.

---

# 9. Strikethrough

Support:

```
~~deleted text~~
```

Render the enclosed text using a strikethrough decoration.

---

# 10. Inline Code

Support:

```
`code`
```

Apply a monospace/code style.

The backticks remain in the underlying text.

Optionally give the backticks a subdued syntax color/style.

Do not introduce a separate code editor in V1.

---

# 11. Code Blocks

Support fenced code blocks:

````
```js
const hello = "world";
```
````

Requirements:

* Detect opening and closing fences.
* Style the entire block as code.
* Use monospace font.
* Preserve indentation and whitespace.
* Preserve all original Markdown.
* The opening/closing fences remain editable.
* Language identifiers such as `js` should remain editable.

Do not implement full syntax highlighting for programming languages in V1 unless the existing project already has an appropriate dependency.

Basic code-block styling is sufficient.

---

# 12. Unordered Lists

Support:

```
- Item
- Item
- Item
```

Also support:

```
* Item
+ Item
```

Style list markers appropriately.

The list markers remain in the Markdown source.

Support multiple levels where practical:

```
- Parent
  - Child
  - Child
```

Do not attempt complex list layout logic in V1.

---

# 13. Ordered Lists

Support:

```
1. First
2. Second
3. Third
```

Style ordered-list markers appropriately.

Preserve the original numbering.

Do not automatically renumber existing content in V1 unless it is trivial and safe.

---

# 14. Blockquotes

Support:

```
> This is a quote.
```

Apply quote styling to the line/content.

The `>` marker remains editable.

For multiple lines:

```
> Line one
> Line two
```

style them consistently.

---

# 15. Links

Support normal Markdown links:

```
[OpenAI](https://openai.com)
```

The visible link text should have link styling.

The URL remains part of the underlying editable Markdown.

V1 does NOT need to make links tappable inside the editor.

If making them tappable would interfere with cursor placement/editing, do not do it.

The existing preview mode should continue handling actual link interaction.

Also recognize bare URLs only if this can be done safely without interfering with editing.

---

# 16. Horizontal Rules

Recognize common Markdown horizontal rules:

```
---
***
___
```

Render the line using a subtle divider-like appearance if practical.

Do not replace the source text.

If implementing a visual divider is difficult with the chosen Flutter text widget, apply a subdued syntax style instead.

---

# 17. Inline Escaping

Recognize basic Markdown escapes:

```
\*
\_
\`
\#
```

Do not incorrectly interpret escaped Markdown characters as formatting.

Example:

```
\*not italic\*
```

must not become italic.

---

# 18. Syntax Styling

Create a centralized Markdown syntax style.

For example:

```
MarkdownStyles
    heading1
    heading2
    heading3
    heading4
    heading5
    heading6
    bold
    italic
    strikethrough
    inlineCode
    codeBlock
    blockquote
    listMarker
    link
    markdownSyntax
```

Do not hard-code styles throughout the parser.

The editor should inherit the application's theme.

Do not hard-code colors.

Use ThemeData, ColorScheme, TextTheme, or an appropriate existing design system.

The Markdown syntax itself should generally be less visually prominent than the content.

For example:

```
**important**
```

should visually communicate "important" first, rather than making the `**` markers visually dominant.

---

# 19. Critical Requirement: Preserve Text Exactly

Styling must NEVER mutate the Markdown source.

For example, if the user enters:

```
# Hello **world**
```

the controller's text must remain:

```
# Hello **world**
```

The editor must not convert it into:

```
Hello world
```

or:

```
<h1>Hello <strong>world</strong></h1>
```

or any other representation.

The TextSpan tree is purely a visual representation.

---

# 20. Cursor and Selection

This is one of the most important parts.

The editor must use the original Markdown string for:

* cursor positions
* selection positions
* insertion
* deletion
* copy
* paste
* undo
* redo

Do NOT create a separate visible string with Markdown characters removed.

There must be a 1:1 relationship between the editable text and Flutter's selection offsets in V1.

This is intentionally different from the more advanced Bear behavior where syntax can disappear.

---

# 21. Cursor Behavior

The cursor should behave exactly as it does in a normal Flutter text editor.

Examples:

If the text is:

```
Hello **world**
```

the user should be able to place the cursor:

* before `**`
* inside `world`
* between the two `*`
* after the closing `**`

Nothing should prevent editing the Markdown syntax directly.

Do not make syntax spans non-editable.

Do not use overlay widgets that interfere with cursor positioning unless absolutely necessary.

---

# 22. Selection Behavior

Selecting text must operate on the actual Markdown string.

For example, selecting:

```
**world**
```

must select the actual six/eight characters including Markdown markers depending on the user's selection.

Copy should copy the Markdown source.

For example:

```
**world**
```

not:

```
world
```

This is essential because Markdown is the source of truth.

---

# 23. Copy/Paste

Pasting Markdown must work naturally.

If the user pastes:

```
# Heading

**bold**
```

the editor should insert exactly that Markdown.

Styling should update automatically.

Do not convert pasted Markdown into HTML or another document representation.

---

# 24. Undo/Redo

Do not break Flutter's normal text editing undo/redo behavior.

Every text modification should remain compatible with the normal editing system.

Avoid modifying the text automatically during `buildTextSpan()`.

`buildTextSpan()` must be a pure visual operation.

---

# 25. IME / Android Keyboard Support

This is an Android-first application, so prioritize correct interaction with:

* Gboard
* Android IME
* autocorrect
* composing text
* predictive text
* hardware keyboards
* paste
* selection handles

Do not rebuild or replace the text controller value unnecessarily.

Be particularly careful not to reset:

* selection
* composing range
* caret position

when Markdown styling is regenerated.

---

# 26. Performance

The editor must remain responsive for normal notes.

Do not run an expensive complete Markdown parser repeatedly if it can be avoided.

V1 should target notes of at least:

* 10 KB
* 50 KB
* 100 KB

without noticeable typing lag on a normal Android device.

If necessary, begin with parsing the affected paragraph/line rather than the entire document.

However, correctness comes before premature optimization.

Do not introduce isolates/complex incremental parsing unless profiling demonstrates the need.

---

# 27. Debouncing

Do NOT debounce visual editor rendering in a way that makes the editor feel delayed.

Typing should remain immediate.

If expensive operations such as autosave are already debounced, keep that behavior separate from editor rendering.

The Markdown styling should update immediately.

---

# 28. Parser Design

Do not use a pile of unrelated regular expressions that cannot handle nesting.

Create a lightweight tokenizer/parser.

A possible approach:

1. Split document into lines/blocks.
2. Detect block-level constructs:

   * headings
   * blockquotes
   * lists
   * code blocks
   * horizontal rules
3. Parse inline constructs inside normal text:

   * bold
   * italic
   * strikethrough
   * inline code
   * links
4. Generate ranges/spans.
5. Convert ranges into TextSpans.

The exact algorithm is up to you.

Prefer a deterministic parser that behaves predictably while the user is typing incomplete Markdown.

---

# 29. Incomplete Markdown Is Normal

This is an editor, not a static Markdown renderer.

The parser MUST tolerate incomplete syntax.

Examples:

````
**hello

[hello](

[hello]

`hello

```js
````

These should never crash the editor.

Partial Markdown should simply receive partial or no styling.

The user must always be able to continue typing.

---

# 30. Avoid Aggressive Parsing

Do not make assumptions that cause surprising formatting.

For example, don't treat every `*` character as italic syntax.

Handle delimiter pairs conservatively.

Correct behavior for common Markdown should take priority over trying to parse every theoretical Markdown edge case.

---

# 31. Newline Behavior

Normal Enter/newline behavior must work.

When pressing Enter after:

```
- First item
```

the editor should ideally continue the list:

```
- First item
-
```

This is optional for the absolute minimum V1, but highly recommended because it makes the editor feel natural.

Similarly:

```
1. First
```

could become:

```
1. First
2.
```

For blockquotes:

```
> Quote
```

could continue:

```
> Quote
>
```

If implementing these behaviors, make them explicit editing commands rather than parser side effects.

Do not implement them if they risk breaking normal typing.

---

# 32. Markdown Shortcuts

Implement basic Markdown shortcuts where practical.

Examples:

Typing:

```
# 
```

at the beginning of a line should immediately style the line as a heading.

Typing:

```
- 
```

should create a list line.

Typing:

```
> 
```

should create a quote.

However, do NOT delete the Markdown syntax in V1.

The text should remain:

```
# Heading
```

not be converted into an internal heading object.

The shortcut only changes visual styling.

---

# 33. Existing Preview Mode

Do not remove the existing Markdown preview mode.

The app should now have:

```
EDIT
   |
   | Markdown source
   |
PREVIEW
   |
   | rendered Markdown
```

Both must use the same note content.

The preview must continue to render the exact Markdown stored in the note.

---

# 34. Existing Notes

Existing notes may contain arbitrary Markdown/plaintext.

The new editor must open them without migration.

No database migration should be required.

No conversion should happen merely because a note is opened.

Opening and immediately closing a note without editing it must not alter its Markdown content.

---

# 35. Unsupported Markdown

Unsupported Markdown must remain plain editable text.

Never:

* delete it
* transform it
* corrupt it
* reject the document
* show an error merely because the Markdown is unsupported

The editor should degrade gracefully.

---

# 36. Theme Integration

The editor must work with:

* light theme
* dark theme
* system theme

Do not hard-code a Bear-specific color palette.

Use the application's existing theme where possible.

The editor should visually fit the existing application.

Pay particular attention to:

* background
* primary text
* secondary/syntax text
* selection
* cursor
* headings
* links
* code blocks
* quotes

---

# 37. Typography

The editor should feel like a note editor rather than a code editor.

Use the application's existing font if one exists.

Suggested visual hierarchy:

```
Normal text
    ↓
H1
    ↓
H2
    ↓
H3
```

Bold/italic should modify the existing text rather than dramatically changing size.

Inline code can use a monospace font.

Code blocks can use a monospace font with a subtle background if the current UI supports it.

---

# 38. Editor API

Create a clean API around the editor.

For example, conceptually:

```
MarkdownEditor(
  controller: controller,
  focusNode: focusNode,
  onChanged: onChanged,
  style: ...,
)
```

The exact API should follow the existing application's architecture.

Do not unnecessarily expose parser internals to screens.

---

# 39. Error Handling

The editor must never crash because of malformed Markdown.

Test inputs such as:

````
**

*

_

__

[foo

[foo](

`

```

``` 

> 

# 

######

- 

1. 

**foo *bar**

~~foo **bar~~
````

The editor should remain completely usable.

---

# 40. Testing

Implement unit tests for the parser/tokenizer.

At minimum test:

### Headings

```
# Heading
## Heading
###### Heading
```

### Inline formatting

```
**bold**
*italic*
***bold italic***
~~strike~~
`code`
```

### Links

```
[Google](https://google.com)
```

### Blocks

````
> quote
- list
1. ordered
```
code
```
````

### Escaping

```
\*not italic\*
```

### Nesting

```
**bold *italic***
```

### Malformed Markdown

```
**hello
[hello](
`hello
```

### Plain text

Ensure ordinary text receives no accidental formatting.

---

# 41. Widget Tests

Add widget tests verifying:

1. The editor displays Markdown.
2. Styled text appears correctly.
3. User input modifies the underlying Markdown.
4. Cursor positioning still works.
5. Selection works.
6. Copy returns Markdown source.
7. Paste works.
8. Existing notes load correctly.
9. Preview receives the exact same Markdown.
10. Theme changes don't break the editor.

---

# 42. Performance Tests

Test at least:

* 1 KB note
* 10 KB note
* 50 KB note
* 100 KB note

Measure typing responsiveness.

If performance becomes problematic, profile first.

Do not prematurely introduce a complicated incremental parser.

---

# 43. Accessibility

Ensure:

* normal text remains readable
* contrast is sufficient
* cursor is visible
* selection is visible
* headings have appropriate visual hierarchy
* the editor works with Android accessibility features where possible

Do not communicate formatting exclusively through color.

For example, bold must actually be bold, not merely a different color.

---

# 44. What NOT to Implement in V1

Explicitly DO NOT implement:

* hidden Markdown syntax
* cursor-dependent syntax visibility
* WYSIWYG HTML storage
* rich-text JSON storage
* block IDs
* collaborative editing
* real-time collaboration
* CRDT
* full CommonMark compliance
* full GitHub Flavored Markdown compliance
* advanced programming-language syntax highlighting
* arbitrary embedded widgets
* complex drag-and-drop blocks
* floating formatting toolbars unless the existing app already has one
* separate rich-text and Markdown representations

These belong to later versions.

---

# 45. Future Compatibility

Although V1 stores Markdown directly, structure the code so that a more advanced editor can be implemented later.

Future versions may introduce:

* syntax hiding
* cursor-aware Markdown visibility
* inline images
* attachments
* checkboxes
* tables
* slash commands
* richer Markdown parsing
* incremental parsing
* block-level editing
* Markdown AST
* offline synchronization

Do not implement these now.

But avoid architectural decisions that make them impossible later.

---

# 46. Important Bear-Like Behavior

The goal is NOT to clone Bear's implementation.

The goal is to reproduce the core feeling:

* clean writing surface
* Markdown remains the underlying language
* formatting is visible while writing
* headings look like headings
* bold looks bold
* italic looks italic
* code looks like code
* links look like links
* Markdown syntax is unobtrusive
* typing remains fast
* the user never has to switch to a separate preview window just to see formatting

The editor should feel like a normal writing environment.

---

# 47. Implementation Strategy

Before writing code:

1. Inspect the existing Flutter project.
2. Identify:

   * current note model
   * note persistence
   * current editor widget
   * current Markdown preview implementation
   * theme system
   * autosave logic
   * undo/redo behavior
3. Reuse existing infrastructure where possible.
4. Do not rewrite unrelated parts of the application.

Then implement in this order:

### Step 1

Create Markdown token/range models.

### Step 2

Implement block-level parsing.

### Step 3

Implement inline parsing.

### Step 4

Create MarkdownEditingController.

### Step 5

Connect it to the existing editor screen.

### Step 6

Add theme-aware Markdown styles.

### Step 7

Verify cursor/selection/IME behavior.

### Step 8

Add Markdown shortcuts.

### Step 9

Add tests.

### Step 10

Profile performance.

---

# 48. Important Constraint

Do not change note persistence unless absolutely necessary.

The following should continue to work:

```
save(note.markdown)

load(note.markdown)
```

The new editor should simply provide a better editing UI around the existing Markdown string.

---

# 49. Acceptance Criteria

V1 is complete when all of the following are true:

* [ ] Existing Markdown notes open correctly.
* [ ] Plain text remains editable.
* [ ] Markdown remains the source of truth.
* [ ] Headings are visually styled.
* [ ] Bold is visually styled.
* [ ] Italic is visually styled.
* [ ] Bold + italic works.
* [ ] Strikethrough works.
* [ ] Inline code works.
* [ ] Code blocks are styled.
* [ ] Unordered lists are styled.
* [ ] Ordered lists are styled.
* [ ] Blockquotes are styled.
* [ ] Links are styled.
* [ ] Horizontal rules are recognized.
* [ ] Escaped Markdown isn't incorrectly formatted.
* [ ] Markdown markers remain editable.
* [ ] Cursor positions remain correct.
* [ ] Selection remains correct.
* [ ] Copy copies Markdown.
* [ ] Paste preserves Markdown.
* [ ] Undo/redo works.
* [ ] Android keyboard/IME works.
* [ ] Incomplete Markdown never crashes the editor.
* [ ] Existing preview mode continues working.
* [ ] Light theme works.
* [ ] Dark theme works.
* [ ] Normal notes remain responsive.
* [ ] Parser unit tests exist.
* [ ] Editor widget tests exist.
* [ ] No unnecessary database migration is introduced.

---

# 50. Final Engineering Principle

The most important rule for this implementation is:

```
Markdown is the data.
TextSpan styling is the presentation.
```

Never reverse those responsibilities.

The user should be editing the actual Markdown string at all times.

The visual formatting is only a representation of that string.

Build V1 to be simple, reliable, fast, and compatible with the existing application before attempting advanced Bear-style syntax hiding.
