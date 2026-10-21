# MASTER IMPLEMENTATION PROMPT
## Production-Ready Per-Note Export & Portable Note Package System

You are working inside an existing production-oriented Flutter note-taking application called **Quiet Paper**, inspired by Bear.

Implement a complete, extensible, production-ready **individual note export system**.

This is not a prototype and not a UI-only feature. The implementation must integrate correctly with the application's existing architecture, canonical Markdown storage, attachments, Cloudinary storage, OCR subsystem, note links/URIs, tags, password-protected notes, trash/deletion lifecycle, synchronization, and existing rendering infrastructure.

Do not invent parallel data models unnecessarily. Reuse existing abstractions wherever they are appropriate.

---

# 1. PRIMARY OBJECTIVE

Add a first-class export subsystem for an individual note supporting:

1. Markdown export (`.md`)
2. PDF export (`.pdf`)
3. HTML export (`.html`)
4. Plain text export (`.txt`)
5. DOCX export (`.docx`) where technically feasible using maintained Flutter-compatible tooling
6. Full-fidelity Quiet Paper Note Package export (`.qpnote`)
7. Share/export through the native mobile share sheet
8. Save/export to a user-selected destination where supported by the platform
9. Configurable metadata, attachment, OCR, and note-link handling
10. Secure handling of password-protected notes
11. Correct handling of trashed notes
12. Deterministic filenames and sanitized filesystem-safe names
13. Importability of `.qpnote` as a future-proof portable format
14. Versioned package format
15. Strong validation, failure recovery, and test coverage

The canonical note body is **Markdown**. There is currently no canonical JSON/Rich-text document representation. Do not introduce JSON as a second source of truth merely for rendering/export.

The architecture must remain:

```text
Canonical Markdown
        |
        +---- Markdown Export
        |
        +---- Plain Text Export
        |
        +---- HTML Rendering
        |          |
        |          +---- PDF Rendering
        |          |
        |          +---- DOCX conversion/generation
        |
        +---- Full Fidelity .qpnote Package
```

The Markdown remains authoritative.

---

# 2. MANDATORY FIRST STEP: ANALYZE THE EXISTING CODEBASE

Before changing code:

1. Inspect the entire repository structure relevant to:
   - note model
   - note repository
   - database
   - Markdown parsing/rendering
   - attachments
   - Cloudinary integration
   - documents/PDFs
   - OCR
   - note links / URI scheme
   - password-protected notes
   - trash
   - sync
   - backup
   - sharing
   - file system access
   - dependency management
   - Android platform code
   - iOS platform code

2. Identify:
   - canonical note entity/model
   - canonical Markdown field
   - note title source
   - tag representation
   - note UUID/ID
   - created/updated timestamps
   - attachment metadata model
   - attachment download mechanism
   - Cloudinary public/private identifiers
   - document/PDF representation
   - OCR persistence model
   - note link representation
   - password-protection implementation
   - trash representation
   - repository/service layer boundaries
   - existing rendering components
   - existing PDF/share/file-save dependencies

3. Search for all code paths that create, update, delete, trash, restore, sync, or permanently delete notes.

4. Determine whether any export-related functionality already exists and extend it rather than duplicating it.

5. Determine the project's current Flutter/Dart version and package compatibility requirements.

6. Identify all architectural constraints imposed by the existing codebase.

Do not modify code during this analysis phase.

Produce an implementation plan internally before coding. Do not ask the developer questions unless the repository contains a genuinely impossible ambiguity. Make reasonable production-safe decisions from the actual code.

---

# 3. ARCHITECTURAL REQUIREMENTS

Create a dedicated export subsystem with clear separation of concerns.

Recommended conceptual architecture:

```text
ExportService
   |
   +-- ExportRequest
   +-- ExportResult
   +-- ExportOptions
   +-- NoteExportData
   |
   +-- MarkdownExporter
   +-- PlainTextExporter
   +-- HtmlExporter
   +-- PdfExporter
   +-- DocxExporter
   +-- QpNotePackageExporter
   |
   +-- AttachmentResolver
   +-- OcrExportResolver
   +-- NoteLinkResolver
   +-- MetadataExporter
   +-- FilenameGenerator
   +-- ExportSecurityGuard
   +-- PackageValidator
   |
   +-- ShareService
   +-- FileSaveService
```

Do not blindly create exactly these classes if the repository has a better architecture. Preserve the intent:

- orchestration must be separate from format generation
- file acquisition must be separate from serialization
- security validation must happen before data leaves the application
- rendering must not access database objects directly
- exporters should operate on immutable export DTOs/snapshots wherever practical

The export subsystem must not directly manipulate widgets.

---

