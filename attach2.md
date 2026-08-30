

# MASTER IMPLEMENTATION PROMPT

## Quiet Paper — Phase 2A: Text Attachment Viewer & Read-Only Text Intelligence

You are working inside the existing Quiet Paper Flutter application.

Implement **Phase 2A of the Generic Attachment System**.

The objective is to make textual attachments first-class, polished, and useful inside Quiet Paper.

This phase covers:

* plain-text attachments
* Markdown attachments
* structured-text attachments
* source-code attachments as plain monospaced text for now
* CSV/TSV attachments
* read-only viewing
* local search within a text attachment
* selection/copy
* word wrap
* line numbers where appropriate
* Markdown rendered/source viewing
* CSV/TSV table presentation
* encoding detection
* large-text-file safeguards
* Open With
* Share
* Save As
* Create Note from File
* attachment capability resolution
* secure access to encrypted attachment bytes

This phase **does not implement syntax highlighting**.

Syntax highlighting is a separate upcoming subsystem and must not be introduced as a fake or temporary implementation here.

This phase also does **not** implement persistent global full-text indexing of generic attachments.

---

# 1. EXISTING ARCHITECTURE MUST REMAIN INTACT

The application already has:

* generic encrypted attachments from Phase 1
* image attachments
* specialized scanned-document/PDF handling
* OCR
* Cloudinary storage/synchronization
* encrypted local storage
* attachment lifecycle
* note trash/permanent deletion semantics
* backup
* export
* Markdown as the canonical note representation
* a sophisticated Markdown editor
* search
* responsive tablet/split-view UI

Do not replace those systems.

Do not flatten specialized documents into generic text attachments.

Do not introduce a new attachment database model if the Phase 1 architecture already provides the required generic attachment abstraction.

---

# 2. CORE PRINCIPLE

The original attachment remains authoritative.

For a text attachment:

```text id="z0m7b1"
Encrypted original file
        ↓
secure local access
        ↓
decode text
        ↓
read-only presentation
```

The viewer is derived presentation.

It must never become a second source of truth.

---

# 3. ABSOLUTE IMMUTABILITY RULE

Viewing a text attachment must never modify:

* original file bytes
* content hash
* filename
* MIME type
* attachment ID
* attachment creation timestamp
* attachment content
* sync state

except for explicitly requested metadata operations such as Rename.

The following must be presentation-only:

* word wrap
* line numbers
* search
* Markdown rendered/source toggle
* scrolling
* zoom/text-size presentation
* CSV table rendering
* pretty-print view
* line selection

---

# 4. PHASE 2A SCOPE

Support these logical text categories.

## Plain text

```text
.txt
.text
.log
.conf
.ini
.env
```

where safely recognized.

## Markdown

```text
.md
.markdown
.mdown
```

## Structured text

```text
.json
.jsonl
.yaml
.yml
.xml
.toml
```

## Data text

```text
.csv
.tsv
```

## Source files

Recognize common source-code extensions.

Examples:

```text
.dart
.py
.js
.ts
.java
.kt
.swift
.rs
.go
.c
.h
.cpp
.hpp
.cs
.php
.rb
.sh
.sql
.html
.css
```

However:

> Source-code files are plain monospaced text in Phase 2A.

Do not implement syntax highlighting yet.

---

# 5. UNKNOWN TEXT

An unknown extension may still be a text file.

If content detection determines the file is safely text-readable:

```text
Text File
```

and show it through the plain-text viewer.

If the file appears binary:

```text
Generic File
```

and use the generic attachment behavior.

Do not display binary garbage as text.

---

# 6. ATTACHMENT CAPABILITY MODEL

Use the Phase 1 capability architecture.

Do not scatter file-extension checks through widgets.

The resolver should determine capabilities such as:

```text id="y0mq5n"
canPreview
canSearch
canSelectText
canCreateNote
canOpenExternally
canShare
canSaveAs
```

Example:

```text id="9m7d6s"
.txt
preview ✓
search ✓
select/copy ✓
create note ✓
open externally ✓
share ✓
save as ✓
```

```text id="md001a"
.md
preview ✓
render Markdown ✓
source view ✓
search ✓
create note ✓
```

```text id="rv3k21"
.dart
preview ✓
plain text ✓
search ✓
create note ✓
syntax highlighting ✗ for Phase 2A
```

```text id="csv001"
.csv
preview ✓
table view ✓
search ✓
create note ✓
```

```text id="zip001"
.zip
preview ✗
search ✗
create note ✗
open externally ✓
share ✓
```

Only expose capabilities that genuinely work.

---

# 7. UNIFIED ATTACHMENT VIEWER

Create one common viewer entry point.

Conceptually:

```text id="l1r4sj"
AttachmentViewer
      ↓
AttachmentPreviewResolver
      ↓
PlainTextViewer
MarkdownViewer
CsvViewer
GenericFileViewer
```

Existing specialized viewers remain specialized:

```text id="bs2jvi"
PDF → existing PDF/document viewer
Image → existing image viewer
```

Do not force PDFs/images through the generic text viewer.

---

# 8. DO NOT CREATE A SECOND EDITOR

The attachment viewer must be read-only.

Do not use:

```text EditableText
TextField
MarkdownEditingController
```

as the authoritative representation of the attachment.

A text rendering widget may use scrolling/selection infrastructure, but it must not behave like a note editor.

---

# 9. PLAIN TEXT VIEWER

Create a polished read-only text viewer.

Conceptually:

```text id="ptview"
┌────────────────────────────────────────┐
│ ‹  server.log                     ⋯   │
├────────────────────────────────────────┤
│                                        │
│  1  Server started                     │
│  2  Listening on port 8080             │
│  3  Client connected                   │
│  4  Request received                   │
│                                        │
└────────────────────────────────────────┘
```

The design must use Quiet Paper's existing typography and theme tokens.

Do not make it look like an IDE.

---

# 10. MONOSPACED VS PROPORTIONAL TEXT

Use proportional body typography for:

* `.txt`
* prose-like `.text`

Use monospaced typography for:

* logs
* source code
* JSON
* YAML
* XML
* TOML
* configuration
* CSV/TSV

Use the existing code-font configuration where appropriate.

Do not add syntax highlighting in this phase.

---

# 11. LINE NUMBERS

Support line numbers where they improve usability.

Recommended:

```text id="4lhc2w"
source code
JSON
YAML
XML
logs
CSV
```

Plain prose `.txt` does not necessarily need line numbers.

The decision should be capability/category based, not extension checks scattered in the UI.

---

# 12. LINE NUMBER IMPLEMENTATION

Line numbers are presentation-only.

They must not alter:

* source content
* line endings
* byte offsets
* attachment hash

Do not include line numbers when the user selects/copies text.

For example:

Displayed:

```text id="c1"
1 | hello
2 | world
```

Copy result:

```text id="c2"
hello
world
```

not:

```text id="c3"
1 | hello
2 | world
```

---

# 13. WORD WRAP

Provide a word-wrap toggle where appropriate.

Example:

```text id="f4v7p0"
Wrap Text                    ✓
```

When disabled:

* preserve long lines
* allow horizontal scrolling

When enabled:

* wrap long lines naturally

This must not alter the original file.

---

# 14. DEFAULT WRAP POLICY

Recommended:

### Prose `.txt`

```text wrap ON
```

### Code/log/config

```text wrap OFF
```

unless the current application typography/layout conventions suggest otherwise.

Make the choice presentation-only.

---

# 15. HORIZONTAL SCROLLING

When wrapping is disabled:

* support horizontal scrolling
* preserve vertical scrolling
* do not clip text
* do not shrink font to fit

Handle nested horizontal/vertical gestures carefully on touch devices.

---

# 16. SEARCH WITHIN TEXT ATTACHMENT

Implement local in-viewer search.

Example:

```text id="q34jz1"
⌕ authentication
```

Show:

```text
3 matches
```

Provide:

* next
* previous
* close search

Highlight matching ranges.

Search must operate on the decoded text representation.

---

# 17. SEARCH MUST BE EPHEMERAL

Phase 2A search within a viewer must not automatically create a persistent search index.

Do not store full extracted plaintext merely because the user searched.

Do not modify FTS5.

Do not add generic attachment content to Global Search in this phase.

---

# 18. SEARCH PERFORMANCE

Small/medium files may be searched in memory.

Large files must use a bounded strategy.

Do not load enormous files into an unbounded Flutter `String`.

Use:

* file-backed/chunked search
* bounded loading
* streaming search
* or another appropriate large-file strategy

where necessary.

Choose based on profiling and actual implementation constraints.

---

# 19. SEARCH RESULT NAVIGATION

When the user searches:

```text id="2zmz3l"
authentication
```

and a match is found:

* scroll to match
* highlight it
* preserve context

For source files/logs with line numbers, optionally display the line number.

Do not modify the file.

---

# 20. SEARCH TEXT SELECTION

The highlighted search result must not interfere with normal text selection.

The user must still be able to:

* select text
* copy
* scroll
* dismiss search

---

# 21. COPY

Support:

```text id="bj4f4h"
Copy
```

and:

```text Select All
```

for text attachments.

Copied content must be original text content without:

* line numbers
* search highlighting
* viewer decorations

---

# 22. SELECTABLE TEXT

Use a proper selectable-text mechanism.

Do not simulate selection with tap handlers alone.

Selection should support:

* drag selection
* long press
* copy
* select all

where the platform supports it.

---

# 23. SHARE

The attachment viewer must expose existing Share behavior.

The actual file bytes must remain unchanged.

Reuse the Phase 1 attachment share service.

Do not create a text-specific sharing implementation.

---

# 24. SAVE AS

Allow:

> Save As

through the existing safe platform storage mechanism.

The exported copy must match the original file bytes exactly.

Do not save the decoded/re-encoded text if that changes:

* BOM
* line endings
* encoding
* byte representation

For Save As, copy the original attachment bytes.

---

# 25. OPEN WITH

Allow:

> Open With…

through the Phase 1 attachment-opening mechanism.

Use the original file bytes.

Do not generate a new text file simply to open an existing one.

---

# 26. RENAME

Existing attachment Rename remains available.

Renaming must not modify file bytes.

Do not change:

```text content hash
attachment ID
MIME type
```

merely because the filename changed.

---

# 27. FILE INFORMATION

Add an attachment information screen/sheet where appropriate.

For text files:

```text id="7d20j0"
Filename       server.log
Type           Text File
Size           84 KB
Encoding       UTF-8
Lines          1,842
Status         Synced
```

Only show metadata that is actually known.

Do not fabricate line counts if computing them is unsafe or excessively expensive.

---

# 28. ENCODING DETECTION

Implement robust text decoding.

At minimum support:

* UTF-8
* UTF-8 BOM
* UTF-16 LE
* UTF-16 BE

where the chosen decoding libraries/platform APIs allow it.

Prefer deterministic decoding.

---

# 29. UTF-8 BOM

If present:

* detect BOM
* don't display BOM as visible content
* preserve original bytes

If the viewer displays the text, the BOM should not appear as `﻿`.

---

# 30. ENCODING FALLBACK

If encoding cannot be determined confidently:

Do not silently corrupt text.

Use a clear fallback strategy.

Possible UI:

```text id="wmxq8w"
Text encoding couldn't be determined.

[ Try UTF-8 ]
[ Open Externally ]
```

or another safe flow consistent with the application's UX.

Only provide options that are implemented.

---

# 31. LINE ENDINGS

Support:

* LF
* CRLF
* CR

for display.

Normalize only in the presentation layer.

Never rewrite original bytes.

---

# 32. UNICODE

Text viewers must correctly handle:

* Unicode punctuation
* accented characters
* CJK
* emoji where fonts support them
* combining marks
* RTL text

Do not assume ASCII.

---

# 33. LARGE FILE SAFETY

Define internal thresholds based on profiling.

Conceptually:

```text id="x61nzk"
small
→ full viewer

medium
→ optimized viewer

large
→ bounded/streamed viewer

huge
→ limited preview + external open
```

Do not hard-code arbitrary thresholds without validating them.

---

# 34. VERY LARGE FILE UX

For extremely large files:

```text id="u0msga"
This file is too large to display in full.

Showing a preview.

[ Open Externally ]
[ Save As ]
```

The original attachment remains fully preserved.

---

# 35. PARTIAL TEXT PREVIEW

If implementing partial preview:

Make the boundary explicit.

Example:

```text id="s5sp3c"
Showing first 2 MB of 180 MB
```

Do not imply that the displayed text is the entire file.

---

# 36. NO UNBOUNDED TEXTFIELD

Never put arbitrarily large generic text attachments into:

```text TextEditingController
```

or equivalent whole-document editor state.

The attachment viewer is read-only.

---

# 37. MARKDOWN ATTACHMENT VIEWER

For `.md`, implement two presentation modes:

```text id="x2u31a"
Rendered
Source
```

Default to:

> Rendered

unless existing product conventions suggest Source.

---

# 38. MARKDOWN RENDERED MODE

Rendered mode must use the application's existing Markdown rendering semantics.

Do not create a second Markdown dialect.

It should support, where already supported by the application's Markdown renderer:

* headings
* paragraphs
* bold
* italic
* strikethrough
* highlights
* code blocks
* lists
* checklists
* blockquotes
* links
* images
* tables
* horizontal rules
* frontmatter semantics

The existing editor/preview already has extensive Markdown support. Reuse it. 

