# Phase 1 templates — engineering report

## A. Implementation summary

Users can save eligible ordinary notes as independent templates, choose among
eight bundled structures and their own snapshots, search names, inspect a
read-only preview, favorite entries, rename/delete their own templates and create
ordinary notes. Settings, both note-list layouts, nested tag headers and the
desktop command palette are integrated. Template content and favorite IDs take
part in existing backups/restores and full local-vault erasure.

The feature is implemented end to end. Automated verification is limited to
explicitly selected files because the user prohibited the complete Flutter test
suite. No full-suite result or physical device validation is claimed.

## B. Architecture

- Immutable `NoteTemplate`: stable identity, independent name, canonical body,
  explicit existing-compatible format, normalized snapshot tags, UTC timestamps,
  schema v1; favorites/source are derived.
- Drift 20 → **21** adds dedicated template and favorite tables; existing note,
  attachment, tag, journal, sync and search contracts remain intact. Generated
  database sources are regenerated.
- Dedicated parameterized repository, application service/content validation and
  Riverpod database streams under `lib/features/templates/`.
- Shared adaptive browser, bounded row snippets, selected-document read-only
  preview, save/rename/delete dialogs and Settings management screen.
- Save flushes Visual edits and awaits canonical local autosave. Instantiation
  validates/re-resolves the template and calls the ordinary note repository with
  fresh identity/timestamps, clear state flags and normalized active tag context.
- Rich JSON display projection supports Markdown Source and Super Editor without
  rewriting persisted bytes merely on open. Actual edits retain existing editor
  serialization behavior. Existing frontmatter editing supports safely quoted
  instantiated titles without changing unrelated values.
- Optional backup v1 collections stay within the existing authenticated
  encryption envelope. Template restore changes participate in the same SQLite
  transaction as notes; merge/timestamp and replacement semantics are covered.
  Template definitions never enter cloud synchronization.

See [templates.md](templates.md) for the complete subsystem contract.

## C. Added and modified files

All paths below are relative to the repository root.

| Path | Change |
| --- | --- |
| lib/features/templates/domain/note_template.dart | Immutable model, names, tags, serialization metadata |
| lib/features/templates/data/built_in_templates.dart | Eight immutable bundled definitions |
| lib/features/templates/data/template_repository.dart | Drift CRUD, streams and favorite persistence |
| lib/features/templates/application/template_content.dart | Serialization/asset validation, previews and frontmatter normalization |
| lib/features/templates/application/template_service.dart | Snapshots, instantiation, metadata mutations and sorting |
| lib/features/templates/application/template_providers.dart | Repository/service and reactive combined catalog |
| lib/features/templates/presentation/template_picker.dart | Adaptive picker and management navigation |
| lib/features/templates/presentation/template_preview.dart | Read-only selected-document renderer |
| lib/features/templates/presentation/templates_screen.dart | Settings management and normal editor navigation |
| lib/features/templates/presentation/widgets/template_browser.dart | Virtualized/searchable sections, actions and guarded creation |
| lib/features/templates/presentation/widgets/template_dialogs.dart | Adaptive name/delete dialogs and recoverable errors |
| lib/core/database/tables/note_templates_table.dart | Dedicated tables |
| lib/core/database/app_database.dart | Registration, migration and vault erase |
| lib/core/database/app_database.g.dart | Regenerated Drift entities/managers |
| lib/core/backup/backup_models.dart | Backward-compatible optional payload sections |
| lib/core/backup/backup_service.dart | Collection export, validation and transactional restore |
| lib/features/editor/application/editor_provider.dart | Awaitable snapshot flush and safe overlapping autosave |
| lib/features/editor/application/frontmatter_editor_helper.dart | Opt-in quoted title normalization and escaped-value parsing |
| lib/features/editor/presentation/editor_screen.dart | Save action, canonical display projection and history preservation |
| lib/features/editor/presentation/widgets/markdown_editor.dart | Publish pending canonical Visual changes |
| lib/features/notes/presentation/notes_screen.dart | Menus, palette shortcut, tag context and editor navigation |
| lib/features/notes/presentation/widgets/notes_command_palette.dart | Shared spotlight commands |
| lib/features/tags/presentation/widgets/tag_context_header.dart | New-from-template callback in tag overflow |
| lib/features/settings/presentation/settings_screen.dart | Templates row |
| test/templates/template_domain_test.dart | Catalog, Unicode, formats, snippets, rich content and unsupported media |
| test/templates/template_database_test.dart | CRUD/streams, migration, rollback, erasure, restart and scale |
| test/templates/template_service_test.dart | Flushing, failures/races, identity, tags, independence and sync isolation |
| test/templates/template_backup_test.dart | Encryption, legacy formats, merge/replacement and restore rollback |
| test/templates/template_widget_test.dart | Picker/search/favorites/preview, management, errors, keyboard/layout and submission guards |
| test/templates/template_editor_integration_test.dart | Actual editor snapshot flow, all modes/formats and protected contexts |
| test/templates/template_navigation_test.dart | Phone/desktop nested tags, Settings and keyboard palette routes |
| test/tags/tag_hierarchy_ui_test.dart | Keep inline widget scopes on the explicit in-memory database |
| test/backup/attachment_backup_test.dart | Explicit independent-database test configuration; assertions unchanged |
| prompts/templates.md | Copy of the user-provided untracked specification from the main checkout |
| handoff/templates.md | Subsystem guide and repository audit |
| handoff/templates-report.md | This report and completion audit |
| handoff/INDEX.md | Documentation map |
| handoff/editor-and-typography.md | Canonical flush/projection contract |
| handoff/sync-and-storage.md | Local-only schema, backup and erase contract |
| handoff/latest-logs.md | Appended engineering entry 334 |
| HANDOFF.md | Root implementation summary and validation |

