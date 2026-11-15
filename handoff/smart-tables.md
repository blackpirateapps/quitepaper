# Smart Tables

## Phase 0: audited integration boundaries

Source → `MarkdownTableParser` → source-offset `MarkdownTable` →
`MarkdownTableController` / `MarkdownTableEditor` → source formatter → note body.
Visual → `deserializeMarkdownToDocument` → SuperEditor's `TableBlockNode` →
`QuietTableComponent` → the same cell editor → `ReplaceNodeRequest` →
`QuietTableBlockNodeSerializer` → note body → existing encryption/sync.
`TableEditorScreen` is the expanded workspace. `RichTableEditor` is the older
RichDocument surface; both reuse the source table editor. Preview currently
uses flutter_markdown GFM rendering. Imports and remote notes enter as Markdown;
source/visual switching recreates the visual tree. Note-level sync/merge stores
Markdown and does not understand independent table cells.

Decision: extend TableBlockNode using raw-source metadata, preserving the existing
component and source projection. A custom Markdown block syntax will retain raw
formulas, escaped pipes, alignment and adjacent metadata instead of passing these
through SuperEditor's inline serializer (which can escape formula operators and
lose comments/alignment). No new document model, database or network protocol.

Existing behavior to retain: inline and expanded editing, row/column operations,
inline formatting, source-offset edits, Tab/Enter, raw Markdown persistence,
read-only display, preview, and document history. The current inline editor stages
edits until Done; this must change to publish committed cell edits before autosave
or navigation can lose them. Local table history must also cover cell edits.

Compatibility verification targets: source and visual mode, Linux hardware keys,
Android IME Next/Done, narrow/mobile and tablet widths, read-only preview,
import/export, reopening, encrypted sync and conservative conflict handling.
Automated tests cover shared Dart/Flutter paths; actual device and multi-client QA
must be reported separately.

## Phase 1: formula domain

`domain/smart_tables/formula_engine.dart` contains the bounded tokenizer/Pratt
parser, table-scoped expression/dependency/result caches, downstream invalidation,
A1 addresses and structural/fill rewriting. Decimal arithmetic uses BigInt with
18 fractional digits and 48 integer digits; multiply/divide round half away from
zero. Input with greater precision or magnitude reports #LIMIT!. Aggregates skip
text/blanks, propagate formula errors, count zero; empty MIN/MAX use #VALUE! and
empty AVERAGE uses #DIV/0!. A leading apostrophe before = renders as literal text
without the apostrophe and is retained in Markdown. Baseline: 17 tests passed;
formula domain: 6 tests passed including baseline (grammar, cycles, caches,
precision, limits, references, aggregates).

## Phase 2: canonical source and derived display

`deserializeQuietMarkdown` registers both table and math block syntax/converters
and math inline syntax for note loading, controller paste and native-menu math
paste. Table regions bypass prose normalization in each path, keeping annotations
attached when formulas and prose share a snippet.

Custom table Markdown syntax/converter retains the exact raw table in existing
TableBlockNode metadata. The custom node serializer uses that source; formulas
are never replaced by values. Visual edits now publish through ReplaceNodeRequest
with a stable node ID, and external history replacements reload the cell session.
Read-only tables suppress editing controls. The shared table view and native
Markdown preview calculate ephemeral results; source mode remains raw. Formula
caches are scoped to an active table controller, not the whole editor. Composing
IME text is not rewritten into table delimiters. Bridge + existing visual/table
widget regressions: 45 tests passed. No database or sync changes.

## Phase 3: selection and summary rows

Shift-click or long-press extends a rectangular selection; the functions menu can
select the data column on touch. The strip computes Sum/Average/Min/Max/Count
without mutations and reports excluded errors, with raw/display copy and SUM
insertion. Summary actions materialize aggregate formulas in a final row and
record its exact contents in a versioned comment immediately after the table.
Row/column insertion and deletion rebase references and metadata atomically;
summary formulas exclude themselves. Unknown/malformed annotations are opaque
and retained, and externally altered summary signatures disengage automation.
Table-controller history captures complete source transactions. Summary and
existing widget tests: 19 passed; flutter analyze: no issues.

## Phase 4: calculated columns and number presentation

Calculated-column actions confirm before filling blanks or explicitly replacing
manual values. Templates are materialized into raw A1 formulas, follow anchors
and inserted rows, and survive node/source/reopen conversion in metadata.
Column format settings support plain numbers, fixed decimals (0–18 places), ISO
currency codes and percentages. Intl supplies locale affixes/grouping/digit
shapes, while BigInt decimals retain precision even beyond double's integer
range. The active formula input always shows raw source. Shared inactive views
and preview use formatting without saving display strings. Formula/metadata and
locale tests: 14 passed. Existing prose normalization is bypassed for raw tables
and their annotations to prevent reinterpreting multiplication as Markdown.

## Phase 5: keyboard, clipboard, focus and history

Inline and full-screen operations share controller history, including cell input,
formats, summary/column intent and TSV paste in a single operation. Ctrl/Cmd+Z,
Shift+Z/Y, range copy and bounded TSV paste are scoped to the table. Single-cell
paste retains ordinary text selection behavior. Escape restores the original
cell and enters navigation mode; arrows there navigate/extend selections, while
in-cell arrows remain caret controls. Enter/F2 resumes editing; IME Next advances.
Row/column move/duplicate/promote now rebase formula coordinates with structure.
A summary row cannot move into the data region. Cell semantics expose coordinates,
displayed results and source formulas. Read-only views cache their per-table
projection and formatting. Legacy RichDocument paths retain the annotation too.

