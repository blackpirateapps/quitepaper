Imp instruction: despite what may be written below, under any circumstances do not run full test suite, only the relevant ones. 
# Quiet Paper — Production-Ready Email Import System

## Role and mission

You are a senior Flutter, Dart, Kotlin, Linux desktop, application security, and software architecture engineer working directly in the Quiet Paper repository.

Your task is to **design, implement, integrate, test, and document a complete, production-ready Email Import feature**.

This is an implementation assignment, not a request for a proposal, architectural discussion, or partial prototype.

Implement the entire feature end to end, including native platform integration, MIME parsing, UI, encrypted persistence, attachment handling, search integration, synchronization compatibility, regression tests, and documentation.

Do not stop at scaffolding. Do not leave mock implementations, TODOs, placeholders, unconnected buttons, or functionality that works only in tests.

Do not request implementation decisions from the user. All product requirements and behavior are specified below. Resolve repository-specific technical details by inspecting the existing code and following established architecture.

**Primary target platforms:**

- Linux desktop: drag-and-drop, file picker, and existing editor integration.
- Android: system share sheet, Open With, file picker, and existing Quick Capture integration.

The feature must also compile safely on other supported platforms without introducing platform regressions.

---

# 1. Product goal

Quiet Paper is an offline-first, privacy-focused notes application inspired by Bear Notes.

Users should be able to selectively preserve important email messages as ordinary, editable Quiet Paper notes.

The intended workflow is:

1. A user opens an email in Proton Mail, Gmail, Outlook, or another email service.
2. The user exports the email as an `.eml` file or shares available email content to Quiet Paper.
3. Quiet Paper recognizes the incoming content and presents an Email Import preview.
4. The user selects a destination and confirms import.
5. Quiet Paper creates an editable note containing the email content and metadata.
6. The original email and its attachments are preserved in the encrypted attachment vault when available.
7. The imported note behaves like any other Quiet Paper note: editable, searchable, taggable, exportable, backed up, and synchronizable.

The feature must not require:

- Proton Mail Bridge.
- A paid Proton Mail subscription.
- Gmail or Outlook OAuth.
- IMAP or SMTP credentials.
- Email forwarding addresses.
- An external conversion service.
- A hosted processing backend.
- An active internet connection.

All email parsing, conversion, and initial persistence must happen locally.

## 1.1 Required Linux use case

The primary desktop use case is Proton Mail Free in a Linux web browser.

The user exports an email as an `.eml` file, then drags the downloaded file directly into Quiet Paper.

Quiet Paper must recognize the file, open the import preview, and allow it to be saved as a note.

This must work whether the user is viewing the main notes screen or an existing note in the editor.

## 1.2 Required Android use case

When an Android email application or file manager shares an `.eml` file through the system share sheet, Quiet Paper must appear as an eligible receiving application for supported MIME types.

The imported file must travel through the same email-import pipeline used on Linux.

For email applications that share only selected text, HTML, or a URL, Quiet Paper must preserve existing share behavior and offer an explicit way to save the available content as an email note.

**Important limitation:** An Android application cannot necessarily provide complete email content through its share sheet. Quiet Paper must never fabricate missing headers, recipients, or attachments. If only text or a link is provided, the UI must clearly reflect that.

---

# 2. Required architectural reconnaissance

Before modifying code, inspect the current repository.

Read and follow:

- `AGENTS.md`
- `handoff/INDEX.md`
- `handoff/core-architecture.md`
- `handoff/editor-and-typography.md`
- `handoff/sync-and-storage.md`
- `handoff/ocr-and-documents.md`
- `handoff/platform-and-builds.md`
- `handoff/tags-and-search.md`
- `handoff/latest-logs.md`

Also inspect the current source implementations rather than assuming the documentation is exhaustive or fully current.

Pay particular attention to these previously documented components:

- `lib/core/sharing/shared_file_importer.dart`
- `lib/core/web_clipper/share_intent_handler.dart`
- `lib/features/quick_capture/`
- `lib/features/editor/presentation/editor_screen.dart`
- `lib/core/attachments/`
- `lib/core/documents/`
- `lib/features/notes/`
- `lib/core/database/`
- `lib/core/sync/`
- `lib/features/search/`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/blackpiratex/quietpaper/MainActivity.kt`
- Existing desktop drag-and-drop handlers.
- Existing note import/export services.
- Existing backup and restore services.
- Existing Markdown and RichDocument conversion pipelines.

Determine the real current APIs, models, storage schemas, and platform registration mechanisms before making changes.

### Non-negotiable architectural requirements

1. Reuse existing note repositories and persistence mechanisms.
2. Reuse existing encrypted attachment services.
3. Preserve the three editor modes: Markdown Source, Visual Editor, and Super Editor.
4. Preserve existing Android file-sharing, web clipping, and Quick Capture behavior.
5. Preserve existing Linux drag-and-drop behavior for ordinary images and documents.
6. Do not introduce a second independent notes database.
7. Do not introduce a separate unencrypted archive of imported emails.
8. Do not create a server-side email parsing or conversion endpoint.
9. Do not change unrelated editor, search, or synchronization behavior.
10. Respect the existing dependency versions and supported Flutter SDK unless a verified dependency change is necessary.

Use existing project conventions for dependency injection, Riverpod providers, error handling, theme tokens, navigation, and testing.

---

# 3. Supported input formats

## 3.1 Full email files

The primary format is RFC 5322-compatible `.eml`, including MIME multipart messages.

Support:

- `.eml` filename extension.
- `message/rfc822` MIME type.
- Recognized equivalent email MIME types where legitimately used.
- Valid `.eml` content provided with a generic MIME type.
- `.eml` files received from Android `content://` providers.
- `.eml` files opened through supported Android Open With actions.
- `.eml` files dropped from Linux file managers.
- `.eml` files selected through the application's file picker.