## D. Verification

Flutter **3.47.2** / Dart **3.13.2**, matching the pinned CI SDK.

| Check | Result |
| --- | --- |
| Drift generation | Passed; generated source checked in |
| Initial selected regression run | 250 passed |
| Combined selected run below | 349 passed; no failing tests |
| Final focused rerun below | 91 passed (77 templates + 14 tag hierarchy), no warnings/errors |
| Distinct selected tests across runs | 350 (one new row-excerpt test was added after the combined run) |
| Final `flutter analyze` | No issues found |
| `git diff --check` | Passed |
| Bundled body comparison | All eight match the supplied specification verbatim |
| Complete Flutter suite | Not run, explicitly prohibited by the user |

The combined run exposed pre-existing test-harness connection warnings in tag
fixtures. The final rerun verifies their corrected in-memory provider scopes.
No assertions were removed or weakened. No backend tests were needed because
backend code was untouched.

Commands executed (all test invocations used explicit selected paths; final
invocations use one worker):

```sh
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test --no-pub --concurrency=1 test/templates test/tags/tag_hierarchy_ui_test.dart
git diff --check
```

Combined selected command (349 passed before the last new excerpt test):

```sh
flutter test --no-pub --concurrency=1 \
  test/templates \
  test/database/app_database_test.dart \
  test/database/database_migration_test.dart \
  test/backup \
  test/editor/editor_overflow_menu_test.dart \
  test/editor/dual_mode_editor_screen_test.dart \
  test/editor/editor_provider_tag_test.dart \
  test/editor/frontmatter_editor_helper_test.dart \
  test/editor/frontmatter_wysiwyg_preservation_test.dart \
  test/editor/version_history_test.dart \
  test/editor/rich_document_parser_serializer_test.dart \
  test/editor/quiet_super_editor_test.dart \
  test/settings/settings_screen_test.dart \
  test/notes/notes_list_audit_regression_test.dart \
  test/notes/notes_filter_and_sort_ui_test.dart \
  test/quick_capture/quick_capture_service_test.dart \
  test/journal/journal_service_test.dart \
  test/sync/sync_engine_test.dart \
  test/notes/note_security_service_test.dart \
  test/widgets/spotlight_palette_test.dart \
  test/tags/tag_workspace_navigation_test.dart \
  test/tags/tag_hierarchy_ui_test.dart
```

Earlier targeted file runs were used during development to fix compiler,
keyboard-focus and tag-menu overflow issues before the successful final runs.
Full raw output remains in the ignored `.dart_tool/template-verification/`
directory of this worktree.

