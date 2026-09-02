# Quiet Paper — Production Implementation Prompt
## Semantic WYSIWYG Markdown Editor + Dual Editing Modes + Frontmatter Properties

You are working inside the existing **Quiet Paper Flutter application**.

Read the existing codebase and `HANDOFF.md` / current engineering handoff before making changes. Treat the existing architecture as the source of truth. Do not replace working subsystems simply to implement this feature.

The objective is to evolve the current Markdown-aware editor into a **true Bear-like semantic WYSIWYG editing experience**, while preserving the existing Markdown editor as a fully supported alternative that users can select from Settings.

This is an editor architecture upgrade, not a cosmetic change.

---

# 1. Product Goal

Quiet Paper currently stores note bodies as canonical Markdown and already has a Markdown-aware editor that dynamically styles Markdown syntax while editing.

The new goal is to support **two editing styles**:

### Markdown Mode
The existing editing experience.

Markdown syntax remains visible:

```text
# Heading

This is **bold** and *italic*.

- Item
- Item
```

The current editor behavior, keyboard shortcuts, formatting toolbar, native selection, undo/redo, IME behavior, tables, code blocks, checklists, etc. must remain intact.

### WYSIWYG Mode
A new Bear-like writing experience in which Markdown syntax is hidden during normal editing.

The same source:

```markdown
# Heading

This is **bold** and *italic*.

- Item
- Item
```

is displayed while editing as:

```text
Heading

This is bold and italic.

• Item
• Item
```

The formatting is visible, but the Markdown delimiters are not.

The underlying canonical Markdown remains unchanged.

---

# 2. Non-Negotiable Architectural Invariants

These rules must not be violated.

## 2.1 Markdown remains the only canonical persisted representation

Do not introduce:

- rich-text JSON
- Delta
- Quill document models
- ProseMirror persistence
- HTML persistence
- a persisted AST
- a second canonical body representation

The existing Markdown string remains the sole source of truth.

The semantic/token/projection structures introduced for the editor are ephemeral presentation/editing structures only.

Existing SQLite schema, encrypted payload format, cloud sync, backups, imports, exports, and version history must continue storing Markdown.

No database migration should be required for this feature.

---

## 2.2 Preserve existing source integrity

Existing guarantees must remain true:

- Markdown source is preserved exactly when it is not intentionally edited.
- Copying Markdown/source returns the actual Markdown source.
- Pasting Markdown preserves Markdown structure.
- Autosave continues to save canonical Markdown.
- Cloud sync continues to encrypt and sync canonical Markdown.
- Local backups continue to contain canonical Markdown.
- Version history continues recording canonical Markdown.
- Undo/redo remains reliable.
- Existing note links and `qp://` resources remain untouched.
- Existing attachment references remain untouched.

---

## 2.3 Do not break the existing Markdown editor

The existing Markdown editing mode must remain a first-class editor.

When Markdown mode is selected:

- preserve existing syntax visibility
- preserve current styling behavior
- preserve current parser/tokenizer behavior where possible
- preserve current formatting toolbar
- preserve current shortcuts
- preserve current checklist behavior
- preserve current code-block behavior
- preserve current table behavior
- preserve current selection behavior
- preserve current IME handling
- preserve current large-document handling

Do not "fake" Markdown mode by building it from the new WYSIWYG representation.

Both modes should ultimately operate on the same canonical Markdown source.

---

# 3. Settings: Global Editing Style

Add a new persistent application setting:

## Settings → Editor → Editing Style

Options:

### Markdown
**Show Markdown syntax while editing**

### WYSIWYG
**Hide Markdown syntax for a cleaner writing experience**

Default:

**WYSIWYG**

The setting should be persistent across app restarts using the same application preferences architecture already used elsewhere in Quiet Paper.

Use the project's existing Riverpod/settings conventions rather than introducing an isolated state-management mechanism.

Suggested conceptual model:

```dart
enum EditorEditingStyle {
  markdown,
  wysiwyg,
}
```

Persist a stable string representation, for example:

```text
markdown
wysiwyg
```

Do not persist transient editor state in the note itself.

---

# 4. Per-Note Temporary Escape Hatch

The global setting controls the normal editing experience.

Additionally, the editor overflow menu must provide a temporary action:

### Edit Markdown

When selected while the global setting is WYSIWYG:

- immediately switch the currently open editor into Markdown presentation
- do not change the global setting
- do not write anything to the note merely because the visual mode changed
- preserve the same note
- preserve current Markdown source
- preserve scroll position where practical
- preserve caret/selection where mapping permits
- preserve focus when possible

