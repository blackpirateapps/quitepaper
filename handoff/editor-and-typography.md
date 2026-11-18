# Quiet Paper — Editor & Typography Subsystem

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Editor Philosophy & Dual-Mode Architecture

Quiet Paper emphasizes an editorial, distraction-free writing environment inspired by Bear Notes and iA Writer. 

The editor supports three editing styles:
1. **Markdown Source Mode**: Raw Markdown editing with syntax highlighting and specialized table fields.
2. **Visual Editor** (`wysiwyg`): `RichEditorSurface`, `RichTextEditor`, and `RichChecklistEditor` edit an authoritative `RichDocument` AST.
3. **Super Editor**: The separate `super_editor` document editor, including smart checklists, math, native code blocks, and typewriter scrolling.

### Key Architectural Invariants
- **Content is Canonical**: The user's text and formatting are preserved without loss.
- **RichText AST Source of Truth**: In Visual Editor mode, the in-memory AST serves as the canonical representation. Edits modify the AST directly, eliminating intermediate compilation cycles during typing and autosave.
- **Zero-Compilation Saves**: Note autosaving serializes directly from the active AST or text buffer without lag.
- **On-Demand Mode Conversion**: Conversion between Markdown text and the SuperEditor AST occurs only when explicitly switching modes.

---

### Visual and Markdown input lifecycle

- Visual Math insertion uses a `CodeBlock(language: 'math')` in the existing
  AST. Its TeX source is editable with the established code input; insertion
  selects the placeholder and focus routes to that block. JSON persistence and
  fenced Markdown conversion are lossless. This is source editing in Visual
  mode; Super Editor retains its separate rendered formula component.
- Malformed JSON-like source falls back to Markdown parsing once. `setContent`
  and `setMarkdown` must never recursively delegate failed decoding.
- Before changing editor mode, reset active field targets to the persistent
  source buffer so the destination toolbar cannot observe disposed controllers.
- Text fields publish their current selection after tap focus settles, because native
  clicks may deliver selection before focus. Programmatic focus retains AST intent. Toolbar edits then use that caret.

- Text mutations received while a toolbar menu owns focus also publish their
  resulting selection to the AST. Selection-only notifications still require
  field focus. Tag and note-link prompts keep the caret after their markers;
  Visual note-link edits rely on rich-field autosave for canonical JSON.
- Code language selection and cancellation restore the code field and its caret.
  Markdown toolbar history normalizes invalid snapshot carets and focuses the body.
- Visual toolbar and keyboard undo/redo use `RichDocumentController` snapshots,
  including ordinary text-span edits and caret positions. History restoration
  marks the document dirty for autosave. The toolbar observes the persistent
  source buffer, because segment controllers may be disposed during restoration.
- Visual code fields register their surface-owned focus node and publish their
  active text controller. Code insertion selects the new block, and code/language
  edits resolve the block by ID and commit directly to the AST. External history
  updates reconcile code text/selection after the frame without losing unchanged
  IME composition or reparsing the document.
- Visual text/checklist segments use stable block-ID keys. Text-segment focus
  nodes live for the surface lifetime and are pruned after block removal. A plain
  document uses the same segment layout as a mixed document. The supplied body
  focus node belongs to the first text/checklist field, including checklist-first
  notes, so title submission always targets a mounted editable field.
- The surface rebuild supplies current segment indices before text reconciliation.
  Checklist callbacks resolve their current index by block ID. Structural changes
  suppress automatic sibling-focus publication until the selected destination is
  mounted. Focus requests and checklist selections revalidate the current document
  selection before applying; focused ranges and unchanged IME composition survive
  synchronization. IME list continuation keeps canonical document offsets after
  list markers are inserted.
- Wrapped checklist Up/Down navigation stays within the current text field until
  its first/last visual line; crossing into an adjacent task preserves the visual
  column. Modified arrow keys retain Flutter's selection/navigation behavior.
- Rendered editable spans must have the same UTF-16 length as the text controller.
  Link enhancement is a field suffix action, outside the editable span stream;
  no unbacked `WidgetSpan` may shift hit testing or caret offsets.
