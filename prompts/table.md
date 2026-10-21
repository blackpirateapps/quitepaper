# MASTER IMPLEMENTATION PROMPT
## Quiet Paper — Hybrid Markdown Table Editor
### Spreadsheet-Like Table Editing With Markdown as the Single Source of Truth

You are working inside the existing Quiet Paper Flutter application.

Implement a production-ready **hybrid Markdown table editor**.

The goal is to make Markdown tables feel like a lightweight spreadsheet while preserving Quiet Paper's core architectural invariant:

> **Markdown remains the single canonical source of truth.**

The user must be able to interact with a table as a real visual grid:

- visible rows and columns
- cell selection
- cell cursor/editing
- Tab navigation
- Shift+Tab navigation
- Enter behavior
- add/remove rows
- add/remove columns
- column alignment
- selection-aware formatting
- inline Markdown formatting inside cells
- copy/paste
- undo/redo
- keyboard navigation
- touch interaction

while the underlying stored note remains ordinary Markdown table syntax.

Example canonical source:

```markdown
| Feature | Status | Notes |
|---------|--------|-------|
| OCR     | Done   | Local |
| Sync    | Done   | E2E   |
| Tables  | WIP    | V3    |
```

The user should visually experience something closer to:

```text
┌──────────┬─────────┬──────────┐
│ Feature  │ Status  │ Notes    │
├──────────┼─────────┼──────────┤
│ OCR      │ Done    │ Local    │
│ Sync     │ Done    │ E2E      │
│ Tables   │ WIP     │ V3       │
└──────────┴─────────┴──────────┘
```

The visual table is an editing surface.

The Markdown remains the document.

---

# 1. NON-NEGOTIABLE ARCHITECTURAL RULE

Do NOT introduce a second canonical representation.

Do NOT store table data as:

- JSON
- Delta
- Quill document
- ProseMirror document
- HTML
- database rows
- rich-text objects
- serialized Flutter widgets

Do NOT convert the entire note into an AST and make that AST the persisted document.

The only canonical persisted content is the existing Markdown string.

The table editor is a **temporary editing projection** over a Markdown region.

Conceptually:

```text
                Canonical Markdown
                       │
                       ▼
              Markdown block parser
                       │
                 detects table
                       │
                       ▼
               TableProjection
                 /          \
                /            \
      Normal Markdown       Hybrid Table UI
        Text Editor               │
                                  │
                             User edits cell
                                  │
                                  ▼
                         Markdown transformation
                                  │
                                  ▼
                         Canonical Markdown
```

Every table edit must ultimately mutate the Markdown source string.

---

# 2. EXISTING EDITOR ARCHITECTURE

Before coding, inspect the current implementations of:

- `MarkdownTokenizer`
- `MarkdownParser`
- `MarkdownEditingController`
- `MarkdownTextInputFormatter`
- `MarkdownFormatter`
- `MarkdownEditor`
- `EditorScreen`
- `FormattingToolbar`
- context menu implementation
- undo/redo
- selection handling
- checklist hit-testing
- Markdown preview
- search/highlight integration
- typography settings

The current editor already supports:

- H1–H6
- bold
- italic
- bold italic
- strikethrough
- highlight
- inline code
- fenced code blocks
- unordered lists
- ordered lists
- blockquotes
- checklists
- links
- tags
- escaping
- tolerant incomplete Markdown parsing.

It also already supports:

- smart list/checklist continuation
- code-fence safety
- delimiter pairing/skipping
- selection-aware formatting
- keyboard shortcuts
- native undo/redo integration
- interactive checklist toggling.

Do not regress any of those behaviors.

---

# 3. WHY HYBRID MODE IS REQUIRED

Do not attempt to make a standard `EditableText` visually behave like a complete spreadsheet through TextSpan styling alone.

Simple syntax styling is appropriate for:

```text
**bold**
# Heading
- List
> Quote
```

but tables have fundamentally different editing semantics.

Tables require:

- cell boundaries
- navigation between cells
- row/column operations
- alignment
- insertion/deletion
- structured selection

Therefore implement a **hybrid table editing region**.

The normal Markdown editor remains active outside tables.

---

# 4. USER EXPERIENCE MODEL

When the cursor is outside a table:

```text
normal Markdown editor
```

When the cursor enters a valid Markdown table:

```text
hybrid table editing surface
```

The table region becomes visually spreadsheet-like.

The rest of the document remains the existing Markdown editor.

Example:

```text
Normal paragraph...

┌──────────┬─────────┐
│ Name     │ Status  │
├──────────┼─────────┤
│ OCR      │ Done    │
│ Sync     │ Done    │
└──────────┴─────────┘

Another paragraph...
```

Do not replace the entire EditorScreen with a spreadsheet.

Only the table block is hybridized.

---

# 5. TABLE DETECTION

Add robust table detection to the Markdown block parser/tokenizer.

Recognize GitHub-Flavored Markdown table structure:

```markdown
| Header 1 | Header 2 |
|----------|----------|
| Value 1  | Value 2  |
```

Also support:

```markdown
Header 1 | Header 2
---------|---------
Value 1  | Value 2
```

if compatible with the application's chosen Markdown parser.

Support optional leading/trailing pipes:

```markdown
| A | B |
|---|---|
| C | D |
```

and:

```markdown
A | B
--|--
C | D
```

Do not misidentify ordinary text containing a pipe as a table.

A valid table must have:

1. header row
2. delimiter/separator row
3. at least one column
4. syntactically valid separator cells

---

# 6. CODE FENCE SAFETY

Do NOT detect table syntax inside fenced code blocks.

Existing code-fence handling must remain authoritative.

For example:

````markdown
```text
| A | B |
|---|---|
```
````

must remain a code block.

No table projection must be created.

The current editor already explicitly protects formatting behavior inside fenced code blocks.

---

# 7. TABLE PROJECTION MODEL

Create an internal immutable table projection model.

Conceptually:

```text
MarkdownTable
    sourceStart
    sourceEnd
    header
    rows
    alignment
    columns
```

Each cell should have enough information to map back to source:

```text
TableCell
    rowIndex
    columnIndex
    sourceStart
    sourceEnd
    contentStart
    contentEnd
    rawText
```

Do NOT use the projection as persistence.

It exists only to translate between:

```text source offsets
↔
table coordinates
```

---

# 8. SOURCE OFFSET MAPPING

This is critical.

Every table cell must have an exact mapping back to the canonical Markdown source.

For example:

```markdown
| Name | Status |
|------|--------|
| OCR  | Done   |
```

The projection must know:

```text
row 0 col 0 → source range
row 0 col 1 → source range
row 1 col 0 → source range
row 1 col 1 → source range
```

Do not derive source positions from approximate string searches after editing.

Use parsed source offsets.

---

# 9. SOURCE-PRESERVING TRANSFORMATIONS

All table operations must be implemented as pure source transformations where possible.

Examples:

```text
add row
delete row
add column
delete column
move cursor
change alignment
edit cell
```

must produce a new Markdown string.

Do not mutate an in-memory table and then regenerate the entire document blindly if doing so could destroy:

- spacing
- inline Markdown
- escaped pipes
- formatting
- comments
- surrounding content

Prefer minimal source edits.

---

# 10. CELL EDITING

When the user taps/clicks a cell:

- activate that cell
- position the caret appropriately
- show the cell content in an editable field or editing overlay
- preserve inline Markdown

Example source:

```markdown
| **OCR** | ==Done== |
```

The cell visually shows:

```text
OCR      Done
```

but editing must preserve:

```markdown
**OCR**
```

and:

```markdown
==Done==
```

Do not flatten cell content to plain text.

---

# 11. INLINE MARKDOWN INSIDE CELLS

Support the Markdown constructs already supported by the editor inside table cells:

- bold
- italic
- strike
- highlight
- inline code
- links
- tags

Use the same inline parser/renderer used by the editor.

Do not create a second inline formatting grammar for tables.

---

