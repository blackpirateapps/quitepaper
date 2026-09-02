# Quiet Paper — Complete Visual Editor Rewrite
## Editor V4: Delete the Existing WYSIWYG Editor and Rebuild It From Scratch

You are working on the existing Quiet Paper Flutter notes application.

The current visual/WYSIWYG editor implementation is not acceptable as a production-quality editor. It has become a collection of projection logic, source/visual offset workarounds, formatter special cases, fake visual characters, and caret corrections.

Do **not** continue modifying that implementation.

## The task

### First:

**Completely remove the existing WYSIWYG / visual editor implementation.**

### Then:

**Build a brand-new visual editor from scratch using a semantic document-editor architecture.**

This is an intentional architectural reset.

Do not preserve the old visual editor as a fallback.

Do not keep V3 and V4 side by side.

Do not add another abstraction layer on top of the existing visual editor.

Remove it first, verify that the repository is clean, and then implement the replacement.

---

# 1. ABSOLUTE PRODUCT INVARIANTS

The application must continue using **canonical Markdown as the sole persisted note-body representation**.

The following must remain unchanged in principle:

```text
SQLite / Drift
encrypted local storage
E2EE sync
cloud backup
exports
imports
version history
autosave
attachments
images
note links
```

All persist the canonical Markdown string.

The new visual editor may use an ephemeral semantic document model internally.

It must never persist that model.

Never introduce:

```text
JSON rich text
Delta
HTML
Quill document
ProseMirror document
Slate document
custom serialized editor state
```

The canonical source remains:

```text
Markdown string
```

---

# 2. DELETE THE CURRENT VISUAL EDITOR FIRST

Before implementing the new editor, inspect the repository and identify every component belonging specifically to the current V3 WYSIWYG implementation.

Known areas include concepts/components such as:

```text
WysiwygProjectionBuilder
WysiwygEditingController
SourceVisualMapping
WYSIWYG-specific MarkdownEditor behavior
WYSIWYG-specific MarkdownTextInputFormatter behavior
visual-prefix handling
private-use Phosphor checkbox glyph handling
visual-text-to-source synchronization code
projection-specific selection/caret correction
```

Names may differ in the actual repository. Find all dependencies rather than relying only on these names.

Then remove the old visual editor completely.

## Delete/decommission:

- current WYSIWYG projection engine
- current WYSIWYG editing controller
- projection-generated visual text pipeline
- fake visual Markdown characters
- visual-prefix formatter logic
- Phosphor private-use checkbox glyph logic
- WYSIWYG-specific gesture detection based on fake glyph characters
- old visual selection mapping that only exists to support the deleted editor
- old projection-specific caret correction
- obsolete WYSIWYG-specific formatter branches
- obsolete WYSIWYG-only tests
- dead imports
- dead dependencies
- dead helper classes
- dead state fields
- dead widget paths

Do not leave the old editor hidden behind a feature flag.

Do not leave it as a fallback.

Do not leave two WYSIWYG implementations.

When deletion is complete, the codebase should contain **no production path to the old visual editor**.

---

# 3. WHAT MUST NOT BE DELETED

The following are not the old visual editor and must be preserved where they remain valid.

Keep:

- Markdown editing mode
- canonical Markdown storage
- existing Markdown parser infrastructure
- existing Markdown formatter logic that is genuinely source-oriented
- frontmatter parser
- frontmatter surgical mutation logic
- Properties UI
- title synchronization
- existing table editor
- table parsing
- table source mapping
- attachment system
- image system
- note links
- autocomplete
- undo/redo infrastructure
- autosave
- persistence
- encryption
- sync
- export/import
- theme system
- typography system
- existing settings
- existing large-document safety mechanisms

The goal is:

```text
OLD VISUAL EDITOR → DELETE

EVERYTHING ELSE VALID → KEEP

NEW VISUAL EDITOR → BUILD FROM ZERO
```

---

# 4. REMOVE THE OLD EDITOR BEFORE BUILDING THE NEW ONE

Do this in two conceptual stages.

## Stage A — destructive cleanup

Remove the old WYSIWYG implementation.