# 4. EXPORT REQUEST MODEL

Introduce a strongly typed export request/configuration model.

The request must support:

```text
noteId
format
includeMetadata
includeAttachments
attachmentStrategy
includeOcr
ocrStrategy
noteLinkStrategy
includeInternalIds
pdfOptions
htmlOptions
docxOptions
packageOptions
shareAfterExport
```

Use enums rather than free-form strings.

Suggested format enum:

```text
markdown
pdf
html
plainText
docx
qpnote
```

Suggested attachment strategy:

```text
none
embedLocally
preserveRemoteUrls
```

Default strategy must be:

```text
embedLocally
```

when producing a portable export.

Suggested OCR strategy:

```text
none
separateFiles
appendToDocument
```

Default behavior:

- Markdown: do not append OCR by default
- PDF/HTML/DOCX: do not append OCR by default
- QPNOTE: export OCR as structured/separate files when available

Suggested note-link strategy:

```text
preserveQuietPaperUri
preserveAsLinks
rewriteToRelativeFiles
plainTextRepresentation
```

For a single-note export:

- default Markdown behavior: preserve a valid Quiet Paper URI if that is the current app's canonical link mechanism
- full-fidelity package: preserve internal note identity and URI information
- never silently fabricate links to files for notes that were not exported

---

# 5. IMMUTABLE EXPORT SNAPSHOT

Do not perform a long-running export while repeatedly querying mutable UI state.

At export start, create an immutable snapshot containing everything needed.

Conceptually:

```text
NoteExportData
  noteId
  title
  markdown
  createdAt
  updatedAt
  tags
  archived
  trashed
  trashedAt
  passwordProtected
  location
  mood
  sleepData
  attachments
  linkedNotes
  documents
  ocrData
```

Only include fields that actually exist in the current product.

The snapshot must represent one consistent logical version of the note.

Do not allow an export to accidentally combine:

- current title
- old Markdown
- newer attachments
- older metadata

The snapshot should be created using repository/database mechanisms that provide consistent reads.

---

# 6. MARKDOWN EXPORT

Markdown export must preserve the canonical Markdown as faithfully as possible.

Do not unnecessarily re-render and regenerate Markdown.

If the canonical note body is already Markdown, export it directly after applying any required portable-reference transformation.

Filename:

```text
<sanitized note title>.md
```

If the title is empty:

```text
Untitled.md
```

UTF-8 encoding is mandatory.

Preserve:

- headings
- lists
- checkboxes
- tables
- blockquotes
- inline formatting
- code blocks
- fenced code languages
- links
- emphasis
- escaped Markdown
- horizontal rules
- line breaks

Do not strip Markdown syntax.

---

# 7. MARKDOWN + ATTACHMENTS

For portable Markdown export with attachments enabled:

Given:

```markdown
![diagram](quietpaper://attachment/123)
```

or whatever the application's actual attachment URI scheme is, download the referenced attachment and rewrite the Markdown to:

```markdown
![diagram](attachments/diagram.png)
```

Use stable relative references.

Do not expose Cloudinary implementation URLs by default.

Attachment filenames must be:

- filesystem safe
- deterministic
- collision resistant

Handle duplicate names.

Do not allow path traversal.

Never generate:

```text
../../something
```

or equivalent.

Only place files inside the export root.

---

# 8. PLAIN TEXT EXPORT

Create a readable plain-text representation from canonical Markdown.

Do not simply return raw Markdown.

Strip presentation syntax while preserving semantic content.

Examples:

```markdown
# Heading
```

becomes:

```text
Heading
```

And:

```markdown
- [x] Task
```

becomes something readable such as:

```text
☑ Task
```

Code blocks must remain readable and retain their contents.

Links should retain their visible text and, where useful, URL.

Images should be represented meaningfully, for example:

```text
[Image: filename.png]
```

Do not silently lose image references.

---

# 9. HTML EXPORT

Generate standalone valid HTML.

The output must:

- declare UTF-8
- include viewport metadata where appropriate
- have a valid `<html>` structure
- include a `<head>`
- include a `<body>`
- render Markdown semantically
- support syntax-highlighted code blocks
- render images
- render task lists
- render tables
- render links
- render blockquotes
- preserve safe URLs
- escape user-provided text correctly
- prevent HTML injection from note contents

The document title should use the note title.

When attachments are included, use local relative references where practical.

Do not depend on the application's runtime to display the exported HTML.

The generated HTML must be independently viewable.

---

# 10. SYNTAX HIGHLIGHTING

The canonical source remains Markdown.

Fenced code blocks such as:

````markdown
```dart
final note = await repository.getNote(id);
```
````

must remain exactly that in Markdown exports.

