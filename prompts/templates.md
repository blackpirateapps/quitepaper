# Quiet Paper — Phase 1 Template System
## Complete Production Implementation Specification for AI Coding Agents

### Your role

You are a senior Flutter engineer, application architect, SQLite/Drift specialist, and quality-assurance engineer working on Quiet Paper.

Your task is to **fully implement, integrate, test, and document a production-ready Phase 1 note template system** in the existing Quiet Paper application.

You must deliver working code, not an implementation proposal, architectural outline, partial prototype, or collection of TODO comments.

Implement the complete specification below.

Do not ask the user to make technical, architectural, or UX decisions already resolved by this specification.

Do not introduce unrelated features or redesign existing systems.

Do not silently omit requirements because they are difficult.

If the repository's actual implementation differs from the provided handoff documentation, inspect the source code, identify the correct existing integration points, and preserve the existing architectural contracts. Do not invent APIs, classes, database columns, or editor capabilities that have not been verified.

If a genuine technical blocker prevents completion, report the exact blocker and its impact. Never present incomplete or untested work as production-ready.

---

# 1. Project context

Quiet Paper is a calm, offline-first, privacy-focused notes application inspired by Bear Notes.

Its principal technologies include:

- Flutter and Dart
- Riverpod state management
- SQLite persistence through Drift
- Local-first note storage
- Zero-knowledge, end-to-end encrypted cloud synchronization
- Markdown and rich-document editing
- Android, Linux, and other supported Flutter desktop/mobile platforms

The application currently supports three editor experiences:

1. Markdown Source Editor
2. Visual Editor backed by a RichDocument AST
3. Super Editor with structured document components

Existing functionality also includes:

- Smart checklists
- Markdown tables
- Code blocks and syntax highlighting
- Math expressions
- Note links and tags
- YAML frontmatter
- Autosave
- Note pinning, archiving, and trash
- Note history
- Quick Capture
- Daily journaling
- Document and media attachments
- Command palette
- Search
- Offline synchronization
- Encrypted local backups

Preserve all these capabilities.

## 1.1 Architectural invariants

The following are nonnegotiable:

1. Existing notes must never be modified when converted into templates.
2. Creating a note from a template must never modify the template.
3. Templates must remain separate from ordinary notes.
4. Templates must work without an internet connection.
5. Templates must not be uploaded as plaintext to any backend.
6. Phase 1 template records must not enter the existing cloud synchronization queue.
7. Existing note autosave behavior must remain intact.
8. Existing editor document representations must be preserved without lossy conversions.
9. Existing backup encryption must remain intact.
10. Existing note creation paths must continue functioning.
11. Database migrations must preserve existing data.
12. Existing application visual conventions and interaction patterns must be maintained.

Read `AGENTS.md` and the repository's engineering handoff before modifying code.

At minimum, inspect:

- `handoff/INDEX.md`
- `handoff/core-architecture.md`
- `handoff/editor-and-typography.md`
- `handoff/sync-and-storage.md`
- `handoff/tags-and-search.md`
- `handoff/journal-and-audio.md`
- `handoff/platform-and-builds.md`
- `handoff/latest-logs.md`

Also inspect relevant application code and tests.

The provided documents are architectural references, not a substitute for examining the current repository.

---

# 2. Exact Phase 1 scope

Implement all of the following:

1. Full-note templates.
2. Eight bundled, built-in templates.
3. Saving an existing ordinary note as a reusable template.
4. Creating a new ordinary note from a template.
5. A template picker with search and read-only previews.
6. A template management screen.
7. Favorite and unfavorite functionality.
8. Renaming user-created templates.
9. Deleting user-created templates.
10. Persistent local storage.
11. Integration with the existing note editor, navigation, and command palette.
12. Inclusion in the existing encrypted backup and restore system.
13. Complete automated tests.
14. Production error handling.
15. Documentation.

## 2.1 Explicitly excluded from Phase 1

Do not implement:

- Dynamic date/time placeholders
- `{{variable}}` interpolation
- Prompt-driven template fields
- Tab navigation between template fields
- Block or snippet templates
- Automatic recurring templates
- Journal template automation
- Template sharing or public template galleries
- Template marketplaces
- Cloud template synchronization
- Template version history
- Template editing of body content in a dedicated editor
- Template AI generation
- New server endpoints
- New backend database tables
- A template-specific rich-document format

Do not implement these opportunistically.

Design the architecture so these capabilities can be introduced later without rewriting the Phase 1 data model.

---

# 3. Core feature behavior

A template is a reusable snapshot of a note's initial content and applicable organizational metadata.

A template is **not** an ordinary note with a special tag.

A template is **not** a permanently linked source note.

A template is **not** a live document that updates previously created notes.

When instantiated, the template creates a completely independent ordinary note.

## 3.1 Template types

There are exactly two template sources in Phase 1:

### Built-in templates

- Bundled with the application.
- Available immediately after installation.
- Read-only.
- Cannot be deleted.
- Cannot be renamed.
- Can be favorited and unfavorited.
- Do not occupy ordinary user-template database rows.
- Have stable identifiers.

### User-created templates

- Created from existing ordinary notes.
- Persisted in local SQLite.
- Can be renamed.
- Can be favorited and unfavorited.
- Can be deleted.
- Cannot have their body content directly edited in Phase 1.
- Remain independent of their source note.
- Are included in encrypted backups.

The UI must clearly distinguish built-in templates from user-created templates.

---

# 4. Data model

Implement a dedicated template domain model.

Use the following conceptual fields and meanings.

### NoteTemplate