When the user closes the note and opens another note, the global Editing Style setting applies again.

Also provide the inverse action when appropriate:

### Edit Visually

when the current editing surface is temporarily in Markdown mode while the global setting is WYSIWYG.

This is an editor-view state, not a new persisted note property.

---

# 5. Instant Mode Switching

Changing the global editing-style setting must not require:

- restarting the application
- reopening the note
- closing the editor
- converting the document
- saving and reloading the note

An already-open editor must react to the setting and switch presentation immediately.

Whenever possible preserve:

- scroll position
- caret position
- current selection
- focused field
- keyboard visibility

If an exact visual position cannot be preserved because source and visual geometry differ, use the nearest valid equivalent source position rather than losing focus or jumping unexpectedly.

---

# 6. Core Editor Architecture

Do not solve WYSIWYG by merely making Markdown delimiters transparent.

Do not rely on zero-width/zero-size syntax spans as the fundamental architecture.

Instead introduce a **semantic Markdown presentation/projection layer**.

The conceptual pipeline should become:

```text
Canonical Markdown String
          │
          ▼
   Markdown Tokenizer
          │
          ▼
   Semantic Projection
      /           \
     /             \
Visual Runs     Source Mapping
     \             /
      \           /
       ▼         ▼
       Editable Visual Surface
```

The projection is derived from Markdown and is disposable.

It must never become another persisted source of truth.

---

# 7. Source ↔ Visual Mapping

Introduce an explicit source-to-visual mapping abstraction.

The purpose is to represent situations where Markdown source characters do not have direct visible equivalents.

Example:

```markdown
**Hello**
```

The source consists of:

```text
** Hello **
```

but the visible editor contains:

```text
Hello
```

The projection must know:

```text
source 0..2   → hidden structural syntax
source 2..7   → visible "Hello"
source 7..9   → hidden structural syntax
```

The exact implementation is up to the agent, but the abstraction must support:

- source offsets
- visible/document offsets
- hidden structural ranges
- semantic formatting ranges
- caret mapping
- selection mapping
- hit testing
- source mutations
- block boundaries

Do not distort Flutter's native UTF-16 source offsets.

The canonical source remains indexed in native Flutter string/selection terms.

---

# 8. Selection and Caret Requirements

This is one of the highest-priority parts of the implementation.

The user should feel like they are editing a normal rich-text document, not navigating hidden Markdown characters.

Examples:

```markdown
**Hello**
```

should visually behave as:

```text
Hello|
```

without exposing the `**`.

Selections should operate on the visible text naturally.

Selecting "Hello" should visually select "Hello", not create a visually confusing selection over invisible syntax.

When editing formatted content:

- do not reveal delimiters merely because the caret enters the formatted region
- do not reveal delimiters merely because text is selected
- do not flash Markdown syntax during cursor movement
- do not show invisible syntax as tiny empty selection artifacts

However, the underlying selection/source offset mapping must remain deterministic so that source mutations can be correct.

---

# 9. Source Editing Semantics

The WYSIWYG editor is still fundamentally editing Markdown.

All formatting operations must mutate the canonical Markdown string.

For example:

Selecting:

```text
important
```

and tapping Bold should result in source:

```markdown
**important**
```

while visually continuing to display:

```text
important
```

with bold typography.

Similarly:

- Italic → `*text*` / existing supported equivalent
- Bold → `**text**`
- Strikethrough → `~~text~~`
- Highlight → `==text==`
- Inline code → `` `text` ``
- Links → `[label](url)`
- Headings → Markdown heading prefix
- Lists → Markdown list prefix
- Checklists → Markdown checklist syntax
- Quotes → Markdown blockquote syntax

Reuse the existing `MarkdownFormatter` and formatting transformation infrastructure wherever possible.

Do not create a second parallel formatting engine.

---

# 10. Formatting Boundary Intelligence

The WYSIWYG editor must understand formatting boundaries around the caret.

Example source:

```markdown
**hello**
```

Visually:

```text
hello|
```

Typing:

```text
 world
```

at the end of the bold region should correctly determine whether the new text belongs inside or outside the formatting boundary according to natural rich-editor behavior.

The implementation must prevent invisible Markdown delimiters from producing bizarre typing behavior.

Particular attention is required for:

- caret immediately before/after hidden syntax
- backspace at formatting boundaries
- delete at formatting boundaries
- selection expansion
- replacing selected text
- inserting text into formatted text
- Enter inside formatted text
- typing delimiters that already exist
- nested formatting
- partially formatted selections
- empty formatting spans