---

# 39. MARKDOWN SOURCE MODE

Source mode must show the original Markdown text.

Do not modify the source.

Use a read-only source presentation.

Syntax highlighting is NOT required for Phase 2A.

Markdown source syntax may be visually distinct using existing Markdown presentation rules if already available, but do not build a full syntax-highlighting engine in this phase.

---

# 40. MARKDOWN VIEW TOGGLE

Switching:

```text id="yyd2t9"
Rendered ↔ Source
```

must not alter attachment content.

Switching modes must preserve approximately the same document location where practical.

---

# 41. MARKDOWN SEARCH

Search within rendered Markdown or source mode must ultimately map to source content.

Search highlighting should not become confused by hidden/visual Markdown syntax.

---

# 42. MARKDOWN LINK SECURITY

Rendered Markdown links may be clickable.

Respect existing URL safety policies.

Do not execute arbitrary raw HTML/JavaScript from the Markdown attachment.

---

# 43. MARKDOWN HTML

Raw embedded HTML must not become executable content.

Use the existing safe Markdown rendering configuration.

---

# 44. MARKDOWN IMAGES

If an attached `.md` references an external image:

Follow the application's established network/image policy.

Do not automatically download every image simply because a Markdown viewer opened.

If an image cannot be safely/legitimately resolved:

show an appropriate placeholder.

---

# 45. RELATIVE MARKDOWN IMAGES

For:

```markdown id="gr5yuv"
![image](images/photo.png)
```

do not assume the sibling file exists.

Only resolve local relative resources if the attachment/package model actually provides them.

Otherwise show missing-resource behavior.

Do not silently fetch arbitrary neighboring device files.

---

# 46. MARKDOWN TABLES

Attached Markdown containing GFM tables must render using the existing Markdown table support.

Example:

```markdown id="9k74j7"
| Feature | Status |
|---------|--------|
| OCR     | Done   |
```

should display as a table.

Do not use the interactive hybrid table editor here because attachment `.md` files are read-only.

---

# 47. MARKDOWN CODE BLOCKS

Code blocks may render using the application's existing code-block typography.

Do not add syntax highlighting in Phase 2A.

Use the code font if already configured.

---

# 48. FRONTMATTER

Follow the existing Quiet Paper Markdown/frontmatter semantics.

Do not blindly display raw YAML frontmatter if the application's Markdown renderer normally suppresses it. The current app intentionally preserves frontmatter while controlling how it appears in presentation. 

---

# 49. MARKDOWN CREATE NOTE

Provide:

> Create Note from File

for `.md`.

Behavior:

```text id="fvyx11"
attached .md
      ↓
read original bytes
      ↓
decode
      ↓
new Quiet Paper note
```

The resulting note body becomes canonical Markdown.

---

# 50. CREATE NOTE MUST NOT DELETE ATTACHMENT

The original `.md` attachment remains untouched.

The new note is independent.

---

# 51. CREATE NOTE TITLE

Derive a sensible default title from filename.

Example:

```text id="x1a9vb"
research.md
→ Research
```

Do not force an `.md` title unless existing product rules require it.

The user should be able to change the title before saving if the existing note-creation flow supports it.

---

# 52. CREATE NOTE TAGS

Do not invent tags automatically unless existing product semantics already define Markdown/frontmatter tag import.

If frontmatter contains valid tags and the existing Markdown importer already maps them to note tags, reuse that behavior.

Do not write a second metadata parser.

---

# 53. TXT CREATE NOTE

For `.txt`:

```text id="8n0wt2"
plain text
↓
new note body
```

Do not introduce Markdown syntax artificially.

---

# 54. LOG CREATE NOTE

For `.log`:

Create a note containing the log content, preserving line structure.

Do not attempt to turn log lines into Markdown lists unless the user explicitly asks for conversion.

---

# 55. JSON/YAML/XML CREATE NOTE

Preserve the source text.

For readability in a new note, it may be wrapped in an appropriate fenced code block if that is the application's established import convention.

However:

**do not modify the original attachment.**

---

# 56. CSV CREATE NOTE

Provide a distinct action:

> Convert to Markdown Table

rather than ambiguously treating it as ordinary text.

This operation creates a new note.

The CSV attachment itself remains unchanged.

---

# 57. CSV VIEWER

Create a read-only table presentation.

Example:

```text id="csvviewer"
sales.csv

┌───────────┬──────┬────────┐
│ Product   │ Qty  │ Price  │
├───────────┼──────┼────────┤
│ Keyboard  │ 2    │ 80     │
│ Monitor   │ 1    │ 300    │
└───────────┴──────┴────────┘
```

This is presentation-only.

---

# 58. CSV PARSING

Do not parse CSV using:

```dart
line.split(',')
```

CSV may contain:

* quoted fields
* commas inside quotes
* embedded newlines
* escaped quotes

Use a robust parser or a carefully tested implementation.

---

# 59. CSV DELIMITERS

Support:

```text id="fd0w4r"
.csv → comma
.tsv → tab
```

where appropriate.

Do not assume comma for TSV.

---

# 60. CSV EDGE CASES

Handle:

* empty cells
* quoted empty fields
* UTF-8 BOM
* CRLF
* embedded newline
* duplicate columns
* inconsistent row lengths
* trailing delimiters

Malformed CSV must never crash the viewer.

---

# 61. CSV INCONSISTENT ROW LENGTHS

If a row has fewer cells:

show missing cells empty.

If a row has more cells:

either expand the table safely or display an explicit extra-column structure.

Do not silently discard data.

---

# 62. CSV HEADER

If the file has a header row according to the parser/data-viewer's semantics:

display it distinctly.

Do not assume the first row is a header if the file format doesn't explicitly say so unless that is the documented product behavior.

---

# 63. CSV SEARCH

Search should work within cell text.

Highlight matching cells/text.

Do not add line numbers to CSV table presentation unless explicitly selected as a source view.

---

# 64. CSV COPY

For a normal selection/copy of CSV content:

preserve actual CSV text where appropriate.

Do not unexpectedly copy table decoration.

If a future `Copy as Markdown Table` or `Copy as TSV` action is added, make it explicit.

---

# 65. CSV VIEW TO SOURCE VIEW

Consider allowing:

```text id="7trwq3"
Table
Source
```

where Source displays the actual CSV text.

This is recommended if it can be implemented without unnecessary complexity.

The source view must remain read-only.

---

# 66. JSON/JSONL

Treat `.json` and `.jsonl` as text.

Do not execute or deserialize arbitrary values for display.

Pretty-printing may be presentation-only.

---

# 67. JSON PRETTY VIEW

If implementing pretty-print:

* do not modify attachment bytes
* catch malformed JSON
* fall back to raw source
* indicate when the content is malformed

Do not make pretty-printing a save operation.

---