| Field | Type | Meaning |
|---|---|---|
| id | String | Stable unique identifier |
| displayName | String | Name displayed in template UI |
| content | String | Canonical serialized document contents |
| storageFormat | Existing compatible format type | Original document serialization format |
| defaultTags | List of String | Tags to apply to new notes |
| createdAt | DateTime | Template creation timestamp |
| updatedAt | DateTime | Last metadata/content snapshot update timestamp |
| schemaVersion | int | Template record format version |
| isBuiltIn | bool | Derived from template source, not editable |
| isFavorite | bool | Derived from separate local favorite state |

Rules:

- User templates use newly generated UUIDs.
- Built-in templates use fixed, namespaced identifiers.
- `schemaVersion` starts at `1`.
- `createdAt` and `updatedAt` use UTC internally.
- A user's template display name is independent of the originating note's ID.
- Do not retain source-note IDs as dependencies.
- Do not preserve source-note sync revisions.
- Do not preserve public-sharing credentials, passwords, or ephemeral editor state.
- Preserve the existing note's canonical document representation.

The database must not use a single global `is_template` flag on ordinary notes.

## 4.1 Database tables

Add the equivalent of these two dedicated Drift tables.

### `note_templates`

Required columns:

- `id`: text primary key, not null
- `display_name`: text, not null
- `content`: text, not null
- `storage_format`: text, not null
- `default_tags_json`: text, not null
- `created_at`: timestamp, not null
- `updated_at`: timestamp, not null
- `schema_version`: integer, not null, default 1

Use the current repository's timestamp conventions and Drift type converters.

Store `default_tags_json` as a JSON array of strings.

Validate JSON before writing.

Do not introduce redundant normalized tag relationships for templates in Phase 1. Template default tags are snapshot metadata, not membership in the regular note-tag index.

### `template_favorites`

Required columns:

- `template_id`: text primary key

A row indicates that a template is favorited.

Absence of a row means the template is not favorited.

This table deliberately has no foreign key to `note_templates` because built-in templates are not persisted in that table.

When a user-created template is deleted, remove its corresponding favorite row in the same transaction.

Unknown built-in favorite IDs encountered after an application upgrade must be ignored in the UI without crashing; retain them on disk so a temporarily missing built-in can be restored by a future app version.

## 4.2 Database migration

Inspect the current Drift schema version and migration strategy.

Do not assume the schema version shown in an older handoff is still current.

Create the next valid migration using the application's established conventions.

Requirements:

- Existing notes remain untouched.
- Existing tags remain untouched.
- Existing attachments remain untouched.
- Existing sync metadata remains untouched.
- Existing journal entries remain untouched.
- Both new tables are created.
- The migration is transactional where supported.
- Fresh database creation includes the new tables.
- Existing installations upgrade correctly.
- Drift-generated source files are regenerated.
- Database upgrades are tested from an actual pre-feature schema.

Never drop or rebuild the existing notes table simply to introduce templates.

## 4.3 Constraints

Template names:

- Must be nonempty after trimming.
- Maximum 80 Unicode grapheme clusters.
- Must not contain newline or control characters.
- Internal ordinary spaces are allowed.
- Leading and trailing whitespace are removed.
- Unicode characters are supported.
- Duplicate display names are permitted because IDs provide identity.

Template contents:

- Follow the existing note content size and serialization constraints.
- Do not add an arbitrary smaller template body limit.
- Invalid or unsupported serialization must fail validation rather than be silently altered.
- Empty content is permitted only when the original note is a valid ordinary note whose title or other meaningful content makes it worth templating.

All database operations must use parameterized Drift APIs.

---

# 5. Repository and service architecture

Implement a dedicated feature module under:

`lib/features/templates/`

Use the repository's established domain, data, application, and presentation layering.

Expected conceptual structure:

```text
lib/features/templates/
├── domain/
│   └── note_template.dart
├── data/
│   └── template_repository.dart
├── application/
│   ├── template_service.dart
│   └── template_providers.dart
└── presentation/
    ├── template_picker.dart
    ├── template_preview.dart
    ├── templates_screen.dart
    └── widgets/
```

The exact filenames may be adjusted only to conform to an existing, verified naming convention. Do not collapse all functionality into `EditorScreen` or a single giant service file.

## 5.1 Repository responsibilities

Provide explicit operations equivalent to:

```dart
Future<List<NoteTemplate>> getUserTemplates();

Stream<List<NoteTemplate>> watchUserTemplates();

Future<NoteTemplate?> getUserTemplate(String id);

Future<void> insertUserTemplate(NoteTemplate template);

Future<void> renameUserTemplate(
  String templateId,
  String newName,
);

Future<void> deleteUserTemplate(String templateId);

Future<Set<String>> getFavoriteTemplateIds();

Stream<Set<String>> watchFavoriteTemplateIds();

Future<void> setFavorite(
  String templateId,
  bool favorite,
);
```

Adapt signatures to established repository conventions without changing the required behavior.

Use batch queries and reactive streams where appropriate.

Do not initiate full-library note queries to populate the template picker.

Do not parse every template's rich document merely to display a row.

## 5.2 Application service responsibilities

Centralize:

- Built-in template access
- Template validation
- Saving a note as a template
- Template name validation
- Template previews
- Template instantiation
- Sorting
- Favorites
- Unsupported-content detection
- Error mapping

Widgets must not directly perform SQL operations.

Implement a single authoritative pathway for creating ordinary notes from templates.

---

# 6. Built-in templates

Bundle exactly eight built-in templates.

Store definitions as immutable local application data.

Use Markdown serialization for the built-in templates.

Do not create built-in templates in SQLite during installation.

Assign these exact IDs and display names:

| ID | Display name | Category |
|---|---|---|
| `builtin.daily_planner.v1` | Daily Planner | Personal |
| `builtin.meeting_notes.v1` | Meeting Notes | Work |
| `builtin.study_notes.v1` | Study Notes | Learning |
| `builtin.reading_notes.v1` | Reading Notes | Learning |
| `builtin.project_brief.v1` | Project Brief | Work |
| `builtin.bug_report.v1` | Bug Report | Development |
| `builtin.weekly_review.v1` | Weekly Review | Personal |
| `builtin.decision_log.v1` | Decision Log | Work |