Do not expose raw delimiters as a workaround for difficult boundary cases.

---

# 11. Visual Markdown Rules

In WYSIWYG mode, Markdown syntax must become presentation rather than visible source text.

## 11.1 Headings

Source:

```markdown
# Heading
## Heading
### Heading
```

Display as properly sized headings.

The `#` characters and heading separator spaces are hidden.

Use the existing typography scale and typography settings.

Do not introduce a separate heading typography system.

---

# 12. Inline Formatting

### Bold

```markdown
**bold**
```

renders as:

**bold**

No visible `**`.

### Italic

```markdown
*italic*
```

renders as:

*italic*

No visible `*`.

### Bold italic

```markdown
***bold italic***
```

renders appropriately.

No visible delimiters.

### Strikethrough

```markdown
~~deleted~~
```

renders with strikethrough.

### Highlight

```markdown
==highlighted==
```

renders with the existing Quiet Paper highlight treatment.

No visible `==`.

The current highlight semantics must continue to work.

---

# 13. Lists

Unordered:

```markdown
- First
- Second
```

should visually render as:

```text
• First
• Second
```

The Markdown bullet syntax is hidden.

Ordered lists:

```markdown
1. First
2. Second
```

should visually render with the actual visible numbering.

Nested indentation must remain visually correct.

The source must remain valid Markdown.

Do not replace the source list marker with a proprietary representation.

---

# 14. Checklists

Existing checklist functionality must remain intact.

Source:

```markdown
- [ ] Task
- [x] Completed
```

should visually display as interactive checkbox controls and task text.

Tapping the visible checkbox must mutate:

```text
- [ ]
```

↔

```text
- [x]
```

in the canonical Markdown source.

Preserve the current checklist continuation/clearing logic, nested checklist support, keyboard behavior, and autosave.

The Markdown syntax must not be visible in WYSIWYG mode.

---

# 15. Blockquotes

Source:

```markdown
> Important quote
```

should appear as a visually styled quote block.

The `>` prefix is hidden.

Use Quiet Paper's existing warm editorial visual language.

Keep normal text selection and editing behavior intuitive.

---

# 16. Links

Source:

```markdown
[Open website](https://example.com)
```

should visually display:

```text
Open website
```

with link styling.

The Markdown brackets and URL should remain hidden.

Preserve the existing secure link-launching system.

Normal tapping should continue to use the existing trusted-domain / confirmation workflow.

Do not bypass `LinkLauncherHelper`.

For editing:

- long press / context menu should expose an "Edit Link" action where appropriate
- formatting toolbar "Link" should continue to create or modify Markdown links
- editing a link must modify the Markdown source, not a separate link model

---

# 17. Note Links

Existing `[[...]]` / `qp://note/...` functionality must continue working.

In WYSIWYG mode, note links should appear visually as linked note titles rather than raw Markdown/link syntax.

Typing `[[` should continue to trigger the existing inline note-link autocomplete architecture.

The autocomplete must remain focus-preserving and caret-aware.

Do not replace the note-link storage mechanism.

---

# 18. Tags

Do not blindly hide the `#` for ordinary inline tags.

Tags are part of Quiet Paper's semantic language and should remain recognizable.

Render tags using the existing tag visual language while keeping source representation intact.

Be careful not to confuse:

```markdown
# Heading
```

with:

```markdown
#tag
```

The parser must continue distinguishing heading syntax from inline tags.

---

# 19. Inline Code

Source:

```markdown
`someCode()`
```

should display as inline code typography without visible backticks.

Retain the user's configured code font.

Backticks remain in source.

---

# 20. Code Blocks

Use the current code-block architecture.

Source:

````markdown
```dart
final result = calculate();
```
````

WYSIWYG editing should visually display a code block with:

- code typography
- syntax highlighting
- existing code-block styling
- existing language pill
- existing horizontal scrolling
- existing copy behavior
- existing language selector behavior

The raw triple-backtick fences must not be visible in WYSIWYG mode.

The language identifier should not appear as raw Markdown syntax.

The current `CodeBlockOverlay` / language-selection architecture should be preserved and adapted rather than replaced.

Markdown mode must continue showing the existing Markdown-aware representation.

---

# 21. Tables

Do not redesign the existing Markdown table subsystem.

Preserve the existing hybrid table architecture:

- Markdown remains canonical
- one active table at a time
- inactive tables remain lightweight
- cell editing
- row/column insertion
- alignment
- Tab navigation
- Shift+Tab
- Enter behavior
- delete operations
- inline formatting
- copy/paste
- undo/redo

In WYSIWYG mode, table pipes and alignment delimiter syntax should not visually clutter the user.

The visual table should look like the existing table editing surface.

The Markdown representation remains canonical.

---

# 22. Images and Attachments

Use the existing attachment/image semantics.

In WYSIWYG mode:

```markdown
![Alt text](qp://asset/UUID)
```

should display the actual rendered image rather than exposing raw Markdown syntax.

Do not change encryption, asset storage, URI resolution, Cloudinary interaction, or attachment persistence.

The underlying Markdown reference must remain intact.

---

# 23. Frontmatter — Critical Requirement

Frontmatter must be treated differently from ordinary Markdown body content.

The existing application intentionally preserves frontmatter verbatim and already understands recognized properties such as:

- title
- source
- author
- created
- description
- tags

while hiding raw YAML syntax in preview mode.

Continue preserving the complete raw frontmatter source.

---

# 24. Markdown Mode Frontmatter

When editing style is Markdown:

Show frontmatter exactly as stored.

Example:

```yaml
---
title: My Research
author:
  - Jackson
created: 2026-08-30
source: https://example.com
tags:
  - research
  - flutter
custom_field: something
---

# My Research
```

No transformation.

No normalization merely because the note was opened.

No rewriting whitespace.

No reordering keys.

No removal of unknown fields.

No automatic YAML formatting.

Markdown mode is the raw/source-oriented mode.

---

# 25. WYSIWYG Mode Frontmatter

In WYSIWYG mode, raw YAML frontmatter must not appear in the normal writing canvas.

Instead, recognized frontmatter becomes an editable **Properties section** above the document body.

Example:

```text
My Research

Properties
Author      Jackson
Created     Aug 30, 2026
Source      example.com
Tags        #research  #flutter

────────────────────────

My Research

This is my note.
```

Do not expose:

```text
---
title:
author:
...
---
```

during ordinary WYSIWYG writing.

---

# 26. Properties Section State

The Properties section must be:

- visible in WYSIWYG mode
- expanded by default
- visually understated
- consistent with Quiet Paper's warm editorial aesthetic
- integrated into the editor rather than presented as a generic Material card

The user should feel that the metadata belongs to the document.

Use the existing styling tokens and typography system.

Do not introduce noisy cards, Material elevation, or unrelated UI patterns.

---

# 27. Properties Supported in WYSIWYG

Recognize and expose the existing supported frontmatter properties:

### Title
Editable document title.

### Author
Editable author value/list using the current supported semantics.

### Created
Editable date while preserving the application's existing date parsing/formatting expectations.

### Source
Editable source text or URL.

### Description
Editable multiline description.

### Tags
Editable tags using the existing tag model where appropriate.

Any existing recognized frontmatter semantics that are already supported by Quiet Paper must continue to function.

Do not invent a conflicting metadata schema.

---

# 28. Title Synchronization

If frontmatter contains:

```yaml
title: My Research
```

the large visual document title in WYSIWYG mode must display:

```text
My Research
```

Editing that visual title should update the `title:` frontmatter property.

The implementation must preserve the rest of the frontmatter.

Do not recreate the entire YAML document from a generic serializer if that would unnecessarily change formatting or ordering.

Prefer targeted source-range mutation.

---

# 29. Title Precedence

Respect the existing Quiet Paper title behavior.

Where frontmatter `title` is defined and already treated as authoritative, it remains authoritative.

If there is no frontmatter title, retain the existing application title/autotitle behavior.

Do not silently introduce a competing title source.

---

# 30. Unknown Frontmatter

Unknown properties must never be silently deleted.

Example:

```yaml
---
title: My Note
status: draft
rating: 5
aliases:
  - Foo
custom_field: hello
---
```

WYSIWYG mode may show only supported properties such as Title.

The unknown properties remain preserved exactly in the canonical source.

Do not show unknown fields as ordinary editable properties unless they already have an established Quiet Paper representation.

---

# 31. No "Edit Raw Frontmatter" UI

Do not add a dedicated "Edit raw frontmatter" action inside the WYSIWYG Properties UI.

Users who need raw frontmatter should use the existing/implemented **Edit Markdown** escape hatch to access the Markdown editor.

The Properties UI is deliberately the clean visual interface.

---

# 32. Invalid Frontmatter

If frontmatter cannot be safely parsed:

- do not rewrite it
- do not delete it
- do not invent properties
- do not partially serialize it
- preserve the original source

WYSIWYG should gracefully fall back.

Use a neutral, unobtrusive indicator that properties could not be interpreted and that the user can use Markdown editing to inspect the source.

Do not crash.

---

# 33. Frontmatter Source Mutation Safety

When changing one property such as:

```yaml
title: Old Title
```

to:

```yaml
title: New Title
```

prefer modifying only the corresponding source range.

Do not regenerate the entire frontmatter block unless necessary.

The implementation should aim to preserve:

- key ordering
- comments
- blank lines
- quoting style
- indentation
- unknown properties
- multiline representation
- unrelated formatting

This is especially important because imported Markdown may contain carefully authored YAML.

---

# 34. Properties ↔ Markdown Synchronization

When the user edits a property:

1. update the canonical Markdown source
2. update the editor projection
3. trigger the normal `onChanged` path
4. preserve autosave behavior
5. preserve undo/redo semantics
6. preserve version history semantics
7. preserve sync behavior

There must not be a second hidden metadata state that can diverge from the Markdown source.

---

# 35. Undo / Redo

All WYSIWYG editing operations must integrate with the existing editor undo/redo system.

The following must become undoable source mutations:

- formatting
- heading changes
- list changes
- checklist toggles
- link edits
- code-block language changes
- table operations
- title/property changes
- regular typing
- deletion
- paste
- source-mode edits

Switching visual mode itself must **not** create a document undo snapshot.

Do not destroy the existing version-history architecture.

The application's session-based version history should continue seeing substantive Markdown changes as before.

---

# 36. Copy / Paste

## Copy

Normal copy behavior in WYSIWYG mode should be carefully designed.

When the user copies text, preserve the existing Markdown-first philosophy.

For ordinary editing selections, the copied representation should remain compatible with Quiet Paper's existing Markdown workflow and source integrity guarantees.

Do not silently convert content into proprietary rich-text clipboard data as the only representation.

Where the existing application already exposes source Markdown copy behavior, preserve it.

## Paste

Pasting Markdown must remain capable of inserting valid Markdown source into the document.

Example:

```markdown
**important**
```

should become formatted bold text in WYSIWYG mode.

Do not strip Markdown unintentionally.

---

# 37. Keyboard Shortcuts

Preserve existing shortcuts:

- Ctrl/Cmd+B
- Ctrl/Cmd+I
- Ctrl/Cmd+Shift+X
- Ctrl/Cmd+`
- Ctrl/Cmd+K
- Ctrl/Cmd+C
- Ctrl/Cmd+V
- Ctrl/Cmd+X
- Ctrl/Cmd+A
- Ctrl/Cmd+Z
- Ctrl/Cmd+Shift+Z
- existing table shortcuts
- existing checklist/list behavior

WYSIWYG mode must feel natural on:

- Android hardware keyboards
- tablets
- desktop
- web where supported

Do not regress platform conventions.

---

# 38. Touch Editing

WYSIWYG mode must be fully touch-friendly.

Support:

- normal caret placement
- drag selection
- selection handles
- long press
- context menu
- formatting toolbar
- checklist tapping
- links
- tables
- code language pill
- note-link autocomplete

Invisible syntax must not create confusing empty touch targets or visually offset tap behavior.

---

# 39. Formatting Toolbar

Keep the existing formatting toolbar.

Its semantics do not change.

The toolbar continues to create/modify Markdown source.

However, in WYSIWYG mode, the visual editor must immediately reflect the semantic formatting without exposing the Markdown syntax.

The user should experience:

```text
Select text
      ↓
Tap Bold
      ↓
Text becomes visibly bold
```

not:

```text
**text**
```

appearing on screen.

The current routing of toolbar actions to the active editing target must remain compatible with tables and other specialized editing targets.

---

# 40. Context Menu

Retain the existing selection-aware context menu.

Ensure the WYSIWYG editor supports contextual actions for:

- Bold
- Italic
- Strike
- Code
- Link
- Checklist
- existing native actions

Do not show raw Markdown syntax merely because a formatting action was invoked.

---

# 41. Read-Only Mode

Existing read-only behavior must remain compatible.

When read-only:

- no source mutations
- no formatting operations
- no property editing
- no checklist toggling
- no destructive interactions

The visual presentation can remain WYSIWYG if that is the selected editing style, but editing controls should be unavailable.

Do not regress the existing lock/read-only UI.

---

# 42. Performance Architecture

This feature must respect the existing large-document performance architecture.

The project already has a large-document threshold and intentionally avoids full-document TextSpan generation for very large notes.

Do not regress that optimization.

The new source↔visual projection must be designed for incremental updates.

For normal typing:

```text
changed source range
        ↓
