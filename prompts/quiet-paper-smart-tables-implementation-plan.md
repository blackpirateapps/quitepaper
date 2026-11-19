Implement the **Quiet Paper Smart Tables** feature using the attached technical implementation plan. Create a new branch and implement it there. Do the work in phases and make commits after completing each phase. 
Do not run full tests, only run the relevant tests. The github workflow already runs full test. 
You have access to the complete repository. Before implementing anything:

1. Read `AGENTS.md`, `HANDOFF.md`, `handoff/core-architecture.md`, and `handoff/editor-and-typography.md`.
2. Inspect the actual table implementation in SuperEditor, including table nodes, rendering, Markdown parsing/serialization, selection, keyboard handling, and undo/redo.
3. Identify existing functionality that can be reused. Do not assume undocumented classes or rewrite working systems unnecessarily.
4. Validate the implementation plan against the actual codebase. Adapt it wherever necessary.

**Implementation requirements:**
- Implement the selected features in the plan, not just UI placeholders.
- Work in phases, completing and testing the core formula engine before adding advanced table interactions.
- Maintain full compatibility with both Markdown source mode and visual SuperEditor mode.
- Preserve formulas through editing, autosave, app restarts, and encrypted synchronization.
- Keep all calculation logic local and offline.
- Integrate properly with the existing editor's undo/redo, selection, and focus systems.
- Add thorough unit, widget, integration, and regression tests.

**Engineering constraints:**
- Do not break existing note editing, math blocks, task lists, or Markdown support.
- Do not introduce unnecessary architectural complexity.
- Avoid modifying the encryption or synchronization protocols unless absolutely necessary.
- Run `flutter analyze` and `flutter test`, and report the actual results.
- Update `handoff/latest-logs.md` and relevant architectural documentation.

Implement working functionality—not a prototype or mockup.

If you discover significant architectural conflicts with the plan, explain them and choose a solution consistent with the existing repository.

**Deliverables:** Complete implementation, tests, updated documentation, and a final report describing modified files, working features, verification results, and any remaining limitations.



# Quiet Paper — Smart Tables Technical Implementation Plan

**Status:** Implementation proposal, not a claim about existing table internals  
**Scope:** Arithmetic; `SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT`; formula cells and live results; selected-range quick summaries; Markdown round-trip and offline operation; summary rows; calculated columns/auto-fill; numeric formatting; keyboard navigation; copy/paste; undo/redo.

## 0. Evidence, invariants, and non-assumptions

The supplied files are `HANDOFF(3).md`, `core-architecture.md`, and `editor-and-typography.md`.

Confirmed in those files:
- Quiet Paper is Flutter/Dart, offline-first, with Drift/SQLite local persistence and zero-knowledge client-side encrypted sync.
- The visual editor uses `super_editor` and an in-memory `RichDocument` AST as its source of truth, while Markdown source mode edits raw text. Mode conversion occurs on demand, not on every keystroke.
- The editor has a 700 ms debounced autosave and lifecycle/focus/exit flush behavior.
- The visual editor already has custom components and specific solutions for embedded focus and tap conflicts (notably math blocks), but this does **not** establish how tables work.
- The handoff says changes should be logged to `handoff/latest-logs.md`, with relevant domain documentation updated; tests include `flutter test` and `flutter analyze`.

**Unknown until code inspection:** Whether tables are existing `DocumentNode`s, ordinary Markdown, a renderer extension, a third-party component, or a combination; the current table editing commands and selection state; table Markdown parsing/serialization implementation; whether the current Markdown preview supports GFM tables; how table content participates in undo/redo and merge; any table-specific automated tests. **Do not invent file paths, APIs, or a table node type as existing facts.**

### Gate 0 — repository discovery (mandatory before implementation)

Search for table implementations, Markdown handling, and editor command registration:

```bash
rg -n 'table|Table|Gfm|gfm|markdown' lib/features/editor lib/core test
rg -n 'SuperEditor|DocumentNode|ComponentBuilder|DocumentEditor|Undo|Redo|clipboard' lib/features/editor lib/core test
rg -n 'serialize|deserialize|toMarkdown|fromMarkdown|RichDocument|documentChange' lib/features/editor lib/core test
```