For HTML, PDF, and DOCX rendering:

- detect the fenced language
- apply syntax highlighting using an appropriate maintained library
- gracefully fall back to plain monospaced rendering for unknown languages
- never modify the canonical Markdown

Do not hard-code a tiny language whitelist unless required by the chosen renderer.

Support the languages already used by the app's Markdown/code renderer.

---

# 11. PDF EXPORT

Create a real text-based PDF, not a screenshot/rasterized representation of the note.

PDF output must support:

- title
- headings
- paragraphs
- lists
- task lists
- blockquotes
- inline formatting
- tables where supported
- code blocks
- syntax highlighting where technically supported
- images
- links where supported
- page wrapping
- page breaks
- headers/footers where configured
- metadata where configured

Text must remain selectable/searchable.

Do not capture the note widget as an image and place that image into the PDF.

Use an appropriate Flutter/Dart PDF generation library already compatible with the application. Prefer existing dependencies if present.

Support image and attachment sizing so large images do not cause layout overflows.

Implement robust pagination.

Long code blocks must not crash rendering or overflow pages.

---

# 12. PDF OPTIONS

Support at least:

```text
includeMetadata
showTags
showDates
showBacklinks
includeAttachments
```

Do not display sensitive metadata by default unless it is already part of the normal exported document semantics.

Suggested default:

```text
showTags = true
showDates = true
showBacklinks = false
```

Adapt defaults where existing product conventions dictate otherwise.

---

# 13. DOCX EXPORT

Implement DOCX export using a maintained, compatible approach.

Do not build a fake DOCX file manually unless the implementation correctly produces an Office Open XML package.

The resulting `.docx` must open in:

- Microsoft Word
- LibreOffice
- compatible document viewers

Support, at minimum:

- title
- headings
- paragraphs
- lists
- task lists
- code blocks
- links
- images
- basic emphasis
- blockquotes

Gracefully degrade unsupported Markdown constructs.

Do not allow DOCX complexity to contaminate the canonical Markdown architecture.

If current dependency constraints make high-quality DOCX generation impossible, implement the exporter behind an isolated interface and provide a correct user-facing fallback rather than shipping a broken or corrupt DOCX format.

---

# 14. FULL-FIDELITY .QPNOTE PACKAGE

Implement a versioned portable package format.

File extension:

```text
.qpnote
```

Internally, this may be a ZIP container.

Recommended structure:

```text
<note-title>.qpnote
|
+-- manifest.json
+-- note.md
+-- metadata.json
|
+-- attachments/
|   +-- image-001.webp
|   +-- image-002.jpg
|   +-- document-001.pdf
|
+-- ocr/
    +-- document-001/
        +-- page-001.txt
        +-- page-002.txt
```

Do not require this exact physical structure if a better design is needed, but the same concepts must exist.

---

# 15. QPNOTE MANIFEST

Create a versioned manifest.

Example conceptual structure:

```json
{
  "format": "quiet-paper-note",
  "version": 1,
  "noteId": "...",
  "createdAt": "...",
  "updatedAt": "...",
  "content": {
    "markdown": "note.md"
  },
  "metadata": "metadata.json",
  "attachments": [],
  "ocr": []
}
```

The exact schema must be implemented as real strongly typed Dart serialization code where appropriate.

Requirements:

- explicit format identifier
- explicit version
- deterministic semantics
- no silent breaking changes
- future-version rejection must be graceful
- unknown fields should be tolerated where possible
- schema versioning must be independent from the app version

Never depend on the internal SQLite schema for package compatibility.

---

# 16. QPNOTE METADATA

Preserve all useful non-sensitive note metadata supported by the application.

Potential fields include:

```text
noteId
title
createdAt
updatedAt
tags
archived
trashed
trashedAt
favorite/pinned
location
mood
sleep
```

Include other current first-class note fields discovered in the repository.

Do not export:

- authentication credentials
- sync tokens
- Cloudinary secrets
- encryption keys
- session tokens
- database internals
- private server credentials

Never embed provider secrets.

---

# 17. QPNOTE ATTACHMENTS

Attachments must be embedded in the package when enabled.

For every attachment preserve sufficient metadata to reconstruct it:

```text
attachmentId
originalFilename
mimeType
relativePath
size
createdAt
contentHash where practical
attachment type
```

Do not rely exclusively on remote URLs.

The package must remain useful after:

- the Cloudinary asset is deleted
- the user logs out
- the user changes accounts
- the app is uninstalled
- the original remote host disappears

This is the central purpose of the portable package.

---

# 18. CLOUDINARY INTEGRATION

Never leak Cloudinary credentials.

When an attachment needs exporting:

1. Resolve the attachment from the application's existing attachment abstraction.
2. Retrieve the content using the currently supported secure mechanism.
3. Validate the downloaded file.
4. Store it in the temporary export workspace.
5. Include it in the final output.
6. Clean up temporary files.

Do not permanently create local attachment copies merely as a side effect of exporting unless the application already requires such caching.

Do not modify the original cloud object.

---

# 19. OCR EXPORT

The application contains OCR data associated with scanned documents/attachments.

For QPNOTE export:

- preserve OCR where available and permitted
- store OCR separately from canonical Markdown
- preserve page boundaries where possible
- preserve document association
- preserve OCR language metadata if available

Recommended structure:

```text
ocr/
  document-001/
    manifest.json
    page-001.txt
    page-002.txt
```

Do not force OCR into `note.md`.

For PDF/HTML/DOCX exports, OCR must only appear when explicitly configured, or where the existing application's semantics already indicate that document OCR belongs in rendered document content.

If OCR payloads are encrypted at rest, decrypt only transiently during export.

Never write plaintext OCR into unrelated persistent unencrypted caches.

---

# 20. PASSWORD-PROTECTED NOTES

Password-protected notes require explicit security handling.

Before exporting a protected note:

1. Verify the protection state using the application's existing security mechanism.
2. Require successful authentication/unlock if required by the current security model.
3. Inform the user that export creates an external copy.

Do not bypass protection merely because the note is available in a repository object.

The export must never silently weaken the application's access control.

For QPNOTE, support a future-compatible option for encrypted package export.

If encrypted QPNOTE export is implemented now, use a standard authenticated encryption construction and a well-maintained library. Never invent cryptography.

Never store the package password in preferences/logs/database.

---

# 21. TRASHED NOTES

Trashed notes remain valid export sources.

A trashed note must still be exportable.

Preserve trash metadata in QPNOTE:

```text
trashed = true
trashedAt = ...
```

Do not automatically restore a note as part of exporting.

Do not change sync state.

Do not change deletion state.

Do not permanently delete anything during export.

---

# 22. NOTE LINKS

Respect the application's existing note-link syntax and canonical URI format.

For Markdown export:

- preserve canonical note links unless a safe transformation is requested

For QPNOTE:

- preserve note ID and original link information
- do not invent files for notes that were not exported

For a future multi-note package implementation, the format should be capable of rewriting links to relative exported files.

Design the code so single-note export does not block future multi-note export.

---

# 23. METADATA EXPORT RULES

Allow the user to select metadata inclusion.

Suggested metadata categories:

```text
Basic:
- title
- created
- modified
- tags

Extended:
- archive state
- trash state
- favorite/pinned
- location
- mood
- sleep
```

Sensitive information must not unexpectedly leak into plain-text/PDF exports.

Use explicit options for less-obvious metadata.

---

# 24. FILENAME GENERATION

Create a centralized `FilenameGenerator`.

Rules:

1. derive from note title
2. normalize Unicode safely
3. remove filesystem-invalid characters
4. prevent reserved filenames
5. prevent path separators
6. trim excessive whitespace
7. apply safe maximum length
8. provide fallback `Untitled`
9. append correct extension
10. handle collisions

Example:

```text
Meeting: Q3/Planning?
```

becomes something such as:

```text
Meeting - Q3-Planning.pdf
```

Do not hard-code OS-specific path logic into exporters.

---

# 25. TEMPORARY EXPORT WORKSPACE

Use a secure temporary workspace.

Flow:

```text
Create temp directory
        |
Collect export snapshot
        |
Resolve attachment content
        |
Resolve OCR content
        |
Generate files
        |
Validate output
        |
Package if necessary
        |
Return export result
        |
Share/save
        |
Cleanup temp directory
```

Cleanup must execute on:

- success
- failure
- cancellation
- exceptions

Do not leave sensitive temporary plaintext data indefinitely.

Where feasible, use the application's secure storage/file APIs.

---

# 26. EXPORT RESULT

Create a typed export result.

Conceptually:

```text
ExportResult
  file
  format
  filename
  size
  mimeType
  duration
  warnings
```

Do not make callers infer success from nullable strings.

Support structured warnings such as:

```text
attachmentUnavailable
unsupportedMarkdownFeature
ocrUnavailable
syntaxHighlightingFallback
metadataOmitted
```

Successful export should still be able to return non-fatal warnings.

---

# 27. ERROR HANDLING

Every exporter must fail gracefully.

Examples:

- note not found
- note deleted permanently while export starts
- attachment unavailable
- Cloudinary download failure
- OCR decryption failure
- insufficient disk space
- malformed Markdown
- invalid image
- unsupported MIME type
- PDF layout failure
- invalid package path
- unsupported package version