The application should temporarily have:

```text
Markdown mode
```

as the only active editing mode.

The visual editor can temporarily show a clean "not available during editor rewrite" development state if the application requires a widget to compile, but do not preserve the old implementation.

Do not ship that state.

## Stage B — clean implementation

Build the new semantic visual editor.

Do not reuse the deleted visual editing architecture.

---

# 5. NEW EDITOR PHILOSOPHY

The new editor must not be:

> Markdown with syntax hidden.

It must be:

> **A visual document editor whose persistence format happens to be Markdown.**

This is the central architectural decision.

The user edits:

```text
Heading
Paragraph
Bold text
Italic text
List
Checklist
Quote
Code
Link
Image
Table
```

The user does not edit:

```text
#
**
*
~~
`
-
- [ ]
>
```

Those are serialization details.

---

# 6. HIGH-LEVEL ARCHITECTURE

Implement this architecture:

```text
                    Canonical Markdown
                           │
                           ▼
                 Markdown Semantic Parser
                           │
                           ▼
                  SemanticDocument
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
       Semantic editor             Source mapping
              │                         │
              └────────────┬────────────┘
                           ▼
                    User interaction
                           │
                           ▼
                    Semantic command
                           │
                           ▼
                  Source mutation layer
                           │
                           ▼
                    Canonical Markdown
                           │
                           ▼
                Existing persistence/sync
```

The semantic document exists only while editing.

---

# 7. SEMANTIC DOCUMENT MODEL

Create a clean editor-domain model.

At minimum:

```dart
SemanticDocument
SemanticBlock
SemanticInline
SourceRange
DocumentPosition
DocumentSelection
SemanticEditorController
SemanticEditorCommand
```

The exact naming can follow the repository's naming conventions.

The document should conceptually contain:

```text
SemanticDocument
├── Frontmatter metadata
├── HeadingBlock
├── ParagraphBlock
├── ListBlock
├── ChecklistBlock
├── QuoteBlock
├── HorizontalRuleBlock
├── CodeBlock
├── ImageBlock
└── TableBlock
```

Paragraph-like blocks contain inline semantics:

```text
PlainRun
BoldRun
ItalicRun
StrikeRun
InlineCodeRun
LinkRun
NoteLinkRun
```

---

# 8. SOURCE RANGE MODEL

Every semantic object that originated in Markdown must know its source range.

For example:

```text
HeadingBlock
source: 0..15
level: 1
text: "My Heading"

BoldRun
source: 28..42
content: 30..40
text: "important"
```

The exact representation is implementation-dependent.

The requirement is not.

The editor must always know:

```text
which Markdown characters produced this object
```

and:

```text
which semantic object corresponds to this Markdown range
```

---

# 9. DOCUMENT POSITIONS

Do not use raw Flutter `TextSelection.offset` as the fundamental document position.

Use a semantic position.

Conceptually:

```dart
DocumentPosition(
  blockId: ...,
  offset: ...,
)
```

Selections:

```dart
DocumentSelection(
  base: ...,
  extent: ...,
)
```

This lets selection work correctly across blocks and formatting boundaries.

---

# 10. INLINE FORMATTING

Implement inline formatting as semantic runs.

Example Markdown:

```md
This is **bold** and *italic*.
```

Semantic structure:

```text
PlainRun("This is ")
BoldRun("bold")
PlainRun(" and ")
ItalicRun("italic")
PlainRun(".")
```

The visual editor only displays:

```text
This is bold and italic.
```

Never put:

```text
**
*
~~
`
```

inside the visual editable content.

---

# 11. BOLD

Visual:

```text
This is bold text.
```

Semantic:

```text
BoldRun("bold text")
```

Markdown serialization:

```md
This is **bold text**.
```

Requirements:

- typing inside bold
- deleting inside bold
- selecting bold text
- selecting part of bold text
- applying bold
- removing bold
- bold across multiple runs
- caret at run boundaries
- copy/paste
- undo/redo

The Markdown delimiters never become part of the user's visual caret model.

---

# 12. ITALIC

Same architecture.

Visual:

```text
This is italic text.
```

Semantic:

```text
ItalicRun("italic text")
```

Markdown:

```md
This is *italic text*.
```

No hidden `*`.

No TextField offset hacks.

---

# 13. STRIKETHROUGH

Visual:

```text
This is struck.
```

Semantic:

```text
StrikeRun("struck")
```

Markdown:

```md
This is ~~struck~~.
```

---

# 14. INLINE CODE

Visual:

```text
Run npm install.
```

Semantic:

```text
InlineCodeRun("npm install")
```

Markdown:

```md
Run `npm install`.
```

Backticks never appear in the visual editable content.

---

# 15. HEADINGS

Represent headings as dedicated blocks.

Markdown:

```md
# Heading
## Subheading
### Section
```

Semantic:

```text
HeadingBlock(level: 1, text: "Heading")
HeadingBlock(level: 2, text: "Subheading")
HeadingBlock(level: 3, text: "Section")
```

The visual typography comes from the heading level.

The Markdown marker is never rendered as document text.

Changing H1 → H2:

```text
HeadingBlock level 1
        ↓
HeadingBlock level 2
```

serializes:

```md
# Heading
```

to:

```md
## Heading
```

while preserving text and logical caret position.

---

# 16. PARAGRAPHS

Normal body text is a semantic paragraph block.

Do not make the entire document a giant editable TextField.

Each paragraph is a document block with its own content model.

Paragraphs must support:

- inline formatting
- links
- note links
- selection
- splitting
- merging
- keyboard editing
- clipboard
- undo/redo

---

# 17. BLOCK SPLITTING

Enter inside a paragraph should split the semantic block.

Example:

```text
Hello world
     ^
```

Press Enter:

```text
Hello

world
```

The corresponding Markdown becomes:

```md
Hello

world
```

The semantic document is updated first.

Do not insert a raw newline into a giant projected text field and hope the projection system reconstructs structure afterward.

---

# 18. BLOCK MERGING

Backspace at the beginning of a paragraph should merge with the previous block when appropriate.

Example:

```text
Hello
world|
```

with the caret at the beginning of `world` becomes:

```text
Helloworld
```

according to the existing document-editor semantics.

The source mutation layer performs the actual Markdown mutation.

Formatting around the merge must be normalized correctly.

---

# 19. UNORDERED LISTS

Represent:

```md
- First
- Second
```

as:

```text
ListBlock
├── ListItem("First")
└── ListItem("Second")
```

The bullet is a visual decoration.

It is not part of editable text.

Visual:

```text
• First
• Second
```

But internally the editable content is:

```text
First
Second
```

Press Enter on a non-empty item:

```text
• First|
```

becomes:

```text
• First
• |
```

Press Enter on an empty item:

```text
• |
```

exits the list.

Implement this at the semantic level.

---

# 20. ORDERED LISTS

Represent:

```md
1. First
2. Second
```

as:

```text
OrderedListBlock
├── ListItem("First")
└── ListItem("Second")
```

Numbers are visual decorations.

Enter produces the next logical item.

Correctly serialize:

```md
1. First
2. Second
```

Do not put `1.` into the editable text.

---

# 21. CHECKLISTS

Represent:

```md
- [ ] Todo
- [x] Done
```

as:

```text
ChecklistBlock
├── ChecklistItem(checked: false, text: "Todo")
└── ChecklistItem(checked: true, text: "Done")
```

The checkbox must be a real visual control.

Do NOT use:

```text
☐
☑
```

as editable characters.

Do NOT use Phosphor private-use glyphs inside text.

Phosphor icons may be rendered as widgets/icons.

Tapping the checkbox performs:

```text
checked: false → true
```

which mutates:

```md
- [ ] Todo
```

to:

```md
- [x] Todo
```

Enter behavior:

```text
non-empty item → new unchecked item
empty item → exit checklist
```

---

# 22. QUOTES

Represent:

```md
> Important text
```

as:

```text
QuoteBlock(
  content: ...
)
```

Visual rendering may use:

```text
│ Important text
```

The `>` is not part of editable content.

Enter should continue the quote naturally.