A focused widget regression caught and fixed competing parent/cell autofocus.
Interaction regression set: 54 passed; additional hardware-key/IME/autosave and
read-only tests: 5 passed. flutter analyze: no issues. Actual Linux/Android device
smoke testing remains distinct from these Flutter widget simulations.

## Phase 6: hardening and interoperability

Metadata format is a single-line (or preserved multiline) comment directly after
the table, with no blank line:

```markdown
<!-- quiet-paper-table:v1 {"id":"qt_…","summary":{"operations":{"3":"SUM"},"cells":["","","","=SUM(D2:D3)"]},"calculatedColumns":{"3":{"formula":"=B2*C2","row":1}},"formats":{"3":{"type":"currency","currency":"INR","digits":2}},"_layout":{"rows":4,"headers":["Item","Qty","Unit price","Total"]}} -->
```

Metadata row/column indexes are zero-based; formula A1 addresses include the
header as row 1. Unknown fields in supported metadata survive edits. Unknown
versions, malformed/oversized metadata and externally mismatched layout signatures
remain opaque and are preserved verbatim. Questionable configuration is not
applied to newly inserted cells; the active UI explains that the annotation needs
review in Markdown. Remove that annotation in source to configure the table
again. Formula evaluation itself never depends on the annotation.

Summary-cell overrides made in-app opt that cell out of generated formulas while
other summary cells remain maintained. Structural mutations update reference
coordinates even for absolute anchors; anchors suppress shifts only during fill.
Deleted range endpoints shrink the range; a fully deleted reference becomes
#REF!. Move/duplicate operations update references, column formats and templates.
Paste appends data before a summary, rebases formulas and restores everything
with one undo. Exceeding edit limits leaves the source/history unchanged and
surfaces #LIMIT! in the active controls.

The parser respects matching code-fence character/length and ignores HTML
comments. Inactive grids cache table calculations and formatting across unrelated
rebuilds. Per-table limits: 10,000 cells, 256 columns, 2,048 formula characters,
512 tokens, parser depth 64, dependency depth 128, range expansion 10,000 cells,
and 100,000 evaluation work units per update. Annotation generation is bounded
to 16,000 JSON characters. A regression evaluates and invalidates a 3,000-row
table within a generous 10-second CI ceiling and verifies total work exhaustion
for many expensive aggregate formulas. No telemetry or content logging was added.

### Supported formula behavior

- `=2+3*4`, parentheses, unary +/-, nested calls and case-insensitive functions.
- `=B2*C2`, `=SUM(D2:D3)`, mixed absolute anchors such as `=$B$1*C2`.
- Numeric literals use a dot and no grouping/exponents; computation is independent
  of display locale. Plain decimal numbers and evaluated formulas are numeric.
- Blank direct references are zero; text in direct arithmetic is #VALUE!.
  Aggregates ignore blank/text cells but propagate referenced formula errors.
- Stable errors: #PARSE!, #REF!, #DIV/0!, #VALUE!, #CYCLE!, #LIMIT!.
- `'=SUM(A1:A3)` stays exactly that in source and displays `=SUM(A1:A3)` as text.
- Percent formatting multiplies only the display by 100; currency/decimals use
  locale symbols/grouping with exact decimal rounding, never double arithmetic.

### Compatibility and remaining manual checks

Automated tests exercise source/visual/source and legacy AST round trips,
Unicode/escaped pipes/inline code, unknown annotations, cell typing before Done,
document and table undo/redo, scoped hardware keys, IME composing/Next,
read-only formula display, summary/auto-fill/format persistence, database saves,
version restoration, offline edits, and two in-memory clients using the actual
crypto/sync engine and an in-memory API. Server payload assertions verify that
formulas and annotations remain encrypted. No backend/schema/dependency changes.

The existing merge engine is line based. Conflicting edits to one table row
retain both sources for manual resolution. Independent concurrent structural
edits are **not** promised to merge safely by cell. Generic Markdown viewers and
Markdown/PDF export paths retain raw formulas unless they explicitly use native
preview; computed/static export is outside this implementation. Search indexes
stored raw content, not ephemeral calculated values. Displayed TSV applies number
and formula presentation; ordinary inline Markdown cell text retains its syntax.
There are no cell format overrides, merged cells, cross-table references,
exponents, scripts or remote functions. The specified column formats are present;
cell-level overrides were optional in the proposal.

Actual Android/Linux devices, screen-reader announcements, keyboard/IME vendor
behavior, real multi-device networking and PDF appearance still require manual
QA. Flutter widget simulations and local sync tests are not claims of those
physical-device checks.

### Final verification

- Final `flutter analyze --no-pub`: **no issues** (10.9 seconds).
- `flutter test --no-pub`: **2,615 passed** on the serial full-suite rerun.
- Final focused run after expanded-return history and deleted-template-row fixes:
  `flutter test --no-pub test/editor/smart_tables test/editor/table_editor_screen_test.dart test/editor/quiet_super_editor_test.dart test/editor/markdown_table_widget_test.dart`
  — **72 passed**. This includes 32 Smart Tables tests.
- The first full run's single missing SQLite native-library failure was caused
  during concurrent Flutter test builds. The serial rerun passed that test and
  every other repository test. Keep native-asset-building test commands serial.
- `git diff --check`: clean. No backend tests were needed because no backend path
  changed. Physical-device and real-network QA remain listed above.

Returning from the expanded workspace is one transaction in the active inline
history. Repeated Done commits skip unchanged node replacements. Deleting a
calculated column's example row reanchors its template before reference deletion
so subsequent rows retain relative formulas; both have dedicated regressions.