Never crash the UI isolate because an export failed.

Never expose stack traces to end users.

Log useful diagnostic information using the application's existing logging framework.

Never log:

- note body
- passwords
- decrypted OCR
- sensitive attachment content
- secrets
- tokens

---

# 28. ISOLATE / PERFORMANCE REQUIREMENTS

Exporting must not freeze the Flutter UI.

Heavy work such as:

- PDF generation
- HTML generation
- package compression
- hashing
- large attachment processing
- document serialization

should run off the main UI isolate where practical.

Follow existing app conventions for background isolates.

Do not casually spawn a new isolate for every tiny operation.

Large exports must be designed with memory constraints in mind.

Avoid reading all large files into memory simultaneously.

Prefer streaming file operations where supported.

---

# 29. CANCELLATION

The export API should be designed to support cancellation.

At minimum, the implementation should have clear cancellation boundaries between:

- snapshot
- downloads
- rendering
- packaging
- finalization

If true cancellation cannot be supported by a chosen third-party library, cancellation must still stop subsequent work and clean up temporary resources.

---

# 30. SHARE SHEET

Integrate native sharing.

Recommended user flow:

```text
Note
  |
  +-- More
       |
       +-- Export
       |
       +-- Share
```

`Share` should generate the selected/default export and invoke the platform-native share sheet.

Do not force the user to manually browse to a temporary directory.

Use the project's currently supported sharing package, or add a maintained Flutter package only if necessary.

---

# 31. SAVE EXPORT

Provide a save/export destination flow where the target platform supports it.

Use platform-appropriate APIs.

Do not assume Android, iOS, Windows, macOS, or Linux have identical filesystem semantics.

The core exporter must remain platform-neutral as much as practical.

---

# 32. USER EXPERIENCE

From an individual note, add:

```text
⋮
Export
```

Export sheet:

```text
Export Note

Markdown
PDF
HTML
Plain Text
DOCX
Quiet Paper Package

------------------------

Advanced Export
```

A quick export should require minimal interaction.

Advanced export should expose:

```text
Include metadata
Include attachments
Include OCR
Link handling
```

Format-specific options should only appear when relevant.

Do not overwhelm the normal user.

---

# 33. DEFAULTS

Use sensible defaults.

Recommended:

### Markdown

```text
includeMetadata = false
includeAttachments = true
attachmentStrategy = embedLocally
includeOcr = false
noteLinkStrategy = preserveQuietPaperUri
```

### PDF

```text
includeMetadata = true
showTags = true
showDates = true
showBacklinks = false
includeAttachments = true
includeOcr = false
```

### HTML

```text
includeMetadata = true
includeAttachments = true
includeOcr = false
```

### Plain text

```text
includeMetadata = false
includeAttachments = false
includeOcr = false
```

### DOCX

```text
includeMetadata = true
includeAttachments = true
includeOcr = false
```

### QPNOTE

```text
includeMetadata = true
includeAttachments = true
includeOcr = true
preserveIds = true
preserveTrashState = true
```

Adjust only where the existing application semantics make a different default clearly necessary.

---

# 34. REMEMBER LAST EXPORT PREFERENCES

Persist lightweight export preferences where useful:

```text
lastExportFormat
includeAttachments
includeMetadata
includeOcr
```

Do not store note content.

Do not store attachment data.

Do not store passwords.

Use the application's existing preferences abstraction.

These preferences should be user-level preferences, not part of note synchronization.

---

# 35. SECURITY / PRIVACY

Apply defense-in-depth.

Required:

- sanitize filenames
- prevent zip-slip/path traversal
- validate archive entries
- validate MIME/file type where practical
- never expose Cloudinary secrets
- never expose auth tokens
- never log note contents
- never log OCR contents
- do not accidentally persist decrypted protected content
- clean temporary files
- verify protected-note access
- avoid HTML injection/XSS in exported HTML
- escape metadata properly
- avoid unsafe external URL generation
- never deserialize untrusted package data into executable code

QPNOTE import must be considered untrusted input.

---

# 36. QPNOTE VALIDATION AND FUTURE IMPORT

Even if import is not implemented in this phase, design the package validator now.

Create a package validation layer capable of checking:

- correct extension
- valid ZIP/container
- manifest presence
- supported format identifier
- supported version
- valid JSON
- required fields
- path safety
- file references
- attachment existence
- OCR references
- metadata schema

Future import should be able to trust the validator rather than reimplement all safety checks.

Reject:

```text
../
../../
absolute paths
drive-rooted paths
symlink attacks where relevant
```

Do not extract untrusted archives directly into arbitrary user-controlled paths.

---

