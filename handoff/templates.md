# Phase 1 note templates

## Repository audit

The November 18, 2026 baseline uses Drift schema 20 (not the older versions in
some subsystem guides). Notes have no storage_format column: canonical content
is Markdown or self-identifying RichDocument v1 JSON. Super Editor publishes
Markdown synchronously; Visual Editor publishes JSON after a 50 ms debounce,
except frontmatter documents which remain Markdown. Template saving must flush
that editor buffer and await local autosave before reading the persisted note.

NotesRepository.saveNote maintains normal tags, search, links and dirty-note
sync behavior. It is the instantiation entry point. Templates never use that
path until a user explicitly creates an ordinary note.

BackupPayload v1 accepts optional collections. RestoreStrategy supports merge,
keepBoth and replace within a Drift transaction. Templates extend that payload
without changing its authenticated encryption envelope. Local erasure goes
through AppDatabase.eraseAllLocalVaultData. The shared adaptive modal supports
mobile sheets and desktop dialogs. There is a spotlight modal primitive but no
registered general command palette in the baseline; a small notes command
palette will expose the required template command using that primitive.

## Feature overview and scope

Templates are independent full-note snapshots, separate from the note library.
Phase 1 supports eight bundled read-only templates, user snapshots, name search,
read-only previews, favorites, rename/delete and ordinary note creation. It has
no variables, dates, recurrence, sharing, cloud template sync, body editor,
attachment cloning, journal automation or template history. No dependency or
backend changes were needed. The source specification is `prompts/templates.md`.

## Domain model and validation

`lib/features/templates/domain/note_template.dart` defines immutable snapshots:
UUID identity, independent display name, canonical content, Markdown/richAst
format, normalized default tags, UTC timestamps and schemaVersion 1. The source
and favorite flags are derived. Lists are immutable. Names trim whitespace,
allow duplicates and Unicode, reject controls/newlines and cap at 80 graphemes.
There is no additional template body-size cap.

`application/template_content.dart` recognizes the existing RichDocument v1
schema, validates its structural round trip, rejects unsupported fields/block
identities and keeps the original serialized bytes. Markdown remains verbatim.
Validation and selected-document conversion use `compute`, not per-row parsing.
Normal external hyperlinks and internal note links remain supported. A blank
rich document without meaningful source metadata cannot become a template.

## Schema and migration

Drift **21** adds only `note_templates` and `template_favorites`.

| Table | Columns |
| --- | --- |
| note_templates | id PK, display_name, content, storage_format, default_tags_json, created_at, updated_at, schema_version (default 1) |
| template_favorites | template_id PK |

Timestamps use existing Drift dateTime conventions (second precision on disk).
Tags are a validated JSON string array, not ordinary tag memberships. Favorites
have no foreign key because bundled templates have no database rows. Fresh
creation includes both tables; the upgrade creates them in a transaction without
rewriting notes/tags/attachments/sync metadata. Generated Drift code is checked
in. The migration test opens a real version-20 SQLite file whose schema contains
only the pre-feature tables and verifies existing data after upgrading.

## Bundled catalog

`data/built_in_templates.dart` contains immutable definitions with empty tags,
no default favorites, fixed order, and bodies copied verbatim from the prompt:

| ID suffix (all prefixed `builtin.`) | Name |
| --- | --- |
| daily_planner.v1 | Daily Planner |
| meeting_notes.v1 | Meeting Notes |
| study_notes.v1 | Study Notes |
| reading_notes.v1 | Reading Notes |
| project_brief.v1 | Project Brief |
| bug_report.v1 | Bug Report |
| weekly_review.v1 | Weekly Review |
| decision_log.v1 | Decision Log |

The repository rejects built-in inserts/rename/delete by requiring a UUID for
user records. No installation seeding or ordinary-note flag is involved.

## Repositories, services and reactive state

`data/template_repository.dart` handles parameterized Drift queries and reactive
streams. Deletion removes a user record and its favorite in one transaction.
`application/template_service.dart` is the authoritative creation pathway and
centralizes source eligibility, snapshots, instantiation, favorites, rename,
delete, preview and section ordering. `template_providers.dart` combines database
streams with bundled definitions. Search, selection, focus, mutation guards and
recoverable errors belong to each browser/dialog session and are disposed with
that session; there is no global mutable template collection.