Backspace at appropriate boundaries should allow exiting/merging according to document-editor behavior.

---

# 23. HORIZONTAL RULE

Represent:

```md
---
```

as:

```text
HorizontalRuleBlock
```

Render a real visual divider.

Do not replace it with Unicode characters in editable text.

The Markdown source range remains attached to the block.

---

# 24. LINKS

Represent:

```md
[Quiet Paper](https://example.com)
```

as:

```text
LinkRun(
  text: "Quiet Paper",
  destination: "https://example.com"
)
```

Visual editor shows:

```text
Quiet Paper
```

with link styling.

Never show the URL as hidden editable text.

Editing the label edits only the visible label.

Provide an intentional mechanism for editing the URL.

Preserve existing Quiet Paper link behavior.

---

# 25. NOTE LINKS

Represent existing Quiet Paper note-link syntax semantically.

For:

```md
[[Another Note]]
```

the WYSIWYG editor shows the note link as a semantic inline link.

Do not show `[[` or `]]`.

Preserve existing autocomplete.

Preserve focus and caret position.

---

# 26. IMAGES

Images become semantic blocks.

The user interacts with the visual image.

The underlying Markdown continues to contain the canonical image/attachment reference.

Preserve all existing attachment resolution and storage behavior.

Do not expose image Markdown in WYSIWYG mode.

---

# 27. CODE BLOCKS

Represent code blocks as dedicated blocks.

Markdown:

```md
```dart
final x = 42;
```
```

Semantic:

```text
CodeBlock(
  language: "dart",
  content: "final x = 42;"
)
```

Visual editor:

```text
final x = 42;
```

inside an appropriate code surface.

The fences are not editable content.

Language metadata is not part of the code text.

Preserve indentation, newlines, and source fidelity.

Integrate syntax highlighting using the project's existing/new approved highlighting architecture.

---

# 28. TABLES

Keep the existing table editor.

Do not rewrite working table functionality just for consistency.

Integrate the table editor as:

```text
TableBlock
```

The table remains a real visual table with its existing interaction model.

This is the standard that the rest of the WYSIWYG editor should aspire to.

Preserve existing table features and tests:

- insert
- cell editing
- row insertion
- row deletion
- column insertion
- column deletion
- alignment
- cell formatting
- table deletion
- source-range mapping
- undo/redo
- Markdown serialization

---

# 29. FRONTMATTER

Keep the current frontmatter parser and Properties UI.

Frontmatter is metadata, not body content.

The visual editor should integrate with:

```text
FrontmatterDocument
FrontmatterEditorHelper
FrontmatterPropertiesSection
```

where those components remain valid.

Preserve:

- expanded default Properties
- known property editing
- unknown-property preservation
- malformed YAML protection
- title synchronization

Do not expose raw YAML while in WYSIWYG mode.

Markdown mode continues to show raw YAML.

---

# 30. TITLE

The note title should be a semantic title/header area.

If the canonical frontmatter contains:

```yaml
title: My Note
```

the visual title shows:

```text
My Note
```

Editing it updates the existing title/frontmatter mutation mechanism.

Do not create a second title field persisted independently from Markdown.

---

# 31. FORMAT TOOLBAR

Keep the existing toolbar visual design where it still fits Quiet Paper.

Rewire its commands to the new semantic editor.

Examples:

```text
Bold
→ ToggleBoldCommand

Italic
→ ToggleItalicCommand

Heading
→ SetHeadingLevelCommand

Bullet
→ ToggleUnorderedListCommand

Ordered List
→ ToggleOrderedListCommand

Checklist
→ ToggleChecklistCommand
```

The toolbar must operate on:

```text
DocumentSelection
```

not raw Markdown offsets.

Do not make toolbar actions insert syntax directly into the visual document.

---

# 32. CARET BEHAVIOR

This is a top-priority requirement.

The caret must exist in semantic document coordinates.

For:

```text
This is bold text|
```

the caret is at the end of visible text.

It must never move to:

```text
This is |bold text
```

or:

```text
This is bold text**|
```

because of Markdown serialization.