Inspect the relevant actual source files and construct a table-flow diagram: Markdown source → parser → AST/table representation → component/selection/edit actions → serializer → persisted note body → renderer/preview. Identify the *same paths* for import, editor switch, and remote sync/conflict resolution. Determine which layer already owns table cell IDs, row insertion, keyboard shortcuts, and undo. Only then choose an adapter or component design.

**Gate-0 deliverables:** a concise inventory of actual table-related files and entry points; an explicit decision whether to extend the existing table node or introduce a custom one; baseline tests proving current table create/edit/save/reopen/source-mode behavior; a list of existing table behavior that must remain unchanged.

## 1. Product contract and strict scope

1. Tables remain visually quiet when not selected. A cell containing a formula displays a calculated result; selecting/editing it reveals its original `=...` formula. Errors are visible but do not replace stored source.
2. Standard Markdown table syntax remains readable in other apps. Formula strings are canonical Markdown cell contents. Optional Quiet Paper behavior is carried by a versioned, ignorable metadata annotation, not by storing computed values in place of formulas.
3. Only calculations within the **same table** are supported. Cross-table/note references, time/date functions, user-defined code, charts, filtering, and macros are out of scope.
4. Evaluation is deterministic, on-device, and pure Dart. It never makes network calls or uses arbitrary code execution. Calculation results and cached dependency graphs are ephemeral derived state.
5. No note content should be rewritten or dropped simply because a formula cannot be evaluated, metadata is unknown, or an external Markdown editor changes the table.
6. The source/visual modes preserve text, formulas, and metadata without silent destructive transformations. All edits flow through the existing canonical editor/save path.

## 2. Functional specification

### 2.1 Formula grammar

A **formula** is a trimmed cell value starting with `=` (e.g. `=B2*C2`). A literal string beginning with `=` can be entered with a leading apostrophe convention (`'=SUM(A1:A3)`); document its exact rendering/escaping behavior and test it. Use A1 coordinates, where the header row is row 1 and the first data row is row 2. Column letters are `A..Z`, then `AA`, and so on.

MVP syntax:

```text
expression  := additive
additive    := multiply (("+" | "-") multiply)*
multiply    := unary (("*" | "/") unary)*
unary       := ("+" | "-") unary | primary
primary     := decimal | reference | function_call | "(" expression ")"
reference   := "$"? column "$"? positive_row
range       := reference ":" reference
function_call := ("SUM" | "AVERAGE" | "MIN" | "MAX" | "COUNT") "(" range_or_expr_args ")"
```

Implement a real tokenizer/parser (Pratt or recursive descent) with explicit limits. Do **not** evaluate expressions via code execution, a WebView, or string substitution. Function names are case-insensitive. Commas separate function arguments; `:` designates contiguous inclusive ranges. Allow numeric literals, parentheses, unary negatives, and nested arithmetic. Relative/absolute `$` references are strongly recommended from the outset because auto-fill otherwise becomes underspecified; if not supported, explicitly reject them and implement only relative references until later.

**MVP semantics:**
- `+`, `-`, `*`, `/` operate on numbers; `=B2-C2` is subtraction; `=B2/C2` is division.
- Aggregates ignore empty cells and plain-text cells. `COUNT` counts numeric values including zero, not text. `AVERAGE` with no numbers reports `#DIV/0!`; empty `SUM`/`COUNT` are zero; empty `MIN`/`MAX` report `#VALUE!` (document this chosen behavior).
- A referenced formula cell uses its computed numeric result. Referenced errors propagate into dependent formulas; a direct arithmetic reference to nonnumeric text reports `#VALUE!` rather than guessing.
- Use a decimal arithmetic strategy rather than relying on binary floating point for money-related calculations. Determine supported precision/range and rounding policy; keep raw values numeric and formatting separate.
- Use stable, non-executable errors such as `#PARSE!`, `#REF!`, `#DIV/0!`, `#VALUE!`, `#CYCLE!`, and `#LIMIT!`.
- Do not support references across tables or hidden arbitrary names in MVP.

### 2.2 Table operations