Rows use short editorial descriptions for built-ins and bounded literal
snippets for user snapshots, including a bounded inline excerpt for ASTs when
available (a format label otherwise). A favorite toggle
never reparses bodies or touches ordinary note indexes. Search trims whitespace
and matches names case-insensitively. Favorites sort alphabetically, user
snapshots newest first, and built-ins keep catalog order. A favorite is displayed
only once. Unknown bundled favorite IDs remain on disk but do not create rows
in the UI.

## Save-as-template flow

The editor overflow action is shown for a persisted ordinary editable source;
trash, journal, read-only and specially protected content are ineligible.
An unlocked password-protected note remains ineligible. Quick Capture has no
template action. The adaptive name dialog uses the editor's visible title and
keeps input/errors after failed writes.

Before snapshotting, `MarkdownEditorState.flushPendingChanges` publishes pending
Visual edits through the existing 50 ms autosave serialization pathway. The
notifier then cancels its debounce and awaits local persistence, including an
in-flight save and edits made during it. Failed autosave cannot produce a stale
snapshot. The service re-reads the canonical persisted note and validates it
before inserting a new independent UUID and tag snapshot. Snapshot insertion
does not change source timestamps, history, flags or sharing metadata.

Autosave now serializes overlapping local writes and keeps/reschedules dirty
edits made during a prior write. Template operations do not create a second
editor/autosave controller.

## Instantiation and title/frontmatter handling

Resolve by ID again at activation, validate content, construct a fresh normal
`Note`, then call `NotesRepository.saveNote`. Tags combine template defaults
with the invoking tag workspace and normalize/deduplicate through `TagParser`.
The new note title is the current template display name. IDs/timestamps are
fresh; archive/trash/pin/journal/password/share/history/sync revisions are not
copied. The repository maintains ordinary tag/search/link/dirty-sync behavior;
providers refresh the note collection and trigger its existing sync engine.

If a supported YAML title exists, only the instantiated copy's title scalar is
updated via `FrontmatterEditorHelper.updateTitle(quoteValue: true)`. The helper
uses JSON-compatible YAML quoting and decodes quoted escapes safely. Other
frontmatter remains unchanged. An unsafe normalization fails before persistence.
A populated note (including a title-only note) survives normal empty-draft cleanup.

Navigation happens after local persistence. Creation disables repeated submission
and Back while pending. The picker keeps submission disabled while closing.
Deletion during selection reports unavailability and never creates a fallback.

## Editor representation rules

Source and instantiated snapshots retain canonical Markdown or RichDocument
JSON. Visual Editor loads the AST directly. Markdown Source and Super Editor
need a Markdown display projection when opening an AST note; this projection
never marks the note dirty or rewrites storage merely on open. Real subsequent
edits use the existing editing-mode serialization rules. Version-session checks
read the canonical notifier content after flushing Visual edits, avoiding a
spurious history entry for display-only projection. Template previews create no
editor session and explicitly disable checklist changes and link navigation.

## Attachment policy

Phase 1 blocks private `qp://asset`, attachment/document and other non-note
resource references, local file/content URIs, embedded Markdown/HTML images,
audio/video/file/document blocks, data media and cached preview thumbnails.
Both the application document parser and CommonMark image parsing are used,
with additional URI/metadata checks. Nothing is silently stripped or converted.
The save dialog presents the specification's text-only-copy explanation and OK.
Normal prose such as “Profile:” or “Content:” is not mistaken for a local URI.

## UI integration

- `presentation/template_picker.dart`: adaptive phone sheet / desktop dialog,
  at most 560 dp wide, search, sections, favorite controls, preview and management.
- `widgets/template_browser.dart`: virtualized rows, bounded snippets, local
  mutation guards and shared management behavior; Escape/Back return from
  preview before dismissal and restore search focus.
- `template_preview.dart`: selected-document read-only existing Markdown renderer.
- `templates_screen.dart`: Settings → General → Templates, immediately below
  the cloud/account/security section. A single app-bar title, 680 dp content
  column, compact filled search with a clear action, subtle dividers, explicit
  typography and Phosphor controls follow the app's paper themes. Rename/delete
  user records, preview and ordinary creation remain available; built-ins expose
  no rename/delete menus.