# 37. DETERMINISTIC PACKAGE BEHAVIOR

When exporting the same logical note version twice, the contents should be as deterministic as practical.

Avoid embedding:

- random temporary identifiers
- local absolute paths
- machine-specific paths
- current clock times unless semantically required

Where package timestamps are required, distinguish note timestamps from filesystem timestamps.

This makes testing and future integrity verification easier.

---

# 38. HASHES / INTEGRITY

For QPNOTE, include content hashes where practical.

At minimum consider SHA-256 for:

- note.md
- metadata.json
- attachments
- OCR files

This allows future import validation.

Do not use hashes as encryption.

Do not expose security-sensitive internal hashes unnecessarily.

---

# 39. CONTENT SAFETY / HTML SAFETY

HTML generation must correctly escape:

- title
- tags
- note text
- metadata
- code
- alt text
- filenames

Do not concatenate raw user content into HTML templates unsafely.

If Markdown rendering permits raw HTML, explicitly decide whether raw HTML should:

1. be preserved
2. be sanitized
3. be stripped

Base the decision on the current application's Markdown semantics.

For exported standalone HTML, favor safe behavior.

Do not introduce an XSS vulnerability.

---

# 40. DATABASE / SYNC INTEGRATION

Export must be read-only.

It must not:

- create sync records
- mark note as modified
- update `updatedAt`
- mark attachment dirty
- alter trash state
- alter Cloudinary state
- change OCR state
- alter conflict state

Do not route export operations through mutation APIs.

Exporting a note must not affect synchronization.

---

# 41. SEARCH INTEGRATION

Export must not alter the search index.

Do not create special search records.

Do not mutate FTS5 tables.

Do not persist exported OCR into the existing search index merely because the export subsystem decrypted it.

---

# 42. UI STATE / REACTIVE ARCHITECTURE

Integrate with the application's current state management system.

Do not build a new state-management architecture solely for export.

The UI should expose:

- export progress
- current phase
- success
- non-fatal warnings
- failure
- cancellation

Progress should never require exact percentages if the underlying operation cannot estimate them accurately.

Prefer meaningful stages:

```text
Preparing note…
Downloading attachments…
Rendering document…
Creating PDF…
Finalizing export…
```

---

# 43. ACCESSIBILITY

Export UI must support:

- screen readers
- keyboard navigation where relevant
- logical focus order
- descriptive buttons
- sufficient touch target size
- clear error states
- no color-only status indication

Use platform-standard dialogs/sheets.

---

# 44. PLATFORM SUPPORT

Inspect the current project's supported platforms.

Do not break unsupported platforms accidentally.

Where a capability is platform-specific:

- provide the appropriate implementation
- provide a graceful unsupported-platform response
- do not crash

Examples:

- native file picker
- share sheet
- document directory
- platform temporary directories

---

# 45. DEPENDENCY POLICY

Before adding dependencies:

1. Check whether the repository already contains an equivalent dependency.
2. Check compatibility with the current Flutter/Dart version.
3. Prefer actively maintained packages.
4. Prefer minimal dependency count.
5. Avoid abandoned libraries.
6. Avoid packages that require unsafe native modifications unless necessary.

Do not blindly upgrade unrelated packages.

Do not create unrelated dependency churn.

After adding dependencies, regenerate lockfiles as appropriate.

---

# 46. TESTING REQUIREMENTS

Write comprehensive tests.

At minimum:

## Unit tests

Test:

- filename sanitization
- Markdown export
- plain text conversion
- metadata serialization
- HTML escaping
- attachment path rewriting
- URI handling
- OCR path generation
- QPNOTE manifest creation
- content hashes
- path traversal prevention
- ZIP entry validation
- package version validation
- trash metadata preservation
- password-protected-note guard behavior

## Golden/snapshot-style tests

Where practical, test stable output for:

- HTML
- PDF layout/content
- plain text
- Markdown transformations
- QPNOTE manifest

Do not make tests depend on machine-specific absolute paths.

## Integration tests

Test:

1. normal note export
2. note with images
3. note with document/PDF attachment
4. note with OCR
5. note with tags
6. note with internal links
7. password-protected note
8. trashed note
9. empty-title note
10. malformed/edge-case Markdown
11. large attachment
12. attachment unavailable
13. failed Cloudinary download
14. failed export cleanup
15. share flow where testable

---

# 47. SECURITY TESTS

Explicitly test malicious inputs:

```text
../../../secret.txt
..\..\secret.txt
/absolute/path
C:\absolute\path
```

and malicious archive names.

Test HTML content such as:

```html
<script>alert(1)</script>
```

and ensure exported HTML cannot unintentionally execute unsafe raw content under the chosen security model.