**Formula cell:** Editing displays `=B2*C2`; committed display is computed number. Underlying source never becomes the computed number. Recalculate after commits (and optionally with a short edit debounce for in-cell preview), without waiting for autosave.

**Selected-range quick summary:** When a contiguous rectangular set of numeric cells is selected, show a small contextual summary strip or popover: Sum, Average, Min, Max, Count. It is read-only until the user chooses Copy Value or Insert Result/Formula. For mixed selection, skip blank/text; surface how many invalid/error cells were excluded. No document mutation when simply viewing the summary.

**Summary row:** An explicit action adds/marks a designated final summary row. Per numeric column the user can choose one aggregator; write the generated cell formula into Markdown and record the row's special role in metadata. The summary formula range covers only data rows, never its own cell. When data rows are appended or deleted, update generated formulas atomically, keeping the summary row last. User-overridden summary cells are not silently overwritten.

**Calculated column:** The user converts a column to a formula-driven column from a selected example cell/formula. Existing eligible blanks can be filled on confirmation; new data rows receive a shifted copy of the template. Relative references shift by row; `$` absolute anchors do not. Record the template and column intent in metadata while still materializing each generated formula as canonical Markdown. Do not overwrite manually edited cells unless the user chooses Reapply Formula. Display a subtle indicator only while the table is active.

**Formatting:** Column default, optionally cell override, for plain number, decimal precision, currency (ISO currency code), and percentage. Persist a numeric raw value/formula in Markdown; format only the result on display (e.g., raw `0.15` formatted as `15%`, raw `2500` as `₹2,500.00`). Format settings are locale-aware for display only; formula parsing and persisted numeric literals remain locale-neutral. Copy/paste offers raw and displayed modes where practical.

**Keyboard/accessibility:** Tab/Shift+Tab navigate to next/previous cell, Enter commits and advances, Escape cancels edit, arrow keys navigate **only outside in-cell text editing**. Tab from the last data cell can add a row before a summary row. A text editor within a cell owns its caret keys. Ctrl/Cmd+C copies selection as TSV, Ctrl/Cmd+V parses TSV/compatible clipboard text, and ordinary single-cell text paste remains intact. Copy/paste and bulk fill must be a single undoable edit. Expose keyboard focus, row/column coordinates, displayed value, and formula source to accessibility APIs. Test Android IME Next/Done and desktop behavior separately.

## 3. Architecture proposal (suggested new modules, not claimed existing)

Keep the following as *pure Dart* services independent of Flutter widgets, the backend, and SQLite:

| Concern | Suggested abstraction | Responsibility |
|---|---|---|
| Values | `CellValue` (`number`, `text`, `blank`, `error`) | Typed evaluation results; no UI labels as source |
| Table snapshot | `TableSnapshot` / `CellAddress` | Immutable rows, columns, raw cell strings, table ID |
| Parser | `FormulaTokenizer`, `FormulaParser` | Produce typed expression AST and source spans |
| Evaluator | `FormulaEngine` | Evaluate expressions/functions deterministically |
| Dependencies | `TableDependencyGraph` | Track referenced cells/ranges, invalidate affected results, detect cycles |
| Editing operations | `TableEditPlanner` | Produce atomic cell/row/column changes, rebase references, and metadata edits |
| Configuration | `SmartTableMetadata` | Versioned summary/calculated-column/format settings |
| Markdown bridge | `SmartTableMarkdownAdapter` | Parse and serialize raw Markdown/metadata losslessly |
| UI bridge | Existing or new table component adapter | Render values, handle focus/selection, dispatch edits via actual editor command APIs |

### Integration boundaries