- `widgets/template_dialogs.dart`: adaptive save/rename/delete dialogs and safe
  errors; persistence failures preserve input/records and allow retry.
- Phone and desktop notes overflow menus: New from Template. TagContextHeader
  supplies the same action in its separate tag menu with the active nested tag.
- Phone and desktop palettes: searchable New Note / New from Template commands,
  opened from the overflow menu or Ctrl/Cmd+Shift+P. Desktop uses the spotlight
  primitive; Android uses a visible themed sheet with keyboard inset padding,
  scrolling, close control and an empty-results message. Enter/Go activates the
  first matching command. Both notes overflow layouts pair these actions with
  Phosphor icons and wrapping labels. The existing creation handlers and
  Ctrl/Cmd+N remain unchanged; the baseline had no general command registry.
  Initial notes focus permits shortcuts before a field has been focused.

Settings and picker management navigation use existing Material routes. A picker
opened from a tag also passes that context if its management footer is used.
There is no new sidebar destination or permanent editor toolbar button.

## Favorites and failure behavior

Stars update only after successful local writes; failed writes leave prior state
visible. User-template deletion removes its star transactionally and leaves
source/created notes untouched. Rename changes metadata only. Writes do not
produce sync tombstones. Dialog errors use safe messages, and development
logging records error types without content, protected metadata or keys.

## Backup, restore and vault erasure

The existing v1 `.qpbackup` payload gains optional `templates` and
`templateFavorites` collections. Bundled bodies are never duplicated. Encrypted
backups put both collections inside the existing Argon2id/XChaCha20-Poly1305
authenticated ciphertext. There is no plaintext sidecar. The existing explicit
unencrypted backup option retains its semantics and includes local templates;
it must not be described as encrypted. Old payloads with no sections restore
as empty collections.

Restore validates metadata/content/UUIDs before destructive changes, then writes
all template changes inside the existing restore transaction. Replacement clears
user records/favorites and restores valid incoming IDs. Merge and keepBoth
upsert stable template IDs only when the incoming updatedAt is later; equal
timestamps preserve local content. Favorite sets combine, dangling user IDs are
removed, and incoming favorites are limited to present users/recognized bundled
IDs. Unknown bundled favorites already on disk survive non-replacement upgrades.
Failure later during note restore rolls back template writes/deletions as well.
`eraseAllLocalVaultData` deletes both collections in its existing transaction.

## Privacy

Templates are offline local SQLite data, not guaranteed encrypted at rest.
No template table, favorite, title or body enters cloud sync/indexes/endpoints.
There are no new network requests or encryption/backend changes. Instantiated
ordinary notes enter the existing client-encrypted note sync pathway. Protected
notes are blocked even while unlocked. Full local-vault erase removes snapshots
and stars; bundled definitions remain available with no favorites.

## Testing and verification

Tests live in `test/templates/` and cover domain/Unicode/catalog validation,
CRUD/reactive streams, migration, source flush/failure/races, independence,
all editor formats, unsupported assets, offline dirty-row sync, encrypted backup,
legacy/merge/replacement/rollback, vault erasure, restart persistence, modal
keyboard behavior, responsive themes/layouts, management failures and navigation.
Scale coverage includes 1,000 saved templates, a roughly 1 MB body, rapid favorite
toggles, repeated picker sessions and deletion during preview. The source code
keeps rows lazy and does not issue a full-library note query when opening a picker.

Use Flutter **3.47.2** / Dart **3.13.2**, matching repository CI. Run targeted
files with `--concurrency=1` to limit resource use. The user explicitly prohibited
the full Flutter test suite; do not run it for this feature. Final command counts
and verification limits are recorded in the implementation log and report.
Physical Android/desktop application smoke testing is separate from widget
platform emulation; no device build/install is claimed here.

## Future extension points

Versioned records, explicit format tags, stable source namespaces, separate
favorites and a single instantiation service allow future variable/schema,
sharing, sync or asset-cloning work without reclassifying ordinary notes.
Those capabilities are intentionally not implemented in Phase 1.