# 12. NESTED BLOCK MARKDOWN INSIDE CELLS

GFM table cells do not support arbitrary block structures reliably.

Do not attempt to make table cells support:

- full nested paragraphs
- arbitrary fenced code blocks
- nested tables
- blockquotes spanning rows

unless the underlying Markdown format actually supports them.

Keep the initial table cell model intentionally constrained to inline content.

Gracefully preserve unsupported source syntax rather than silently destroying it.

---

# 13. ESCAPED PIPE HANDLING

This is essential.

A pipe inside a table cell can be literal if escaped:

```markdown
| Name | Description |
|------|-------------|
| A    | x \| y     |
```

The `\|` must NOT be interpreted as a column separator.

The parser must correctly distinguish:

```text
structural |
```

from:

```text
escaped \|
```

Also consider inline code contexts where a pipe appears.

Do not split cells naively with:

```dart
line.split('|')
```

---

# 14. INLINE CODE PIPE HANDLING

For:

```markdown
| Example | Value |
|---------|-------|
| `a|b`   | test  |
```

the pipe inside inline code must remain part of the cell content if the Markdown grammar permits it.

Implement context-aware cell splitting.

Do not use a naive regular expression that breaks valid content.

---

# 15. TABLE WIDTH / COLUMN LAYOUT

The hybrid table UI should calculate column widths.

Default strategy:

- distribute width sensibly
- give longer columns more room
- prevent tiny unusable cells
- cap extremely wide columns
- support horizontal scrolling when necessary

Do NOT force every column to equal width.

For example:

```text
Name      20%
Description 50%
Status     15%
Date       15%
```

could be approximated dynamically.

The exact algorithm should be determined from content and available width.

---

# 16. MINIMUM CELL WIDTH

No cell should become so narrow that text is impossible to edit.

If total natural width exceeds available width:

- allow horizontal scrolling
- maintain visible column boundaries
- do not compress text to unreadable sizes

Do not reduce typography just to make a giant table fit.

---

# 17. HORIZONTAL SCROLLING

Large tables should be horizontally scrollable.

Vertical document scrolling must continue to work naturally.

Be careful about nested scrollables.

Preferred interaction:

- vertical gesture → document scroll
- horizontal gesture inside table → table horizontal scroll

Do not break the editor's normal vertical scroll behavior.

---

# 18. TABLE HEADER

Visually distinguish the header row.

Possible treatment:

- subtle weight increase
- slightly different background
- bottom divider
- compact typography

Do not make it look like a Material DataTable.

The table should remain visually consistent with Quiet Paper's editorial style.

---

# 19. GRID LINES

Use restrained borders.

Do not create a heavy spreadsheet grid.

Recommended:

- subtle horizontal dividers
- subtle vertical separators
- soft background for header
- clear active-cell border/accent

The goal is:

> spreadsheet usability without spreadsheet visual noise.

---

# 20. ACTIVE CELL

The currently active cell should be obvious.

Use:

- subtle accent outline
- mild tinted background
- cursor

Do not use a thick bright border.

Follow Quiet Paper's existing accent tokens.

---

# 21. CELL SELECTION

Support:

- single-cell selection
- text selection within a cell
- multi-cell selection where practical

For initial implementation, prioritize:

1. text selection inside a cell
2. cell navigation
3. row/column operations

Multi-cell range selection may be added if it can be implemented cleanly.

Do not build an unusably complex spreadsheet selection model merely for parity with Excel.

---

# 22. TAB NAVIGATION

Inside a table:

```text
Tab
```

moves to the next cell.

For example:

```text
A1 → B1 → C1 → A2
```

At the last cell:

```text
Tab
```

creates a new row and moves to its first cell.

This behavior must be configurable internally but enabled by default.

---

# 23. SHIFT+TAB

Inside a table:

```text
Shift+Tab
```

moves to the previous cell.

At the first cell:

- remain in first cell
- do not unexpectedly delete anything

Do not move focus outside the editor unless explicitly designed.

---

# 24. ENTER BEHAVIOR

Default:

```text
Enter
```

in a cell should create a line break within that cell only if that behavior is compatible with the chosen Markdown table representation.

Because ordinary GFM table syntax is line-based, arbitrary literal newlines inside cells are problematic.

Therefore inspect the Markdown grammar and choose one safe behavior.

Recommended initial behavior:

- Enter commits the current cell and moves to the next row's same column only if this remains valid Markdown
- otherwise use Shift+Enter for an inline/newline-like behavior if safely representable

Do not silently generate invalid Markdown.

This behavior must be clearly documented/tested.

---

# 25. ADD ROW

Provide:

```text
Add row below
Add row above
```

The default action should insert a row below the current row.

Example:

```markdown
| A | B |
|---|---|
| 1 | 2 |
```

becomes:

```markdown
| A | B |
|---|---|
| 1 | 2 |
|   |   |
```

Place the cursor in the first newly created cell.

---

# 26. DELETE ROW

Delete the active row.

Do not allow deleting the delimiter/header row accidentally.

If deleting the only body row would leave a header-only table, that is valid if the Markdown parser supports it.

Confirm destructive deletion only where the operation would remove substantial user content.

Do not show confirmation for every normal row deletion.

---

# 27. ADD COLUMN

Provide:

```text
Add column left
Add column right
```

Default:

```text
Add column right
```

Update:

- header row
- delimiter row
- every body row

Preserve existing row content.

If rows have inconsistent cell counts, normalize them safely before the operation.

---

# 28. DELETE COLUMN

Delete the active column.

Do not allow creating a zero-column table.

If there is only one remaining column:

- deleting it should either be prevented
- or convert the table to plain text only if explicitly designed

Preferred:

> prevent deletion of the final column.

Do not silently destroy the table.

---

# 29. COLUMN ALIGNMENT

Support GFM alignment:

```markdown
| Left | Center | Right |
|:-----|:------:|------:|
```

Expose:

```text
Align Left
Align Center
Align Right
```

for the current column.

The operation must modify only the corresponding delimiter cell.

Examples:

```text
:---:
```

for center.

```text
---:
```

for right.

```text
:---
```

for left.

---

# 30. ALIGNMENT UI

Do not put alignment controls permanently in the main editor toolbar.

Show them contextually when:

- table is active
- cell is active
- table selection menu is open

Possible compact contextual toolbar:

```text
Table
[ +Row ] [ +Col ] [ Align ] [ ⋯ ]
```

Then:

```text
Alignment
Left
Center
Right
```

---

# 31. TABLE CONTEXT MENU

When cursor is inside a table, expose contextual actions.

Suggested:

```text
Table

Add Row Above
Add Row Below

Add Column Left
Add Column Right

Delete Row
Delete Column

Alignment
```

Do not overwhelm the normal editor menu.

Only show table actions inside tables.

---

# 32. TABLE FLOATING TOOLBAR

If the existing selection/context toolbar architecture supports it, extend it.

The normal editor already has a selection-aware context menu with formatting operations.

Inside a table, it may become:

```text
+ Row
+ Column
Align
Delete
```

Keep it compact.

---

# 33. INSERT TABLE

Add a real `Insert Table` command.

Possible UI:

```text
Insert Table

Columns
[-] 3 [+]

Rows
[-] 3 [+]

[Insert]
```

or a compact grid picker:

```text
Insert Table
3 × 4
```

The inserted Markdown must be valid.

---

# 34. CURSOR PLACEMENT AFTER INSERT

After insertion:

- table receives focus
- first body cell becomes active
- caret is placed at the first cell's content
- keyboard is opened on mobile where appropriate

Do not leave the cursor at the end of the document.

---

# 35. TABLE INSERTION LOCATION

If there is a selected block of text:

- ask whether the selection should be replaced by the table
- or use the existing block replacement behavior

If there is no selection:

Insert at the current block boundary.

Do not inject a table in the middle of a word.

---

# 36. MULTI-LINE SELECTION → TABLE

Optional but valuable:

Selecting tab/newline-separated text such as:

```text
Name    Status
OCR     Done
Sync    Done
```

and choosing:

> Convert to Table

should generate:

```markdown
| Name | Status |
|------|--------|
| OCR  | Done   |
| Sync | Done   |
```

This is a useful future/optional capability.

Only implement it if it can be done reliably.

---

# 37. MARKDOWN TABLE → NORMAL TEXT

Provide an escape hatch:

> Convert Table to Markdown Text

This should return the region to normal Markdown editing if the user explicitly wants raw syntax.

Do not lose content.

---

# 38. SOURCE MODE

If the application eventually has Source Mode, table regions must naturally display raw Markdown there.

The hybrid editor is presentation only.

It must never block access to the actual Markdown source.

If Source Mode already exists, integrate it correctly.

Do not invent a second document representation.

---

# 39. COPY / PASTE

Copying a table should produce canonical Markdown.

For example:

```markdown
| Name | Status |
|------|--------|
| OCR  | Done   |
```

Copy operation should not produce:

```text
Name\tStatus
OCR\tDone
```

unless the user explicitly chooses:

> Copy as TSV

Potential future enhancement:

```text
Copy Markdown
Copy TSV
```

but default copy should preserve Markdown.

---

# 40. PASTE TSV INTO TABLE

A valuable enhancement:

When a user pastes tab-separated data into an active table cell:

```text
Name    Status
OCR     Done
Sync    Done
```

detect TSV structure and offer:

> Paste as Table

If accepted, insert/expand rows and columns.

Do not automatically interpret arbitrary pasted text as TSV.

---

# 41. PASTE MARKDOWN TABLE

If a Markdown table is pasted into the editor:

- recognize it
- render it as a hybrid table once parsed
- preserve the canonical Markdown source

Do not immediately convert it into a different syntax.

---

# 42. TABLE NORMALIZATION

Existing notes may contain inconsistent tables.

Example:

```markdown
| A | B |
|---|---|
| 1 |
| 2 | 3 | 4 |
```

The editor must not crash.

When entering such a table:

- parse safely
- display missing cells as empty
- represent extra cells if the parser can
- normalize only when the user performs an editing operation

Do NOT silently rewrite the user's table merely by opening the note.

---

# 43. MALFORMED TABLE HANDLING

If the structure is ambiguous or malformed:

Do not force hybrid mode.

Fall back to normal Markdown text presentation.

Show no destructive auto-repair.

Optionally offer:

> Format as Table

as an explicit action.

---

# 44. INCOMPLETE TABLE WHILE TYPING

Typing:

```markdown
| A |
```

must not crash.

Typing:

```markdown
| A | B |
|---|
```

should be tolerated as incomplete syntax.

Only activate full hybrid mode when a complete table structure can be safely identified.

The existing parser explicitly guarantees tolerant handling of incomplete Markdown. Preserve that invariant.

---

# 45. TABLE DETECTION DURING TYPING

Do not reparse the entire multi-megabyte note on every keystroke.

Use the existing large-document/performance architecture.

The current application has explicit safeguards because large notes can reach 1–5 MB and full AST tokenization on every frame causes severe performance problems.

For table detection:

- identify the changed block/region where practical
- invalidate only affected table projection
- reuse cached parsing for unchanged blocks

---

# 46. PERFORMANCE ARCHITECTURE

For normal-size documents:

```text
Markdown
→ block parse
→ table projection
→ editor presentation
```

For large documents:

- preserve the existing high-performance mode
- do not create dozens/hundreds of Flutter widgets for every table cell across the entire document
- only instantiate the hybrid editor representation for the table currently being edited
- non-active tables can remain lightweight rendered spans

This is essential.

---

# 47. ONE ACTIVE TABLE EDITOR AT A TIME

Do not build an entire document of nested editable widgets.

At any point:

```text
zero or one active table editing region
```

is sufficient.

Other tables may render as lightweight visual representations until entered.

This keeps:

- widget count
- memory
- focus complexity
- selection complexity

under control.

---

# 48. TABLE ENTER/EXIT

When the user moves the caret out of the table:

- commit any pending source update
- dispose/close the active table editing projection
- return focus to the normal Markdown editor
- preserve cursor position

Do not leave stale TextEditingControllers attached to the table.

---

# 49. FOCUS ARCHITECTURE

Only one cell should have editing focus at a time.

The application must correctly handle:

- focus changes
- keyboard open/close
- editor dispose
- route changes
- note switching
- read-only mode
- password lock

No hidden focused `TextField` should remain active after leaving the table.

---

# 50. READ-ONLY MODE

The existing editor supports read-only mode and hides the formatting toolbar.

In read-only mode:

- table remains visually formatted
- cells are not editable
- row/column actions disappear
- table navigation may optionally remain available
- copying content remains possible

Do not expose mutation controls.

---

# 51. PASSWORD-PROTECTED NOTES

Protected-note behavior must remain intact.

Until the note is unlocked:

- no table editing
- no Markdown mutation
- no source extraction beyond what the current unlocked presentation already permits

Do not bypass the existing `PasswordUnlockView`/security flow.

---

# 52. UNDO/REDO

Every table mutation must integrate with the existing undo/redo architecture.

Examples:

```text
Insert table
Add row
Delete row
Add column
Delete column
Change alignment
Edit cell
```

must behave as normal editor edits.

The application already creates atomic undo snapshots for programmatic Markdown formatting operations. Extend that concept rather than creating a separate table undo stack.

---

# 53. ATOMIC OPERATIONS

Recommended:

```text
Add Row
→ one undo step

Delete Row
→ one undo step

Add Column
→ one undo step

Delete Column
→ one undo step

Alignment Change
→ one undo step
```

Typing inside a cell should use the existing continuous-typing batching behavior.

Do not create an undo entry per character unnecessarily.

---

# 54. EXTERNAL DATABASE/SYNC UPDATES

If the active note changes externally due to:

- sync
- version restore
- another editor instance
- lifecycle update

do not overwrite unsaved table edits.

Follow the existing editor dirty-state/external-update synchronization architecture.

The project already contains protections against stale editor buffers overwriting fresh synced content.

---

# 55. TABLE SOURCE UPDATE STRATEGY

When editing cell content:

1. capture current source version
2. capture cell source range
3. transform that exact range
4. create updated Markdown
5. update controller
6. preserve logical cursor position
7. trigger existing dirty/autosave flow

Never blindly reconstruct the whole note from visible table cells.

---

# 56. CURSOR MAPPING AFTER SOURCE TRANSFORMATION

After editing a cell or changing table structure:

- calculate new source cursor position
- maintain user intent
- preserve selection if practical

Examples:

After:

```text
Add Row Below
```

the cursor should enter the corresponding new row.

After:

```text
Add Column Right
```

the cursor should enter the new cell.

After:

```text
Delete Row
```

the cursor should move to the nearest surviving cell.

Do not dump the caret at position 0.

---

# 57. TABLE CELL TEXTEDITINGCONTROLLER

If using per-cell editable controls:

- do not create one permanent controller for every cell in every table
- instantiate them only for the active table
- dispose deterministically
- synchronize them from canonical source
- avoid controller recursion when source updates

Do not allow cell controllers to become a second source of truth.

---

# 58. CELL STYLE

Use existing Markdown typography settings.

The application already allows user customization of:

- heading font
- body font
- code font
- font size
- line height
- letter spacing
- paragraph width/indent.

Table text must respect body typography.

Inline code inside cells must use code typography.

Heading-like content should not be invented inside normal cells.

---

# 59. DARK MODE

The table surface must work in dark mode.

Use existing Quiet Paper theme tokens.

Check:

- grid lines
- active cell
- header row
- text
- selection
- hover state on desktop
- keyboard focus
- contextual toolbar

Avoid bright spreadsheet-like colors.

---

# 60. MOBILE TOUCH

On mobile:

- cell tap should activate editing
- table should remain horizontally scrollable
- keyboard must not cover the active cell
- active cell should automatically scroll into view
- row/column actions should be accessible without tiny handles

