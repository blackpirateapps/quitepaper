# Tasks workspace and due dates

Implementation branch: `feat/tasks-workspace`. This guide records the actual
contracts and verification limits; a branch implementation is not a production
release approval.

## Integration map

- `features/tasks/domain`: task occurrences, version-scoped resolution, minimal
  canonical mutations and field-level merge helpers.
- `editor/domain/task_metadata.dart`: validated local calendar dates and strict
  version-1 metadata. Editor block IDs remain distinct from durable task IDs.
- `core/markdown/markdown_checklist_helper.dart`: shared source checklist scan,
  offsets, literal exclusion, checkbox counting/toggling and metadata suppression.
- `core/database/task_index.dart`: schema 26 installation-local projection,
  canonical-save maintenance, durable dirty triggers and bounded repair.
- `features/tasks/application`: shared completion/date/capture/rename/delete commands,
  field-aware operation receipts and Riverpod state.
- `features/tasks/presentation`: lazy Tasks list, capture, phone date sheet and
  staged desktop date picker.
- Sidebar and command palette expose Tasks and New task. The existing notes
  workspace hosts Tasks in its middle pane; phones retain a full list route and
  push the existing editor. Task search/tag/tab/scroll state is separate from
  note-list filters. Editor navigation flushes through the existing active editor
  barrier.
- `TaskEditorBridge` resolves an attached editor by note ID. Visual changes use
  RichDocumentController snapshots; Source uses its existing text history; Super
  Editor replaces task nodes through undoable editor requests. Source mutations
  never replace an unrelated editor's live buffer.
- `saveNote` indexes in the canonical transaction, including sync ingestion and
  ordinary imports/restores. Direct lifecycle/content writes leave a durable
  per-note dirty marker. Queries join current note eligibility and suppress dirty
  projections. Rebuild repairs batches of 32 notes and yields between batches.

## Phone Tasks presentation

The phone shell leaves its app bar to Tasks, preventing duplicate toolbars. Tasks
uses the supplied November 25 smartphone references: serif title, Phosphor icons,
search on demand, underlined Open/Completed counts and compact All tags filtering.
Date groups retain canonical ordering. Adjacent tasks from the same source note
share a note heading; standalone tasks retain their source subtitle. Circular
checkboxes invoke the existing completion command. Tapping the task text expands
one row with due-date, Rename and Delete actions. Source-note headings and
subtitles include a Phosphor arrow and open the exact note directly, independently
of row expansion or completion. Wide-font/large-text controls adapt to the available
width and expanded actions wrap.

At viewport widths below 600 logical pixels, due dates use a paper-themed modal
bottom sheet with the source task title. Presets commit on selection; Pick a date
commits only after calendar confirmation, and Clear date is explicit. Dismissal
returns no selection. Capture stages the returned date in its draft as before;
existing task changes retain canonical persistence and Undo. Wider viewports keep
the staged desktop dialog with Cancel/Save.

Initial index loading omits counts and displays a progress message and three
skeleton rows. Refreshes with cached results retain those results. Widget coverage
includes light/dark phone expansion, large text and combined filtering, first
load, date dismissal/presets/calendar/clear, canonical date/completion/Undo and
source opening. A targeted real app-shell test verifies one toolbar and drawer
navigation. Rendered widget previews were inspected at 390 × 844 logical pixels;
these checks do not establish physical-device acceptance.

## Editing tasks and filtering tags

Rename/Delete use the same note persistence and attached-editor barrier as dates
and completion. Rename accepts one literal line and preserves completion, date,
identity, unrelated note content, and Markdown prefix/continuation/line endings.
Replacing a name replaces its inline styling; an unchanged name preserves styling.
The rename sheet keeps its draft on failure. Delete confirms removal of the task
and its indented continuation/nested items, rechecking the source version to
avoid deleting children added since the list snapshot. Closed-note rename/delete
Undo restores the exact previous content only while the source content remains
unchanged. Attached editors retain their own history too. Super Editor renames
through task-node replacement and reconciles structural changes using undoable
node requests, retaining unaffected prefix/suffix nodes.