The source Markdown is irrelevant to the user's visual caret position.

---

# 33. SELECTION

Implement real semantic selection.

Support:

- selection inside one run
- selection across multiple runs
- selection across paragraphs
- selection across list items
- selection across headings
- selection across blocks
- mouse selection
- touch selection
- keyboard selection
- Shift selection
- select all

Formatting commands operate on semantic selections.

Copy/delete operate on semantic selections.

Source mapping translates the semantic selection into the correct Markdown source range.

---

# 34. COPY / PASTE

Copy visible content rather than raw Markdown syntax.

For example, copying:

```text
This is bold.
```

must not unexpectedly copy:

```md
This is **bold**.
```

unless the explicit Markdown mode/source-copy behavior requires it.

WYSIWYG clipboard semantics should be human-oriented.

Preserve existing table clipboard behavior where already implemented.

Pasted content must have deterministic behavior.

Do not accidentally expose Markdown delimiters simply because the canonical source contains them.

---

# 35. KEYBOARD BEHAVIOR

Implement a proper document-editor keyboard model.

Required:

```text
Enter
Backspace
Delete
Arrow keys
Home
End
Shift+Arrow
Ctrl/Cmd+A
Ctrl/Cmd+C
Ctrl/Cmd+X
Ctrl/Cmd+V
Ctrl/Cmd+B
Ctrl/Cmd+I
Undo
Redo
```

Support platform-specific modifier conventions.

Do not rely on a Markdown `TextInputFormatter` to infer semantic structure from fake visual characters.

---

# 36. UNDO / REDO

Use the existing Quiet Paper undo infrastructure where appropriate.

One logical user action should normally equal one undo step.

Examples:

```text
Toggle bold → one undo
Toggle checklist → one undo
Checkbox click → one undo
Insert heading → one undo
Insert table → one undo
Delete selection → one undo
```

Caret movement must not create undo entries.

Selection changes must not create undo entries.

Do not create giant duplicate full-document snapshots unnecessarily.

---

# 37. SOURCE MUTATION

Create a centralized semantic mutation layer.

Conceptually:

```text
insertText()
deleteSelection()
splitBlock()
mergeBlocks()
toggleBold()
toggleItalic()
toggleStrike()
toggleInlineCode()
toggleLink()
setHeadingLevel()
toggleList()
toggleChecklist()
toggleChecklistState()
createQuote()
createCodeBlock()
insertImage()
deleteBlock()
```

These commands operate on semantic state.

They then mutate the canonical Markdown.

UI widgets must not directly manipulate Markdown strings wherever avoidable.

---

# 38. SURGICAL MARKDOWN MUTATION

Do not rewrite the entire Markdown note after every keystroke.

Given:

```md
This is **important** text.
```

changing `important` must modify only the required source range.

Preserve:

- unrelated whitespace
- comments
- unknown Markdown
- frontmatter fields
- attachment references
- link URLs
- code contents
- table syntax

This matters for sync, version history, diffs, and user trust.

---

# 39. SOURCE PRESERVATION

Opening a note in WYSIWYG mode must not alter its Markdown merely because it was opened.

This is a hard invariant.

Example:

```md
# Hello

This is **bold**.

<!-- keep this -->

- Item
```

Entering WYSIWYG and then switching back to Markdown without editing must produce semantically equivalent—and preferably byte-identical—canonical Markdown.

Do not normalize the whole document simply by opening the editor.

---

# 40. MODE SWITCHING

The application retains two modes:

```text
WYSIWYG
Markdown
```

WYSIWYG is the default.

Markdown mode remains the direct source editor.

The per-note action remains:

```text
Edit Markdown
Edit Visually
```

Switching modes must never:

- lose text
- duplicate text
- alter formatting unexpectedly
- corrupt frontmatter
- alter attachments
- alter tables
- expose hidden syntax in WYSIWYG

Where technically possible preserve:

- caret
- selection
- scroll position
- focus

---

# 41. UNSUPPORTED MARKDOWN

The semantic parser will not necessarily support every Markdown extension immediately.

Unsupported syntax must never be destroyed.