Their display order is the order shown above.

Their default tags are empty.

Use the following initial bodies verbatim.

## 6.1 Daily Planner

```markdown
## Top priorities

- [ ] Priority 1
- [ ] Priority 2
- [ ] Priority 3

## Schedule

- Morning:
- Afternoon:
- Evening:

## Notes

## End-of-day reflection
```

## 6.2 Meeting Notes

```markdown
## Meeting details

**Participants:**

**Date:**

## Agenda

- 

## Discussion

## Decisions

## Action items

- [ ] Follow-up task

## Next meeting
```

## 6.3 Study Notes

```markdown
## Topic

## Key concepts

## Definitions

## Important formulas

## Worked examples

## Questions to revisit

- [ ] Review question

## Summary
```

## 6.4 Reading Notes

```markdown
## Book or article

**Author:**

**Source:**

## Main ideas

## Notable quotations

## Personal reflections

## Questions

## Takeaways
```

## 6.5 Project Brief

```markdown
## Overview

## Problem

## Goals

## Scope

### Included

### Excluded

## Requirements

## Milestones

- [ ] First milestone

## Risks

## Next steps
```

## 6.6 Bug Report

```markdown
## Summary

## Environment

**Platform:**

**App version:**

## Steps to reproduce

1. First step
2. Second step
3. Third step

## Expected behavior

## Actual behavior

## Evidence

## Possible cause

## Resolution checklist

- [ ] Fix implemented
- [ ] Regression test added
- [ ] Verification completed
```

## 6.7 Weekly Review

```markdown
## Highlights

## Completed this week

- [ ] Item

## Challenges

## Lessons learned

## Unfinished tasks

- [ ] Item

## Priorities for next week

- [ ] Priority
```

## 6.8 Decision Log

```markdown
## Decision

## Context

## Options considered

### Option A

### Option B

## Reasoning

## Final decision

## Trade-offs

## Follow-up actions

- [ ] Action
```

Built-in bodies must not contain dynamic placeholder syntax.

Do not automatically insert the current date.

When instantiated, the initial note title must match the built-in template's display name.

---

# 7. Save an existing note as a template

## 7.1 Entry point

Add the action:

**Save as Template**

to the existing note editor overflow menu.

Use the application's existing menu components.

Do not create another permanent editor toolbar button.

The action must not appear in contexts where there is no valid source note.

## 7.2 Supported source notes

Permit the action for normal, editable, persisted notes.

Do not permit it for:

- Notes in Trash
- Password-protected notes
- Locked notes
- Canonical journal entries
- Transient Quick Capture drafts
- Read-only shared notes
- Notes with unsupported embedded media or private asset references

A password-protected note must remain ineligible even if temporarily unlocked. Phase 1 must not create an unprotected reusable copy of specially protected content.

For otherwise eligible notes containing unsupported media, show the unsupported-content explanation described below.

## 7.3 Save dialog

Display an adaptive dialog.

Title:

**Save as Template**

Description:

"Create a reusable template from this note. The original note won't change."

Input label:

**Template name**

Prefill using the existing note's visible title.

For a blank visible title, prefill:

`Untitled Template`

Primary action:

**Save Template**

Secondary action:

**Cancel**

Validation:

- Disable Save while the trimmed name is empty.
- Disable Save when it exceeds 80 grapheme clusters.
- Show inline validation for invalid characters.
- Prevent double submission.
- Keep the dialog open when persistence fails.
- Preserve the entered name after a recoverable failure.

Do not add template variable editing or advanced metadata configuration.

## 7.4 Source snapshot rules

Before saving the template:

1. Flush the active editor's pending changes using its existing safe autosave mechanism.
2. Await completion of the relevant local persistence operation.
3. Read the newest canonical note data.
4. Validate eligibility.
5. Validate document serialization.
6. Check for unsupported media references.
7. Construct a new independent template snapshot.
8. Persist it transactionally.
9. Return success to the UI.

Do not build a template from an older cached body while unsaved edits are pending.

Do not create a second source note.

Do not update the source note's `updatedAt` merely because a template was saved if no actual source content changed.

Do not create source-note version history entries for template operations.

## 7.5 Content snapshot

Preserve:

- Paragraphs
- Headings
- Bold, italic, and inline formatting
- Lists
- Nested checklists
- Checklist completion states
- Tables
- Code blocks
- Code languages
- Math source
- Dividers
- Blockquotes
- Standard hyperlinks
- Valid internal note links
- Valid supported YAML frontmatter
- Existing normalized note tags

Do not flatten rich documents into plain text.

Do not use rendered HTML as the template's canonical storage.

Do not convert rich AST content to Markdown merely for convenience.

Use the same validated serialization format supported by the existing note persistence system.

## 7.6 Unsupported embedded assets

Phase 1 does **not** support cloning binary media into templates.

This includes embedded or referenced:

- `qp://asset/` resources
- `qp://attachment/` resources
- `qp://document/` resources
- Embedded images
- Audio memos
- PDFs
- File attachments
- Locally cached link-preview thumbnails
- Other private binary resources requiring ownership or lifecycle tracking

Detect these references in both Markdown and structured rich-document representations.

Use existing document parsers and asset-reference extraction utilities where available.

Do not rely solely on searching raw Markdown for a single URI pattern.

If unsupported content is detected:

- Do not create the template.
- Do not remove the media silently.
- Do not store broken asset references.
- Display:

"This note contains attachments or documents that can't be included in templates yet. Make a text-only copy of the note and save that copy as a template."

Provide an **OK** action.

This is an explicit Phase 1 product limitation, not permission to lose content.

Normal hyperlinks and internal note links that do not require duplicated binary asset ownership remain supported.

