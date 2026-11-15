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
