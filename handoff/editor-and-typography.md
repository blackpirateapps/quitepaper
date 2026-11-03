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
  - Implemented in [`QuietMathBlockNode`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_block_node.dart) and rendered via [`QuietMathBlockComponent`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/math/quiet_math_block_component.dart).
  - Delimiters supported: `\[ ... \]`, `$$ ... $$`, and ````math ... ````.
  - Interactive UX: displays rendered mathematical formula with hover/active controls (Copy LaTeX, Delimiter Toggle, Delete, Edit). Tapping expands an inline TeX editor card with live real-time formula preview, delimiter switcher, `Ctrl/Cmd+Enter` to save, and `Escape` to cancel.
  - Shortcut creation: typing `$$` or `\[` on an empty line and pressing `Enter` automatically transforms the paragraph into a `QuietMathBlockNode` via `handleMathBlockFenceNewlineRequest`.
- **Inline Math (`QuietInlineMath`)**:
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

### Typewriter Scrolling
- Automatically keeps the active cursor centered vertically in the viewport during typing.
- Operates across both mobile and desktop screens to prevent the cursor from dropping below the keyboard or viewport edge.

### Autosave & Empty-Draft Disposal
- **Debounced Autosave**: 700ms debounce timer triggers local SQLite saves.
- **Lifecycle Flush**: Focus changes, app pausing, or navigating back immediately flushes pending changes.
- **Empty-Draft Cleanup**: If a user creates a new note but exits without typing any content, the draft is cleanly discarded to prevent empty note clutter.

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
- LaTeX Math Syntax Support (Block & Bear-Style Inline Folding): [Latest Logs, Section 253](latest-logs.md#253-supereditor-comprehensive-math-syntax-support-latex-block--inline-math-bear-style-folding)
- Left-Aligned Note Title & Full-Width SuperEditor Code Blocks: [Latest Logs, Section 251](latest-logs.md#251-ui-polish-left-aligned-note-titles--full-width-supereditor-code-blocks-november-2026)
- Smart Todolist & Task Boundary Isolation: [Latest Logs, Section 242 & 243](latest-logs.md#242-architecture-smart-todolist-in-supereditor-with-optical-alignment-placeholders-auto-sorting--collapsible-done-items-october-2026)
- Native Code Blocks with Syntax Highlighting: [Latest Logs, Section 241](latest-logs.md#241-architecture-super-editor-native-code-block-with-live-syntax-highlighting--line-numbers-october-2026)
- Typewriter Scrolling: [Latest Logs, Section 223](latest-logs.md#223-typewriter-scrolling-ambient-cursor-vertical-centering-across-all-editor-modes-october-2026)
- RichDocument Visual Editor AST: [Latest Logs, Section 136 & 140](latest-logs.md#136-production-grade-richdocument-visual-editor-architecture)
- iA Writer Quattro Typography Integration: [Historical Logs v1.5, Section 32](archive/logs-v1.5.md#32-ia-writer-quattro-typography-integration--cdn-font-delivery)