- Markdown source notifications are compared with the last observed source text.
  Selection/style-only notifications must never deserialize the older autosave
  buffer over pending visual edits. Markdown text segments around tables use
  ordinal keys, independent of changing character offsets, and the first text
  segment uses the supplied body focus node.
- Markdown code overlays always keep the editor in the same Stack child slot.
  Adding/removing the first/last fence only changes overlay pills, preserving
  EditableText state and the focused native input client. Read-only overlays
  retain the same layout while suppressing their interactive pills.

### Checklist audit resolutions (November 16, 2026)

The [checklist audit](audits/checklist-stress-2026-11-16/README.md) has twelve
resolved findings, each with regression coverage and an independent fix commit.

- `ChecklistItemBlock.indent` persists hierarchy through Markdown, JSON and Enter;
  old JSON defaults to zero. Row padding displays that hierarchy. Super Editor
  uses `QuietTaskBlockSyntax` before CommonMark task grouping so nested tasks
  retain separate text, depth, formatting and completion state.
- Visual snippet insertion splices parsed blocks at the AST selection. It never
  indexes Markdown using a plain-text document offset. Prefix/suffix spans,
  unaffected block identities, task metadata, resulting caret and one-step Undo
  are preserved, including forward/reverse cross-task selections.
- Checklist Enter replaces the selected range; forward Delete joins the next
  task. Toolbar text edits are accepted while menus own focus. Composing Enter
  remains with the input method; committed platform newlines continue tasks or
  exit an empty task into a paragraph in one mutation.
- Linux printable input and hardware events can arrive through different queues.
  Linux task splitting uses the ordered IME newline, and rebases queued updates
  containing a consumed row prefix. Structural continuation reparents the same
  TextField/controller/focus node into the new row to retain the native client.
- Boundary arrows accept key repeats, publish their destination immediately and
  exchange the active client with the destination field. Checklist selection-only
  notifications skip full-surface reconstruction and unchanged span invalidation,
  keeping large-list navigation responsive while retaining wrapped-line behavior.
- `QuietLinuxHomePlugin` consumes plain/Shift Home after applying line navigation,
  including when the caret is already at the boundary. Falling through there
  allowed the native IME's synthetic `. ` prefix and buffer to mutate saved text.
  Modified Home combinations keep their existing handling.

[Native evidence and replay scripts](audits/checklist-stress-2026-11-16/fix-verification/README.md)
cover the four input/persistence/navigation risks. Other fixes have parser,
controller, widget IME and actual EditorScreen toolbar/autosave regressions.
Physical Android/iOS/CJK sessions and release profiling were not performed.

## 2. SuperEditor Components & Smart Widgets