affected block(s)
        ↓
reparse affected region
        ↓
update projection
```

Do not reparse the entire document for every keystroke in a large note.

Avoid:

- whole-document regex scans on every keystroke
- whole-document string splits
- rebuilding hundreds of thousands of spans on cursor blink
- unbounded mapping allocations
- excessive object churn

Use the existing block/chunk architecture where practical.

---

# 43. Large Documents

For documents above the existing large-document threshold:

- maintain current performance safeguards
- do not attempt an expensive full WYSIWYG projection on every frame
- preserve editing responsiveness
- maintain IME functionality
- maintain search overlays where supported
- maintain plain/high-performance fallback behavior where the existing architecture already requires it

The agent should document the behavior for oversized documents rather than silently introducing a severe regression.

---

# 44. IME Stability

Android IME behavior is a high-risk area.

The project has already encountered issues caused by span boundary fragmentation, font metric changes, composing ranges, and whitespace around headings/list prefixes.

The new implementation must preserve:

- composing ranges
- predictive text
- Gboard
- FUTO or similar IMEs
- cursor advancement
- spaces
- heading typing
- list typing
- checklist typing
- quoted text

Do not introduce isolated one-character spans for whitespace around structural syntax.

Do not produce font-metric discontinuities merely because a hidden syntax range starts or ends.

The composing region must continue to map safely to the underlying Markdown source.

---

# 45. Structural Prefix Handling

For block prefixes such as:

```text
# 
## 
> 
- 
1. 
- [ ] 
- [x] 
```

treat the entire structural prefix as a coherent semantic unit.

Do not fragment:

```text
#
(space)
```

into typography-incompatible spans.

The existing unified prefix invariant should remain intact.

---

# 46. Mode-Specific Presentation Rules

The same source must produce two distinct editing projections.

## Markdown Mode

Syntax visible.

Example:

```markdown
# Heading

This is **bold**.

- Item
```

## WYSIWYG Mode

Syntax hidden.

Example:

```text
Heading

This is bold.

• Item
```

Both modes must retain semantic formatting and source correctness.

Do not duplicate parser logic unnecessarily.

---

# 47. Unsupported / Ambiguous Markdown

Not every Markdown extension needs a custom rich visual representation.

When a construct cannot be safely represented:

- preserve the source exactly
- do not corrupt it
- do not delete it
- do not invent semantics
- use a neutral fallback presentation
- provide an unobtrusive path to "Edit Markdown" for that content where useful

Do not reveal all Markdown syntax globally merely because one unsupported construct exists.

---

# 48. Important Edge Cases

Test and handle:

- empty document
- empty headings
- heading with spaces
- multiple spaces after heading markers
- nested bold + italic
- bold inside headings
- links containing formatted text
- nested formatting
- partially selected formatted text
- selection spanning formatting boundaries
- deleting only part of a formatted span
- backspacing at hidden syntax boundaries
- empty formatted spans
- adjacent formatted spans
- escaped Markdown
- malformed/incomplete Markdown
- unfinished links
- unfinished code fences
- code blocks containing Markdown-looking text
- lists with blank items
- nested lists
- nested checklists
- tables adjacent to paragraphs
- frontmatter followed immediately by body text
- empty frontmatter
- unknown frontmatter
- malformed frontmatter
- multiline YAML values
- YAML lists
- quoted YAML values
- comments in YAML
- imported notes with unusual formatting
- very large documents
- undo/redo across mode changes
- app lifecycle/backgrounding during edits
- autosave during property changes
- sync while switching editing modes

---

# 49. Autosave

Mode switching must never interfere with autosave.

Property changes must enter the normal note-change pipeline.

Continue respecting the project's existing autosave behavior, including:

- debounce
- focus change
- lifecycle change
- exit flush
- empty draft handling

Do not add a special autosave mechanism for WYSIWYG mode.

---

# 50. Version History

WYSIWYG changes must automatically feed the existing version-history mechanism.

A user changing:

```yaml
title: Old
```

to:

```yaml
title: New
```

through the Properties UI is a real Markdown document mutation and must appear naturally in version history according to the existing session/micro-edit rules.

Do not make version history store a visual projection.

It must continue storing canonical Markdown.

---

# 51. Cloud Sync and Encryption

No backend changes should be necessary.

The editor must continue producing the same canonical Markdown payload expected by:

- Drift
- encryption layer
- sync engine
- Turso
- cloud backups
- local backups
- version history

Mode changes are presentation state only.

Do not transmit editor mode metadata as part of note content.

---

# 52. Settings UI Integration

Integrate the new Editing Style setting into the existing Settings design.

The project uses a Bear/iOS Grouped Table-inspired settings presentation.

Follow the existing conventions:

```text
EDITOR