`taskTagsProvider` stores a set independently of note-list filters. All tags opens
a searchable selection sheet (compact dialog on desktop) offering tags from all
eligible task notes and their ancestor paths. Selected tags remain removable
while searching. **Any selected tag** matches that tag or its descendants; task
search and completion state further narrow results. Counts reflect those combined
filters. Apply commits the staged selection, Clear filters stages an empty set,
and dismissing discards staged changes. Untagged task notes produce an explanatory
empty state. The sheet keeps its controls visible above the keyboard and supports
large text and both palettes.

## Canonical format

Rich checklist nodes optionally carry:

```json
{"task":{"v":1,"id":"03fe77cf-8000-4d05-ba80-d365fd69b17c","due":"2026-11-27"}}
```

Markdown uses a terminal comment on the first physical checklist line:

```markdown
- [ ] Send estimate <!-- qp-task:v1 id=03fe77cf-8000-4d05-ba80-d365fd69b17c due=2026-11-27 -->
```

Only the exact recognized version/fields, UUID shape and real calendar dates bind
metadata. Unknown/malformed source comments remain source content. Inline code,
escaped syntax, frontmatter, code fences and HTML blocks are excluded. A duplicated
ID is ambiguous: commands refuse to guess. Legacy tasks have a content SHA-256
and document ordinal, valid only for that exact content. Durable IDs can resolve
across later content revisions when unique and when the affected field still has
its expected value.

Dates are calendar strings, with no UTC conversion. Today/Tomorrow and localized
calendar labels are presentation values. The Tasks view checks local midnight,
resume and periodic clock/timezone changes. Its clock is injectable.

Read/index/render operations do not assign IDs. Capture and the first date change
assign UUIDs; clearing a date retains identity. Closed-note mutations change only
the completion character or terminal metadata in Markdown, preserving CRLF and
unaffected source bytes; rich changes preserve unrelated raw JSON nodes/fields.
Visual/Source splits retain the first item's metadata and leave the continuation
undated. Visual forward joins ask before removing the second item's deadline.
Copied snippets and duplicated notes rekey assigned IDs and retain dates.
Template instantiation rekeys and clears dates. Encrypted backup/restore retains
canonical IDs; the derived index is excluded from backups and cloud envelopes.

Recognized comments are omitted from task labels, note search, Markdown preview
and public-share Markdown. Personal native Markdown export keeps them. Existing
rendered export paths continue through the app's renderer. No task/date columns
were added to cloud payloads and no task replication API exists.

## Consistency, privacy and recovery

The database belongs to the existing single local vault. The index has the same
local SQLite boundary as ordinary note text. Password-protected notes are not
indexed; archive/trash/protection immediately gate existing projections, and
normal note writes atomically remove them. Session state hides results and suppresses capture-result toasts while
locked and cancels late provider yields on invalidation/account change. Vault
erasure cascades projection and dirty state. No note text or dates are logged by
Tasks; parser recovery stores only a failed note ID and presents a generic retry.

Mutations serialize per service instance. Closed writes re-read inside the same
Drift transaction as their save. An attached editor flushes first, verifies the
latest committed content and uses its own undo history. Local durability precedes
success; normal note dirty state handles pending encrypted sync. Field-aware Undo
refuses competing edits, preserves independent durable-task fields, and refuses
to remove an edited capture. A normal editor Undo makes a stale toast receipt
unavailable instead of undoing twice.

Capture IDs survive retries within the dialog. One vault-key-derived UUIDv5
purpose identity resolves Task Inbox independently of its title. Destination
creation and append share a transaction when closed; open destinations use their
editor. Today's Journal resolves through the existing daily-note service using
today, independently of the journal calendar selection. A trashed inbox offers
restoration through the existing repository restore path. Failed writes retain
the dialog draft, date and destination.

The existing diff3 boundary now merges independent completion/date edits for
unique durable tasks, including rich JSON. Competing dates, deletion/edit and
ambiguous structure use existing recoverable conflicts. There is no plaintext
server metadata.