# 68. YAML

Treat YAML as untrusted text.

Do not execute constructors, tags or arbitrary embedded code.

Display safely.

---

# 69. XML

Treat XML as untrusted text.

Do not execute external entities.

Do not render arbitrary XML as HTML.

---

# 70. HTML TEXT ATTACHMENTS

For `.html` attachments:

Do not automatically render them as active web pages in Phase 2A.

Treat them as text/source.

Provide:

> Open Externally

for users who want browser rendering.

This avoids turning arbitrary HTML attachments into an active script surface.

---

# 71. SVG

Treat `.svg` cautiously.

Do not automatically execute embedded scripts/external resources.

In Phase 2A it may remain a generic file or source/text attachment depending on MIME detection.

---

# 72. SOURCE CODE

Source-code files should open in the read-only text viewer.

Use:

* monospace
* word wrap off by default
* line numbers
* search
* copy
* Open With
* Share
* Save As

Do NOT add:

* syntax highlighting
* code editing
* code execution
* formatting
* compilation

in Phase 2A.

---

# 73. CODE LANGUAGE DETECTION

You may identify the language for a future capability resolver using:

* MIME
* extension

but do not use it to claim syntax highlighting exists.

Example UI:

```text id="48v4l1"
server.dart
Dart Source
```

with plain monospaced text.

---

# 74. UNKNOWN TEXT FILES

If:

```text id="pyp1ka"
mystery.config
```

is confidently text:

show as Plain Text.

If binary:

show Generic File.

---

# 75. TEXT DECODING FAILURE

If decoding fails:

Do not display corrupted replacement characters as if the content were correct.

Offer:

```text id="e91xft"
This file's encoding isn't supported.

Open Externally
Save As
```

as appropriate.

---

# 76. ATTACHMENT DOWNLOAD

If the encrypted attachment exists remotely but not locally:

Opening the viewer should:

```text id="0s0i0m"
download
→ verify
→ decrypt
→ decode
→ display
```

Reuse the Phase 1 transfer service.

Do not create a separate download path.

---

# 77. ATTACHMENT INTEGRITY

Verify content hash after obtaining the plaintext attachment.

If integrity fails:

```text id="0q2wz8"
Attachment integrity check failed.
```

Do not display potentially corrupted text as valid.

---

# 78. DECRYPTION SECURITY

Decrypt only when necessary.

Do not leave plaintext attachment bytes permanently in cache.

Use the existing encrypted attachment storage architecture.

---

# 79. VIEWER CACHE

Do not create a permanent plaintext cache by default.

An in-memory bounded cache may be used for small files if useful.

For large files use file-backed/bounded processing.

---

# 80. TEMP FILES

If a decrypted temporary file is required:

* use secure app-private temporary storage
* use unpredictable paths
* clean after use
* perform stale-temp cleanup where appropriate

Do not expose internal vault paths.

---

# 81. CREATE NOTE MEMORY SAFETY

Creating a note from a small/medium text attachment may read it into memory.

For large files:

* enforce the note-import size limit
* use bounded reads
* or refuse with a clear message

Do not crash because a user selected a huge log file.

---

# 82. CREATE NOTE SIZE POLICY

Do not reuse the attachment size limit blindly for note import.

A generic attachment can be much larger than a practical Markdown note.

Use the editor's existing large-document constraints as a factor. The current editor already uses special handling for very large notes. 

---

# 83. LARGE MARKDOWN ATTACHMENT

If a `.md` file is huge:

* allow generic storage
* allow bounded/source preview
* allow external open
* do not automatically load the entire document into the normal note editor

If Create Note is requested and it exceeds safe limits:

> This file is too large to import as a note.

Do not truncate silently.

---

# 84. TEXT VIEWER PERFORMANCE

Do not rebuild the entire viewer when:

* scrolling
* moving search highlight
* changing wrap state
* changing line-number state

Use localized state.

---

# 85. VIRTUALIZATION

For large text:

Use an efficient rendering strategy.

Do not create one Flutter widget per line for extremely large files unless the framework implementation is explicitly virtualized.

---

# 86. SCROLL POSITION

When opening an attachment:

* start at the top
* unless a search result/deep link requests another position

When switching source/rendered Markdown mode:

* preserve approximate document position where possible

---

# 87. SEARCH POSITION

If search jumps to line 5000:

* scroll there
* make the matched text visible
* don't jump back to top after rendering finishes

---

# 88. LINE COUNT

Do not scan the entire 500 MB file synchronously merely to display:

> 5,000,000 lines.

Calculate lazily or omit the count until safely available.

---

# 89. UI HEADER

Recommended:

```text id="7q4h1y"
‹  filename                              ⋯
```

Optional secondary information:

```text
Text File · 84 KB
```

Do not waste vertical space with giant headers.

---

# 90. VIEWER ACTION MENU

Generic text attachment:

```text id="6xgzzp"
Search
Copy
Select All
Create Note
Open With
Save As
Share
Rename
Delete
```

Only display applicable actions.

---

# 91. MARKDOWN ACTION MENU

Markdown may add:

```text id="v3j4rc"
Rendered / Source
Create Note
```

---

# 92. CSV ACTION MENU

CSV may add:

```text id="uo8h51"
Table / Source
Convert to Markdown Table
```

only if fully implemented.

---

# 93. LOG ACTION MENU

Logs may include:

```text id="cq7g0g"
Search
Wrap Text
Line Numbers
```

No fake filters.

---

# 94. SOURCE FILE ACTION MENU

Source files may include:

```text id="bhyix1"
Search
Line Numbers
Wrap Text
```

No syntax highlighting in this phase.

---

# 95. TOOLBAR VISIBILITY

Do not permanently display every possible action.

Keep the viewer clean.

Example:

```text id="2u7b2v"
‹ server.dart                         ⋯
```

with actions in overflow.

Search may have a dedicated icon when contextually useful.

---

# 96. SEARCH UI

Use a compact search field:

```text id="8n1xkg"
⌕ Search…                         3/8   ×
```

Do not open a huge search panel.

---

# 97. EMPTY TEXT FILE

A zero-byte text file should display:

```text id="74z0o7"
Empty file
```

and still support:

* Share
* Save As
* Open With
* Rename
* Delete

---

# 98. WHITESPACE-ONLY FILE

Render whitespace faithfully enough for source-oriented viewing.

Do not collapse meaningful whitespace in code/source views.

---

# 99. TRAILING NEWLINE

Preserve trailing newline in display/copy where appropriate.

Do not silently remove it during Create Note if the import semantics should preserve it.

---

# 100. TAB CHARACTERS

Source/code viewers must preserve tab characters visually according to a sensible tab-width policy.

Do not replace actual tabs in the stored file.

---

# 101. CONTROL CHARACTERS

Handle non-printable characters safely.