Editing Style
WYSIWYG
```

with a trailing disclosure/selection indicator or equivalent existing settings pattern.

Opening the setting should provide the two choices cleanly.

Avoid introducing a large custom modal if the existing settings architecture already has a preferred row/sheet pattern.

The selected mode should be clearly indicated.

---

# 53. Accessibility

Both modes must expose meaningful semantics.

A screen reader should understand:

- heading
- paragraph
- list item
- checklist
- link
- code block
- property
- property value
- title

Do not let hidden Markdown syntax become accessibility noise.

A screen reader should not announce:

```text
asterisk asterisk
```

simply because the visual WYSIWYG editor is built from Markdown source.

---

# 54. Visual Quality

The WYSIWYG mode should feel unmistakably like Quiet Paper:

- calm
- editorial
- spacious
- borderless where appropriate
- restrained
- typography-led
- warm
- minimal
- no noisy Material chrome
- no unnecessary cards
- no excessive badges

Use existing:

- AppColors
- AppSpacing
- AppRadii
- AppTypography
- typography settings
- theme engine
- accent colors

The editor must adapt automatically to the active Quiet Paper theme.

Do not hardcode a separate WYSIWYG color palette.

---

# 55. Existing Typography Settings

WYSIWYG rendering must respect all existing typography settings:

- heading font
- body font
- code font
- font size
- line height
- letter spacing
- paragraph width
- paragraph indent
- custom fonts

Do not create separate font settings specifically for WYSIWYG.

Markdown Mode and WYSIWYG Mode should render the same semantic document using the same typography configuration.

---

# 56. Implementation Strategy

Before editing code:

1. inspect the existing editor architecture
2. identify the current parser/tokenizer/controller pipeline
3. identify all source mutation utilities
4. identify selection/undo/redo integration
5. identify code block/table/attachment overlays
6. identify frontmatter parsing logic
7. identify title handling
8. identify settings state architecture
9. identify large-document performance safeguards
10. identify editor tests already covering IME, selection and formatting

Reuse existing abstractions wherever they are appropriate.

Do not rewrite stable subsystems unnecessarily.

---

# 57. Suggested New Abstractions

The exact class names are up to the implementation, but the architecture should have equivalents of:

```dart
EditorEditingStyle
```

```dart
MarkdownDocumentProjection
```

```dart
SourceVisualMapping
```

```dart
MarkdownVisualRun
```

```dart
MarkdownSemanticNode
```

and a frontmatter abstraction capable of representing:

```dart
FrontmatterDocument
FrontmatterProperty
FrontmatterSourceRange
```

These must remain transient/in-memory structures.

Do not persist them.

---

# 58. Frontmatter Parser Requirements

Reuse the existing frontmatter parser behavior where possible.

The new frontmatter editor layer should know:

- whether frontmatter exists
- opening delimiter source range
- closing delimiter source range
- property key
- source range of property value
- source range of property line/block
- parsed semantic value
- whether a value is safely editable
- whether parsing was successful

Prefer range-based edits rather than whole-document serialization.

---

# 59. Formatting Parser Requirements

The semantic projection must distinguish:

### Visible semantic content

such as:

```text
Hello
```

from:

### Structural Markdown syntax

such as:

```text
**
#
- 
> 
[ ]
```

Structural syntax may be hidden in WYSIWYG mode.

Do not merely classify characters by punctuation. Parsing must understand context.

For example:

```text
#tag
```

is not the same thing as:

```text
# Heading
```

and:

```text
* literal asterisk
```

must remain literal if Markdown parsing says it is escaped/non-formatting.

---

# 60. Selection Mapping Strategy

Implement deterministic conversion between:

```text
Flutter source selection
```

and:

```text
visual editing selection
```

where required.

The exact mechanism is implementation-specific, but it must handle hidden source spans correctly.

Important:

Do not fake a visible string that is completely detached from the source and then attempt to reconstruct Markdown afterward.

That approach risks losing exact source information.

The source must remain authoritative throughout editing.

---

# 61. Do Not Introduce a Parallel Hidden Text Model

Do not create:

```text
sourceMarkdown
+
visualText
```

as two independently mutable document strings.

There may be an ephemeral projection representation for rendering, but there must only be one mutable canonical text source.

Any visual edit must resolve into a source mutation.

---

# 62. Regression Protection

Existing tests must continue passing.

Do not delete tests simply because implementation changes.

Add comprehensive tests for the new architecture.

At minimum cover:

### Mode tests
- default is WYSIWYG
- Markdown mode works
- setting persists
- switching is immediate
- temporary Edit Markdown does not alter global preference

### Projection tests
- bold hides delimiters
- italic hides delimiters
- headings hide markers
- lists hide markers
- quotes hide markers
- checklists hide source markers
- links hide brackets/URLs
- inline code hides backticks
- code fences hide
- images render visually

### Source integrity tests
- WYSIWYG does not alter untouched source
- formatting writes correct Markdown
- copy source remains correct
- pasted Markdown remains correct

### Mapping tests
- caret inside bold
- caret at bold boundary
- backspace at formatting boundary
- selection inside formatting
- selection across formatting
- replacing selected formatted content
- nested formatting
- headings
- lists
- checklists

### Frontmatter tests
- recognized properties display
- Properties default expanded
- title edits update frontmatter
- source edits update Markdown
- unknown fields preserved
- comments preserved
- ordering preserved
- malformed frontmatter preserved
- multiline YAML preserved
- list-valued YAML preserved

### Existing subsystem tests
- code blocks
- tables
- note links
- attachments
- autosave
- undo/redo
- version history
- read-only
- search overlays
- large-document behavior

### IME tests
At minimum:

- Gboard-like composing input
- spaces after headings
- spaces after list markers
- checklist typing
- formatting while composing
- caret advancement around hidden syntax

---

# 63. Performance Tests

Add tests/benchmarks or instrumentation appropriate to the project for:

- ordinary notes
- 10k+ character notes
- notes near the current large-document threshold
- very large notes
- rapid typing
- repeated cursor movement
- selection changes
- mode switching
- repeated formatting operations

No O(document-size) rebuild should happen merely because the caret blinked or selection moved when it can be avoided.

---

# 64. Acceptance Criteria

The implementation is complete only when all of the following are true:

### Editing modes
- WYSIWYG mode exists
- Markdown mode remains available
- WYSIWYG is the default
- setting persists
- setting changes apply instantly
- per-note Edit Markdown escape hatch works

### WYSIWYG behavior
- Markdown syntax is normally invisible
- formatted text remains visually formatted
- headings look like headings
- lists look like lists
- quotes look like quotes
- checklists are interactive
- links look like links
- inline code looks like code
- code blocks remain visually rich
- tables remain visual tables
- images remain visual images

### Frontmatter
- raw YAML is hidden in WYSIWYG
- Properties are visible and expanded by default
- recognized fields are editable
- title synchronization works
- unknown metadata is preserved
- malformed metadata is preserved
- no raw-frontmatter editor is added to the Properties UI
- Markdown mode still exposes raw frontmatter

### Integrity
- Markdown remains canonical
- no database migration
- no sync schema change
- no encryption changes
- no backup format changes
- no version-history format change

### UX
- caret feels natural
- selection feels natural
- typing feels natural
- hidden syntax never leaks into normal visual editing
- formatting boundaries behave predictably
- touch editing works
- keyboard shortcuts work
- accessibility remains meaningful

### Performance
- existing large-document protections remain
- WYSIWYG does not cause whole-document reparsing for trivial edits where avoidable
- no keystroke lag introduced
- IME stability preserved

### Quality
- `flutter analyze` clean
- all existing tests pass
- new editor tests pass
- no knowingly introduced warnings
- no placeholder UI
- no TODO-based incomplete behavior
- no temporary hacks such as transparent syntax as the primary architecture

---

# 65. Final Implementation Principle

The finished product should feel like this:

### For a normal user

> "I am editing a beautifully formatted document."

### For a Markdown user

> "I can switch to Markdown and see/edit exactly what is stored."

### For the system

> "There is still only one canonical Markdown document."

That is the core objective.

Do not sacrifice the existing Markdown-native architecture to obtain the Bear-like experience.

Instead, build a robust semantic presentation/editing layer on top of the canonical Markdown source.

The result should make Quiet Paper feel like a true Bear-style editor while retaining Markdown as a first-class, transparent-to-storage foundation.