## Compatibility and release gate

| Path/client | Contract |
| --- | --- |
| Current Tasks-aware Markdown/Visual/Super Editor | Recognized metadata round trips; focused automated coverage recorded below. |
| Current encrypted sync/backup | Canonical content carries IDs and dates; derived index omitted. |
| Personal Markdown export | Reserved comments retained. |
| Rendered/public sharing | Recognized task metadata suppressed. |
| Older clients that rewrite rich JSON | **Unsafe**: an older checklist decoder can omit unknown task fields. |
| Older clients that rewrite Markdown | Preservation is not guaranteed; unsupported comments can become literal content or be dropped during conversion. |
| Future/unknown rich task metadata | Ordinary rich JSON copies retain raw fields; unsupported format conversions still require compatibility acceptance. |

**Release is blocked until supported-client rollout/version gating prevents older
rewriting clients from silently losing metadata.** Existing device version
telemetry is not an enforcement gate. Do not describe older clients as safe merely
because encrypted sync transports the new bytes.

The key-derived inbox namespace is stable within a vault key. The existing
local-to-cloud migration can replace that key; migration of the system identity
across that transition needs explicit acceptance before release. Concurrent inbox
creation converges on one note ID; incompatible initial contents can still enter
the app's existing recoverable conflict flow.

Additional acceptance work remains for arbitrary continuation/HTML structures,
unknown-metadata conversions, all structural joins, native clipboard routes,
exact geometry/highlighting in every folded editor layout, assistive technology,
and an Android physical-device/emulator session. Record concrete tests rather than
assuming coverage from a build.

## Performance and platform evidence

The implementation uses existing Dart parsing and SQLite. No task Rust API or
FRB change was justified by measurement; Rust receives no task payloads/keys.
The reproducible synthetic corpus has 120 notes, 50 tasks each, alternating
Markdown and rich JSON, Unicode, formatting and fenced literal examples.
`tool/benchmark_tasks.dart` measures canonical writes, 32-note repair batches,
index reads and 30 search/sort samples. It is designed for release AOT through
`flutter run -d linux --release -t tool/benchmark_tasks.dart` in an isolated D-Bus
session when another app instance is running.

`integration_test/tasks_workspace_test.dart` and `test_driver/tasks_driver.dart`
exercise an isolated in-memory native UI, task date/completion/Undo and opening
the source editor. The same target is suitable for Linux or Android; no real
vault/account is used. A Linux profile run passed; its 6,000-task repair measured
340 ms, canonical writes 585 ms and index read 36 ms on this host. Profile timing
is not release evidence. The dated release corpus exposed string allocation in
calendar comparisons; integer calendar comparisons replaced it. Release timings
and final command outcomes are appended in the engineering log.

## Final validation summary

Analysis is clean; the completed full Flutter run passes **3,229 tests**. Focused
task/sharing validation passes **47 tests**, an overlapping task/sharing/export
run passes **51**, and backend contract validation passes **144 tests**. Linux
release compilation, the bundled FRB contract-2 smoke and the isolated native
Linux integration pass. The GitHub-flavor Android debug build passes; Android
runtime/device acceptance remains unverified. The final dated-corpus release
benchmark measures **708 ms** repair, **65 ms** projection read and **8.854 ms
median / 12.981 ms p95** search plus sorting. See
[aggregate evidence](../docs/tasks-workspace-evidence.json) for exact commands and
limits. The user requested no further full-suite runs after the completed run.

### Integration with main and safe queue triggers

PR #20 integrates schema 26 with the Rust CLI bootstrap snapshot and keeps the
startup repair for legacy Tasks triggers. Both newly created queue triggers use
`INSERT ... ON CONFLICT(note_id) DO NOTHING`; `OR IGNORE` is unsafe under an outer
note UPSERT and can abort repeated saves. Existing task-index rows and cleanup
logic survive the repair. See engineering logs 359–361 and the file-backed
regressions in `test/database/legacy_task_trigger_repair_test.dart`.