Migration verification opens an actual pre-feature v20 SQLite database and
checks existing notes, tags, server revision, dirty status, journal data,
attachments and sync metadata after upgrading to v21. Fresh creation and a real
connection close/reopen are also covered.

Backup verification exercises password-authenticated ciphertext, user templates
and bundled/user favorites, old payloads without template sections, replacement,
newer/tied merge collisions, invalid metadata and unsupported content. A failure
in note insertion after template writes rolls the entire restore back.

Editor verification covers canonical Markdown and RichDocument fixtures in
Markdown Source, Visual and Super Editor, including headings, formatting, lists,
checklists, tables, code, math, quotes, dividers and note links. Actual editor
saving and subsequent independent note editing are exercised. Source/template
content remains unchanged. Frontmatter title tests preserve unrelated values.

Scale verification covers 1,000 stored templates, a roughly 1 MB body, rapid
favorite toggles, repeated picker sessions and deletion during preview. Bounded
row extraction avoids full rich-document parsing when displaying a row.

## E. Known limitations

Explicit Phase 1 exclusions remain: binary attachment cloning, protected/journal
sources, dynamic variables/dates, recurrence, template body editing, sharing,
cloud template sync, AI generation and template version history. Local template
SQLite data is not claimed encrypted at rest. An explicitly unencrypted backup
retains that choice; encrypted backups include templates inside ciphertext.

Flutter widget platform emulation covers phone/desktop sizing and keyboard
behavior. Physical Android/desktop smoke testing and live cloud deployment were
not performed. No backend code was changed. The complete Flutter suite was not
run, as directly instructed by the user.

## F. Definition-of-Done audit

The checklist below is copied from the specification. The full-suite requirement
is blocked by the user's later explicit instruction; it is not reported passed.

## Functional

- [x] Eight built-in templates exist.
- [x] Built-in IDs are stable.
- [x] Built-ins cannot be renamed or deleted.
- [x] Existing ordinary notes can become templates.
- [x] Existing notes remain unchanged.
- [x] Unsupported notes/assets are handled safely.
- [x] New independent notes can be created from templates.
- [x] Template picker works.
- [x] Template previews work.
- [x] Template search works.
- [x] Favorites work.
- [x] Favorites persist after restart.
- [x] User templates can be renamed.
- [x] User templates can be deleted.
- [x] Deleting templates does not affect existing notes.
- [x] Original blank-note creation remains unchanged.
- [x] Settings integration works.
- [x] Command palette integration works.
- [x] Active tag context is preserved.

## Architecture

- [x] Templates are stored separately from notes.
- [x] SQLite migration is safe.
- [x] Riverpod integration follows existing patterns.
- [x] No redundant template editing architecture is introduced.
- [x] Markdown content is preserved.
- [x] Rich-document content is preserved.
- [x] Super Editor compatibility is verified.
- [x] No unsupported private asset references are silently copied.
- [x] Note creation uses existing repository invariants.
- [x] Source note metadata is not incorrectly cloned.

## Privacy and persistence

- [x] Template features work offline.
- [x] Templates do not enter cloud sync.
- [x] Instantiated notes use normal encrypted sync.
- [x] Templates are included in encrypted backups.
- [x] Legacy backup restoration works.
- [x] Full vault erase removes local templates/favorites.
- [x] Protected-note restrictions are respected.

## Quality

- [x] New unit tests pass.
- [x] New widget tests pass.
- [x] New database tests pass.
- [x] New integration tests pass.
- [x] Existing regressions pass.
- [x] `flutter analyze` is clean.
- [ ] **Blocked by user instruction:** Full `flutter test` — intentionally not run; targeted verification replaces it for this task.
- [x] Documentation is updated.
- [x] No dead code or abandoned prototype remains.
- [x] No placeholder implementation remains.
- [x] No known data-loss regression is introduced.


## G. Final status

`IMPLEMENTED — Verification incomplete`

All feature code and authorized targeted checks are completed. This status
reflects the intentionally excluded full-suite check and physical-device
validation limits, not a known unfinished implementation.