Do not rely on mouse hover.

---

# 61. DESKTOP / TABLET

Support:

- mouse click
- keyboard navigation
- Tab
- Shift+Tab
- arrow keys where appropriate
- context menus
- right-click if the platform supports it

Do not make mobile interaction dependent on desktop focus mechanics.

---

# 62. ARROW KEY NAVIGATION

Inside the table, support:

```text
Arrow Left
Arrow Right
Arrow Up
Arrow Down
```

to navigate between cells when the caret is at an appropriate boundary.

Do not hijack arrows while the user is moving within normal text inside a cell unless navigation intent is clear.

Recommended:

- Left/Right normally move inside the current cell
- Up/Down navigate rows only when caret is at the corresponding line boundary or when cell content is single-line

Be conservative.

---

# 63. TAB CONFLICT WITH FOCUS TRAVERSAL

The table must intercept Tab only while the table cell editor is active.

Outside the table:

- Tab behavior remains normal

Inside the table:

- Tab navigates cells

On desktop, ensure this does not break application-level keyboard focus traversal when the user intentionally exits the editor context.

---

# 64. SELECTION FORMATTING INSIDE CELLS

The existing formatting toolbar must work inside cells.

Example:

Select text:

```text
OCR
```

Tap Bold.

Canonical source becomes:

```markdown
| **OCR** | Done |
```

not:

```text
| OCR | Done |
```

with styling stored outside Markdown.

---

# 65. TAGS INSIDE CELLS

Existing hashtag semantics may appear in cells.

For example:

```markdown
| Topic | |
|---|---|
| #flutter | |
```

The tag should retain existing tokenization/visual styling.

Do not automatically create actual note tags merely because a hashtag appears in a table cell unless the existing tag extraction semantics already do so.

---

# 66. LINKS INSIDE CELLS

Support:

```markdown
| Resource |
|---|
| [Quiet Paper](https://...) |
```

Links should remain interactive in preview mode.

During editing they should remain source-editable.

Do not hijack every tap on the link and prevent editing.

Use a deliberate gesture/interaction distinction.

---

# 67. SEARCH HIGHLIGHTING

The existing editor supports in-note search and styled search matches inside Markdown presentation.

Search highlighting must continue to work inside table cells.

Do not modify search offsets incorrectly because the table projection hides Markdown delimiters.

Search positions must map back to source coordinates correctly.

---

# 68. SEARCH/EDIT TRANSITION

If search is active and a table cell contains a match:

- show the search highlight
- allow navigation to it
- activating the match should focus the correct cell
- preserve the exact source offset

Do not lose search state when entering hybrid table mode.

---

# 69. MARKDOWN PREVIEW CONSISTENCY

The Preview mode must render exactly the same canonical table Markdown.

The editor's hybrid appearance is an editing projection.

Preview remains the final Markdown-rendered representation.

Do not make the table editor write special syntax that Preview does not understand.

---

# 70. EXPORT CONSISTENCY

Markdown export must preserve the actual Markdown source.

HTML/PDF/DOCX renderers must receive canonical Markdown and render the table structurally.

The table editor must not require special export-only table data.

---

# 71. SEARCH INDEX CONSISTENCY

Table cell text remains part of canonical Markdown.

Therefore:

- existing FTS indexing should continue to capture it according to current search projection rules
- no separate table search index is required
- no duplicate content should be inserted into FTS

Do not change search architecture merely because tables become visually hybrid.

---

# 72. NOTE VERSION HISTORY

Table edits are normal Markdown edits.

They must flow through existing version history/session tracking.

Do not create table-specific versions.

A substantive table edit should naturally contribute to the note's existing version history.

---

# 73. AUTOSAVE

Table edits must use the existing editor dirty/autosave pipeline.

Do not write directly to SQLite from the table widget.

The flow should be:

```text
table interaction
→ Markdown source transformation
→ editor state
→ existing dirty tracking
→ existing autosave
→ repository
```

---

# 74. SYNC

Table operations must automatically participate in existing note synchronization because the canonical Markdown changes.

Do not add:

- table-specific sync records
- table IDs
- table conflict records

The sync engine should see an ordinary note-content change.

---

# 75. CONFLICT RESOLUTION

If a sync conflict occurs, table data must remain ordinary Markdown within the existing conflict/version architecture.

Do not build table-specific conflict logic.

---

# 76. TABLE INSERTION FROM TOOLBAR

Add a Table action to the existing formatting UI.

It should not dominate the toolbar.

Possible icon:

```text
table_chart
```

or an existing project-consistent table icon.

Do not add huge labels.

---

# 77. TOOLBAR CONTEXT

Normal editor toolbar:

```text
Undo Redo
Bold Italic Strike Code Link
...
Table
```

Table active:

```text
+Row +Column
Align
Delete
...
```

Use the context-aware philosophy rather than making every control permanently visible.

---

# 78. SLASH COMMAND

If implementing slash commands, include:

```text
Table
```

under block insertion commands.

Example:

```text
/
Heading
Quote
Bullet List
Numbered List
Checklist
Code Block
Table
Divider
```

Do not require a slash-command system if it doesn't already exist; this can remain an extension point.

---

# 79. TABLE CREATION DIALOG

The table creation UI should be minimal.

Example:

```text
Insert Table

3 × 3
```

Use either:

- grid picker
- compact row/column selectors

Do not make the dialog large.

After insertion, focus the first body cell.

---

# 80. TABLE ACTIONS SHEET

Mobile long-press/tap action can show:

```text
Table
──────────────
Add Row Above
Add Row Below
Add Column Left
Add Column Right
Alignment
Delete Row
Delete Column
```

Use the existing action sheet style.

---

# 81. TABLE CONTEXTUAL DECORATION

Do not put giant resize handles on every cell.

Avoid looking like Excel.

Use simple boundaries and a lightweight active-cell indicator.

---

# 82. COLUMN RESIZING

Manual column resizing can be a future feature.

Do not implement complex persistent column widths unless there is a Markdown-compatible way to represent them.

Remember:

> Markdown does not natively persist arbitrary pixel widths.

Therefore the visual column width is presentation state, not document state.

Do not store column widths in a second note model.

---

# 83. RESPONSIVE COLUMN WIDTHS

Column width can be computed dynamically at runtime.

It may change when:

- viewport changes
- tablet rotates
- editor width changes
- font settings change

No Markdown mutation should occur because of a visual width change.

---

# 84. TABLE HEADER ALIGNMENT

Changing a column's alignment modifies its separator row.

Example:

Before:

```markdown
| Name |
|------|
```

After center:

```markdown
| Name |
|:----:|
```

Do not add alignment metadata elsewhere.

---

# 85. CELL MARKDOWN ESCAPING

When inserting plain user-entered text into a cell, escape structural characters when necessary.

For example:

User types:

```text
A | B
```

inside a cell.

The source must become:

```markdown
A \| B
```

rather than accidentally creating a new column.

This escaping must be context-aware.

---

# 86. CELL RECONSTRUCTION

When replacing a cell's content:

- preserve alignment row
- preserve other cells
- preserve row delimiters
- preserve surrounding whitespace as reasonably possible
- maintain valid Markdown syntax

Do not normalize every table row unnecessarily.

---

# 87. TABLE NORMALIZATION POLICY

Do not automatically beautify every table.

Preserve existing user formatting when possible.

For example, don't automatically turn:

```markdown
|A|B|
|---|---|
|C|D|
```

into:

```markdown
| A | B |
|---|---|
| C | D |
```

unless a table operation requires reconstruction.

User content preservation is more important than aesthetic normalization.

---

# 88. TABLE EDITING OF EXISTING NON-NORMALIZED TABLES

When entering a malformed-but-recoverable table:

- project it
- preserve original style where practical
- normalize only the rows touched by an operation if necessary
- never rewrite unrelated note content

---

# 89. TABLE PARSER TEST MATRIX

Test:

```text
standard GFM
leading pipe
trailing pipe
no leading pipe
no trailing pipe
escaped pipe
inline code containing pipe
empty cells
empty header cells
duplicate headers
Unicode
very long cells
multiple rows
multiple columns
inconsistent row lengths
missing delimiter
malformed delimiter
table-like text
table inside code fence
```

---

# 90. TABLE TRANSFORMATION TEST MATRIX

Test:

```text
insert table
edit first cell
edit middle cell
edit last cell
add first row
add middle row
add last row
delete first body row
delete middle row
delete last body row
add first column
add middle column
add last column
delete column
align left
align center
align right
multiple operations
undo each operation
redo each operation
```

---

# 91. CURSOR / SELECTION TESTS

Test:

- click cell
- enter cell
- Tab
- Shift+Tab
- arrow navigation
- selection
- replace selected text
- formatting selection
- copy
- paste
- focus loss
- keyboard dismissal

---

# 92. SOURCE INTEGRITY TESTS

For every table operation verify:

```text id="0w5b4w"
displayed table
=
canonical Markdown projection
```

After every edit:

1. update source
2. reparse affected table
3. verify projection matches source
4. verify surrounding Markdown is unchanged

---

# 93. ROUND-TRIP TESTS

For every supported table fixture:

```text Markdown
→ parse
→ project
→ perform operation
→ Markdown
→ parse again
→ project again
```

The second projection must be consistent with the first intended operation.

---

# 94. DATA LOSS TESTS

Explicitly test cases involving:

- escaped pipes
- inline Markdown
- empty cells
- Unicode
- long content
- rows with missing cells
- duplicate delimiters
- malformed input

No content may be silently lost.

---

# 95. LARGE DOCUMENT TEST

Create a large note containing:

- 100,000+ characters
- multiple unrelated blocks
- at least several tables
- long code blocks
- long lists

Verify that:

- typing outside tables remains responsive
- opening a table does not parse the entire document repeatedly
- editing a table does not cause full-document widget reconstruction
- memory remains reasonable
- UI remains responsive

The current editor's large-document threshold and performance protections must remain effective.

---

# 96. MANY-TABLE TEST

Test a document with 100+ Markdown tables.

Only the active table should instantiate heavyweight interactive editing widgets.

Do not create 100 independent editable grids.

---

# 97. TABLE EXIT TEST

When leaving a table:

- source committed
- active cell disposed
- normal editor resumes
- cursor position is correct
- no ghost table overlay remains
- keyboard behavior returns to normal

---

# 98. NOTE SWITCH TEST

While editing a table:

1. switch notes
2. return to the original note

Verify:

- no stale cell controller remains
- content is saved through the normal pipeline
- selection/focus state is restored appropriately
- no cross-note table state leaks

---

# 99. EDITOR LIFECYCLE TEST

Test:

- open note
- enter table
- rotate device
- background app
- resume
- lock note
- unlock note
- close editor
- reopen editor

No data loss.

---

# 100. TABLE FORMAT COMMANDS

Create reusable pure transformations such as:

```text
insertTable(...)
addRow(...)
deleteRow(...)
addColumn(...)
deleteColumn(...)
setColumnAlignment(...)
updateCell(...)
```

These should operate on `TextEditingValue` or equivalent source-edit models.

Do not couple them to Flutter widgets.

This follows the existing architecture where `MarkdownFormatter` provides pure functional Markdown source transformations.

---

# 101. SOURCE TRANSFORMATION API

A transformation should return enough information for the UI to restore cursor/selection.

Conceptually:

```text
MarkdownEditResult
    newText
    newSelection
    changedRange
```

This is preferable to returning only a new string.

---

# 102. ATOMIC MULTI-CELL OPERATIONS

For operations like:

```text paste TSV
```

create one atomic Markdown edit and one undo step.

Do not create one undo entry per pasted cell.

---

# 103. TABLE NAVIGATION MODEL

Define a typed coordinate:

```text
TablePosition
    row
    column
```

Use it internally.

Do not represent a cell simply by an integer offset.

Maintain both:

```text table coordinates
+
source offsets
```

---

# 104. ACTIVE CELL STATE

The active cell state should be scoped to the active table editor instance.

It should not be persisted in the note.

It should not sync.

It should not become part of version history.

---

# 105. VISUAL TABLE RENDERING

Do not use a raw Flutter `DataTable` if that forces a Material look inconsistent with Quiet Paper.

Build a custom lightweight table editor or adapt an existing suitable primitive.

The visual design should feel:

- editorial
- flat
- warm
- minimal
- touch-friendly

---

# 106. TABLE ROW HEIGHT

Rows should size naturally based on content.

Do not force a fixed one-line height if cell content needs wrapping.

Avoid excessive vertical padding.

---

# 107. CELL TEXT WRAPPING

Allow text to wrap.

A very long word/URL should not break the table layout.

Use reasonable overflow/wrapping behavior.

Do not silently truncate user content.

---

# 108. LONG CONTENT

Long cell content must remain editable.

Examples:

```text
very long URL
long sentence
large inline Markdown
Unicode text
```

Do not cap cell content length.

---

# 109. LARGE TABLE

A table with:

```text
50 columns × 100 rows
```

should not instantiate 5,000 heavy editable widgets simultaneously.

Use virtualization/lazy construction if necessary.

However, only implement this complexity if profiling demonstrates a realistic requirement.

At minimum, instantiate editors lazily.

---

# 110. TABLE OVERLAY / POSITIONING

If using an overlay to transform a region of the normal Markdown editor into a hybrid table:

- calculate source-to-screen mapping carefully
- handle scroll
- handle keyboard insets
- handle rotation
- handle text scaling
- handle tablet split view

Do not rely on fixed pixel coordinates.

---

# 111. NORMAL MARKDOWN TEXT CONTINUITY

Above and below the table:

```text
normal Markdown editor
```

must look exactly as before.

Entering a table should not change surrounding text styling.

---

# 112. TABLE EXIT VISUAL TRANSITION

When leaving table mode:

- remove hybrid controls smoothly
- preserve the document position
- avoid flicker

Do not animate aggressively.

---

# 113. TABLE PREVIEW WHEN NOT ACTIVE

Tables that are not actively being edited can render using a lightweight visual representation.

They should still look better than raw pipes.

Example:

```text
┌──────┬──────┐
│ Name │ Qty  │
├──────┼──────┤
│ Pen  │ 2    │
└──────┴──────┘
```

This keeps the entire editor more WYSIWYG.

However, don't instantiate full edit controllers for inactive tables.

---

# 114. TABLE TAP BEHAVIOR

When tapping an inactive table:

- activate it
- focus the tapped approximate cell
- convert to hybrid editing region
- preserve scroll position

Do not require a second tap just to enter edit mode.

---

# 115. EDITOR PRESENTATION MODE

Do not create a separate "table edit mode" that prevents normal document interaction.

The hybrid table is contextual.

The user remains inside the same document.

---

# 116. SOURCE TRUTH INVARIANT

At all times:

```text
Visible table content
must be derivable from
canonical Markdown
```

and:

```text
canonical Markdown
must be sufficient to reconstruct
the table presentation
```

No hidden data.

No visual-only cell contents.

No detached table objects.

---

# 117. UNDO/REDO INVARIANT

Undo must restore the canonical Markdown exactly.

Redo must restore the exact next Markdown state.

Do not merely restore table widget state.

---

# 118. VERSION HISTORY INVARIANT

Version history should contain the Markdown result exactly as any other editor change.

When a version is inspected, its Markdown must reconstruct the same table.

---

# 119. SYNC INVARIANT

Sync must continue to treat a table edit as normal note-content mutation.

No special table synchronization.

---

# 120. SEARCH INVARIANT

Search must continue to search the canonical Markdown-derived text.

No duplicate indexing.

No table-only indexing.

---

# 121. EXPORT INVARIANT

Every export format must operate from canonical Markdown.

No exporter should require the interactive table state.

---