## 7.7 Success behavior

After successful persistence:

- Close the dialog.
- Show a restrained success message:

"Template saved"

- Make the template immediately available in the picker and management screen.
- Do not navigate away from the original note.
- Do not automatically favorite it.

---

# 8. Create a note from a template

## 8.1 Required behavior

When the user chooses **Use Template**:

1. Resolve the selected template by stable ID.
2. Validate that it still exists.
3. Validate that its serialization is supported.
4. Prepare a new ordinary note.
5. Generate a new note UUID.
6. Assign the template's display name as the new note title.
7. Deep-copy its canonical document contents.
8. Preserve the supported storage format.
9. Apply the template's default tags.
10. Apply the active note-list tag context using the existing new-note rules.
11. Persist the note using the existing note repository.
12. Open the existing editor with the newly created note.
13. Place the cursor at the normal document editing position.
14. Return focus to the editor.
15. Trigger ordinary note synchronization through the established mechanism.

Do not implement template note creation with a direct, untracked database insert that bypasses repository invariants.

## 8.2 New note metadata

Do not copy source-note values for:

- Original note ID
- Original creation timestamp
- Original update timestamp
- Original sync timestamp
- Original sync revision
- Original version history
- Dirty state from the source
- Archive state
- Trash state
- Pin state
- Password protection state
- Public sharing settings
- Share tokens
- Source document ownership
- Original journal date
- Previous editor focus or selection state

The new note must receive current timestamps through the normal note creation mechanism.

It must begin:

- Not archived
- Not trashed
- Not pinned
- Not publicly shared
- Without password protection
- With a fresh identity

If the original source note is later deleted or modified, the instantiated note must remain unchanged.

## 8.3 Tags

Use the template's stored normalized tags.

If the picker was opened from a tag-filtered notes view, include that active tag using the existing note creation semantics.

Combine both sets without duplicates.

Preserve valid nested tag paths.

Do not add tags to the template itself simply because it was used from a tag view.

Never alter the source note's tags.

## 8.4 Titles and YAML frontmatter

The new note's visible title must be the template display name.

If the copied document has a YAML `title` field that the app treats as canonical, update that title in the newly instantiated copy using the existing frontmatter editing utility so it does not disagree with the visible note title.

Preserve all unrelated frontmatter values.

Do not rewrite unrelated date, author, source, or custom metadata.

Do not modify the stored template when normalizing the generated note's title.

If safe normalization is impossible, fail the creation with a recoverable error; do not create a note whose body and canonical title disagree because of a partial transformation.

## 8.5 Persistence and navigation

Persist the note before reporting successful creation.

If persistence fails:

- Do not navigate to a nonexistent note.
- Do not leave a partially created note.
- Show a clear error.
- Allow the user to retry.

When the user taps **Use Template** repeatedly while the first operation is in progress, only one creation operation may run.

After completion, a new explicit request may create another independent note.

Notes populated from templates are real notes and must not be deleted by empty-draft disposal merely because the user exits immediately without editing.

If a template is deleted between picker display and activation, show:

"This template is no longer available."

Do not fall back to a different template or create a blank note without user consent.

---

# 9. Template picker

## 9.1 Presentation

Implement an adaptive template picker using Quiet Paper's existing modal conventions.

Phone:

- Modal bottom sheet or equivalent established adaptive modal
- Scrollable list
- Keyboard-safe layout
- System Back dismissal

Tablet and desktop:

- Centered adaptive dialog
- Maximum width 560dp
- Responsive height constrained to the available window
- Escape dismissal
- Keyboard navigation

Do not create a full-screen dashboard.

## 9.2 Picker content

Header:

**Choose a Template**

Subtitle:

"Start with a reusable structure."

Include a search field:

Placeholder:

"Search templates"

Organize rows into these sections:

1. Favorites
2. My Templates
3. Built-in Templates

Rules:

- Hide Favorites if empty.
- Hide My Templates if empty.
- Never duplicate a favorite template in a later section.
- Display every template exactly once.
- Show a distinguishing Built-in or My Template label where necessary.
- Show a template icon, name, and short content preview.
- Provide a favorite toggle on each row.

Ordering:

- Favorites: alphabetical by display name.
- My Templates: most recently created first.
- Built-in Templates: predefined order from Section 6.

Use a case-insensitive, whitespace-trimmed substring search against display names.

Do not search entire template bodies in Phase 1.

When no names match, display:

"No templates found"

Do not alter application-wide search behavior.

## 9.3 Template selection and preview

Selecting a template opens its read-only preview.

Display:

- Template name
- Built-in or My Template source
- Rendered document body
- Relevant formatting
- A clear **Use Template** primary action
- A back action returning to the picker

Do not start an editable note autosave session for the preview.

Do not make checklists interactive in preview.

Do not change the template's content when previewing it.

Do not create a note merely because a user selected a template row.

## 9.4 Preview performance

Use existing read-only rendering components.

For long user templates:

- Preserve scrolling.
- Keep rendering bounded.
- Avoid synchronous full-library parsing.
- Avoid expensive editor initialization where only a preview is required.

Loading a template preview must not cause a visible application freeze.

## 9.5 Picker footer

Provide:

**Manage Templates**

This navigates to the template management screen using established navigation patterns.

Back navigation must not leave a stray modal or focus overlay.

---

# 10. Template management screen

Add a screen accessible through:

**Settings → Templates**

Use the application's existing Settings navigation structure.

Title:

**Templates**

Subtitle:

"Reusable starting points for your notes."

Display built-in and user-created templates with the same categories and visual language as the picker.

## 10.1 User-created template actions

Each user-created template must support:

- Preview
- Rename
- Favorite / Unfavorite
- Delete
- Create note from template

## 10.2 Built-in template actions

Each built-in template must support:

- Preview
- Favorite / Unfavorite
- Create note from template

Built-in templates cannot be renamed or deleted.

Do not show nonfunctional disabled menus for unsupported built-in operations.

## 10.3 Rename

Use an adaptive dialog.

Title:

**Rename Template**

Prefill its current display name.

Use the same validation as template creation.

Actions:

- Cancel
- Save

Renaming changes only the template metadata.

It does not rename existing notes previously created from the template.

It does not change the template's canonical document content.

Update `updatedAt`.

## 10.4 Delete

Before deleting a user-created template, display a confirmation dialog.

Title:

**Delete Template?**

Message:

"This template will be deleted. Notes created from it won't be affected."

Actions:

- Cancel
- Delete Template

The delete action is destructive-styled using existing theme tokens.

Deletion must:

- Remove the template row.
- Remove its favorite record.
- Update active watchers.
- Preserve existing instantiated notes.
- Preserve its original source note.
- Not create cloud sync tombstones.
- Not delete note attachments or document assets.

After success, show:

"Template deleted"

If deletion fails, preserve the template and display a recoverable error.

---

# 11. Favorites

Favorite functionality is available in:

- Template picker
- Template management screen
- Template preview where it fits the existing design

Use the existing icon conventions.

Behavior:

- Favorite state changes immediately after successful local persistence.
- Favorites survive app restarts.
- Favorites work offline.
- Built-in and user-created templates use the same favorite behavior.
- Favoriting a template does not create a note.
- Favoriting does not alter template content.
- Unfavoriting removes the favorite database record.
- Deleting a user-created template removes its favorite state.
- Favorites must not affect ordinary pinned-note behavior.

Avoid optimistic UI that permanently diverges from persistence after a failure. Roll back any optimistic change when the database operation fails.

Default state:

**No templates are favorited on first install.**

The picker displays its My Templates and Built-in Templates sections normally.

---

# 12. Navigation integration

## 12.1 Existing New Note action

Preserve existing one-tap blank-note creation everywhere.

Do not replace the primary New Note action with a mandatory template selection dialog.

Existing users must still be able to create a blank note just as quickly as before.

## 12.2 New entry points

Add:

**New from Template**

to the existing notes-list overflow menu.

Also add the action to the existing desktop command palette.

The command palette action must open the same picker implementation, not a separate template workflow.

Where the active notes view represents a tag, pass its tag context to the picker so creating the note applies that tag.

## 12.3 Editor action

Add:

**Save as Template**

to the note editor overflow menu.

Its state must reflect the current note's eligibility.

## 12.4 Settings integration

Add:

**Templates**

under Settings.

Do not add a permanent top-level sidebar section in Phase 1.

## 12.5 Other workflows

Do not change the behavior of:

- Quick Capture
- Imported documents
- Share-to-note
- Daily journal creation
- Linux `qp new`
- Existing keyboard New Note shortcut
- Note duplication, if already present
- Other application-specific creation flows

They must continue creating ordinary notes through their current mechanisms.

---

# 13. UI and visual design

Quiet Paper follows a warm, minimal editorial aesthetic.

Reuse:

- `AppColors`
- `AppTypography`
- `AppSpacing`
- `AppRadii`
- Existing adaptive modal components
- Existing dialog conventions
- Existing icon library
- Existing list-row styles

Do not introduce another visual design system.

## 13.1 Design requirements

- Paper-tone surfaces
- Subtle dividers
- Minimal elevation
- Quiet accent usage
- Restrained typography
- Generous but efficient spacing
- No oversized colorful cards
- No gradient backgrounds
- No glassmorphism
- No unnecessary animations
- No persistent floating template toolbar

The picker should feel like a native part of Quiet Paper.

## 13.2 Accessibility

Every interactive element must have:

- A meaningful semantic label
- Adequate contrast
- Correct enabled/disabled semantics
- A target size consistent with existing accessible controls
- Keyboard focus support on desktop
- Screen-reader feedback for favorite toggling
- Correct Escape/System Back behavior

The favorite control must announce whether the template is currently favorited.

Dialogs must return focus correctly when closed.

Long template names must wrap or truncate without overlapping action icons.

Support both light and dark themes.

Do not introduce fixed font sizes that defeat existing typography accessibility settings.

## 13.3 Keyboard interactions

Required:

- Escape closes the picker or preview.
- Arrow keys navigate focused template list items on desktop.
- Enter activates the focused item.
- Tab moves between interactive controls in logical order.
- Escape closes rename/delete dialogs without applying changes.

Do not override keyboard shortcuts used by any editor.

---

# 14. Editor compatibility

This is a critical requirement.

Quiet Paper has multiple editor representations and an established canonical content lifecycle.

The template feature must reuse that lifecycle rather than invent a parallel conversion engine.

## 14.1 Markdown source

Verify preservation of:

- Markdown text
- Headings
- Lists
- Nested tasks
- Tables
- Code fences
- Language identifiers
- Blockquotes
- Math expressions
- Links
- Frontmatter

## 14.2 Visual Editor

Verify:

- RichDocument serialization is preserved.
- Rich blocks are not flattened into plain text.
- Inline formatting remains intact.
- Checklist metadata remains intact.
- Table structure is preserved.
- Block identities are handled using the existing document-loading conventions.
- The copied note has no shared mutable AST references to the template or source.

## 14.3 Super Editor

Verify:

- Supported Markdown structures load correctly.
- Smart tasks remain separate structured tasks.
- Nested task hierarchy is preserved.
- Code blocks retain languages.
- Math remains editable.
- Dividers and blockquotes remain valid.
- Normal document editing still works immediately after creation.

## 14.4 Cross-mode behavior

Create tests that instantiate templates and open them in every supported editor mode.

Switching modes must not silently remove supported content.

Do not perform unnecessary mode conversions during template persistence.

