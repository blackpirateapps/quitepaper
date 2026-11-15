# Quiet Paper — Editor & Typography Subsystem

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Editor Philosophy & Dual-Mode Architecture

Quiet Paper emphasizes an editorial, distraction-free writing environment inspired by Bear Notes and iA Writer. 

The editor supports two modes:
1. **Markdown Source Mode**: Raw markdown text editing with syntax highlighting, live formatting toolbar, cycling heading hotkeys, and inline previews.
2. **Visual Editor (SuperEditor)**: Native Flutter document tree editor powered by `super_editor`, featuring rich AST nodes, interactive checklists, code blocks, and typewriter scrolling.

### Key Architectural Invariants
- **Content is Canonical**: The user's text and formatting are preserved without loss.
- **RichText AST Source of Truth**: In Visual Editor mode, the in-memory AST serves as the canonical representation. Edits modify the AST directly, eliminating intermediate compilation cycles during typing and autosave.
- **Zero-Compilation Saves**: Note autosaving serializes directly from the active AST or text buffer without lag.
- **On-Demand Mode Conversion**: Conversion between Markdown text and the SuperEditor AST occurs only when explicitly switching modes.

---

## 2. SuperEditor Components & Smart Widgets

The visual editor resides in [`lib/features/editor/`](file:///home/dog/git/quitepaper/lib/features/editor/) and [`lib/core/syntax/`](file:///home/dog/git/quitepaper/lib/core/syntax/).

### Smart Todolist Subsystem
- **Component**: [`QuietTaskNode`](file:///home/dog/git/quitepaper/lib/features/editor/) / `QuietTaskComponent`.
- **Features**:
  - **Optical Alignment**: Checkbox aligns with the body text baseline.
  - **Smart Placeholders**: Prompting hint text on new empty task items.
  - **Auto-Sorting & Collapsible Done Items**: Completed items can be automatically sorted to the bottom and collapsed into a compact section.
  - **Task Boundary Isolation**: Paragraphs immediately following a task list are isolated so that strikethrough or collapse styles do not spill over into regular paragraphs.

### Native Code Blocks
- **Component**: Native code block node with live syntax highlighting and line numbers.
- **Features**:
  - Multi-language syntax highlighting powered by `flutter_highlight` and bundled syntax definitions.
  - Line numbering gutter with monospaced alignment.
  - Quick language selector modal.

### LaTeX Math Syntax Support (Block & Bear-Style Inline Folding)
- **Engine**: 100% offline, pure-Dart LaTeX rendering powered by `flutter_math_fork`. Zero WebViews or external JavaScript runtimes.
- **Block Math (`QuietMathBlockNode`)**:
  - Loading and paste use `deserializeQuietMarkdown`, registering both math and
    Smart Tables syntax: a custom block syntax
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

## Smart Tables (November 15, 2026)

Tables reuse SuperEditor's `TableBlockNode` and the existing Markdown table
controller/grid. `QuietTableSyntax`/`QuietTableConverter` preserve raw table
Markdown and an adjacent versioned annotation in node metadata;
`QuietTableBlockNodeSerializer` restores this source exactly. Existing prose
normalization bypasses these regions so formula multiplication and annotations
survive visual/source conversion. Legacy RichDocument tables retain annotations.

The pure Dart formula engine supports decimal arithmetic, A1 references and
anchors, ranges, SUM/AVERAGE/MIN/MAX/COUNT, dependency invalidation, cycle/error
propagation and bounded evaluation. Computed results are ephemeral: raw formulas
and optional summary/calculated-column/format metadata stay in the encrypted
note body. Markdown preview uses a display-only projection. Markdown exports
continue to contain formulas; third-party viewers display their source text.

Inline committed text updates reach document history/autosave immediately, without
waiting for Done. Table history includes typing, structural rebasing, rectangular
TSV paste, summary rows, calculated columns and formats. Escape cancels the active
cell and enters table navigation; arrows move/select only outside cell editing.
Shift-click/long-press extend ranges; the functions menu supplies touch column
selection, quick aggregate copy/insertion, summaries and numeric formatting.

See [Smart Tables architecture, grammar, metadata and limitations](smart-tables.md)
and [engineering log 276](latest-logs.md#276-smart-tables-november-15-2026).