Do not let terminal/control sequences alter the viewer.

For example, ANSI escape sequences in logs should not become active terminal commands.

---

# 102. ANSI LOGS

If `.log` contains ANSI color escape sequences:

Phase 2A may display them as source text or strip them only in a view-layer presentation if clearly documented.

Do not execute terminal escape sequences.

Do not implement a terminal emulator.

---

# 103. FILE SIZE DISPLAY

Use human-readable units:

```text id="g7j8mo"
84 KB
2.4 MB
1.2 GB
```

Use existing app formatting utilities if present.

---

# 104. TYPE DISPLAY

Examples:

```text id="qy7a2h"
Markdown
Plain Text
JSON
YAML
CSV
Dart Source
JavaScript Source
XML
```

Use a centralized resolver.

---

# 105. MIME DISPLAY

Do not normally show raw MIME types.

Only show them in advanced file information if useful.

---

# 106. SECURITY OF MARKDOWN

Do not allow raw Markdown attachments to become a route for:

* script execution
* unsafe file access
* arbitrary local-file reads

Use safe rendering.

---

# 107. SECURITY OF HTML

Never render arbitrary attached HTML with unrestricted JavaScript simply because the file is named `.html`.

---

# 108. SECURITY OF YAML/JSON/XML

Treat all structured text as untrusted.

Do not instantiate application objects directly from arbitrary attachment contents.

---

# 109. EXTERNAL OPEN SECURITY

Use the Phase 1 secure external-file opening flow.

Do not expose the attachment vault directly.

---

# 110. SHARE SECURITY

Use temporary decrypted files as required by the platform.

Clean them safely.

Do not share encrypted ciphertext.

---

# 111. SAVE AS SECURITY

Same principle.

Only temporary decrypted output is exposed to the destination chosen by the user.

---

# 112. NOTE CREATION SECURITY

Creating a note from an attachment is an explicit content transformation.

The resulting note must follow normal note encryption/protection/sync behavior.

Do not retain a plaintext intermediate longer than needed.

---

# 113. ACCOUNT BOUNDARY

Text viewers must only access attachments belonging to the current authenticated notebook/account.

No attachment ID should be sufficient by itself to bypass authorization.

---

# 114. PROTECTED NOTE BOUNDARY

If an attachment belongs to a protected note:

* honor the note's existing protection state
* do not expose attachment content before authorized unlock

Do not make the generic attachment viewer a security bypass.

---

# 115. SEARCH SECURITY

Viewer search must operate only after attachment access has been authorized.

Do not persist search content outside the authorized session.

---

# 116. BACKUP

Do not add a separate text backup mechanism.

Phase 1 generic attachment backup should already preserve the original file.

Phase 2 only needs to ensure viewer functionality works after restore.

---

# 117. EXPORT

Do not create text-specific export storage.

Use Phase 1 export handling.

Markdown export of a note should preserve its generic attachments according to the export system.

---

# 118. QPNOTE

QPNOTE should preserve the original text attachment bytes.

Do not store only extracted/decoded text instead.

---

# 119. CONTENT HASH

The content hash is based on the original file bytes.

Decoding/pretty-printing/searching must never change it.

---

# 120. PROCESSOR VERSIONING

Phase 2A can use ephemeral decoding.

If persistent derived metadata is introduced, include a processor/version concept.

Do not persist derived plaintext casually.

---

# 121. ATTACHMENT PREVIEW STATE

The viewer should distinguish:

```text id="yi9x45"
loading
ready
partial
decodeError
integrityError
downloadRequired
```

Do not collapse all failures into "No preview."

---

# 122. GENERIC FALLBACK

If the file cannot be previewed safely:

```text id="n2h3op"
This file can't be previewed in Quiet Paper.

[ Open With… ]
[ Share ]
[ Save As ]
```

No broken viewer.

---

# 123. NO FAKE PREVIEW

Do not display a generic file icon and call that "preview."

The capability resolver determines whether real preview exists.

---

# 124. TEXT PREVIEW AVAILABILITY

If text decoding is supported:

show actual text.

If not:

fallback.

---

# 125. ATTACHMENT OPENING

Opening a text attachment should not change:

* note updated timestamp
* note revision
* dirty state
* sync state

Viewing is read-only.

---

# 126. CREATE NOTE IS AN EXPLICIT MUTATION

Only Create Note creates new data.

It must use existing repository/note-creation mechanisms.

---

# 127. ATTACHMENT RENAME

Opening Rename may mutate metadata.

Use the existing attachment repository/service.

Do not write directly to SQLite from the viewer.

---

# 128. DELETE

Deletion must use the existing attachment lifecycle.

Do not directly delete files from the viewer.

---

# 129. NAVIGATION

The viewer should return to the exact note/context from which it was opened.

Do not create an unrelated navigation stack.

---

# 130. MULTI-PANE TABLET

Ensure the viewer works correctly in:

* phone
* tablet
* split view
* embedded editor contexts

Do not break the existing tablet navigation model.

---

# 131. RESPONSIVE UI

Do not hard-code heights.

Handle:

* narrow width
* wide width
* landscape
* keyboard
* safe areas
* large text scaling

---

# 132. LARGE FONT ACCESSIBILITY

Text viewer content must remain usable under increased system font scaling.

Don't solve overflow by shrinking text below accessible sizes.

---

# 133. TOUCH TARGETS

Search, overflow, back and viewer controls must remain accessible.

---

# 134. KEYBOARD SUPPORT

On desktop/tablet:

* Ctrl/Cmd+F → search within attachment
* Escape → close search
* Ctrl/Cmd+A → select all where platform text selection supports it
* Ctrl/Cmd+C → copy

Do not conflict with the normal note editor because the attachment viewer is read-only.

---

# 135. SEARCH SHORTCUT

Implement `Ctrl/Cmd+F` only while the text attachment viewer has focus.

---

# 136. COPY SHORTCUT

Normal platform copy behavior should work.

Do not copy line numbers/search markers.

---

# 137. MARKDOWN SOURCE SHORTCUT

If a Source/Rendered toggle exists:

make it keyboard accessible.

---

# 138. TESTING — TEXT DECODING

Test:

* UTF-8
* UTF-8 BOM
* UTF-16 LE
* UTF-16 BE
* LF
* CRLF
* CR
* Unicode
* emoji
* combining characters

---

# 139. TESTING — BINARY DETECTION

Use fixtures for:

* plain text
* binary data
* unknown extension
* misleading extension
* UTF-8 with null bytes
* malformed UTF-8

Ensure binary content isn't rendered as garbage.

---

# 140. TESTING — PLAIN TEXT VIEWER

Test:

* open
* scroll
* wrap
* no wrap
* line numbers
* search
* select
* copy
* open externally
* share
* save as
* rename
* delete

---