Render it as a neutral source-preserving fallback block.

For example:

```text
UnsupportedMarkdownBlock
```

with a subtle:

```text
Edit Markdown
```

affordance.

The original source must remain intact.

Do not invent an approximation that changes meaning.

---

# 42. LARGE DOCUMENTS

Preserve existing Quiet Paper performance safeguards.

The project already has an explicit strategy around large documents because full-document tokenization/rebuilding caused lag. Existing safeguards around the approximately 60,000-character threshold should not be removed casually.

Do not make the new semantic editor:

```text
every keystroke
→ parse entire document
→ rebuild every block
→ rebuild every widget
→ rebuild every mapping
```

Instead prefer:

```text
edit current block
→ mutate local semantic structure
→ update affected source ranges
→ update canonical Markdown
→ rerender affected blocks
```

Use lazy/block-level parsing and rendering where appropriate.

Scrolling must remain smooth.

Cursor movement must not rebuild the document.

Caret blinking must not trigger document parsing.

---

# 43. PERFORMANCE ARCHITECTURE

Use stable identifiers for blocks.

Do not recreate every block object after every keystroke if only one block changed.

Use stable widget keys.

Avoid unnecessary controller recreation.

Avoid rebuilding unrelated tables, images, code blocks, or large sections.

Cache parsed structures where useful.

Use incremental source-range updates where practical.

---

# 44. TOUCH EXPERIENCE

The visual editor must work naturally on touch devices.

Support:

- tap to position caret
- double-tap word selection
- long press selection
- drag selection handles
- checkbox tapping
- link tapping
- table interaction
- image interaction

Semantic decorations must have correct hit testing.

A checkbox must behave like a checkbox, not like text.

A heading must behave like a heading, not like invisible `# ` characters.

---

# 45. DESKTOP EXPERIENCE

Support mouse/keyboard editing naturally.

Examples:

```text
click text
drag selection
Shift+click
Ctrl/Cmd+A
Ctrl/Cmd+C
Ctrl/Cmd+V
Ctrl/Cmd+B
Ctrl/Cmd+I
Backspace
Delete
Enter
Arrow navigation
```

The editor should feel like a real desktop document editor.

---

# 46. VISUAL DESIGN

The new editor should preserve Quiet Paper's aesthetic.

Use the existing:

- theme system
- typography
- spacing
- colors
- editor metrics
- toolbar styling

The editor should feel:

```text
quiet
editorial
spacious
focused
calm
Bear-like
```

Avoid:

- excessive borders
- card around every paragraph
- heavy editor chrome
- visual clutter
- artificial syntax indicators

The document itself should be the visual focus.

---

# 47. DOCUMENT HIERARCHY

The final visual editor must make the semantic structure immediately obvious.

The user should visually recognize:

```text
large heading
normal paragraph
bold/italic inline formatting
list
checklist
quote
code
image
table
```

without seeing Markdown syntax.

---

# 48. FRONTMATTER UI

Keep the existing Properties concept and styling.

It should appear above the body when appropriate.

It must remain:

- understated
- editable
- expanded by default
- synchronized with Markdown
- safe with malformed YAML

Do not rebuild frontmatter management unnecessarily.

---

# 49. EXISTING TABLE EDITOR IS THE REFERENCE

The table editor is the architectural example for this rewrite.

The desired interaction model is:

```text
real visual object
        ↕
semantic model
        ↕
source Markdown range
```

Apply that principle to:

```text
heading
bold
italic
lists
checklists
quotes
links
code
images
```

Do not make those features behave like the old projected TextField.

---

# 50. TESTING — MANDATORY

Do not rely on compilation or a passing general test suite.

Create dedicated V4 tests.

## Parser tests

Test:

- paragraph
- heading
- bold
- italic
- strike
- inline code
- link
- note link
- unordered list
- ordered list
- checklist
- quote
- horizontal rule
- image
- code block
- table
- frontmatter
- malformed syntax
- unsupported syntax

## Semantic model tests

Test:

- block creation
- inline run creation
- run merging
- run splitting
- source ranges
- positions
- selections

## Mapping tests