Use extension, declared MIME type, and bounded content inspection together to classify input safely.

A filename alone is not proof that a file contains valid email data.

For ambiguous generic MIME types, require convincing message structure before classifying the input as an email.

## 3.2 Shared text and HTML

Support explicit import of available email content received through:

- `text/plain`
- `text/html`
- Android `ACTION_SEND` text extras.
- Existing Quick Capture text-sharing mechanisms.

Do not automatically reinterpret every shared text message as an email.

A normal shared paragraph must continue to behave like ordinary Quick Capture.

Provide an explicit **Save as Email** action for shared text.

The user may supply or edit:

- Subject.
- Sender.
- Date.
- Recipients, if known.

These fields are optional for text-only sharing.

Clearly identify such imports as **Shared content**, not a verified full email archive.

## 3.3 Out-of-scope formats

Do not implement native parsing of:

- Outlook `.msg`.
- MBOX mailbox archives.
- PST or OST archives.
- Remote mailboxes.

For unsupported formats, show a clear explanation and preserve existing generic attachment-import behavior where applicable.

Never mislabel an unsupported file as a successfully parsed email.

---

# 4. Linux desktop integration

## 4.1 Drag-and-drop

Extend the existing desktop file-drop pipeline.

When the user drags an `.eml` file over Quiet Paper:

- Recognize it as a possible email import.
- Display a subtle drop-target indicator.
- Preserve the existing editor and its unsaved changes.
- Accept the drop without requiring a new window.
- Validate the file.
- Open the Email Import preview.

### Required drop locations

Support dropping onto:

1. Main notes list or workspace.
2. An open note editor.
3. Empty areas of the application window that belong to the main workspace.

Dropping an email into an editor must **not immediately insert raw email text at the cursor**.

Instead, display the Email Import preview and allow the user to create a new note or append it to an existing note.

The current note should be offered as the first append destination when appropriate.

### Drag-and-drop behavior

- Do not show the email-drop overlay for unsupported content.
- Do not interfere with existing image insertion.
- Do not interfere with generic document dragging.
- Do not consume ordinary text drag operations.
- Do not modify the current note before confirmation.
- Do not read, rename, move, or delete the user's original downloaded file.
- Handle file read failures gracefully.
- Accept multiple `.eml` files in one drop operation.
- Never silently discard unsupported files in a mixed drop.

For a mixed batch, identify unsupported files and offer to continue with the valid emails.

## 4.2 Linux packaging

Test the feature with the existing supported Linux distribution formats:

- DEB.
- RPM.
- AppImage.
- Flatpak.

Pay particular attention to Flatpak sandboxing and file-access permissions.

Dropped files may arrive through different platform-specific path or URI representations.

Use the existing native file-access and desktop drop infrastructure. If additional Linux platform integration is required, implement it without weakening the application sandbox.

No unrestricted filesystem access may be introduced merely to support drag-and-drop.

## 4.3 Manual import

Add an **Import Email** action to the appropriate existing import menu.

Also make the command discoverable through Quiet Paper's desktop command palette.

The action opens a file picker filtered primarily for `.eml`, while allowing generic MIME fallback when necessary.

Multiple selection must be supported.

The file picker and drag-and-drop must invoke the same central import service.

Do not duplicate import logic across entry points.

---

# 5. Android share-sheet integration

## 5.1 Existing implementation

Quiet Paper already has documented Android sharing infrastructure using `receive_sharing_intent`, `ShareIntentHandler`, `SharedFileImporter`, and Quick Capture.

Extend these components instead of creating an unrelated competing intent handler.

Inspect the actual installed plugin version and its contracts before modifying Android native code.

## 5.2 Required Android intent support

Support the relevant combinations of:

- `ACTION_SEND`
- `ACTION_SEND_MULTIPLE`
- `ACTION_VIEW`
- `EXTRA_STREAM`
- `EXTRA_TEXT`
- `EXTRA_SUBJECT`
- `ClipData`
- `content://` URIs

Register the relevant MIME types, including `message/rfc822`.

Support generic binary MIME for shared files where required, but avoid introducing an unrestricted Open With handler for every file on the device.

Preserve current intent filters for PDF, Markdown, text, and web clipping.

Do not add unnecessary storage permissions.

## 5.3 Android content URI handling

A shared file may be represented by a content URI rather than a filesystem path.

Implement reliable content access using Android's `ContentResolver` or the verified capabilities of the existing sharing plugin.

Requirements:

- Read the supplied stream.
- Resolve display names when available.
- Resolve declared MIME type when available.
- Treat display names and MIME values as untrusted.
- Handle missing metadata.
- Handle temporary URI permissions.
- Handle provider failures.
- Support cold and warm application launches.
- Avoid leaking temporary content URI grants.

Read or securely stage incoming content while the relevant access permission remains valid.

Do not assume a `content://` URI can be converted to a conventional filesystem path.

Do not require broad storage permissions.

## 5.4 Native lifecycle