Test protected notes without proper authentication.

Test malformed QPNOTE packages.

Test unsupported QPNOTE versions.

---

# 48. LARGE FILE TESTING

Test notes containing:

- thousands of lines
- long code blocks
- many images
- large documents
- many tags
- many attachments
- OCR across many pages

Verify:

- UI remains responsive
- memory use is reasonable
- output is valid
- temp files are removed
- errors are recoverable

---

# 49. FAILURE RECOVERY

Every export operation must have a cleanup boundary.

Pseudo-flow:

```text
try:
    prepare temp workspace
    snapshot note
    resolve resources
    render/export
    validate
    finalize
    return result
catch:
    record safe diagnostic information
    cleanup
    surface user-safe error
finally:
    cleanup any remaining resources
```

Cleanup must be idempotent.

If cleanup itself fails, do not hide the original export failure.

---

# 50. LOGGING

Use existing application logging.

Log:

- export start
- format
- phase transitions
- duration
- warning categories
- failure category

Do not log:

- full Markdown
- note title if considered sensitive under app policy
- note body
- OCR
- passwords
- access tokens
- Cloudinary credentials
- attachment contents

Use IDs only where already considered safe by the application's logging policy.

---

# 51. ANALYTICS

Do not introduce analytics just for this feature unless analytics already exists and the repository's product conventions require it.

Never send:

- note content
- titles
- tags
- OCR
- attachment names

If export telemetry already exists, use only coarse event data such as:

```text
export_started
export_completed
export_failed
format
duration
```

---

# 52. IMPLEMENTATION ORDER

Implement in this order:

### Phase A — Architecture

1. inspect codebase
2. identify reusable infrastructure
3. define export domain models
4. define export service interfaces
5. define attachment/resource resolution
6. define security guard
7. define filename handling

### Phase B — Core formats

8. Markdown
9. Plain Text
10. HTML

### Phase C — Rich document formats

11. PDF
12. DOCX

### Phase D — Full fidelity

13. QPNOTE manifest
14. QPNOTE metadata
15. QPNOTE attachment embedding
16. QPNOTE OCR
17. package validation
18. integrity hashes

### Phase E — UX

19. export sheet
20. advanced options
21. progress/error states
22. native share
23. save destination
24. remembered preferences

### Phase F — Hardening

25. security tests
26. integration tests
27. performance tests
28. cleanup verification
29. static analysis
30. formatting
31. dependency audit
32. regression testing

Do not stop after implementing only the UI.

---

# 53. DO NOT DUPLICATE RENDERING LOGIC

The application may already have Markdown rendering.

Reuse the existing parser/tokenizer/rendering semantics where safe.

Do not create one Markdown parser for the UI and a completely incompatible parser for exporting.

The goal is:

```text
Canonical Markdown
        |
        +---- Existing UI renderer
        |
        +---- Export rendering pipeline
```

The rendered semantics should remain consistent.

Where an existing UI renderer is widget-specific and cannot be reused directly, reuse its parsing/AST semantics rather than duplicating Markdown interpretation from scratch.

---

# 54. EXPORT DATA SHOULD BE DETACHED FROM DATABASE MODELS

Do not pass ORM/Drift/database row objects through every exporter.

Create immutable export DTOs or equivalent structures.

For example:

```text
NoteExportSnapshot
AttachmentExportItem
OcrExportItem
MetadataExport
```

This makes the export subsystem:

- testable
- deterministic
- independent from database migrations
- future-compatible

---

# 55. ATTACHMENT TYPES

Support all attachment types currently present in the application.

Inspect the repository and explicitly handle:

- ordinary images
- scanned PDFs/documents
- other file attachments

Do not assume every Cloudinary resource is an image.

Respect:

- MIME type
- resource type
- original extension
- existing attachment semantics

---

# 56. DOCUMENT/PDF ATTACHMENTS

For a note containing an attached PDF:

QPNOTE:

```text
attachments/document.pdf
ocr/document/
```

Markdown:

```markdown
[Document](attachments/document.pdf)
```

or equivalent correct reference based on the actual Markdown attachment syntax.

Do not embed a PDF as an image.

Do not silently discard it.

---

# 57. EXPORTING EMBEDDED IMAGES

Embedded images should preserve usable dimensions/aspect ratio.

Do not upscale unnecessarily.

For PDF:

- constrain image width to document content area
- preserve aspect ratio
- gracefully paginate

For HTML:

- use responsive image sizing

For Markdown:

- reference the actual attachment path

---

# 58. NOTE TITLE VS MARKDOWN H1

Do not automatically insert a Markdown H1 into an export if the canonical Markdown does not contain one, unless that is an explicit format rule.