An existing rich-document template must follow the same normal document-loading rules as an existing rich-document note.

Do not change the application's canonical editor representation solely for templates.

---

# 15. Autosave and undo/redo

## 15.1 Saving as template

Save-as-template must use the latest document state, including pending editor changes.

The operation must not:

- Lose the editor caret
- Reset editor selection
- Replace the editor document
- Insert a new undo checkpoint into the source note
- Create duplicate autosave events
- Cause a stale save to overwrite recent edits

## 15.2 Creating from template

The created note must open in the normal editor.

Subsequent edits must use existing autosave and undo/redo.

Template instantiation itself is not a text-edit undo operation.

The created note is a normal persisted document.

No template-specific autosave controller should be introduced.

---

# 16. Security and privacy

Follow the existing application trust model.

## 16.1 Local storage

Phase 1 templates are local application data.

Do not sync their dedicated database rows or favorites through the cloud.

Do not create new unencrypted network requests.

Do not claim the local template table is encrypted at rest unless this is genuinely guaranteed by the application's existing storage layer.

## 16.2 Cloud privacy

When a template is used, its resulting ordinary note may synchronize through the existing encrypted note-sync mechanism.

The template definition itself must not be uploaded.

Do not modify the backend encryption model.

Do not introduce plaintext template metadata into cloud indexes.

Do not reuse sensitive sharing identifiers from source notes.

## 16.3 Protected content

Protected and locked notes cannot become templates in Phase 1.

This restriction applies even when a protected note is temporarily unlocked.

Do not weaken or bypass protected-note handling.

## 16.4 Local vault deletion

Inspect the existing local-vault erase/reset implementation.

Ensure that erasing all local vault data also removes:

- User-created template rows
- Template favorite records

Do not leave user-created template contents behind after a full local-vault erase.

Bundled built-in definitions naturally remain available after reset, with all favorite state reset.

---

# 17. Encrypted backups and restoration

Templates must be included in Quiet Paper's existing encrypted backup workflow.

This is mandatory despite Phase 1 not including cross-device synchronization.

## 17.1 Backup data

Include:

- User-created template IDs
- Display names
- Serialized content
- Storage formats
- Default tags
- Creation/update timestamps
- Template schema versions
- Favorite template IDs, including built-in favorites

Do not duplicate built-in template bodies in the backup.

Do not export templates into an unencrypted sidecar file.

## 17.2 Compatibility

Inspect the existing `.qpbackup` format.

Extend its payload/schema in a backward-compatible way.

Existing backups created before the template feature must still restore.

If an old backup has no template section, treat that section as empty.

Do not silently reject a valid old backup because templates are absent.

Preserve existing encryption and authentication requirements.

## 17.3 Restore behavior

Follow the existing backup restore operation type.

For a full replacement restore:

- Restore the backed-up user templates.
- Restore the backed-up favorite state.
- Remove user-template data that is not part of the replacement backup.
- Restore favorites only for IDs that remain valid or are recognized built-in IDs.
- Keep the built-in template catalog bundled with the application.

For any existing merge-style restore:

- Upsert user templates by stable ID.
- On ID collision, prefer the template with the later `updatedAt`.
- If timestamps are identical, preserve the existing local row.
- Combine favorite ID sets.
- Remove invalid favorite references to nonexistent user templates.

Do not add a new merge-style restore feature if the application currently supports only full replacement.

## 17.4 Atomicity

Template restoration must participate in the existing restore transaction or rollback mechanism.

A failed restore must not leave half-restored templates.

Test:

- Backup with user templates
- Backup with favorites
- Backup with no templates
- Backup from an older app version
- Restore with existing notes
- Corrupted template metadata
- Rollback on restore failure

---

# 18. Performance

The feature must remain responsive with large collections.

## 18.1 Required behavior

- Template picker queries only template data.
- Favorite state uses a small dedicated query.
- No entire-notebook scan when opening the picker.
- No entire-note index rebuild when renaming templates.
- No global Markdown parsing on every favorite toggle.
- No unnecessarily repeated rich-document deserialization.
- Template preview loads only the selected template.
- Existing note-list pagination remains untouched.

## 18.2 Scale testing

Add tests or benchmarks exercising:

- 1,000 saved templates
- Long template names
- Large template bodies within current note limits
- Rapid favorite toggles
- Repeated picker opening/closing
- Deletion while the picker is open
- Creating multiple independent notes from one template

Verify that these operations do not cause unintended full-notebook queries or obvious synchronous main-isolate work proportional to all note contents.

---

# 19. Error handling

Do not swallow exceptions.

Use the application's existing error presentation patterns.

Required user-facing cases:

| Failure | Expected behavior |
|---|---|
| Invalid template name | Inline validation |
| Database write failure | Preserve dialog, show error |
| Template deleted during selection | Explain unavailability |
| Unsupported source attachment | Block safely with explanation |
| Invalid template serialization | Do not instantiate |
| Note creation failure | Do not navigate |
| Favorite persistence failure | Restore previous UI state |
| Delete failure | Keep template visible |
| Vault locked/unavailable | Respect existing lock workflow |
| Backup template corruption | Fail safely with restore rollback |

Do not display raw stack traces in the interface.

Preserve useful diagnostic details in development logging.

Avoid logging note/template body content, encryption keys, or protected metadata.

---

# 20. State management

Use Riverpod consistent with the current application.

Expose state for:

- User templates
- Combined built-in and user-template catalog
- Favorites
- Picker search query
- Selected template
- Loading and mutation state
- Creation-in-progress state
- Recoverable errors

Do not create a second global state-management architecture.

Database-backed providers should react to valid repository changes.

Do not use global mutable singleton lists as the source of truth.

Dispose temporary controllers, focus nodes, and subscriptions correctly.

Prevent navigation callbacks from updating disposed widgets.

---

# 21. Integration and regression safety