The same shared item must not be imported twice because of overlapping initial-intent and intent-stream delivery.

Use an incoming-request identity and an idempotent coordinator.

Requirements:

- One incoming share creates one pending import session.
- Returning from the preview must not reprocess the same intent.
- Warm-start and cold-start behavior must be equivalent.
- Rapid consecutive shares must queue safely.
- A new share must not overwrite an active unsaved Quick Capture draft.
- An app restart must not automatically create a note without confirmation.
- App lock state must be respected before sensitive email content is displayed.

## 5.5 Shared text behavior

Preserve existing Quick Capture functionality.

For plain text originating from an email app:

1. Open Quick Capture as usual.
2. Expose an unobtrusive **Save as Email** action.
3. Allow the user to inspect/edit metadata.
4. Route it through the email-import system.

Do not treat a URL alone as complete email content.

If the user shares only a link, preserve the existing web clipping or Quick Capture behavior.

## 5.6 Android user experience

Keep the UI lightweight and mobile-friendly.

Use a bottom sheet or full-screen preview depending on available space and existing design conventions.

Support cancellation with system Back.

Avoid excessive dialogs.

---

# 6. Unified email import pipeline

Create one central email-import feature module.

Recommended organization:

- `lib/features/email_import/domain/`
- `lib/features/email_import/application/`
- `lib/features/email_import/data/`
- `lib/features/email_import/presentation/`

The exact file boundaries should follow existing repository conventions, but all responsibilities below are mandatory.

The pipeline must follow this sequence:

1. Receive input.
2. Normalize input representation.
3. Validate bounded size and supported type.
4. Parse MIME structure where available.
5. Decode headers and message content.
6. Extract email metadata.
7. Extract and classify attachments.
8. Sanitize HTML.
9. Convert content to canonical Markdown.
10. Calculate duplicate-detection identifiers.
11. Present preview.
12. Collect user confirmation and destination.
13. Prepare encrypted attachments.
14. Commit the note and provenance.
15. Update local search/index state.
16. Queue existing encrypted synchronization.
17. Open the saved note or destination.
18. Report completion.

Parsing and conversion must never depend on the widget lifecycle.

All entry points must share the same parser, converter, persistence coordinator, and duplicate-detection service.

Use testable pure Dart logic wherever possible.

---

# 7. MIME parsing requirements

Implement complete handling of ordinary real-world RFC 5322/MIME messages.

Do not write a naive parser that splits on the first blank line and assumes everything afterward is plain text.

Use a maintained, compatible Dart MIME/email parsing library if one satisfies the requirements. Inspect its implementation, version, license, security properties, and supported character encodings. Where gaps exist, implement bounded adapters and regression tests rather than silently dropping data.

The parser must support:

- Folded RFC 5322 headers.
- RFC 2047 encoded headers.
- RFC 2231 filename parameters.
- RFC 6532 UTF-8 headers.
- `multipart/mixed`.
- `multipart/alternative`.
- `multipart/related`.
- Nested multipart boundaries.
- `message/rfc822` attached messages.
- Base64 transfer encoding.
- Quoted-printable transfer encoding.
- 7-bit and 8-bit text.
- CRLF and LF line endings.
- Unicode and non-ASCII content.
- Common declared character encodings.
- Missing optional headers.
- Invalid dates.
- Empty bodies.
- Duplicate header fields.
- Quoted email replies.
- Inline MIME images.
- Binary attachments.

## 7.1 Metadata extraction

Extract where available:

- Subject.
- From display name and address.
- To recipients.
- Cc recipients.
- Bcc recipients, only if present in source.
- Reply-To.
- Original sent date and timezone.
- Message-ID.
- In-Reply-To.
- References.
- Attachment filenames and MIME types.
- Source content hash.

Preserve decoded display values while retaining original identifiers needed for provenance.

Do not infer authenticity or trustworthiness from these headers.

For a malformed date, display **Date unavailable** rather than inventing a valid timestamp.

For a missing subject, use **Untitled Email**.

For a missing sender, use **Unknown sender**.

Preserve original message dates separately from the note's actual creation and modification timestamps.

## 7.2 Multipart body selection

For `multipart/alternative`, do not concatenate duplicate plain-text and HTML representations.

Preferred behavior:

1. Use the sanitized HTML representation converted to Markdown when it contains useful readable content.
2. Fall back to the plain-text representation when HTML is empty, unsupported, or unusable.
3. If neither is available, display an empty-body explanation while preserving the original `.eml`.

Keep the original source untouched.

For attached `message/rfc822` parts, preserve the nested message as an attachment. Do not automatically create another top-level note.

---

# 8. HTML email to Markdown

This is a critical part of the implementation.

HTML emails often contain complex layouts, tracking elements, external images, scripts, and invalid markup.

The resulting Quiet Paper note must remain readable and editable.

## 8.1 Conversion rules

Preserve meaningful structure:

- Paragraphs.
- Line breaks.
- Headings.
- Bold and italic emphasis.
- Ordered and unordered lists.
- Blockquotes.
- Hyperlinks.
- Simple tables.
- Code or preformatted text.
- Inline images that can be resolved safely.

Remove:

- Scripts.
- Stylesheets.
- Tracking pixels.
- Forms.
- Interactive widgets.
- Invisible content.
- Unsafe embedded objects.
- Tracking-only decorative elements.
- Unnecessary email-client formatting.
- Unsafe URL schemes.