# 141. TESTING — MARKDOWN

Test:

* rendered view
* source view
* toggle
* headings
* emphasis
* lists
* tables
* code
* links
* frontmatter
* images where applicable
* search

---

# 142. TESTING — CSV

Test:

* comma fields
* quoted commas
* escaped quotes
* multiline quoted fields
* empty cells
* inconsistent rows
* TSV
* BOM
* malformed CSV
* search
* source view if implemented
* Markdown table conversion if implemented

---

# 143. TESTING — JSON

Test:

* valid JSON
* malformed JSON
* large JSON
* Unicode
* search
* pretty view if implemented
* copy

---

# 144. TESTING — YAML/XML

Test:

* normal source
* malformed source
* Unicode
* large text
* search
* copy

Do not execute anything.

---

# 145. TESTING — CODE

Test:

```text id="75kqvf"
.dart
.py
.js
.ts
.json
.sql
```

Verify:

* plain monospaced view
* line numbers
* search
* wrap toggle
* copy
* external open

Do not expect syntax highlighting in Phase 2A.

---

# 146. TESTING — LARGE FILE

Test multiple sizes:

```text id="a71f4c"
small
medium
large
very large
```

Measure:

* memory
* initial display latency
* search latency
* scrolling
* disposal

---

# 147. TESTING — BYTE FIDELITY

For every textual attachment:

```text original bytes
→ preview
→ Save As
```

Verify SHA-256 matches.

For:

```text original bytes
→ Create Note
```

the original attachment remains byte-identical.

---

# 148. TESTING — RENAME

Verify:

```text filename changes
content hash unchanged
bytes unchanged
attachment ID unchanged
```

---

# 149. TESTING — OPEN WITH

Where platform integration can be tested:

verify:

* MIME
* filename
* bytes

are correct.

---

# 150. TESTING — SHARE

Verify share flow receives the correct plaintext file representation and no encrypted vault path is exposed.

---

# 151. TESTING — DOWNLOAD

Remote-only attachment:

```text download
→ verify hash
→ decrypt
→ preview
```

must work.

---

# 152. TESTING — CORRUPTION

Corrupt local ciphertext.

Verify:

* no preview
* integrity error
* retry/download available where remote copy exists

---

# 153. TESTING — ACCOUNT ISOLATION

Attachment from Account A must not be visible in Account B.

---

# 154. TESTING — PROTECTED NOTE

Verify unauthorized access to protected attachment content is impossible.

---

# 155. TESTING — LIFECYCLE

Verify:

```text id="7x9anx"
note active
→ attachment visible

note trashed
→ attachment retained

note restored
→ attachment visible

note permanently deleted
→ attachment cleaned according to ownership/reference semantics
```

---

# 156. TESTING — BACKUP RESTORE

Backup → restore → open text attachment.

Verify exact bytes and viewer behavior.

---

# 157. TESTING — EXPORT

Verify QPNOTE and Markdown export preserve text attachment bytes.

---

# 158. TESTING — NOTE CREATION

For `.md`:

```text attachment
→ Create Note
→ Markdown body
→ correct title/tags where supported
```

For `.txt`:

```text attachment
→ Create Note
→ exact textual content
```

For CSV:

```text attachment
→ Convert to Markdown Table
→ new note
→ original CSV untouched
```

---

# 159. TESTING — LARGE CREATE NOTE

Attempt Create Note from a file larger than the safe note-import threshold.

Expected:

* no crash
* no silent truncation
* clear user-facing message

---

# 160. TESTING — NAVIGATION

Test:

```text note
→ attachment
→ viewer
→ back
```

and:

```text attachment
→ viewer
→ search
→ back
```

Ensure navigation state is preserved.

---

# 161. TESTING — TABLET

Test in:

* three-pane layout
* two-pane layout
* narrow Notes column
* orientation changes

---

# 162. TESTING — DARK MODE

Verify:

* text
* selection
* search highlight
* line numbers
* tables
* headers
* buttons
* source/rendered controls

---

# 163. TESTING — ACCESSIBILITY

Verify:

* filename accessible
* viewer content accessible
* search accessible
* line numbers don't pollute copied content
* rendered Markdown has useful semantics
* actions have labels

---

# 164. PERFORMANCE TESTING

Do not decode/parse the entire file merely to determine whether the attachment card can be displayed.

Metadata comes from Phase 1.

Content is loaded only when needed.

---

# 165. NO N+1

Opening an attachment list must not decode every text attachment.

Only the opened attachment gets content access.

---

# 166. NO BACKGROUND FULL-TEXT EXTRACTION

Do not scan every text attachment when the app starts.

That belongs to the later attachment-search/indexing phase.

---

# 167. NO PERSISTENT PLAINTEXT CACHE

Do not create a database table containing:

```text id="a1"
attachment_id
plaintext
```

as part of Phase 2A.

That is explicitly out of scope.

---

# 168. FUTURE SEARCH ARCHITECTURE

Design the viewer so a later persistent text-extraction/indexing system can be added without changing the viewer API.

The viewer should request:

```text id="6wqyem"
readAttachmentText(...)
```

rather than owning storage/extraction logic.

---

# 169. FUTURE SYNTAX HIGHLIGHTING

Design the text viewer so a future `SyntaxHighlightingService` can provide:

```text id="e1y1z1"
plain text
↓
highlighted spans
```

without replacing the viewer.

Do not implement the highlighter now.

---

# 170. FUTURE ATTACHMENT SEARCH

The viewer's search interface should be reusable later for:

```text local viewer search
```

and potentially:

```text global attachment search
```

but these must remain separate in Phase 2A.

---

# 171. NO GLOBAL SEARCH CHANGES

Do not alter the current FTS5 search subsystem as part of this phase.

Your existing search architecture is already carefully designed around FTS5 candidates, background ranking and OCR security. Do not destabilize it for attachment text just yet. 

---

# 172. NO SYNC CHANGES UNLESS REQUIRED

The generic attachment lifecycle from Phase 1 should remain authoritative.

Phase 2A primarily consumes it.

Do not create text-specific sync entities.

---

# 173. NO BACKEND CHANGES

Do not alter backend schema unless a genuine Phase 1 defect prevents text attachments from functioning.

Do not add text-extraction server endpoints.

---

# 174. NO CLOUD PROCESSING

Do not upload text content to a third-party text extraction service.

All Phase 2A text viewing/decoding should be local.

---

# 175. PRIVACY PRINCIPLE

Text attachments may contain highly sensitive content.

Treat them as private data.

Do not:

* log content
* send content to external APIs
* put plaintext into analytics
* persist plaintext unnecessarily

---

# 176. UI COPY

Use calm, concise language.

Examples:

```text id="1p4yw3"
Text File
Markdown
CSV
Dart Source
JSON
```