Test:

```text
Markdown source → semantic position
semantic position → source offset
semantic selection → source range
source range → semantic selection
```

with formatting delimiters.

## Formatting tests

Test:

```text
bold
italic
strike
inline code
links
mixed formatting
partial selections
collapsed caret
format boundaries
```

## Heading tests

Test:

```text
paragraph → H1
H1 → H2
H2 → paragraph
caret preservation
selection preservation
```

## List tests

Test:

```text
paragraph → bullet
bullet → paragraph
bullet + Enter
empty bullet + Enter
ordered list + Enter
empty ordered item + Enter
```

## Checklist tests

Test:

```text
toggle checklist
toggle checkbox
check/uncheck
Enter continuation
empty item + Enter
selection preservation
undo/redo
```

## Quote tests

Test:

```text
create quote
continue quote
exit quote
edit quote
undo/redo
```

## Code block tests

Test:

```text
create
edit
delete
language
copy
undo/redo
```

## Link tests

Test:

```text
create
edit label
edit destination
selection
copy
undo/redo
```

## Table tests

Run and preserve all existing table tests.

## Clipboard tests

Test:

- copy visible text
- copy formatted text
- paste
- replace selection
- multi-block copy/paste

## Mode-switch tests

For every major Markdown construct:

```text
Markdown
→ WYSIWYG
→ Markdown
```

must preserve canonical Markdown.

---

# 51. GOLDEN DOCUMENT

Create a comprehensive integration fixture:

```md
---
title: Semantic Editor Test
author: Dr. Watson
tags:
  - test
  - editor
---

# Main Heading

## Secondary Heading

Plain paragraph with **bold**, *italic*, ~~strike~~, `inline code`, [link](https://example.com), and [[Another Note]].

- First item
- Second item

1. Ordered one
2. Ordered two

- [ ] Unchecked
- [x] Checked

> Quote

---

```dart
final value = 42;
print(value);
```

| A | B |
|---|---|
| 1 | 2 |
```

Use this fixture for comprehensive integration testing.

---

# 52. EXACT USER EXPERIENCE TARGET

When the note contains:

```md
# Hello

This is **bold**, *italic*, and `code`.

- First
- Second

- [ ] Task
- [x] Done

> Quote

[Link](https://example.com)

```dart
final x = 42;
```
```

WYSIWYG should visually feel approximately like:

```text
Hello

This is bold, italic, and code.

• First
• Second

☐ Task
☑ Done

│ Quote

Link

[real code block]
```

The user never needs to encounter:

```text
#
**
*
`
-
- [ ]
>
[ ]
()
```

while using the visual editor.

---

# 53. DELETE ALL OLD WYSIWYG TEST ASSUMPTIONS

Tests that exist only because the previous editor had to:

- hide characters
- translate TextField offsets
- detect fake bullets
- detect fake checklist glyphs
- restore source selections from projected text
- inspect hidden delimiters
- inject visual prefixes

should not simply be patched.

Delete them.

Replace them with semantic-editor tests.

The tests should verify what the user actually experiences rather than preserving implementation quirks of the old editor.

---

# 54. REPOSITORY CLEANUP

After implementation, search the entire repository for obsolete concepts.

Look for:

```text
WysiwygProjectionBuilder
WysiwygEditingController
SourceVisualMapping
visual prefix
Phosphor checkbox glyph
private-use checkbox
WYSIWYG projection
projection text
fake checkbox
hidden delimiter
```

Remove stale references and dead code.

Do not leave misleading names behind.

If `SourceVisualMapping` can be repurposed meaningfully as source-range infrastructure, rename/rebuild it rather than blindly preserving the old abstraction.

The new semantic source mapping should reflect the new architecture.

---

# 55. NO COMPATIBILITY LAYER

This is intentional.

Do NOT:

```text
keep old editor and wrap new editor around it
```

Do NOT:

```text
reuse old WysiwygEditingController internally
```

Do NOT:

```text
reuse old projection builder and add semantic widgets around it
```

Do NOT:

```text
retain fake visual characters because migration is easier
```

Do NOT:

```text
maintain a V3 fallback
```

The old visual editor is being removed because its architecture is the problem.

---

# 56. NO "PATCH UNTIL IT WORKS"

Do not solve individual symptoms with increasingly specific conditions.

For example, avoid solutions like:

```text
if visual text starts with •
if visual text starts with private-use glyph
if cursor is after hidden marker
if selection overlaps **
if this is WYSIWYG and Enter was pressed
if controller came from projection
```

That is precisely the architecture being replaced.

Solve behavior at the semantic-document level.

---

# 57. ERROR SAFETY

If parsing fails:

- never clear the note
- never overwrite canonical Markdown
- never silently normalize malformed content
- render a source-preserving fallback

If a semantic mutation fails:

- preserve the previous canonical Markdown
- preserve user content
- fail gracefully
- never corrupt the note

Do not log decrypted/private note content.

---

# 58. FINAL VERIFICATION COMMANDS

Before declaring the implementation complete, run:

```bash
flutter analyze
flutter test
```

Also perform a repository-wide search for obsolete V3 WYSIWYG components.

Verify:

- no old visual editor production path
- no old projection controller
- no fake checkbox glyph editing
- no fake list-prefix editing
- no WYSIWYG formatter hacks
- no dead imports
- no unused classes
- no TODO placeholders
- no production stubs

---

# 59. MANUAL QA CHECKLIST

Manually test:

### Typing

- paragraph typing
- heading typing
- bold typing
- italic typing
- code typing
- list typing
- checklist typing
- quote typing

### Caret

- start
- middle
- end
- formatting boundary
- block boundary

### Selection

- word
- sentence
- run
- multiple runs
- multiple blocks

### Keyboard

- Enter
- Backspace
- Delete
- arrows
- Home/End
- shortcuts

### Toolbar

- bold
- italic
- strike
- code
- headings
- bullets
- numbered list
- checklist
- quote
- link

### Structures

- tables
- images
- links
- note links
- code blocks
- frontmatter

### Persistence

- autosave
- restart application
- reopen note
- sync
- export
- import
- version history

### Mode switching

```text
Markdown → WYSIWYG
WYSIWYG → Markdown
```

with complex documents.

---

# 60. FINAL SUCCESS CRITERIA

The implementation is complete only when the answer to all of these is YES:

### Does WYSIWYG feel like a real document editor?

YES.

### Are Markdown markers completely absent from the visual editing model?

YES.

### Are bullets and checkboxes real visual controls?

YES.

### Are headings real blocks?

YES.

### Are bold and italic real semantic runs?

YES.

### Are links semantic inline objects?

YES.

### Are code blocks real blocks?

YES.

### Is the table still a real table?

YES.

### Is Markdown still the canonical source?

YES.

### Can every visual edit serialize back to correct Markdown?

YES.

### Can every supported Markdown construct be loaded back into the visual editor?

YES.

### Does caret movement ignore Markdown delimiters?

YES.

### Does selection ignore Markdown delimiters?

YES.

### Does Enter behave naturally?

YES.

### Does Backspace behave naturally?

YES.

### Does undo/redo work at logical-action granularity?

YES.

### Does mode switching preserve the document?

YES.

### Does frontmatter remain safe and synchronized?

YES.

### Are unsupported constructs preserved?

YES.

### Does large-document performance remain safe?

YES.

### Has the old visual editor actually been removed?

YES.

### Are there no V3 WYSIWYG compatibility hacks left?

YES.

---

# 61. THE ARCHITECTURAL RULE TO FOLLOW

The old editor tried to do this:

```text
Markdown
   ↓
hide Markdown characters
   ↓
make TextField behave like a document editor
```

Do not recreate that.

The new editor must do this:

```text
Markdown
   ↓
Semantic document
   ↓
Real visual blocks and inline runs
   ↓
User edits semantic objects
   ↓
Semantic mutation
   ↓
Canonical Markdown
```

The user's visual editing experience and the Markdown serialization format are intentionally separate concerns.

The editor should feel as though Markdown syntax does not exist.

Because, from the perspective of the visual editor, it doesn't.