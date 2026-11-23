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

`SearchFilterBar` uses content-width underline tabs on desktop, tablet, and mobile.
A themed accent underline identifies the active category above a thin baseline;
labels and positive result counts share a text baseline. The native scrollable
`TabBar` keeps categories accessible in narrow panes and follows provider-driven
category changes through its `TabController`. There is no filled segmented track.

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
  The notes scroll physics hold the list at its top while the reveal owns a
  deliberate pull, preventing a second bounce underneath the sliding card.
  Pointer release commits immediately; cancellation restores the list. Opening,
  closing and spring-back share one interruptible animation, and search focus
  waits until opening finishes. Inline search owns its system-Back handling.
  See the [native animation audit](audits/swipe-search-2026-11-17/README.md).
- **Desktop Search Opening**: Toolbar and keyboard actions open search on the
  next frame without the touch slide animation. The swipe preference gates only
  scroll gestures; explicit search actions remain available when it is disabled.
- **In-Note Search & Replace**: In-editor search bar supporting next/previous navigation and batch text replacement.

---

## Notes List Preview Work

Paginated and legacy grouped-note providers leave metadata extraction to mounted
`NoteListTile` widgets. Grouped pagination watches note data and the selected sort,
so loading flags do not regroup or parse the collection. The screen does not scan
all loaded notes for speculative thumbnails; mounted thumbnail widgets retain
their existing bounded cache and request deduplication.

`NoteMetadataExtractor` keeps an LRU of at most 500 entries. Cache identity compares
exact note ID, title, body, timestamp, tag values and optional snippet. The explicit
`prewarmAll` utility fills unused capacity only, preserving demand-loaded entries
when handed a collection larger than the cache. Large-library state changes must
not reintroduce synchronous collection-wide parsing.

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

## Imported email notes

Email imports use ordinary notes and deterministic existing tag management,
suggesting `email` without requiring it. Visible metadata, converted body and
attachment labels enter the existing FTS/fuzzy-search paths; no separate email
index or ranking policy was added. The source-hash/Message-ID index serves only
duplicate detection. Fresh-device encrypted sync tests verify ordinary search
and tag behavior. See [email import](email-import.md).

## Multi-tag picker

`TagPickerDialog` replaces the editor's plain overflow input and is shared by
the tag bar, frontmatter field and selected-note tagging action. Suggestions
appear before typing. Suggested combines pinned order, local recency and note
counts; Recent, Most used and Pinned expose those categories independently.
Search relevance precedes category ordering. Attached and staged tags are
excluded. Results are bounded to 40 rows, and asynchronous results from older
queries are hidden while the next query loads.

Tap suggestions or press Enter to stage a tag, use Tab to complete a path and
arrow keys to navigate, or paste comma/newline-separated tags. Staged chips can
be removed; Cancel discards all staged changes. Apply also validates and includes
any remaining typed input, with a count including those pending tags. Invalid
paste batches remain editable without partially accepting their valid prefixes.
Slash queries such as `work/` stay within that parent and prefer direct children;
leaf queries such as `project` can find `work/project`. Breadcrumb buttons and
row browse actions fill parent paths. Trailing slashes cannot create tags.

`EditorNotifier.addTags` deduplicates/normalizes a batch and saves it once.
Frontmatter writes a combined tag list in one document update to avoid repeatedly
replacing tags using a stale widget snapshot. Bulk note tagging excludes tags
common to all selected notes and appends only missing tags to each note.

`recently_added_tags_v1` stores at most 50 canonical names in SharedPreferences,
newest first. Editor saves report newly added metadata/inline tags only after
successful persistence; metadata-only edits and failed saves do not update use.
Bulk tagging records history after successful writes. History starts empty on
upgrade, is device-local, and does not change tag sync timestamps. Missing or
renamed names are filtered by the current catalogue until used again. Preference
write failure keeps in-memory history without failing an already-saved note.

Pure Rust `api/tags.rs` supplies deterministic ranking via the existing Linux
watched-import FRB library. `TagSuggestionService` uses the same ordering in Dart
on Android/iOS/other targets or native-load failure; mobile builds gain no Rust
toolchain prerequisite. Bridge output remains under the watched-import native
directory to reuse the existing bundled library and initialization guard.
`tool/tag_suggestions_native_test.dart` compares the actual shared library with
portable results across categories, paths, Unicode, exclusions and limits.