Do not render arbitrary HTML inside the editing surface.

Convert sanitized content into the canonical representation understood by the existing editor.

## 8.2 URLs and remote content

Only permit safe link schemes appropriate to the existing application, such as HTTP(S) and supported mail links.

Reject dangerous schemes such as JavaScript URLs.

Do not fetch remote images automatically.

Do not fetch any email-linked external resource during import.

Remote image blocking must protect against tracking requests.

If a remote image cannot be embedded, do not fabricate a local asset. Preserve meaningful alt text or a safe, non-automatically-loaded reference where appropriate.

## 8.3 CID inline images

Support MIME inline images referenced through Content-ID.

For example, an HTML message may contain an image with a `cid:` reference.

Resolve such references against the MIME parts, import their image bytes into Quiet Paper's encrypted asset vault, and replace the inline reference with the appropriate existing `qp://asset/<UUID>` representation.

Do not duplicate the same inline image as multiple separate assets.

## 8.4 Plain-text conversion

Escape plain-text content safely so it does not unintentionally become Markdown formatting.

Preserve:

- Blank lines.
- Indentation.
- Unicode.
- Lists where recognizable.
- Quoted replies.
- Meaningful URLs.

Never silently interpret untrusted plain text as executable HTML or code.

---

# 9. Import preview UI

Before saving, display a preview.

The interface should follow Quiet Paper's restrained editorial design.

Avoid large Material-style cards, cluttered toolbars, or excessive controls.

## 9.1 Preview structure

Display:

**Import Email**

- Editable note title.
- Sender.
- Recipient summary.
- Original email date.
- Scrollable preview of converted content.
- Attachment count and filenames.
- Import destination.
- Import mode.
- Editable tags.
- Import confirmation button.
- Cancel action.

Use the existing warm paper backgrounds, typography, spacing, and theme tokens.

Support both light and dark themes.

## 9.2 Import modes

Implement exactly three modes.

### Mode A: Editable note + original

**Default and recommended mode.**

Create an editable Quiet Paper note containing:

- Email metadata.
- Converted Markdown body.
- Imported attachments.
- A reference to the preserved original `.eml`.

This is the default for full `.eml` imports.

For text-only sharing, show that an original `.eml` is unavailable and import the content without fabricating one.

### Mode B: Original archive only

Create a note containing:

- Email metadata.
- A clearly labeled original `.eml` attachment.

Do not insert the converted body into the note.

This mode is unavailable for text-only shares without an original email file.

### Mode C: Append to existing note

Allow the user to search existing notes and choose a destination.

Insert the imported email as a distinct section at the end of the note.

Preserve the destination's existing content, formatting, attachments, metadata, and editor mode.

Include the original `.eml` reference when available.

Default the picker to the current note when the import originated from an open editor.

Never silently choose the currently open note without user confirmation.

## 9.3 Tags

Suggest the existing or newly created `#email` tag.

The user can remove or replace it before saving.

Reuse Quiet Paper's existing tag management and deterministic tag identities.

Do not create duplicate tags.

## 9.4 Cancellation

Cancellation must leave the user's notes unchanged.

Do not create a visible empty note before import confirmation.

Discard uncommitted temporary conversion resources safely.

---

# 10. Canonical note formatting

Use native, editable note content rather than a special email-only editor.

For a new note:

- The note title is the imported subject.
- The note body starts with an Email Details section.
- Metadata is followed by a divider.
- The converted email content follows.
- Attachments appear after the body.
- The original email is presented as a clearly labeled attachment.

Example:

**Note title:** Your order has been confirmed

**Note body:**

From: Store Support — support@example.com

To: recipient@example.com

Date: 18 November 2026, 10:30 IST

---

Thank you for your order.

Your purchase has been confirmed.

**Order details**

- Order number: 12345
- Total: ₹2,499

---

**Attachments**

- invoice.pdf
- Original email (.eml)

The metadata should be readable in the ordinary editor and searchable.

For appended messages, insert a divider and a heading containing the email subject before the metadata.

Do not overwrite the original note title.

Avoid including every raw transport header in the visible note body.

Keep machine-readable import metadata separately from the visible content.

---

# 11. Import provenance and persistence

Implement a stable provenance model that supports duplicate detection across normal application restarts and device synchronization.

## 11.1 Required provenance structure

Define a typed, versioned model called `NoteImportSource` or the nearest equivalent consistent with the existing architecture.

For each imported email source, preserve:

- Schema version: `1`.
- Source kind: `email`.
- Input type: `eml` or `shared_text`.
- Original SHA-256 digest when raw source bytes are available.
- Normalized Message-ID when present.
- Canonical content fingerprint.
- Import timestamp in UTC.
- Original message date when available.
- Source attachment asset ID when available.
- IDs of imported attachment assets.
- Original message subject.
- Original sender metadata.
- Relevant reply/thread identifiers.

Store this metadata in the note's encrypted canonical data.

Add an optional `importSources` collection to the note domain model and persistent representation.

This must support multiple sources on a single note, because users can append multiple emails to one note.

Do not place machine metadata in HTML comments, invisible text, or fragile editor-only syntax.

## 11.2 Database integration

Extend Drift persistence and the shared note entity mapper.

Implement a defensive migration.

Existing notes must receive an empty import-source collection by default.

Required properties:

- Backward compatibility.
- Deterministic serialization.
- No loss of existing note fields.
- Safe behavior during database upgrades.
- Correct handling through backup and restore.
- Correct handling through note duplication or deletion.
- Correct handling through sync conflict merging.

For fast duplicate lookup, maintain a derived local index keyed by the relevant source hashes and Message-IDs.

The encrypted note provenance remains authoritative; the index is a rebuildable local cache.

Rebuild or update that index after relevant imports, restores, sync pulls, and note deletions.

Never use a full-library scan on the UI thread for each incoming email.

## 11.3 Synchronization

Provenance must be included in Quiet Paper's encrypted note representation.

Extend the existing client-side serialization and merge pipeline so provenance survives multi-device synchronization.

Do not transmit plaintext sender addresses, message subjects, recipients, or email bodies as server-visible metadata.

Avoid introducing backend API endpoints for importing emails.

The existing backend must remain crypto-blind.

If the existing encrypted note envelope needs a backward-compatible optional field, implement and test that extension while preserving compatibility with existing notes and clients.

Ensure source records are union-merged by stable identity when concurrent edits involve the same note.

Preserve note body conflict handling according to current repository behavior.

---

# 12. Encrypted attachment handling

This feature must integrate with the existing attachment vault.

Do not create a second attachment system.

## 12.1 Original `.eml`

For complete email imports, preserve the original `.eml` bytes without modification.

Import the original file as a generic encrypted attachment.

Link it from the note using the existing attachment URI and rendering mechanism.

The original must remain exportable or shareable through the application's existing attachment controls.

## 12.2 Email attachments

Import supported MIME attachments individually.

Preserve:

- Original filename.
- MIME type.
- Original decoded bytes.
- Available content-disposition metadata.
- Association with the imported note.

Support arbitrary binary attachments using the existing generic attachment mechanism.

Do not reject an email merely because an attachment is not a PDF or image.

Sanitize filenames before filesystem interaction.

Prevent path traversal.

Never execute attachments during import.

## 12.3 Asset deduplication

Within one email, reuse the same stored asset for repeated identical MIME parts when their decoded content and intended representation are identical.

Do not create duplicate assets for multiple references to the same CID image.

Respect any existing content-hash deduplication mechanisms.

## 12.4 Transaction safety

The import must be failure-safe.

Use an import preparation phase and a commit phase.

Before confirmation, parsing and preview must not mutate the user's canonical notes.

After confirmation:

1. Prepare required encrypted assets.
2. Prepare note content and metadata.
3. Validate the destination note state.
4. Commit the note, source records, and local references coherently.
5. Trigger repository notifications and sync.

If preparation or commit fails, remove newly created unreferenced staged assets without deleting assets used by other notes.

Avoid orphaned records.

Avoid creating a note that claims to contain attachments that were never successfully stored.

Never delete the source `.eml` from the user's Downloads directory.

---

# 13. Duplicate detection

Duplicate handling is mandatory.

## 13.1 Identification

Calculate:

- SHA-256 of original raw `.eml` bytes when available.
- Normalized Message-ID.
- Canonical content fingerprint derived from normalized sender, subject, original date, and email body.

Do not rely on subject alone.

Do not rely on filenames alone.

The original hash is authoritative for exact raw-file duplicates.

Message-ID helps identify possible duplicate messages, but a matching Message-ID with different content must not be silently treated as identical.

## 13.2 Duplicate workflow

For an exact duplicate:

Show a nonintrusive message such as:

**This email is already saved.**

Offer:

- Open existing note.
- Import another copy.
- Cancel.

For a possible duplicate with a matching Message-ID but differing content:

Show **A related email may already be saved**, and let the user inspect the existing entry before proceeding.

For an email already appended to the selected destination, warn before appending it again.

Never silently discard input.

Never silently create duplicate notes.

## 13.3 Scope

Duplicate detection must work after:

- Application restart.
- Note editing.
- Backup restoration.
- Normal note synchronization.
- Re-importing the same downloaded file under a different filename.

Preserve the user's explicit choice to import a duplicate.

---

# 14. Security and privacy requirements

Treat every imported email as untrusted input.

## 14.1 No external network activity

Email parsing must not send content to:

- Proton servers.
- Gmail or Outlook APIs.
- Quiet Paper's backend in plaintext.
- External HTML conversion endpoints.
- AI services.
- External image hosts.
- Remote analytics services.

Normal Quiet Paper encrypted sync may occur after persistence, following the user's existing sync configuration.

## 14.2 Bounded resource consumption

Enforce these initial limits:

- Maximum raw `.eml`: 50 MiB.
- Maximum individual decoded attachment: 25 MiB.
- Maximum total decoded attachments per email: 50 MiB.
- Maximum MIME parts per email: 200.
- Maximum MIME nesting depth: 20.
- Maximum decoded email body: 10 MiB.
- Maximum top-level emails in a single batch: 100.

Reject excessive input with a meaningful error.

Check limits during processing, not only after allocating the entire decoded content.

Handle malformed base64, oversized encoded headers, malicious boundary nesting, and decompression-like expansion safely.

Do not block the Flutter main isolate during large imports.

Use bounded background parsing, isolates, or existing worker infrastructure.

## 14.3 HTML safety

Never execute:

- Scripts.
- Inline event handlers.
- Embedded frames.
- Remote stylesheets.
- External tracking elements.
- Active HTML content.

Ensure unsafe links cannot escape the application's URL validation policy.

## 14.4 Sensitive data handling

Do not log:

- Email bodies.
- Email addresses.
- Subjects.
- Attachment contents.
- Message-ID values.
- Unencrypted file paths containing sensitive names.

Use sanitized operational error codes for diagnostics.

When temporary plaintext files are unavoidable, use an application-private temporary directory with restricted permissions, minimize their lifetime, and remove them on cancellation, completion, and recoverable failure.

Keep memory usage bounded.

Ensure lock/logout and secure-cache-clear flows invalidate any retained plaintext email previews.

Do not claim that normal filesystem deletion guarantees secure erasure on SSDs or journaled filesystems.

## 14.5 Encrypted sync and backup

All new persisted email-related content must follow existing Quiet Paper security invariants.

Original `.eml` files and imported MIME attachments must use the existing encrypted asset vault.

Do not introduce new unencrypted background caches or cloud-accessible plaintext storage.

---

# 15. Existing editor compatibility

The imported email must work correctly in:

1. Markdown Source mode.
2. Visual Editor mode.
3. Super Editor mode.

Test a full conversion cycle:

Import email → Save → Open Visual Editor → Switch to Markdown → Switch to Super Editor → Save → Reopen.

Required preservation:

- Email body.
- Paragraphs.
- Lists.
- Tables.
- Blockquotes.
- Links.
- Inline images.
- Attachment references.
- Metadata text.
- Machine-readable provenance.
- Existing note content.

Do not repeatedly reparse a RichDocument on every keystroke.

Respect the existing canonical AST and autosave behavior.

## 15.1 Appending to existing notes

Appending must be safe when the target note uses a rich AST storage format.

Do not insert raw Markdown text into serialized AST JSON.

Use the existing supported document insertion/conversion mechanisms.

Preserve active editor selections and unsaved content.

If the target note changed during preview, revalidate its current revision before committing.

Never overwrite newer note content with a stale snapshot.

If an append cannot be reconciled safely, block commit and offer a retry without losing the pending email import.

---

# 16. Batch importing

Support importing multiple emails from:

- Linux multi-file drag-and-drop.
- Linux file picker.
- Android multi-share intents.
- Android multi-file selection.

## 16.1 Batch preview

Display:

- Total selected files.
- Valid email count.
- Unsupported or invalid file count.
- Exact duplicates.
- Potential duplicates.
- Total estimated attachment size.

Let users remove individual items before import.

The default behavior is to create one new note per email.

Append mode must require explicit destination selection.

## 16.2 Batch execution

Process imports in a bounded sequential queue to avoid excessive memory usage.

Show progress:

**Importing emails — 4 of 12**

Keep the interface responsive.

Allow cancellation between imports.

A canceled batch must retain successfully completed imports, roll back the current incomplete import, and leave remaining items unprocessed.

Present a completion summary showing:

- Imported.
- Skipped.
- Duplicates.
- Failed.

Provide meaningful per-item errors without exposing sensitive message content in logs.

---

# 17. Search and organization

Imported emails must participate in the existing Quiet Paper search system.

Searchable content includes:

- Note title.
- Visible email metadata.
- Converted email body.
- Normal attachment filenames through existing supported indexing.

Use the existing fuzzy-search and indexing mechanisms.

Do not introduce a separate email-only search engine.

Do not change ranking for unrelated notes.

Existing tag filters must work with `#email`.

If attachments already support local OCR or extraction, preserve those capabilities without triggering expensive processing automatically.

In particular, do not violate Quiet Paper's manual-only OCR policy.

---

# 18. User experience and accessibility

Use existing application styling.

Required UI qualities:

- Quiet Paper's warm editorial visual language.
- Light and dark themes.
- Compact, readable metadata.
- Clear primary and secondary actions.
- Proper keyboard focus.
- Linux keyboard navigation.
- Android Back support.
- Screen-reader labels.
- Visible errors and progress.
- No unnecessary modal stacking.

## 18.1 Loading behavior

Use distinct states:

- Receiving.
- Parsing.
- Ready to review.
- Saving.
- Completed.
- Failed.

Disable duplicate Save actions while committing.

Make preview transitions stable.

Do not dismiss an error automatically before the user can read it.

## 18.2 Successful import

For one imported email:

- Show a brief success message.
- Open the newly created note or selected destination.
- Preserve normal navigation history.

For a batch:

- Show the import summary.
- Offer to view the imported notes.

Do not automatically archive or delete the original email in its mail provider.

---

# 19. Error handling

Implement explicit handling for:

- Invalid `.eml`.
- Empty email.
- Missing sender.
- Missing subject.
- Missing date.
- Invalid or unsupported character encoding.
- Corrupted MIME boundary.
- Corrupted base64.
- Invalid attachment filename.
- Oversized attachment.
- Oversized input.
- Permission denied.
- Android URI permission expiration.
- File removed before import.
- Attachment encryption failure.
- Insufficient disk space.
- Database failure.
- Locked encryption vault.
- Sync unavailable.
- Destination note deleted.
- Destination note changed concurrently.
- Duplicate incoming intent.
- User cancellation.
- Application termination during import.

Messages must be understandable to users.

Where possible, allow retry without forcing the user to reselect the source file, provided the source remains safely accessible.

Do not convert exceptions into silent success.

Do not expose raw stack traces in the production UI.

---

# 20. Required automated tests

Implement a comprehensive test suite covering domain, integration, widgets, and platform boundaries.