Audit all affected areas before editing.

At minimum:

1. Note domain model
2. Note repository
3. Note creation pathways
4. EditorScreen
5. Markdown editor
6. RichDocument serialization
7. Super Editor loading
8. Drift database registration
9. Drift migrations
10. Existing Riverpod providers
11. Notes-list overflow actions
12. Settings navigation
13. Command palette
14. Backup service
15. Backup restore service
16. Vault erasure/reset
17. Protected-note checks
18. Tag normalization
19. Search indexing
20. Sync queue handling

Avoid unnecessary changes to unrelated features.

Templates must not appear in:

- All Notes
- Pinned Notes
- Archived Notes
- Trash
- Regular note search
- Journal calendar
- Recent ordinary notes
- Ordinary note counts
- Note-tag membership counts
- Cloud sync changes

Once a note is created from a template, that new ordinary note must appear in all relevant normal note views.

---

# 22. Automated testing

Write meaningful tests, not only smoke tests.

Do not use assertions that pass without exercising the feature.

Add tests using the repository's existing test patterns.

Organize them under an appropriate `test/templates/` directory.

## 22.1 Domain tests

Test:

- Valid template construction
- Invalid names
- Unicode names
- Empty names
- Maximum name length
- Duplicate display names
- Stable built-in IDs
- Correct built-in count
- Built-in immutability
- Default favorite state
- Storage format validation
- Tag normalization

## 22.2 Database tests

Test:

- Insert
- Read
- Stream updates
- Rename
- Delete
- Favorite
- Unfavorite
- Delete/favorite cleanup
- Duplicate names with distinct IDs
- Transaction rollback
- Fresh database creation
- Upgrade from previous schema
- Data preservation after migration

## 22.3 Template service tests

Test:

- Save ordinary note as template
- Source note remains unchanged
- Source unsaved changes are flushed
- Correct tag snapshot
- Correct content snapshot
- Independent template identity
- Independent instantiated note identity
- Correct new timestamps
- Correct title
- Source state flags not copied
- Repeat instantiation creates independent notes
- Deleting a template does not delete its notes
- Deleting source note does not delete its template
- Instantiation correctly queues a normal encrypted note sync

## 22.4 Rich-content tests

Include fixtures containing:

- Multiple headings
- Bold and italic inline spans
- Nested checklists
- Ordered and unordered lists
- Tables
- Code blocks
- Inline and display math
- Dividers
- Blockquotes
- YAML frontmatter
- Internal note links

Test serialization and reopening.

Test valid content in every supported editor mode.

Test that source and template do not share mutable document state.

## 22.5 Unsupported-content tests

Create notes containing:

- Embedded images
- Asset links
- Document links
- Audio references
- PDF references
- Link previews backed by local assets

Verify Save as Template is blocked without mutating source content.

Also verify:

- Protected notes are blocked.
- Journal notes are blocked.
- Trashed notes are blocked.
- Read-only notes are blocked.

## 22.6 Widget tests

Test:

- Save as Template action visibility
- Save dialog rendering
- Name validation
- Cancel behavior
- Successful save feedback
- Picker opening
- Search filtering
- Section ordering
- Favorites moving into Favorites
- No duplicate rows
- Built-in action restrictions
- Template preview
- Use Template
- Rename
- Delete confirmation
- Escape dismissal
- System Back dismissal
- Keyboard focus handling
- Light/dark appearance
- Small-screen layout
- Desktop dialog layout

## 22.7 Integration tests

Exercise complete flows:

**Flow A**

1. Create ordinary note.
2. Enter formatted content.
3. Save as Template.
4. Locate template in picker.
5. Preview.
6. Instantiate.
7. Edit instantiated note.
8. Confirm original source and template unchanged.

**Flow B**

1. Favorite built-in template.
2. Close application state.
3. Recreate providers/database connection.
4. Confirm favorite persisted.
5. Unfavorite.
6. Confirm removal.

**Flow C**

1. Create user template.
2. Rename it.
3. Instantiate note.
4. Delete template.
5. Reopen instantiated note.
6. Verify content remains correct.

**Flow D**

1. Create template.
2. Create encrypted backup.
3. Restore into a clean test database.
4. Confirm template contents and favorites restored.
5. Instantiate restored template.

**Flow E**

1. Create template while offline.
2. Confirm template does not enter sync queue.
3. Instantiate note while offline.
4. Confirm resulting note enters normal sync behavior.
5. Confirm no template-specific cloud payload is produced.

## 22.8 Regression tests

Verify existing behavior is unchanged for:

- Blank note creation
- Autosave
- Empty-draft disposal
- Checklists
- Markdown tables
- RichDocument loading
- Super Editor loading
- Note tags
- Note search
- Archive/trash
- Note pinning
- Quick Capture
- Journal creation
- Backup restoration
- Sync engine
- Protected notes
- Command palette

Do not delete or weaken existing tests to make the feature pass.

---

# 23. Implementation sequence

Implement in this order.

## Step 1 — Repository audit

Read the relevant documentation and actual code.

Identify:

- Current database version
- Existing note factory/creation service
- Current canonical serialization formats
- Existing editor autosave flush methods
- Existing note eligibility/protection rules
- Existing backup payload and restore semantics
- Existing adaptive modal patterns
- Existing command palette registration

Record architectural findings before implementation.

## Step 2 — Domain and database

Implement:

- Template domain model
- Drift tables
- Migration
- Data repository
- Built-in catalog
- Domain validation

Write and run unit/database tests.

## Step 3 — Application services

Implement:

- Save-note-as-template
- Instantiate-template
- Favorite operations
- Rename
- Delete
- Eligibility checks
- Content validation

Write service tests.

## Step 4 — UI

Implement:

- Picker
- Preview
- Management screen
- Save dialog
- Rename dialog
- Delete confirmation
- Favorite controls