Avoid technical implementation jargon.

---

# 177. ATTACHMENT TYPE ICON

Use the centralized attachment icon resolver from Phase 1.

Examples:

```text id="i9r00e"
Markdown → file/document icon
JSON → braces/code style icon
CSV → table icon
Dart → code/file icon
Plain Text → text icon
```

Do not create extension checks in each screen.

---

# 178. VIEWER TRANSITION

Opening an attachment should feel fast.

For small files:

```text tap → immediate viewer
```

For downloaded/large files:

```text tap → lightweight loading state
```

Do not freeze the UI.

---

# 179. RE-OPEN BEHAVIOR

If the same attachment is reopened during the same app session, it may reuse safe transient decoded state where appropriate.

Do not make permanent plaintext caching mandatory.

---

# 180. DISPOSAL

Viewer must clean:

* streams
* file handles
* controllers
* listeners
* search state
* temporary resources

when closed.

No leaked file handles.

---

# 181. FILE LOCKING

Do not keep the encrypted attachment file open longer than needed.

On platforms where file handles affect deletion/replacement, release them correctly.

---

# 182. WINDOWS/FILE LOCKING

If the application supports Windows/desktop:

ensure viewer disposal releases file handles before:

* rename
* delete
* Save As
* attachment cleanup

---

# 183. PAGE STATE

If the user changes:

```text wrap
line numbers
font presentation
Markdown source/rendered
```

these are local UI state.

Do not change attachment metadata.

---

# 184. PREFERENCE PERSISTENCE

Do not globally persist every text-viewer presentation preference unless it improves the product.

If persisting:

* wrap preference may be global/category-specific
* line-number preference may be code/source-specific

Do not store per-file UI state in attachment content.

---

# 185. VIEWER FONT SIZE

If the application already has a text-size setting, use it.

Do not create an unrelated second typography system.

---

# 186. CODE FONT

Use the application's configured code font.

Do not bundle another monospace font solely for this viewer.

The existing typography architecture already distinguishes body and code fonts. 

---

# 187. MARKDOWN RENDERER

Reuse the existing Markdown rendering system.

Do not create an independent parser specifically for `.md` attachments.

---

# 188. CSV PARSER

A dedicated CSV parser is acceptable because CSV is not Markdown.

Keep its parsing isolated from the Markdown system.

---

# 189. JSON/YAML/XML PARSING

These are source viewers, not application data importers.

Do not map them to domain models just to display them.

---

# 190. UNKNOWN TEXT PARSER

Unknown text is plain text.

Do not attempt heuristics that can create destructive transformations.

---

# 191. NO AUTOMATIC FORMATTING

Opening, viewing or searching a text file must not:

* reindent code
* pretty-print JSON permanently
* normalize YAML
* sort CSV columns
* change line endings
* alter whitespace

---

# 192. CREATE NOTE TRANSFORMATION

The only place transformations may occur is an explicit:

> Create Note / Convert to Markdown Table

operation.

Clearly distinguish derived note content from original attachment.

---

# 193. MARKDOWN CREATE NOTE ROUND TRIP

For `.md`:

```text id="2q8tdo"
attachment
→ Create Note
→ note Markdown
```

should preserve the decoded Markdown content.

No rendering round-trip.

Do NOT do:

```text Markdown → HTML → Markdown
```

for Create Note.

---

# 194. TXT CREATE NOTE ROUND TRIP

For `.txt`:

copy decoded text to the new note according to the application's text encoding/import semantics.

Do not apply Markdown formatting.

---

# 195. CSV TO MARKDOWN TABLE

If implemented:

```text CSV
→ parse cells
→ escape Markdown structural pipes
→ create Markdown table
```

Correctly escape:

```text
|
```

inside cell contents.

Do not lose commas/quotes/newlines.

---

# 196. CSV CONVERSION DATA SAFETY

The conversion must be treated as potentially lossy.

If the CSV contains complex multiline fields that cannot be represented safely in a Markdown table:

* preserve them with a safe escaping strategy
* or refuse conversion with a clear message

Never silently lose data.

---

# 197. MARKDOWN TABLE GENERATION

Generated table must be valid Markdown.

Example:

```markdown id="m99sqp"
| Name | Status |
|------|--------|
| OCR  | Done   |
| Sync | Done   |
```

---

# 198. ATTACHMENT ORIGINAL REMAINS

After converting CSV to Markdown:

```text id="5cq7ti"
CSV attachment still exists unchanged.
```

---

# 199. ERROR RESILIENCE

Every viewer must gracefully handle:

* missing local file
* download failure
* corrupt encryption
* corrupt content
* unsupported encoding
* malformed JSON
* malformed YAML
* malformed XML
* malformed CSV
* enormous input

No crash.

---

# 200. NO DATA LOSS ON VIEWER FAILURE

A viewer crash/failure must never modify or delete the source attachment.

---

# 201. TEST COVERAGE TARGET

Add tests covering the new functionality while preserving the existing regression suite.

Test at minimum:

* generic text classification
* capability resolution
* text decoding
* plain viewer
* Markdown viewer
* CSV viewer
* source view
* search
* copy
* Create Note
* Save As
* Share integration
* Open With integration
* large-file handling
* malformed input
* lifecycle/security

---

# 202. EXISTING TEST SUITE

Run the full repository test suite.

Do not only run the new text attachment tests.

The existing application has broad editor, database, crypto, sync, search, OCR and UI tests. Phase 2A must not regress them. 

---

# 203. COMMANDS

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Run additional platform tests where applicable.

Do not suppress warnings.

---

# 204. GOLDEN / VISUAL TESTS

Where the project supports golden tests, cover:

```text id="5ki5kv"
plain text
Markdown rendered
Markdown source
CSV
code/plain monospaced
dark mode
light mode
narrow phone
tablet
search state
```

---

# 205. MANUAL QA DOCUMENT

Create one representative attachment fixture set:

```text id="xv8n0q"
sample.txt
sample.md
sample.log
sample.json
sample.yaml
sample.xml
sample.csv
sample.tsv
sample.dart
sample.py
large.log
unicode.txt
malformed.csv
malformed.json
binary.bin
```

Open every file.

---

# 206. MANUAL QA — PLAIN TEXT

Verify:

```text id="djh4my"
wrap
no wrap
search
copy
select
share
open
save
```

---

# 207. MANUAL QA — MARKDOWN

Verify:

```text id="f3q7pd"
Rendered
Source
tables
links
lists
headings
code
images
frontmatter
```

---

# 208. MANUAL QA — CSV

Verify:

```text id="j8n91a"
table presentation
horizontal scrolling
search
malformed data
quoted commas
multiline fields
```

---

# 209. MANUAL QA — LARGE FILE

Verify:

* no UI freeze
* memory remains reasonable
* external open works
* viewer doesn't load unbounded data