For PDF/HTML/DOCX, a document title may be rendered independently from the note body.

The title must not be silently persisted back into Markdown.

---

# 59. EMPTY NOTES

Export an empty note successfully.

Use:

```text
Untitled
```

when there is no title.

PDF/HTML/DOCX should still be valid documents.

QPNOTE must still contain valid metadata and manifest.

---

# 60. EXPORTING TRASH / ARCHIVE

Archived and trashed states are metadata, not reasons to block export.

Never accidentally restore, unarchive, or mutate the note.

---

# 61. QPNOTE FILE EXTENSION AND MIME TYPE

Register/use the appropriate MIME type where supported.

Suggested conceptual type:

```text
application/vnd.quietpaper.note
```

If platform registration requires a different implementation-specific value, follow the platform's constraints.

Do not rely solely on extension validation.

---

# 62. VERSIONING STRATEGY

QPNOTE version 1 must be explicit.

Future version behavior:

```text
major/minor or integer schema version
```

Choose one clear system and document it in code.

A future incompatible version must produce a clear error such as:

```text
This Quiet Paper note package requires a newer version of Quiet Paper.
```

Do not partially import a package whose schema is not understood.

---

# 63. DOCUMENTATION

Add developer documentation describing:

- export architecture
- supported formats
- QPNOTE specification
- manifest schema
- attachment resolution
- OCR handling
- security model
- versioning strategy
- extension points for future export formats
- future import architecture

Also document how to add a new exporter.

The implementation should make adding a future format such as EPUB straightforward.

---

# 64. NO-HACK REQUIREMENT

Do not solve the task by:

- exporting a screenshot
- scraping visible UI text
- copying widget state
- hardcoding note fields
- embedding Cloudinary secrets
- creating arbitrary JSON dumps of database rows
- making the export format dependent on SQLite
- storing a second canonical rich-text document
- silently dropping attachments
- silently dropping OCR
- silently changing links
- blocking the UI with synchronous heavy work
- bypassing password protection

---

# 65. CODE QUALITY

Follow the project's existing:

- naming conventions
- architecture
- null-safety standards
- error-handling conventions
- dependency injection patterns
- state-management patterns
- logging conventions
- test conventions

Use strongly typed APIs.

Avoid giant "god classes".

Avoid global mutable state.

Avoid hidden side effects.

Prefer composable services.

Add comments only where behavior or security implications are non-obvious.

---

# 66. DEFINITION OF DONE

The feature is considered complete only when all of the following are true:

- individual notes can be exported from the note UI
- Markdown export works
- PDF export works
- HTML export works
- plain text export works
- DOCX export works or is safely isolated with an explicit supported fallback if the current project cannot technically support DOCX
- QPNOTE export works
- attachments can be embedded into portable exports
- OCR is preserved appropriately in QPNOTE
- metadata can be configured
- protected notes are secured
- trashed notes export correctly
- filenames are sanitized
- note links remain valid according to the selected strategy
- no sync mutation occurs
- no search-index mutation occurs
- no Cloudinary credentials leak
- no sensitive content is written to logs
- temporary files are cleaned
- UI remains responsive
- native sharing works
- save/export destination works where supported
- export preferences persist appropriately
- tests cover normal, edge, failure, and security scenarios
- analyzer/linter passes
- formatter passes
- existing application tests continue to pass
- documentation exists
- package format is versioned and future-import-ready

---

# 67. FINAL AGENT BEHAVIOR

Do not merely describe what should be implemented.

Actually inspect the repository and implement the feature.

Before coding, identify relevant existing files and abstractions.

During implementation:

- reuse existing infrastructure
- avoid unnecessary refactors
- do not break existing sync/trash/OCR/search behavior
- keep the canonical Markdown architecture
- maintain backwards compatibility
- add tests alongside production code
- validate outputs rather than assuming libraries generated valid files

After implementation:

1. run formatter
2. run analyzer/linter
3. run relevant unit tests
4. run integration tests
5. run existing regression tests
6. manually inspect representative generated outputs where feasible
7. inspect package contents of a real `.qpnote`
8. verify cleanup behavior
9. verify protected-note behavior
10. verify attachment download failures
11. verify large-note performance

Finally provide a concise implementation report containing:

```text
Implemented:
- ...

Files added/changed:
- ...

Dependencies added/changed:
- ...

Database changes:
- ...

Platform changes:
- ...

QPNOTE schema:
- ...

Tests:
- ...

Known limitations:
- ...

Future extension points:
- ...
```

Do not claim something is implemented unless it is actually implemented and verified.

Do not hide failed tests or unsupported functionality.

The resulting subsystem should feel like a permanent core part of Quiet Paper rather than a one-off export feature.