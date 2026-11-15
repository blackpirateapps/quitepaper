# Quiet Paper — Tags & Search Subsystem

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Nested Tag Hierarchy with Path-Based Identity

Quiet Paper implements an intuitive hierarchical tagging structure similar to Bear Notes, residing in [`lib/features/tags/`](file:///home/dog/git/quitepaper/lib/features/tags/) and [`lib/core/utils/tag_parser.dart`](file:///home/dog/git/quitepaper/lib/core/utils/tag_parser.dart).

### Key Concepts
- **Path-Based Identity**: Tags use forward-slash paths (e.g. `#work/project/planning`).
  - Supports numeric segments (e.g. `#journal/2026`, `#finance/2026/q3`).
  - Hierarchical relations are derived naturally from paths; renaming a parent can propagate to its children.
- **Collapsible Subtrees**:
  - The navigation sidebar and Tags management view feature collapsible chevron indicators.
  - Subtrees can be expanded or collapsed to keep large taxonomies clean.
  - **Subtree Count Propagation**: Parent tags display badge counts representing the total notes contained in their entire descendant subtree.
- **Tag Picker (`#` Trigger)**:
  - Typing `#` in the editor brings up an autocomplete overlay showing matching existing tags.
  - Full paths are displayed clearly to help users select exact subcategories.
  - **Deferred Tag Creation**: New tags typed into a note are not written to the database until the note is saved.
- **Context Menus & Actions**:
  - Long-press or context-clicking any tag reveals unified options: Rename, Delete, Change Color, or "Add nested tag".

---

## 2. Tag Synchronization & Integrity

Cross-device tag synchronization is managed via [`lib/features/tags/application/`](file:///home/dog/git/quitepaper/lib/features/tags/application/):
- **Deterministic IDs**: Tag IDs are generated deterministically from normalized paths to prevent duplicate entries when multiple devices create the same tag offline.
- **FK Constraint Protection**: The `upsertSyncedTag` database helper resolves foreign-key race conditions when synchronizing note-tag relationships before the tag entity itself arrives.
- **Accent Color Lifecycle**: Custom accent colors assigned to tags synchronize seamlessly across devices.

---

## 3. Search Engine & Discovery

The search subsystem resides in [`lib/features/search/`](file:///home/dog/git/quitepaper/lib/features/search/) and [`lib/core/search/`](file:///home/dog/git/quitepaper/lib/core/search/).

### Universal Fuzzy Search
- **Multi-Token Relevance Ranking**: Queries with multiple keywords match against note titles, decrypted note bodies, tag names, document names, and OCR text.
- Results are ranked by relevance (title match > tag match > body match > OCR match).

### Category Filters
- Quick filters allow users to narrow results instantly:
  - **All**: Unfiltered search across all entities.
  - **Notes**: Standard markdown and visual notes.
  - **Docs**: Documents and image attachments, including OCR matches.
  - **Tags**: Notes whose tags match the query.

### Desktop and Tablet Search Workspace

- At an available width of **600dp or greater**, `SearchScreen` shows compact
  results on the left and a read-only preview on the right. Portrait tablets use
  this same arrangement. Narrower windows retain the single-column phone view.
- `SearchWorkspace` keeps search/category controls above the results and provides
  a draggable divider with minimum pane widths. The initial split is 40% results;
  resizing respects each pane's minimum and adapts to window changes.
- The first visible result previews automatically. Clicking a row selects it;
  explicit selections survive progressive result updates. A changed query or
  category selects the first new result, and previous-query results are hidden
  while the search provider refreshes. All preserves the existing notes-then-docs
  ordering; other categories use the model's filtered lists.
- `SearchResultPreview` uses `QuietMarkdownPreview` for Markdown and RichDocument
  notes without mutation callbacks or interactive checklists. Protected notes
  require opening/unlocking. PDF results show their matching page in a viewer
  without annotation controls; images show a passive image and OCR snippet.
  Unavailable documents show their match text, and web snapshots open separately.
- **Open** launches the existing note/document/image viewer; **Edit** opens a note
  in editing mode. Returning from a note refreshes search results. No editor or
  autosave session starts merely from selecting a search result.
- Toolbar/keyboard actions open a full-window search route on desktop/tablet;
  the tablet list's pull gesture opens the same route instead of confining it to
  the 320dp notes pane. Phone pull-to-search retains its in-place reveal.

### Visual Highlighting & Navigation
- Search matches highlight matching terms within note snippets in real time.
- Clicking an OCR match jumps directly to the matching page in the PDF / Scanned Document Viewer.
- **In-Place Pull-Down to Search**: Pulling down on the note list smoothly unveils the search input without jarring screen transitions or layout pops.
- **Desktop Search Opening**: Toolbar and keyboard actions open search on the
  next frame without the touch slide animation. The swipe preference gates only
  scroll gestures; explicit search actions remain available when it is disabled.
- **In-Note Search & Replace**: In-editor search bar supporting next/previous navigation and batch text replacement.

---

## Key References & Logs
- Redesign: Sidebar Navigation Drawer ("Pure Bear List" & Editorial Aesthetic): [Latest Logs, Section 249](latest-logs.md#249-redesign-sidebar-navigation-drawer-quiet-paper-editorial-bear-aesthetic-november-2026)
- Redesign: "Pure Bear List" Aesthetic (Tags Browser): [Latest Logs, Section 247](latest-logs.md#247-redesign-tags-browser-screen-pure-bear-list-aesthetic-november-2026)
- Nested Tag Hierarchy & Path Identity: [Latest Logs, Section 227](latest-logs.md#227-nested-tag-hierarchy-with-path-based-identity-october-2026)
- Tag Picker on '#' & Deferred Creation: [Latest Logs, Section 228](latest-logs.md#228-tag-picker-on--full-path-note-display-and-deferred-tag-creation-october-2026)
- Collapsible Tags & Subtree Count Propagation: [Latest Logs, Section 229 & 230](latest-logs.md#229-prominently-collapsible-children-tags-in-sidebar-and-tags-page-october-2026)
- Tag Sync FK Failure Resolution (`upsertSyncedTag`): [Latest Logs, Section 210](latest-logs.md#210-tag-sync-fix-sqlite-foreign-key-constraint-failure-on-duplicate-tag-merge-upsertsyncedtag-october-2026)
- Pull-Down to Search Unveil: [Latest Logs, Section 203](latest-logs.md#203-in-place-pull-down-to-search-unveil--zero-lag-transition-october-2026)
- Universal Fuzzy Search Engine: [Historical Logs v1.5, Section 63](archive/logs-v1.5.md#63-universal-fuzzy-search--multi-token-relevance-ranking-engine)