# 122. ACCESSIBILITY

The hybrid table must expose semantics such as:

```text
Table
3 columns
4 rows

Cell: Status, row 2, column 2
```

Where the platform supports semantic table descriptions, use them.

For screen readers:

- header cells should be identifiable
- active cell should be announced
- row/column actions should have clear labels

Do not make the visual grid inaccessible.

---

# 123. KEYBOARD ACCESSIBILITY

Support:

- Tab
- Shift+Tab
- arrows where appropriate
- Enter behavior
- Escape to exit contextual UI
- copy/paste
- existing editor shortcuts

Existing shortcuts such as:

```text
Ctrl/Cmd+B
Ctrl/Cmd+I
Ctrl/Cmd+Shift+X
Ctrl/Cmd+`
Ctrl/Cmd+K
```

must continue to work inside a table cell.

---

# 124. FORMATTING TOOLBAR INTEGRATION

When the selection is inside a table cell:

Existing actions:

```text
Bold
Italic
Strike
Code
Link
```

must remain available.

Table-specific actions should be additional/contextual rather than replacing standard formatting.

---

# 125. MOBILE KEYBOARD MANAGEMENT

When a cell gains focus:

- ensure it is visible above the keyboard
- scroll the table/document if required
- preserve horizontal scroll
- avoid keyboard-induced layout jumps

Use existing editor keyboard inset handling.

---

# 126. TABLE CONTEXT TOOLING VISUAL STYLE

Do not make a giant spreadsheet toolbar.

A compact action surface is preferred:

```text
+ Row   + Column   Align   ⋯
```

Use Quiet Paper iconography.

---

# 127. ERROR HANDLING

Malformed table parsing must never crash the editor.

If an internal projection operation fails:

- fall back to normal Markdown rendering
- preserve canonical source
- log a safe diagnostic
- do not modify the note automatically

A rendering failure must never become a data-loss event.

---

# 128. LOGGING

Safe diagnostics may include:

```text table detected
rows=N
columns=N
projection duration
transformation type
```

Never log:

- note body
- cell content
- protected content
- passwords
- decrypted OCR

---

# 129. NO NETWORK DEPENDENCY

Table editing must work fully offline.

Do not call network services.

Do not use server-side Markdown parsing.

---

# 130. DEPENDENCY POLICY

Before adding a table/grid package:

1. inspect existing dependencies
2. assess whether it supports source-preserving editing
3. assess whether it is compatible with the current Flutter/Dart version
4. assess whether it imposes a rich-text/document model
5. assess whether it performs well on mobile
6. assess maintenance quality

Do not add a package that forces the canonical document to become JSON.

A custom lightweight hybrid component may be preferable.

---

# 131. NO DATABASE MIGRATION

This feature should require **no database migration**.

Tables are represented inside the existing Markdown string.

Do not add table columns to the Notes table.

---

# 132. NO CLOUD MIGRATION

Do not change:

- Turso schema
- sync payloads
- encrypted content envelopes
- backend note schema

The canonical Markdown already flows through the existing encryption/sync pipeline.

---

# 133. IMPORT COMPATIBILITY

Existing imported Markdown files containing GFM tables must automatically render as tables.

The current Markdown importer already preserves Markdown content and supports GFM content such as tables.

Do not add an import-specific table format.

---

# 134. WEB CLIPPER COMPATIBILITY

The Web Clipper already generates GFM tables where applicable.

Those imported/clipped tables must automatically become hybrid-editable.

Do not alter the Web Clipper's Markdown representation just for this feature.

---

# 135. PREVIEW COMPATIBILITY

Verify that:

```markdown
| A | B |
|---|---|
| C | D |
```

renders consistently in:

- Editor hybrid mode
- Markdown Preview
- HTML export
- PDF export
- DOCX export
- QPNOTE Markdown content

The underlying source must remain identical.

---

# 136. TABLE STYLE CONSISTENCY

Use the existing:

- AppColors
- AppTypography
- MarkdownStyles
- typography settings
- spacing tokens
- theme infrastructure

Do not invent a separate table theme.

---

# 137. TYPOGRAPHY SETTINGS

Changing:

- font size
- body font
- line height
- letter spacing

must update the table presentation appropriately.

Do not persist table-specific font settings.

---

# 138. LARGE FONT ACCESSIBILITY

Test table editing at increased system text scaling.

The table must remain usable.

Possible response:

- increase row heights
- allow more wrapping
- preserve touch targets

Do not clamp text to keep rows short.

---

# 139. RTL / INTERNATIONALIZATION

Do not assume only left-to-right text.

Even if initial product support is English-first, table cell content may contain Unicode and RTL text.

Ensure:

- text layout respects Flutter text direction
- source offsets remain UTF-16-safe
- pipe parsing does not corrupt Unicode
- cursor movement remains correct

---

# 140. EMOJI

Cells may contain emoji.

Do not strip or corrupt them.

The source must remain unchanged.

---

# 141. COMBINED MARKDOWN EDGE CASES

Test combinations such as:

```markdown
| Name | Description |
|------|-------------|
| **OCR** | ==Done== |
| `sync` | [link](https://example.com) |
```

The hybrid table must visually render all supported inline syntax.

---

# 142. TABLE + LIST ADJACENCY

Test:

```markdown
- list item

| A | B |
|---|---|
| C | D |

- another list
```

No block should accidentally be swallowed into the table.

---

# 143. TABLE + HEADING ADJACENCY

Test:

```markdown
## Heading

| A | B |
|---|---|
| C | D |

## Next
```

No heading should be interpreted as part of the table.

---

# 144. TABLE + CODE ADJACENCY

Test:

````markdown
| A | B |
|---|---|
| C | D |

```dart
final x = 1;
```
````

Both blocks must remain correctly recognized.

---

# 145. TABLE + QUOTE ADJACENCY

Test:

```markdown
> quote

| A | B |
|---|---|
| C | D |
```

No parser leakage between blocks.

---

# 146. TABLE + CHECKLIST

Test:

```markdown
| Task | Done |
|------|------|
| OCR  | [x] |
```

Treat `[x]` as cell content unless the GFM grammar and existing parser explicitly supports task-list semantics inside table cells.

Do not invent semantics.

---

# 147. CONTENT PRESERVATION

The table editor must preserve unknown/unrecognized Markdown inside cells as much as possible.

Do not aggressively sanitize content.

---

# 148. MALFORMED SOURCE SAFETY

If parsing a malformed table fails:

```text
canonical source remains untouched
```

The user can still edit it using normal Markdown mode.

---

# 149. PERFORMANCE BOUNDARY

The current editor uses a special high-performance presentation mode above approximately 60,000 characters.

Respect this.

For massive notes:

- table detection must be lazy
- hybrid tables must activate only on demand
- no entire-document grid construction
- no repeated whole-document parsing
- no unbounded widget tree

---

# 150. IMPLEMENTATION PHASES

Implement in controlled phases.

## Phase 1 — Shared Markdown table parser

Implement:

- detection
- header parsing
- separator parsing
- row parsing
- escaped pipe handling
- source offsets
- alignment extraction
- malformed/incomplete handling

## Phase 2 — Source transformations

Implement pure operations:

- insert table
- update cell
- add row
- delete row
- add column
- delete column
- alignment

## Phase 3 — Lightweight visual table rendering

Implement non-editing visual representation.

## Phase 4 — Active table hybrid editor

Implement:

- cell editing
- focus
- cursor mapping
- Tab
- Shift+Tab

## Phase 5 — Table operations UI

Implement:

- row actions
- column actions
- alignment
- contextual menu

## Phase 6 — Integration

Integrate with:

- undo/redo
- autosave
- search
- typography
- read-only
- password lock
- preview
- export
- sync

## Phase 7 — performance and hardening

Implement:

- lazy active table
- large-note safeguards
- lifecycle handling
- regression tests
- visual testing

---

# 151. TESTING — UNIT

Create comprehensive tests for:

### Parser

- normal table
- pipe variations
- alignment
- escaped pipes
- inline code pipes
- empty cells
- malformed tables
- code fences
- Unicode

### Transformations

- add row
- delete row
- add column
- delete column
- alignment
- cell replacement
- table insertion

### Mapping

- source offset → cell
- cell → source offset
- cursor transformation
- selection transformation

---

# 152. TESTING — WIDGET

Test:

- table appears visually
- table is not rendered as raw pipes when complete
- tapping cell activates it
- editing updates canonical Markdown
- Tab moves across cells
- Shift+Tab moves backwards
- adding rows works
- deleting rows works
- adding columns works
- deleting columns works
- alignment works
- contextual toolbar works
- read-only prevents mutation

---

# 153. TESTING — UNDO/REDO

For every table mutation:

```text
perform action
→ undo
→ exact previous Markdown restored

redo
→ exact post-action Markdown restored
```

Do not merely test visual appearance.

---

# 154. TESTING — AUTOSAVE

Edit a table cell.

Verify:

```text
controller state
→ dirty state
→ autosave
→ repository
→ database
```

and reload the note.

The table must remain correct.

---

# 155. TESTING — SYNC

Modify a table.

Verify:

- note becomes dirty using normal mechanisms
- sync payload contains ordinary encrypted Markdown
- no table-specific payload exists
- another device can sync and render the same table

---

# 156. TESTING — SEARCH

Search for:

- table header
- table cell content
- content inside formatted cells
- Unicode cell content

Verify existing Search architecture finds it.

Do not introduce a second table index.

---

# 157. TESTING — PREVIEW

Verify editor table source produces the expected Preview rendering.

The canonical Markdown must be identical before and after opening/closing the table editor.

---

# 158. TESTING — EXPORT

Verify:

```text
Markdown export
PDF
HTML
DOCX
QPNOTE
```

all receive the canonical table Markdown.

No export-specific table model is required.

---

# 159. TESTING — LARGE NOTE

Create a large document around/above the current large-document threshold and verify:

- scrolling
- typing
- search
- table activation
- table editing
- editor responsiveness

Do not regress the existing large-document performance protections.

---

# 160. TESTING — LIFECYCLE

Test:

- note switch
- app background
- app resume
- rotation
- keyboard dismissal
- editor close
- note lock
- note unlock

No table content loss.

---

# 161. TESTING — MALFORMED USER CONTENT

Verify malformed tables never crash.

Examples:

```markdown
| A | B
|---|
```

```markdown
| A | B |
|---|
| C
```

```markdown
| A | B |
|x|y|
```

```markdown
| A \| B | C |
|--------|---|
```

A malformed table must fall back gracefully.

---

# 162. VISUAL DESIGN REQUIREMENTS

The hybrid table must NOT look like Microsoft Excel.

Avoid:

- blue Excel-style selection
- heavy gridlines
- dense toolbar
- tiny text
- column headers with giant backgrounds
- floating resize handles everywhere

Target:

```text
Quiet Paper
+
light spreadsheet affordance
+
editorial typography
```

---

# 163. VISUAL HIERARCHY

The table should visually communicate:

```text
header
↓
cells
↓
active cell
```

not:

```text
grid lines
grid lines
grid lines
```

Content should remain more visually important than borders.

---

# 164. ACTIVE CELL STYLE

Use the existing accent color subtly.

Possible:

- 1px border
- mild translucent background
- caret

No thick rectangle.

---

# 165. HEADER STYLE

Header row should have:

- slightly stronger font weight
- subtle background tint
- subtle bottom boundary

Do not use dark filled header bands.

---

# 166. TOUCH TARGETS

Cells must remain comfortably tappable.

Do not make row heights microscopic merely to mimic spreadsheets.

---

# 167. EMPTY CELLS

Empty cells must still be obvious and editable.

Tapping an empty cell should put the cursor there.

---

# 168. TABLE CREATION DEFAULT

Default insertion:

```text
3 columns
3 body rows
```

or another sensible small size.

The user can immediately Tab through cells.

---

# 169. TABLE HEADER EDITING

Headers are editable exactly like body cells.

Do not treat them as static labels.

---

# 170. HEADER DELETE SAFETY

Do not allow accidentally deleting the header row via ordinary Delete Row action without an explicit decision.

Header structure is required by the Markdown table format.

---

# 171. EMPTY TABLE

Support:

```markdown
| A | B |
|---|---|
```

as a valid table.

Do not require body rows.

---

# 172. SINGLE-CELL TABLE

Do not create a zero-column state.

Single-column tables remain valid.

---

# 173. MINIMUM TABLE

The smallest valid table should be supported:

```markdown
| A |
|---|
```

If the underlying parser accepts it.

---

# 174. TABLE CONVERSION ROBUSTNESS

If "Convert to Table" is implemented:

- detect row delimiters
- detect column separators
- preserve text
- escape pipes
- generate correct separator row

Do not lose tabs or line boundaries.

---

# 175. PLAIN TEXT CONVERSION

If future support exists for converting a table to plain text:

Use a readable representation.

Do not destroy content during conversion.

---

# 176. TABLE DELETION

Provide:

> Delete Table

only as an explicit contextual action.

It must delete the entire table Markdown block as one atomic undoable edit.

Warn if the table contains substantial content only if the application's existing destructive-action policy requires it.

---

# 177. TABLE DUPLICATION

Consider a contextual action:

> Duplicate Table

This can be useful but is optional.

If implemented, duplicate the source Markdown block correctly.

Do not create a hidden table object.

---

# 178. MOVE ROW UP/DOWN

Optional but useful:

```text
Move Row Up
Move Row Down
```

Only implement if source transformations remain reliable.

Do not prioritize ahead of core editing.

---

# 179. SORT TABLE

Do NOT implement automatic row sorting in the first table-editor release unless explicitly desired.

Sorting rows sounds simple but can destroy semantic relationships.

Keep table editing focused on structure.

---

# 180. FORMULA SUPPORT

Do NOT implement spreadsheet formulas.

Markdown tables are not spreadsheets in terms of data semantics.

The hybrid UI is spreadsheet-like for editing, not a spreadsheet engine.

No:

```text
=SUM(...)
```

evaluation.

---

# 181. COLUMN FILTERING

Do NOT implement spreadsheet filters.

This is a document table.

Keep the feature focused.

---

# 182. CELL MERGING

Do NOT implement merged cells.

Standard Markdown tables do not represent them reliably.

Do not invent proprietary syntax.

---

# 183. ROW SPANNING

Do NOT implement row/column spans.

Preserve compatibility with standard Markdown.

---

# 184. SORTABLE / RESIZABLE COLUMNS

Visual resizing can be temporary.

Do not persist proprietary width metadata.

If implementing resizing, treat it as presentation state only.

---

# 185. TABLE DESCRIPTION / ACCESSIBILITY

Allow screen readers to understand:

- table boundaries
- header
- current row/column
- cell content

Do not expose raw pipe syntax as the primary semantic representation in accessibility mode.

---

# 186. TABLE STYLE IN SOURCE MODE

Source mode must display the raw Markdown exactly.

No visual abstraction should mutate the source.

---

# 187. EDITOR SELECTION INVARIANT

Outside hybrid mode:

- existing selection offsets remain unchanged

Inside hybrid mode:

- source selections map correctly to cells

When exiting:

- final selection returns to the canonical Markdown offsets

This is essential to the existing editor's 1:1 cursor architecture.

---

# 188. NO HIDDEN CONTENT

Every visual cell must correspond to source content.

Do not display:

```text
cell value from table model
```

if that value does not exist in Markdown.

---

# 189. NO TABLE DATABASE MODEL

Do not create tables such as:

```text
note_tables
table_rows
table_cells
```

The note already stores Markdown.

This feature must remain schema-free.

---

# 190. CODE ORGANIZATION

Prefer a structure conceptually similar to:

```text
lib/features/editor/
    domain/
        markdown_table.dart
        markdown_table_cell.dart
        markdown_table_position.dart
        markdown_table_alignment.dart

    application/
        markdown_table_parser.dart
        markdown_table_formatter.dart
        markdown_table_projection.dart
        markdown_table_controller.dart

    presentation/
        widgets/
            markdown_table_view.dart
            markdown_table_editor.dart
            markdown_table_toolbar.dart
            markdown_table_action_sheet.dart
            table_insert_sheet.dart
```

Adapt this to the existing project structure.

Do not create unnecessary new layers.

---

# 191. STATE MANAGEMENT

Reuse the existing editor state architecture.

Do not introduce another state-management package.

The active table editor can be local state owned by the editor.

Do not persist active cell coordinates.

---

# 192. IMMUTABILITY

Where appropriate:

- table projections immutable
- transformation requests immutable
- table positions immutable
- alignment immutable

Avoid global mutable table state.

---

# 193. DISPOSAL

Every temporary cell controller/focus node/listener must be disposed.

Pay particular attention to:

- table exit
- note switch
- editor dispose
- widget rebuild
- orientation change

---

# 194. REBUILD CONTROL

Changing the active cell must not rebuild the entire EditorScreen unnecessarily.

Changing one cell should not recreate unrelated Markdown blocks.

Use localized rebuilds where practical.

---

# 195. TABLE CACHE INVALIDATION

Cache the parsed table projection only as an optimization.

Invalidate it when:

- source region changes
- note changes externally
- formatting transformation touches the table
- source mode toggles
- note switches

Never serve stale table content.

---

# 196. SEARCH HIGHLIGHT / TABLE PROJECTION COEXISTENCE

The existing search system can highlight matches at source offsets.

The table projection must preserve these mappings.

Do not implement search highlights using table-cell-local offsets only.

Source offset must remain authoritative.

---

# 197. IME COMPATIBILITY

The existing editor has already had Android IME/font/whitespace issues and protects composing ranges.

The table editor must correctly handle:

- composing text
- predictive input
- Gboard
- FUTO
- hardware keyboards
- dead keys
- Unicode composition

Do not treat every `TextEditingValue` update as a completed committed character sequence.

---

# 198. IME COMPOSING

Do not mutate source delimiters around an actively composing region incorrectly.

Cell editing must preserve `composing` state where supported.

Do not break Android IME underline behavior.

---

# 199. AUTOCORRECTION

Do not aggressively reformat table cell text while the IME is composing.

For example, don't escape or normalize every pipe character before the composition is committed unless necessary.

---

# 200. TABLE PERSISTENCE TEST

Close and reopen the app after editing a table.

Verify:

- Markdown survived
- table renders
- formatting survived
- alignment survived
- content survived

---

# 201. CROSS-DEVICE SYNC TEST

On Device A:

```text edit table
```

Sync.

On Device B:

```text receive note
```

The table must render identically.

No device-specific table state should be required.

---

# 202. VERSION RESTORE TEST

Create table.

Edit table.

Create version.

Restore version.

Verify table source and visual table match the restored Markdown.

---

# 203. SECURITY TEST

Protected notes must not leak table content through:

- logs
- table diagnostics
- exception messages
- serialized UI state

---

# 204. NO ANALYTICS

Do not add analytics for:

- number of table cells
- table edits
- table rows
- table operations

unless the application already has an explicit product analytics requirement.

---

# 205. FINAL UX

The intended experience is:

### Normal Markdown

```text
Write naturally...

## Project

Some **formatted** text.

- Task
- Task
```

### Table

```text
┌──────────┬──────────┬──────────┐
│ Feature  │ Status   │ Notes    │
├──────────┼──────────┼──────────┤
│ OCR      │ Done     │ Local    │
│ Sync     │ Done     │ E2E      │
│ Tables   │ Building │ V3       │
└──────────┴──────────┴──────────┘
```

### Underlying canonical source

```markdown
## Project

Some **formatted** text.

| Feature | Status | Notes |
|---------|--------|-------|
| OCR     | Done   | Local |
| Sync    | Done   | E2E |
| Tables  | Building | V3 |
```

The user does not need to manually manage the pipe characters during ordinary table editing.

The application manages them as a presentation/editing projection.

---

# 206. FINAL ACCEPTANCE CRITERIA

The implementation is complete only when:

- Markdown remains the sole canonical source
- no table database schema exists
- no table JSON document model exists
- complete GFM tables are detected
- incomplete tables do not crash
- tables inside code fences are ignored
- escaped pipes are handled correctly
- inline code with pipes is handled correctly
- table cells have exact source mappings
- tables become visually grid-like while active
- inactive tables can render cleanly without heavy widgets
- cell editing updates canonical Markdown
- inline Markdown formatting works inside cells
- Tab moves between cells
- Shift+Tab moves backward
- final Tab creates a new row
- rows can be added/deleted
- columns can be added/deleted
- alignment can be changed
- insert-table action works
- copy returns canonical Markdown
- undo/redo works
- autosave works
- search works
- Preview works
- export works
- sync works
- version history works
- read-only mode works
- protected-note behavior works
- large-note performance remains acceptable
- no data is lost
- no duplicate source-of-truth exists
- accessibility works
- mobile works
- tablet works
- desktop works
- dark mode works
- light mode works
- existing editor functionality remains intact

---

# 207. VERIFICATION

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Do not stop after the new table tests.

Run the complete existing editor/database/search/sync regression suite.

The repository has a substantial body of existing editor, search, OCR, sync and UI tests; table functionality must integrate into that regression surface.

---

# 208. MANUAL QA

Create a note containing:

```markdown
# Table Test

Normal **Markdown** text.

| Name | Status | Notes |
|------|--------|-------|
| OCR | **Done** | ==Local== |
| Sync | `Done` | [Link](https://example.com) |
| A \| B | WIP | `x|y` |

More text below.

> Quote

```dart
final value = 42;
```

- [ ] Task
```

Then manually verify:

1. table visually renders as a grid
2. tap any cell
3. edit content
4. Tab across every cell
5. Shift+Tab back
6. Tab from final cell creates a row
7. add/delete row
8. add/delete column
9. alignment changes
10. bold a cell selection
11. add a link inside a cell
12. copy the table
13. undo/redo every operation
14. close/reopen note
15. search for cell content
16. view Preview
17. export PDF
18. export Markdown
19. test dark mode
20. test tablet
21. test large note
22. verify source Markdown has not been corrupted

---

# 209. FINAL REPORT

After implementation, provide:

```text
Hybrid Markdown Table Editor

Architecture:
- ...

Markdown table grammar supported:
- ...

Hybrid editor implementation:
- ...

Source mapping:
- ...

Table operations:
- ...

Keyboard behavior:
- ...

Contextual toolbar:
- ...

Undo/redo:
- ...

Search integration:
- ...

Preview/export integration:
- ...

Performance strategy:
- ...

Files added:
- ...

Files modified:
- ...

Dependencies:
- ...

Database changes:
- None / exact changes if unavoidable

Tests:
- ...

flutter analyze:
- ...

flutter test:
- ...

Manual verification:
- ...

Known limitations:
- ...
```

Do not claim full GFM table support unless the implementation has actually been verified against the supported cases.

---

# FINAL ARCHITECTURAL PRINCIPLE

The most important invariant is:

```text
                USER
                  │
                  ▼
        Hybrid Table Interface
                  │
                  ▼
        Source-Preserving Transform
                  │
                  ▼
          Markdown String
                  │
       ┌──────────┼───────────┐
       ▼          ▼           ▼
     Search     Sync       Export
       │          │           │
       ▼          ▼           ▼
   FTS5/etc.   Encryption   Renderers
```

The table interface is **not the document**.

The Markdown is the document.

The hybrid table editor exists solely to make editing that Markdown dramatically better.

The final experience should feel like:

> “I am editing a normal document, and when I enter a table, the table becomes easy to work with.”

It must NOT feel like:

> “Quiet Paper now has a separate spreadsheet database embedded in every note.”