Tests must use deterministic fixture files and must not require access to real email accounts.

## 20.1 Parser tests

Include fixtures for:

1. Simple plaintext email.
2. HTML-only email.
3. Multipart alternative.
4. Multipart mixed with attachment.
5. Multipart related with CID image.
6. Nested multipart.
7. Encoded UTF-8 subject.
8. Non-Latin sender name.
9. Quoted-printable body.
10. Base64 body.
11. Unicode body.
12. Folded headers.
13. RFC 2231 attachment filename.
14. Missing Subject.
15. Missing From.
16. Invalid Date.
17. Empty body.
18. Malformed boundary.
19. Malformed base64.
20. Nested attached email.
21. CRLF and LF variations.
22. Unsupported encoding.
23. Oversized body.
24. Excessive MIME nesting.
25. Duplicate headers.

## 20.2 Security tests

Include malicious email fixtures containing:

- JavaScript HTML.
- External tracking pixels.
- Iframe elements.
- Unsafe link schemes.
- Relative attachment paths.
- Filename traversal attempts.
- Malicious CID references.
- Extremely large encoded fields.
- Excessive nested multiparts.
- HTML designed to trigger network fetching.
- Malformed content intended to exhaust memory.

Verify safe rejection or sanitization.

No remote fetch may occur during parsing or preview.

## 20.3 Conversion tests

Verify:

- HTML headings become Markdown headings.
- Lists preserve structure.
- Blockquotes survive.
- Links are sanitized.
- Tables remain readable.
- Inline images use valid local asset references.
- Email content survives editor-mode round trips.
- Original bytes remain unchanged.

## 20.4 Persistence tests

Verify:

- New note creation.
- Original `.eml` attachment preservation.
- Binary attachment preservation.
- Text-only import.
- Archive-only mode.
- Append to existing Markdown note.
- Append to existing rich-AST note.
- Tag creation and reuse.
- Import provenance persistence.
- Exact duplicate detection.
- Related-message detection.
- Restart persistence.
- Migration from older schemas.
- Backup/restore compatibility.
- Asset rollback after failure.
- No orphaned assets after cancellation.
- Import without network access.
- Correct indexing after synchronization.

## 20.5 Android integration tests

Verify:

- Cold-start `ACTION_SEND`.
- Warm-start `ACTION_SEND`.
- `ACTION_VIEW`.
- `ACTION_SEND_MULTIPLE`.
- `content://` URI handling.
- Missing display name.
- Generic MIME type.
- Valid `.eml` with incorrect extension.
- Invalid email with `.eml` extension.
- Initial-intent and stream deduplication.
- Existing text Quick Capture preservation.
- Existing URL web clipping preservation.
- Existing PDF import preservation.
- System Back during preview.
- App lock before displaying email content.

## 20.6 Linux integration tests

Verify:

- Single `.eml` drop.
- Multiple `.eml` drop.
- Drop onto notes list.
- Drop onto editor.
- File-picker import.
- Mixed file drops.
- Invalid file drop.
- Existing image drop remains operational.
- Existing document drop remains operational.
- Cancellation.
- File removed during import.
- Flatpak sandboxed file access where testable.

## 20.7 Widget tests

Cover:

- Preview metadata.
- Title editing.
- Mode selection.
- Destination note selection.
- Tag selection.
- Duplicate warning.
- Error state.
- Progress state.
- Disabled Save during commit.
- Successful import navigation.
- Cancellation behavior.
- Dark theme.
- Narrow Android screen layout.
- Linux keyboard interactions.

Use dependency-injected fakes for storage and platform boundaries.

Do not rely exclusively on parser unit tests.

---

# 21. Performance requirements

The feature must remain responsive during typical email import operations.

Targets:

- A small email should preview without noticeable UI blocking.
- Large parsing operations must not freeze the main Flutter isolate.
- Batch import must remain bounded in memory.
- Progress updates must not cause excessive rebuilds.
- Email import must not trigger full-library synchronous indexing.
- Reopening an imported note should perform like reopening an ordinary note with comparable content.

Test with:

- 10 KB plaintext email.
- 1 MB HTML email.
- 10 MB multipart email.
- 40 MB email containing attachments.
- Batch of 50 small emails.

Collect meaningful elapsed-time and memory observations where the environment supports profiling.

Do not invent benchmark results.

---

# 22. Implementation sequence

Execute the work in the following order.

### Phase 1 — Repository audit

Inspect the existing architecture and relevant implementation points.

Identify the specific existing services and models that will be extended.

Check test infrastructure, dependency constraints, and platform support.

### Phase 2 — Core parser and models

Implement:

- Email input normalization.
- MIME parser.
- Metadata extraction.
- Attachment extraction.
- HTML sanitization.
- Markdown conversion.
- Provenance and content fingerprints.
- Parser and security tests.

### Phase 3 — Storage and synchronization

Implement:

- Encrypted `.eml` preservation.
- Encrypted attachment ingestion.
- Import source metadata.
- Drift migration.
- Note serialization.
- Note-source index.
- Backup/restore compatibility.
- Sync merge compatibility.
- Transactional failure recovery.

### Phase 4 — Import workflow UI

Implement:

- Preview.
- Import mode picker.
- Destination picker.
- Editable title.
- Tags.
- Attachment overview.
- Duplicate warnings.
- Saving and error states.

### Phase 5 — Linux integration

Implement:

- Drop recognition.
- Application-level drop handling.
- Editor drop handling.
- File picker.
- Command palette action.
- Batch handling.
- Flatpak compatibility.

### Phase 6 — Android integration

Implement:

- Required intent filters.
- Content URI reading.
- Share routing.
- Open With routing.
- Multi-share.
- Text-only Save as Email action.
- Cold/warm start handling.
- Lifecycle and duplicate-intent safeguards.

### Phase 7 — Regression tests

Run all new and existing tests.

Fix failures rather than suppressing them.

Verify editor, storage, search, sync, Quick Capture, attachments, and existing file import.

### Phase 8 — Documentation

Update relevant handoff documentation and add an implementation log entry.

Provide an accurate verification summary.

**Do not stop after a phase and ask the user to authorize the next phase. Complete all phases in this implementation task.**

---

# 23. Explicit non-goals

Do not implement:

- Proton Mail API authentication.
- Gmail API authentication.
- Outlook OAuth.
- IMAP mailbox synchronization.
- SMTP access.
- Proton Mail Bridge integration.
- A forwarding-to-Quiet-Paper email address.
- Background mailbox monitoring.
- Automatic email deletion or archiving in a provider.
- AI summaries.
- Cloud-based HTML conversion.
- Remote image fetching.
- HTML email execution.
- Automatic contact extraction.
- Outlook PST/MBOX import.
- A separate email inbox inside Quiet Paper.

This feature is a selective email-to-note importer, not an email client.

---

# 24. Validation commands

At minimum, run the repository's actual supported equivalents of:

- `dart format`
- `flutter analyze`
- `flutter test`
- `dart run build_runner build --delete-conflicting-outputs`, if code generation changes
- Backend TypeScript type checking and tests, if sync/backend code changes
- Android debug compilation
- Linux debug or release compilation

Perform `git diff --check`.

Use the Flutter SDK version required by this repository.

Do not upgrade Flutter or packages unrelated to the feature.

If native device testing is unavailable, implement automated coverage and explicitly identify the remaining manual verification requirements.

Do not claim a platform behavior was validated on real hardware if only automated tests or static inspection were performed.

---

# 25. Acceptance criteria

The implementation is complete only when all of the following conditions are met.

- [ ] Linux users can drag an exported Proton Mail `.eml` file into Quiet Paper.
- [ ] The email preview opens before a note is created.
- [ ] The user can create an editable note and preserve the original `.eml`.
- [ ] The email body is converted into readable Markdown.
- [ ] Sender, recipients, subject, and original date are preserved when available.
- [ ] MIME attachments are imported into encrypted storage.
- [ ] CID inline images resolve correctly.
- [ ] Import works fully offline.
- [ ] Android accepts supported `.eml` files through its share sheet.
- [ ] Android Open With works for supported email files.
- [ ] Android shared-text flows offer Save as Email without breaking Quick Capture.
- [ ] Existing PDF, Markdown, text, image, and web-clipping workflows still work.
- [ ] Multiple emails can be imported in a batch.
- [ ] Duplicate detection works reliably.
- [ ] Users can append an email to an existing note.
- [ ] Existing note content cannot be overwritten by stale import state.
- [ ] Imports survive application restart.
- [ ] Imported notes and attachments follow the existing encrypted sync model.
- [ ] Existing backup and restore behavior remains correct.
- [ ] Imported notes work across all three editor modes.
- [ ] Imported content is searchable.
- [ ] Failed imports do not leave broken note references.
- [ ] Cancellation causes no unintended note mutations.
- [ ] No sensitive content is logged or transmitted in plaintext.
- [ ] Linux packaging remains functional.
- [ ] Android builds remain functional.
- [ ] Static analysis and automated tests pass.
- [ ] Documentation is updated.
- [ ] No incomplete buttons, placeholder services, or temporary debugging code remain.

---

# 26. Final engineering report

After implementation, provide a concise but complete engineering report containing:

### A. Implemented functionality

Describe what works on Linux and Android.

Include any platform-specific limitations that remain outside the application's control.

### B. Architecture

Explain the core parser, converter, coordinator, storage integration, provenance model, and platform entry points.

### C. Files changed

List major new files and modified files with their responsibilities.

### D. Database and sync

Document schema migrations, encrypted metadata handling, and compatibility behavior.

### E. Testing

Report the actual commands executed, results, test counts, and failures.

Distinguish automated verification from manual hardware verification.

### F. Security

Summarize input validation, HTML sanitization, attachment encryption, temporary-file handling, and privacy protections.

### G. Remaining risks

Identify unresolved issues honestly.

Do not label untested device behavior as production-verified.

### H. Documentation

Append a detailed entry to `handoff/latest-logs.md`, following the existing numbering and format.

Update relevant domain guides.

Follow `AGENTS.md` for repository-specific completion and commit procedures. Do not overwrite unrelated work or bypass failing tests.

---

# 27. Final instruction

Build this as a cohesive first-class Quiet Paper feature, not as a loose collection of import utilities.

The final experience should feel native to the application:

**Export an email → Drag it into Quiet Paper or share it from Android → Preview → Save → Continue writing.**

Prioritize correctness, preservation of original email data, privacy, error recovery, and compatibility with existing editor and storage architecture.

All requirements in this specification are part of the implementation scope.

Do not reduce scope without a concrete technical blocker. If an external app or operating system cannot provide particular source data, preserve the supported workflow and document that limitation accurately.

Proceed with implementation.