- **Visual AST:** Choose the smallest viable adapter to existing table internals discovered in Gate 0. Raw formula strings and semantic metadata are the model; computed values must be ephemeral view state. Do not replace the entire `RichDocument` or rebuild it on every keystroke. Dispatch edits through existing editor transaction/undo infrastructure.
- **Source editor:** Markdown mode shows the original strings and annotation; edit as plain text. Reparse/recalculate on switching back or when a source preview is requested. Do not put a formula engine inside the source keystroke path.
- **Markdown preview:** The native Quiet Paper preview may display computed values through a non-mutating local projection if its parser supports the table shape. Never write those projected numbers back into the note. A generic external Markdown viewer will normally show the `=...` formulas as text; that compatibility limit is intentional.
- **Persistence and sync:** Continue using the canonical note body and existing encrypted sync flow. A metadata annotation inside that body normally avoids schema/backend migrations, but Gate 0 must verify parser and merge round-trips. Calculation caches remain local and ephemeral; the server sees only existing encrypted note data.
- **Lifecycle:** Re-evaluate after local table mutations, parse or mode switch, note reopen, and remote note apply; reuse existing 700 ms autosave without imposing a new save on every dependency update.

### Incremental computation

Build an expression AST cache keyed by (table ID, raw formula), dependency mapping, and evaluated-value cache per table. On edit: update raw cell → reparse changed formula if needed → invalidate downstream dependents → run topological evaluation or DFS with visitation states → publish only changed visible cells. Use bounded range expansion, recursion-depth limits, and a maximum computation budget. Non-formula tables incur minimal overhead. Avoid a full document parse for simple numeric changes.

## 4. Markdown round-trip contract

### Canonical example

```markdown
| Item | Qty | Unit price | Total |
| --- | ---: | ---: | ---: |
| Paper | 2 | 125 | =B2*C2 |
| Pens | 3 | 40 | =B3*C3 |
| Total | | | =SUM(D2:D3) |
```