The visual editor resides in [`lib/features/editor/`](file:///home/dog/git/quitepaper/lib/features/editor/) and [`lib/core/syntax/`](file:///home/dog/git/quitepaper/lib/core/syntax/).

### Smart Todolist Subsystem
- **Component**: [`QuietTaskNode`](file:///home/dog/git/quitepaper/lib/features/editor/) / `QuietTaskComponent`.
- **Features**:
  - **Optical Alignment**: Checkbox aligns with the body text baseline.
  - **Smart Placeholders**: Prompting hint text on new empty task items.
  - **Auto-Sorting & Collapsible Done Items**: Completed items can be automatically sorted to the bottom and collapsed into a compact section.
  - **Task Boundary Isolation**: Paragraphs immediately following a task list are isolated so that strikethrough or collapse styles do not spill over into regular paragraphs.
- **Selection and keyboard contract**: Checking a focused task moves the selection
  to the next active item (or the previous active item / a plain paragraph below
  the list). An unrelated selection remains unchanged. Selection relocation,
  completion, stable grouping of active/completed rows, and paragraph insertion
  share one undo transaction; selection is never cleared just to hide a caret.
- **Folding contract**: Flat lists fold above three completed items. Folded rows
  have no outer padding and report no selectable text geometry. The text subtree
  stays mounted offstage at the real column width; document height changes
  immediately so selection overlays do not lag animated component sizes. Arrow
  navigation skips folded rows, and IME/programmatic selections reveal the target
  before editing. A terminal folded list has an empty paragraph for continuation.
  Backspace/Delete at a folded boundary reveals tasks before merging text, so
  a following paragraph cannot disappear into a hidden completed item.
- **State lifecycle**: Expansion state is reset on document replacement and pruned
  after deletion or falling below the threshold. Rapid checkbox taps coalesce
  into one cancellable completion timer, which is cancelled on component disposal.
- **Nested tasks**: Lists containing indented tasks retain their order and stay
  unfolded, avoiding detaching children during automatic sorting. Serialization
  preserves task indentation.
- **Preview alignment**: Markdown preview chunks use `fitContent: false` to fill
  the centered paragraph column and keep short checklists at its left edge.

### Native Code Blocks
- **Component**: Native code block node with live syntax highlighting and line numbers.
- **Features**:
  - Multi-language syntax highlighting powered by `flutter_highlight` and bundled syntax definitions.
  - Line numbering gutter with monospaced alignment.
  - Quick language selector modal.

### LaTeX Math Syntax Support (Block & Bear-Style Inline Folding)
- **Engine**: 100% offline, pure-Dart LaTeX rendering powered by `flutter_math_fork`. Zero WebViews or external JavaScript runtimes.
- **Block Math (`QuietMathBlockNode`)**:
  - Loading and paste use `deserializeQuietMathDocument`: a custom block syntax
    captures display math before CommonMark can consume TeX escapes, emphasis,
    list-like lines or internal blank lines. The converter builds math nodes
    directly; the promotion pass retains legacy bracket recovery and fenced
    `math`/`latex`/`tex` support. Unfinished delimiters remain editable text.
  - The normalizer preserves complete formulas and fenced code verbatim when
    isolating blocks and collapsing surrounding blank lines. Code examples are
    excluded from math promotion and folding.
  - Both controller paste and native `PasteEditorRequest` recognize math.
    Structured selection replacement is one undoable transaction. Inserting
    math retains the last valid caret when a menu takes focus, falls back to the
    document end, and opens empty formulas for editing automatically.
  - Implemented in [`QuietMathBlockNode`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_block_node.dart) and rendered via [`QuietMathBlockComponent`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_block_component.dart).
  - Delimiters supported: `\[ ... \]`, `$$ ... $$`, and ````math ... ````.
  - Interactive UX: displays rendered mathematical formulas in a clean, compact textbook-style typographic block (~45px height) with transparent idle background and zero-height floating hover actions (Copy LaTeX, Edit). Delimiter switching pills (`\[ \]`, `$$`, ````math````) remain available in edit mode. Tapping expands an inline TeX editor card with live real-time formula preview, delimiter switcher, `Ctrl/Cmd+Enter` to save, and `Escape` to cancel.
  - Focus isolation & tap handling: component builder wraps in `BoxComponent` with `isVisuallySelectable: true`; [`QuietMathBlockTapHandler`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_block_component.dart) halts SuperEditor gesture interactor when tapping inside the formula card; and `SuperEditorSelectionPolicies(placeCaretAtEndOfDocumentOnGainFocus: false)` eliminates cursor jumping to the end of the document when inner inputs receive focus.
  - Keyboard navigation: [`QuietMathBlockPlugin`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_block_component.dart) equips math blocks with `Enter` and `ArrowDown` handlers to cleanly continue writing below terminal math blocks.
  - Shortcut creation: typing `$$` or `\[` on an empty line and pressing `Enter` automatically transforms the paragraph into a `QuietMathBlockNode` via `handleMathBlockFenceNewlineRequest`.
- **Inline Math (`QuietInlineMath`)**:
  - Folding retains the original UTF-16 length and attribution spans: each
    rendered formula occupies its canonical start offset, followed by invisible
    padding in the display text only. This preserves hit testing, caret movement,
    selection and edits after multiple formulas. Padding never enters persisted
    Markdown or the canonical document.
  - Delimiters supported: `\( ... \)` and `$...$`.
  - Seamless Bear/Typora-style folding: when the user's cursor is outside the formula, it folds into an inline rendered LaTeX equation pill via `AttributedText` placeholders. When the cursor moves inside the equation, it unfolds immediately into the raw LaTeX source for direct editing.
  - Component builders: custom [`QuietMathParagraphComponentBuilder`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_inline_math.dart) and [`QuietMathListItemComponentBuilder`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_inline_math.dart) seamlessly fold formulas in both body paragraphs and bullet/task lists.
- **Roundtrip Serialization & Escape Sanitization**:
  - CommonMark escape protection: automatically unescapes corrupted LaTeX underscores (`\_` -> `_`) and asterisks (`\*` -> `*`) via [`QuietMathParser`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_parser.dart).
  - Markdown preview parity: [`quiet_math_markdown_extension.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/quiet_math_markdown_extension.dart) registers `MathBracketInlineSyntax`, `MathDollarInlineSyntax`, and `MathBlockSyntax` with `QuietMathElementBuilder` for `QuietMarkdownPreview`.

### Horizontal Rules & Dividers
- **Component**: [`QuietHorizontalRuleComponent`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_horizontal_rule_component.dart) and `QuietHorizontalRuleComponentBuilder`.
- **Features**:
  - Themed divider rendered with `colors.divider` and clean padding.
  - Interactive tap target: removes `IgnorePointer` to permit direct pointer and tap events.
  - Sub-divider tap handler: [`QuietDividerTapHandler`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_horizontal_rule_component.dart) and `superEditorAddEmptyParagraphTapHandlerFactory` detect taps on or below terminal dividers and spawn an editable `ParagraphNode` with focused caret.
  - Divider keyboard actions: [`QuietDividerPlugin`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_horizontal_rule_component.dart) registers handlers for `Enter`, `ArrowDown`, `ArrowRight`, and printable typing when a divider is selected to automatically create a paragraph and continue writing seamlessly.
  - Trailing divider invariant: documents ending with `---` automatically load with an editable trailing paragraph.

### Editorial Blockquotes Subsystem
- **Component**: [`QuietBlockquoteComponent`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_blockquote_component.dart) and `QuietBlockquoteComponentBuilder`.
- **Plugin**: [`QuietBlockquotePlugin`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_blockquote_component.dart) (`InsertNewlineInBlockquoteAtCaretCommand`).
- **Features**:
  - **Editorial 3.5px Accent Bar**: Rendered via `_BlockquoteBarPainter` in `colors.accent` with 2px rounded corners at block boundaries.
  - **Compact Inter-Line Spacing**: Collapses the previous 48dp double padding down to 4dp between contiguous quote lines and 8dp outer margins, with balanced 15.5dp total indentation.
  - **Enter Key Auto-Continuation**: Pressing Enter on non-empty quotes continues with another blockquote paragraph; pressing Enter on an empty quote cleanly exits to a regular paragraph across both hardware keyboards and mobile IMEs.

### Typewriter Scrolling
- Automatically keeps the active cursor centered vertically in the viewport during typing.
- Operates across both mobile and desktop screens to prevent the cursor from dropping below the keyboard or viewport edge.

### Autosave & Empty-Draft Disposal
- **Debounced Autosave**: 700ms debounce timer triggers local SQLite saves.
- **Lifecycle Flush**: Focus changes, app pausing, or navigating back immediately flushes pending changes.
- **Empty-Draft Cleanup**: If a user creates a new note but exits without typing any content, the draft is cleanly discarded to prevent empty note clutter.

### Super Editor Title & Empty Body
- Super Editor mode displays a themed divider below the title. Submitting the
  title (Enter / mobile Next) explicitly places a collapsed document selection
  at the start of the body before requesting focus. Keep the existing
  `placeCaretAtEndOfDocumentOnGainFocus: false` policy for embedded input focus.
- The body uses SuperEditor's native hint component for a single empty ordinary
  paragraph. `Start writing...` inherits body typography, disappears on typing,
  and returns when cleared. The hint and title divider are presentation only.
- Controller attachment/detachment notifications defer until after the frame
  when invoked during build, preventing sibling toolbar rebuild assertions.

### Visual and Markdown Title Submission

- The title's `FocusNode` handles physical Enter and numpad Enter directly in
  Visual and Markdown modes. Do not rely exclusively on the native text-input
  submission callback for Linux hardware keyboards.
- Hardware Enter and the mobile Next action share `_focusBodyFromTitle`, which
  clears title composition, selects the start of the active body representation,
  and requests body focus. Explicit editing completion avoids default focus
  traversal through editor controls. Enter during active IME composition remains
  available to the native input method, and read-only notes cannot transfer focus
  through this submission path.

---

## 3. Typography & Aesthetic System

The visual design system is defined in [`lib/app/theme/`](file:///home/dog/git/quitepaper/lib/app/theme/):
- **Palettes**: Soft paper light tones (`#F7F6F2`), calm dark tones (`#1D1C1A`). Zero aggressive elevation or high-contrast borders.
- **Fonts Supported**:
  - **iA Writer Quattro**: Editorial proportional monospaced font bundled with the application.
  - **System Default**, **Serif**, **Sans-Serif**, and **Monospace**.
- **Layout & Metrics**:
  - Phone: 24dp horizontal margins, natural top alignment.
  - Tablet / Desktop: 720dp maximum content reading width, centered horizontally.
  - Spacing: 1.6x line height for comfortable long-form reading and editing.
- **Responsive Theme Extensions**:
  - [`AppColors`](file:///home/dog/git/quitepaper/lib/app/theme/app_colors.dart)
  - [`AppTypography`](file:///home/dog/git/quitepaper/lib/app/theme/app_typography.dart)
  - [`AppSpacing`](file:///home/dog/git/quitepaper/lib/app/theme/app_spacing.dart)
  - [`AppRadii`](file:///home/dog/git/quitepaper/lib/app/theme/app_radii.dart)

---

## Key References & Logs
- SuperEditor Blockquotes Redesign: [Latest Logs, Section 259](latest-logs.md#259-supereditor-blockquotes-redesign-editorial-35px-accent-bar-compact-spacing--enter-auto-continuation-november-2026)
- LaTeX Math Syntax Support (Block & Bear-Style Inline Folding): [Latest Logs, Section 253](latest-logs.md#253-supereditor-comprehensive-math-syntax-support-latex-block--inline-math-bear-style-folding)
- Left-Aligned Note Title & Full-Width SuperEditor Code Blocks: [Latest Logs, Section 251](latest-logs.md#251-ui-polish-left-aligned-note-titles--full-width-supereditor-code-blocks-november-2026)
- Smart Todolist & Task Boundary Isolation: [Latest Logs, Section 242 & 243](latest-logs.md#242-architecture-smart-todolist-in-supereditor-with-optical-alignment-placeholders-auto-sorting--collapsible-done-items-october-2026)
- Native Code Blocks with Syntax Highlighting: [Latest Logs, Section 241](latest-logs.md#241-architecture-super-editor-native-code-block-with-live-syntax-highlighting--line-numbers-october-2026)
- Typewriter Scrolling Decoupling & End-of-Document Clamping: [Latest Logs, Section 268](latest-logs.md#268-typewriter-scrolling-cursor-navigation-decoupling--natural-end-of-document-clamping-november-2026)
- Typewriter Scrolling: [Latest Logs, Section 223](latest-logs.md#223-typewriter-scrolling-ambient-cursor-vertical-centering-across-all-editor-modes-october-2026)
- RichDocument Visual Editor AST: [Latest Logs, Section 136 & 140](latest-logs.md#136-production-grade-richdocument-visual-editor-architecture)
- iA Writer Quattro Typography Integration: [Historical Logs v1.5, Section 32](archive/logs-v1.5.md#32-ia-writer-quattro-typography-integration--cdn-font-delivery)

### Confirmed email appends

`EmailEditorBridge` flushes existing edits before preview and adopts committed
appends, canceling older debounce saves. Existing rich blocks and selection remain
intact. Super Editor recognizes the appended Email Details section and appends
only its parsed nodes after the current frame, retaining the original document,
selection and history. Imported notes disable automatic remote-link preview
baking/promotion; normal unrelated notes retain their existing behavior.