---

# 210. MANUAL QA — SECURITY

Verify:

* HTML doesn't execute
* YAML doesn't execute
* arbitrary binary isn't rendered
* protected note remains protected
* decrypted data isn't logged
* temporary files are cleaned

---

# 211. MANUAL QA — BYTE FIDELITY

For every representative file:

```text id="6c7i0b"
original hash
=
Save As hash
```

---

# 212. MANUAL QA — CREATE NOTE

Verify:

```text id="8k7sxe"
sample.md → note Markdown identical
sample.txt → note content correct
sample.csv → Markdown table correct
```

and original attachments remain intact.

---

# 213. PERFORMANCE ACCEPTANCE

The viewer must remain usable with:

```text id="gyxih8"
1 KB
100 KB
1 MB
10 MB
50 MB+
```

text files as applicable to actual attachment limits.

Do not promise support beyond the tested/supported range.

---

# 214. FINAL ARCHITECTURE

The resulting architecture should look conceptually like:

```text id="7gdyqv"
                    Attachment
                         │
                Capability Resolver
                         │
                 Is it text-capable?
                         │
              ┌──────────┼───────────┐
              │          │           │
            Plain      Markdown      CSV
              │          │           │
         TextViewer   MarkdownViewer CsvViewer
              │          │           │
              └──────────┼───────────┘
                         │
               Common Attachment APIs
                         │
        ┌────────────────┼────────────────┐
        │                │                │
     Download          Share           Open
        │
     Encryption
        │
       Sync
```

The viewer must remain above the attachment storage/security layer.

---

# 215. OUT OF SCOPE — DO NOT IMPLEMENT

Do NOT implement these in Phase 2A:

* syntax highlighting
* code editing
* global attachment full-text indexing
* persistent plaintext text extraction cache
* DOCX rendering
* XLSX rendering
* PPTX rendering
* EPUB reader
* archive browser
* audio player
* video player
* spreadsheet formulas
* code execution
* terminal emulator
* arbitrary HTML active rendering
* attachment content modification

These are future phases.

---

# 216. FUTURE SYNTAX HIGHLIGHTING COMPATIBILITY

The viewer architecture must make future syntax highlighting easy to add.

Future direction:

```text id="rx3xv1"
Raw Text
   ↓
Language Detection
   ↓
Syntax Highlighting
   ↓
Styled Runs
   ↓
Same Text Viewer
```

Do not make today's plain-text viewer incompatible with that future.

---

# 217. FUTURE GLOBAL SEARCH COMPATIBILITY

Future direction:

```text id="81w8gp"
Attachment
   ↓
Text Extraction
   ↓
Secure Derived Representation
   ↓
Optional Search Index
```

Do not implement this now.

Do not bake plaintext indexing into the viewer.

---

# 218. FINAL PRODUCT EXPERIENCE

For a `.txt`:

```text id="t0m2b1"
notes.txt

A calm, selectable text document
with search, wrap, copy and actions.
```

For `.md`:

```text id="71vsz3"
README.md

Rendered

# Project

This is **Quiet Paper**.

┌─────────┬────────┐
│ Feature │ Status │
├─────────┼────────┤
│ Tables  │ Done   │
└─────────┴────────┘
```

with:

```text Rendered | Source
```

For `.csv`:

```text id="y31vq4"
budget.csv

┌──────────┬───────┬────────┐
│ Item     │ Qty   │ Cost   │
├──────────┼───────┼────────┤
│ Keyboard │ 1     │ 80     │
│ Monitor  │ 2     │ 300    │
└──────────┴───────┴────────┘
```

For `.dart`:

```text id="5s6gk8"
server.dart

1  class Server {
2    ...
3  }
```

plain monospaced text for now.

For `.zip`:

```text id="r1xz7u"
project.zip

ZIP Archive · 48 MB

[ Open With… ]
[ Share ]
```

---

# 219. FINAL DEFINITION OF DONE

Phase 2A is complete only when:

### Text classification

* common text formats recognized
* unknown text safely handled
* binaries aren't rendered as text

### Plain text

* selectable
* copyable
* searchable
* wrap toggle
* line numbers where appropriate
* large-file safeguards
* Unicode support
* encoding detection

### Markdown

* rendered view
* source view
* existing Markdown renderer reused
* tables work
* links work
* frontmatter semantics respected
* safe raw HTML handling
* search works

### CSV/TSV

* real CSV parsing
* table display
* malformed input handling
* search
* source view where implemented
* Markdown conversion where implemented
* original file unchanged

### Source/config files

* readable
* monospaced
* searchable
* line-numbered
* no syntax highlighting yet
* no editing

### Common actions

* Open With
* Share
* Save As
* Rename
* Delete
* Create Note from File where supported

### Security

* attachment encryption preserved
* no plaintext persistence by default
* no content logging
* no unsafe HTML execution
* no code execution
* protected-note security preserved

### Lifecycle

* offline access works
* remote download works
* integrity verification works
* trash works
* permanent deletion works
* backup restore works
* sync remains unaffected

### Performance

* no unbounded text loading
* large files handled safely
* no N+1 decoding
* no UI freezing
* viewer disposal is clean

### Architecture

* no second source of truth
* no database table containing the attachment's canonical text
* no generic attachment search index
* no syntax-highlighting implementation yet
* existing image/PDF/document functionality unaffected

### Quality

* full test suite passes
* new tests pass
* `flutter analyze` has zero errors/warnings
* manual QA completed
* light/dark mode verified
* phone/tablet verified
* accessibility verified

---

# 220. FINAL REPORT

After implementation, report:

```text
Quiet Paper — Phase 2A Text Attachments

Text categories supported:
- ...

Viewer architecture:
- ...

Capability resolver:
- ...

Plain text:
- ...

Markdown:
- ...

CSV/TSV:
- ...

Source/config files:
- ...

Encoding support:
- ...

Large-file strategy:
- ...

Search:
- ...

Create Note:
- ...

Security:
- ...

Storage/decryption:
- ...

Sync:
- ...

Backup:
- ...

Export:
- ...

Files added:
- ...

Files modified:
- ...

Database changes:
- ...

Backend changes:
- ...

Dependencies added:
- ...

Tests added:
- ...

Full test suite:
- ...

flutter analyze:
- ...

Manual QA:
- ...

Known limitations:
- ...

Future integration points:
- syntax highlighting
- secure attachment text indexing
```

Do not claim syntax highlighting is supported.

Do not claim persistent attachment search is supported.

Do not claim DOCX/XLSX/PPTX rendering is supported.

The goal of Phase 2A is:

> **Make text files feel like first-class, polished, read-only documents inside Quiet Paper while preserving the original file byte-for-byte and leaving the architecture ready for syntax highlighting and secure attachment search later.**
> :::