In visual mode, the total column displays `250`, `120`, `370`. Source mode remains exactly the formulas above (apart from existing intentional normalizations of the app's current serializer, which need audit). Markdown clients without the feature display formula text.

### Optional metadata — recommended approach after Gate 0

Use a **namespaced, versioned, ignorable Markdown HTML comment adjacent to a table** for functionality not representable in standard pipe tables. The exact delimiter and attachment order must be validated against actual Markdown parser/serializer behavior. Example **proposed** format:

```markdown
<!-- quiet-paper-table:v1
{"id":"qt_8c9","summary":{"position":"last","columns":{"D":"SUM"}},"calculatedColumns":{"D":{"template":"=B{row}*C{row}"}},"formats":{"C":{"type":"currency","currency":"INR","digits":2},"D":{"type":"currency","currency":"INR","digits":2}}}
-->
```

Treat this as a schema sketch, **not** a final specification. Resolve comment location, whitespace, escaping, maximum size, schema version, unknown-field preservation, and table association after inspecting existing parser and document AST. Metadata is part of encrypted note body. Do not add ad hoc SQLite side tables for note-specific settings unless the code audit exposes a concrete need; independent sidecars would complicate export/import, conflict reconciliation, and source-mode fidelity.

**Identity/structural integrity:** Assign stable table IDs when metadata is first needed; ordinary tables require none. Metadata referring to a last-row summary is valid only when that row's formula/content can be verified. On external edits that move/replace rows, conservatively disengage questionable summary/auto-fill semantics and preserve all text; never reinterpret an unrelated row as a summary. Keep column metadata aligned when the app performs column insert/delete/move operations. Track unknown annotation versions verbatim, without deleting or rewriting them.

**Round-trip invariants:**
1. Parse → serialize → parse preserves table dimensions, raw cell strings/formulas, text containing escaped pipes, Unicode, blank cells, column alignment, neighboring paragraphs, and annotations.
2. A formula in canonical Markdown is unchanged by calculation; a calculated display value is never serialized in place of its formula.
3. Source → visual → source is non-destructive, including malformed expressions, unknown metadata versions, and text beginning with `=` that is escaped as literal.
4. Insert/delete row or column appropriately rebases relative A1 references and ranges in the **same atomic edit**. Deleting a referenced cell/column produces `#REF!` where applicable; it never silently points to the wrong data.
5. If a third-party Markdown app strips the metadata, the formula text remains readable and evaluable, but enhanced formatting/automatic-column/summary intent may be lost. This is a documented interoperability trade-off.
6. Sync conflict handling must preserve annotations and formulas as note content. Do not claim safe automatic merge of concurrent structural table edits until the existing merge path is audited and tested.

## 5. Edit commands and undo/redo contract

Model all mutations as semantic operations: `SetCellRawValue`, `InsertDataRow`, `DeleteDataRow`, `FillCalculatedColumn`, `SetColumnFormat`, `CreateSummaryRow`, `SetSummaryOperation`, and `PasteRange`. Each creates one atomic editor transaction containing cell text, row/column structure, any rebased formulas, and metadata updates; record an inverse operation or use the existing editor history system if suitable.

- A single keystroke in a cell should not trigger full serialized note rebuild.
- Editing a value and recalculating its dependents should produce **one** undo step (not one per dependent output); dependent outputs are derived.
- Changing a column format should be undoable even though it doesn't change raw cell numbers.
- Copy uses TSV for rectangular ranges. Paste is bounded by table limits and provides coherent insert/overwrite behavior. Validate multiline quoted cells before offering CSV support; TSV is the MVP.
- Avoid installing table shortcuts globally: register them only while a table cell/selection owns focus. Preserve existing SuperEditor text input, shortcuts, math editing, list and divider behavior.

## 6. Detailed implementation phases, each with a gate

### Phase 0 — Audit and baseline (must finish first)
- Locate actual table create/edit/select/render/serialize paths and all mode-conversion boundaries.
- Write existing-behavior round-trip tests before code changes.
- Produce a compatibility matrix: Android, Linux desktop, tablet, Markdown source, visual, preview, import/export, sync, conflict merge.
- **Gate:** Documented entry points and green baseline tests; adopt or revise architecture based on findings.

### Phase 1 — Pure Dart domain and formula engine
- Implement immutable table snapshots, addresses, tokenizer, parser, decimal calculations, functions, typed errors, graph invalidation, and input limits.
- Implement A1 parsing/rebasing, including relative/absolute behavior required for fill.
- **Gate:** Exhaustive unit tests without Flutter or database; calculation engine has no UI/network dependencies.

### Phase 2 — Canonical Markdown and visual cell integration
- Wire a minimal formula cell into actual existing table architecture; display result, edit formula, show errors.
- Add parse/serialize handling for formula text and literal-leading-`=` cases.
- Hook recalculation into document mutations, mode switches, reopen, and preview projection.
- **Gate:** A note saved/reopened/switched between modes retains source formula exactly and shows correct values, without typing latency or new server migrations.

### Phase 3 — Selection quick summaries and summary rows
- Implement rectangular selection projection with live, read-only quick aggregates; Copy/Insert actions.
- Add a designated summary row with live-updated formulas and table-structure-aware maintenance.
- Implement versioned metadata persistence (and unknown metadata preservation), if not already required earlier.
- **Gate:** Row append/delete updates totals correctly; summaries exclude themselves and are undoable.

### Phase 4 — Calculated columns, formatting, and auto-fill
- Add formula templates and row-relative copy, default blank-cell filling, respect for manually overridden cells.
- Add number, decimals, percentage, and currency formats with fixed persisted raw values.
- **Gate:** New rows get correct relative formulas; undo and Markdown/source switching retain calculated-column intent and presentation settings.

### Phase 5 — Keyboard, clipboard, accessibility, history
- Implement scoped desktop/tablet navigation, mobile keyboard actions, rectangular TSV clipboard, paste transactions, escape/cancel, multi-operation undo/redo.
- Verify focus isolation against SuperEditor components and toolbar behavior.
- **Gate:** Keyboard-focused smoke tests on Linux and Android plus undo/reopen tests pass.

### Phase 6 — Hardening, sync, documentation, release
- Test remote encrypted sync and concurrent note changes, import/export, malformed/out-of-range data, long documents, and maliciously expensive formulas.
- Add performance benchmarks and telemetry-free local profiling; maintain normal typing and scrolling responsiveness.
- Update `handoff/editor-and-typography.md`, active engineering log, and relevant tests/docs; run `flutter test`, `flutter analyze`, plus relevant backend tests if the changed path warrants them.
- **Gate:** All non-negotiable acceptance tests pass on the primary platforms; no plaintext formula data reaches backend code.

## 7. Test matrix (minimum)

| Area | Cases |
|---|---|
| Parser | `=2+3*4` = 14; parentheses; unary `-`; mixed-case function names; malformed tokens; nested calls; escaped literal `=`; source limits |
| Arithmetic | Negative and fractional values, zero, precision policy, divide-by-zero, text-vs-number, out-of-bounds references |
| Aggregates | Sum/average/min/max/count of 0, blank, text, mixed ranges; errors; fully empty ranges; header row; nested formulas |
| Dependencies | Multiple downstream cells; fan-in/fan-out; self-reference; two-cell cycle; range including self; cache invalidation after edits |
| Structural edits | Insert/delete row above formula; append before summary; insert/delete column; preserve/adjust `$` refs; invalid deletion yields `#REF!` |
| Markdown | Source/visual/source; save/reopen; escaped `\|`; Unicode; empty cells; HTML comments; unknown metadata versions; duplicate tables; malformed metadata; external edits |
| Auto-fill | Insert row; fill blanks; relative offsets; absolute anchors; manual overrides; deleting formula source; bulk undo |
| Formats | INR/USD and generic ISO codes, locale grouping, `%` on 0.15, fixed precision, raw-value preservation, copy/display distinction |
| Input/history | Tab/Shift+Tab; Enter/Escape; arrow behavior during cell editing; TSV paste, multi-cell undo, single-cell text paste; accessibility |
| Integration | Editor source/visual/preview, markdown import/export, reopen, multi-device sync, encrypted payload, conflict handling, offline queue |
| Regression | Ordinary Markdown tables; existing math blocks, task lists, dividers, typography, body autosave; Android IME and Linux shortcuts |

**Golden acceptance walkthrough:**

1. Create the canonical example table above. In visual mode see `250`, `120`, `370`; raw Markdown still contains `=B2*C2`, `=B3*C3`, `=SUM(D2:D3)`.
2. Change `B2` from `2` to `4`. See `500`, `120`, `620` immediately; autosave later follows existing behavior.
3. Append a `Notebook | 1 | 50` row before the summary. The calculated column produces `50`, and the summary becomes `670`; summary range expands to cover the inserted row.
4. Set Total to INR with two decimals. Visual values are formatted; source formulas/numeric input remain unchanged.
5. Select the two data totals plus the new row total: quick Sum is `670`, Average is `223.333…` according to the display precision, Count is `3`.
6. Undo row insertion once and get the previous formulas, values, metadata, and row count. Redo restores all.
7. Switch to source mode, switch back, close/reopen, go offline, edit, reconnect and sync to another client. Formulas and intended metadata remain intact, with all calculations local.

## 8. Risks and deliberate decisions

- **Undocumented table internals:** Architectural adapters and file names are proposals until Gate 0; avoid prematurely replacing existing table support.
- **CommonMark interoperability:** Computed values do not appear in third-party Markdown renderers. An explicit “Export as static table” operation can be a future feature, not the canonical storage path.
- **Metadata association and external edits:** Adjacency comments need parser/serializer and merge testing; if robust association cannot be guaranteed, deliver basic formulas first and defer enhanced table state.
- **Coordinate semantics:** A1 references are human-readable but row/column edits require deterministic rebasing. Write structural-edit tests before shipping auto-fill.
- **Numeric accuracy:** Currency needs explicit decimal precision/rounding policy; do not use locale-formatted strings as computational input.
- **Conflict handling:** Existing note-level 3-way merge must be audited for atomic table edits; cannot promise safe independent cell merge on concurrent devices without code evidence.
- **Performance:** Table evaluation must not invalidate the whole document on every keypress; preparse, cache, and incrementally update.
- **Scope:** Do not add charts, user scripts, remote formula functions, or cross-note references in MVP.

## 9. Specific source files needed for code-level execution

The uploaded documentation supports this architecture-level plan, not a verified file-by-file patch. To generate exact edits and commands for the real repository, inspect/upload the concrete files that implement: (1) table node/component/editor commands and selection, (2) Markdown-to-AST and AST-to-Markdown table parsing/serialization, (3) existing editor undo history/clipboard/keyboard bindings, (4) Markdown preview renderer, and (5) any table-related tests. The `handoff/sync-and-storage.md` guide and current engineering logs would help validate conflict and serialization choices, but are not needed to understand this proposed plan.