Write widget tests.

## Step 5 — Application integration

Connect:

- Notes-list overflow menu
- Editor overflow menu
- Settings
- Command palette
- Existing note creation
- Active tag context

Verify existing navigation.

## Step 6 — Backups and privacy

Implement:

- Encrypted backup inclusion
- Backward-compatible restore
- Vault erase integration
- No template cloud synchronization

Write security, backup, and integration tests.

## Step 7 — Full validation

Run all required test suites and analysis.

Fix all regressions caused by the implementation.

## Step 8 — Documentation

Update the repository documentation to reflect the final implementation.

Do not mark the task complete until all required steps are addressed.

---

# 24. Required validation commands

Use the toolchain and exact Flutter SDK pinned by the repository.

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Run targeted template tests independently.

Run any additional checks mandated by `AGENTS.md`.

If backend code was changed, which should not be necessary for this phase, also run the existing backend TypeScript validation and complete backend test suite.

Do not upgrade Flutter, Dart, or unrelated dependencies to implement templates.

Do not remove existing dependencies.

Do not run only the newly added tests and claim the whole application passes.

When a platform-specific behavior cannot be verified in the available environment, clearly identify that limitation and the exact remaining validation steps.

---

# 25. Required documentation

Create:

`handoff/templates.md`

Include:

1. Feature overview
2. Scope and Phase 1 limitations
3. Domain model
4. Database schema
5. Migration strategy
6. Built-in template catalog
7. Save-as-template flow
8. Note instantiation flow
9. UI integration points
10. Editor serialization rules
11. Unsupported attachment policy
12. Favorites behavior
13. Backup and restore rules
14. Privacy/security considerations
15. Testing and verification
16. Future extension points

Update:

`handoff/INDEX.md`

Add the new subsystem guide to the documentation map.

Append an implementation entry to:

`handoff/latest-logs.md`

Use the numbering and engineering-log format established by the current repository.

Do not overwrite historical log entries.

Follow any additional `AGENTS.md` documentation requirements.

---

# 26. Definition of Done

The feature is complete only when every condition below is satisfied.

## Functional

- [ ] Eight built-in templates exist.
- [ ] Built-in IDs are stable.
- [ ] Built-ins cannot be renamed or deleted.
- [ ] Existing ordinary notes can become templates.
- [ ] Existing notes remain unchanged.
- [ ] Unsupported notes/assets are handled safely.
- [ ] New independent notes can be created from templates.
- [ ] Template picker works.
- [ ] Template previews work.
- [ ] Template search works.
- [ ] Favorites work.
- [ ] Favorites persist after restart.
- [ ] User templates can be renamed.
- [ ] User templates can be deleted.
- [ ] Deleting templates does not affect existing notes.
- [ ] Original blank-note creation remains unchanged.
- [ ] Settings integration works.
- [ ] Command palette integration works.
- [ ] Active tag context is preserved.

## Architecture

- [ ] Templates are stored separately from notes.
- [ ] SQLite migration is safe.
- [ ] Riverpod integration follows existing patterns.
- [ ] No redundant template editing architecture is introduced.
- [ ] Markdown content is preserved.
- [ ] Rich-document content is preserved.
- [ ] Super Editor compatibility is verified.
- [ ] No unsupported private asset references are silently copied.
- [ ] Note creation uses existing repository invariants.
- [ ] Source note metadata is not incorrectly cloned.

## Privacy and persistence

- [ ] Template features work offline.
- [ ] Templates do not enter cloud sync.
- [ ] Instantiated notes use normal encrypted sync.
- [ ] Templates are included in encrypted backups.
- [ ] Legacy backup restoration works.
- [ ] Full vault erase removes local templates/favorites.
- [ ] Protected-note restrictions are respected.

## Quality

- [ ] New unit tests pass.
- [ ] New widget tests pass.
- [ ] New database tests pass.
- [ ] New integration tests pass.
- [ ] Existing regressions pass.
- [ ] `flutter analyze` is clean.
- [ ] Full `flutter test` passes.
- [ ] Documentation is updated.
- [ ] No dead code or abandoned prototype remains.
- [ ] No placeholder implementation remains.
- [ ] No known data-loss regression is introduced.

---

# 27. Final engineering report

When implementation is complete, provide a structured final report containing:

### A. Implementation summary

Explain what was implemented and what users can now do.

### B. Architecture

Describe:

- New domain model
- New database tables
- Migration
- Repository/services
- Riverpod providers
- UI components
- Note creation integration

### C. Modified files

List added and modified files with short explanations.

### D. Testing

Provide:

- Commands executed
- Test counts
- Passing/failing results
- Static analysis result
- Migration verification
- Backup verification
- Editor round-trip verification
- Platform-specific limitations, if any

Never claim a test passed unless it actually ran successfully.

### E. Known limitations

List the explicit Phase 1 limitations and any unresolved technical limitations.

### F. Completion checklist

Report each Definition of Done item as complete, incomplete, or blocked.

### G. Final status

Use exactly one of:

- `COMPLETE — Verified`
- `IMPLEMENTED — Verification incomplete`
- `INCOMPLETE — Blocking issues remain`

Only use `COMPLETE — Verified` if the required implementation and verification genuinely succeeded.

---

# 28. Final instruction

You are implementing this feature in an existing, complex production application.

Prefer compatibility, content integrity, privacy, maintainability, and predictable behavior over shortcuts.

Do not create an isolated demo.

Do not add artificial mock implementations to production code.

Do not replace existing editing infrastructure.

Do not silently downgrade document content.

Do not introduce unnecessary dependencies.

Do not change unrelated features.

Do not stop after implementing the database or UI.

Complete the end-to-end feature, run the tests, fix the failures, update the documentation, and provide the final engineering report.

**Begin by auditing the repository, then implement Phase 1 fully according to this specification.
