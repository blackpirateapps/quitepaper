# MASTER IMPLEMENTATION PROMPT
## Quiet Paper — Production Syntax Highlighting Subsystem
### Shared Highlighting for Markdown Code Blocks and Code/Text Attachments

You are working inside the existing Quiet Paper Flutter application.

Implement a complete, production-ready **syntax highlighting subsystem** using the lower-level Dart `highlight` package as the syntax tokenization engine.

The resulting system must support syntax highlighting in **both** of these contexts:

1. fenced code blocks inside Quiet Paper's canonical Markdown notes
2. source/code files attached as generic text attachments

The system must be designed as a reusable application-level service rather than being coupled to a particular widget.

---

# 1. PRIMARY PRODUCT GOAL

After implementation:

A Markdown code block such as:

````markdown id="4n3jxz"
```dart
final note = await repository.getNote(id);
print(note);
```
````

must render with syntax highlighting inside the existing Markdown editor.

An attached file such as:

```text id="5ka82m"
server.dart
```

must render with the same syntax-highlighting engine inside the read-only text attachment viewer.

The two contexts must share:

- language resolution
- grammar/tokenization
- semantic token categories
- syntax theme
- caching strategy
- performance safeguards

They must differ only where presentation requires it.

---

# 2. NON-NEGOTIABLE ARCHITECTURAL RULE

The canonical source remains the original text/Markdown.

Syntax highlighting is derived presentation only.

Do NOT store:

- token arrays
- highlight colors
- styled spans
- highlighted HTML
- syntax ASTs
- serialized widgets

inside the note or attachment as canonical content.

The architecture must be:

```text
Source
  ↓
Language resolution
  ↓
Syntax tokenizer
  ↓
Semantic tokens
  ↓
Quiet Paper syntax theme
  ↓
Flutter presentation
```

The original source remains unchanged.

---

# 3. LIBRARY REQUIREMENT

Use the lower-level Dart `highlight` package as the syntax-tokenization engine.

Do NOT use a package-level code editor widget as the primary editor.

Do NOT replace the existing Quiet Paper editor with a third-party code editor.

Do NOT let the third-party package own:

- cursor state
- selection
- editing
- undo/redo
- IME handling
- note serialization
- attachment storage

`highlight` is a tokenizer/highlighting dependency.

Quiet Paper owns presentation and editor behavior.

---

# 4. FIRST STEP — DEPENDENCY AND API VERIFICATION

Before implementation:

1. Inspect the exact `highlight` package version available/compatible with the current project.
2. Verify its current API in the installed version.
3. Verify actual grammars available in that exact version.
4. Verify Dart compatibility.
5. Verify Flutter compatibility.
6. Verify package license.
7. Verify offline operation.
8. Verify token/range output capabilities.
9. Verify language aliases.
10. Verify behavior on incomplete/invalid source.
11. Verify performance on realistic code blocks.
12. Verify whether all required grammars can be bundled without unacceptable application-size impact.

Do not assume the package supports a language just because a similarly named grammar exists elsewhere.

Document the exact selected version and supported language inventory.

---

# 5. APPLICATION-LEVEL ABSTRACTION

Create a Quiet Paper-owned abstraction conceptually similar to:

```dart
abstract class SyntaxHighlighter {
  HighlightResult highlight({
    required String source,
    required SyntaxLanguage language,
  });
}
```

The actual API should follow project conventions.

The rest of the application must not depend directly on `highlight`.

Only the implementation adapter should import/use the third-party package.

---

# 6. RESULT MODEL

Define a lightweight immutable result.

Conceptually:

```text
HighlightResult
    sourceLength
    language
    tokens
```

Each token should contain at minimum:

```text
start
end
semanticType
```

where:

- `start`
- `end`

use the project's canonical UTF-16 offset model.

Do not return pre-colored Flutter widgets.

---

# 7. TOKEN MODEL

Define a Quiet Paper semantic token vocabulary.

At minimum:

```text
plain
keyword
string
number
comment
function
method
type
className
variable
constant
operator
punctuation
property
attribute
tag
builtin
literal
regexp
annotation
meta
heading
link
```

The exact internal enum may be smaller or more complete depending on the `highlight` package output.

The critical rule is:

> Third-party token classifications must be normalized into Quiet Paper semantic categories.

Do not leak package-specific token names through the entire application.

---

# 8. TOKEN NORMALIZATION

Different grammars may use different token scopes.

Create a deterministic mapping:

```text
highlight token
      ↓
QuietPaperSyntaxTokenType
```

Unknown token categories must fall back safely to:

```text
plain
```

Do not discard source text if the library reports an unfamiliar token.

---

# 9. UTF-16 OFFSET REQUIREMENT

Flutter selection offsets are UTF-16-based.

All token ranges consumed by the editor must use the same offset model.

Verify with source containing:

- emoji
- accented characters
- CJK
- combining marks
- non-BMP Unicode

Example:

```text
😀 final value = 42;
```

Token ranges after the emoji must remain correct.

Do not assume:

```text code-point offset == Dart/Flutter string offset
```

without verification.

---

# 10. TOKEN RANGE VALIDATION

Before producing presentation spans:

- ensure `0 <= start <= end <= source.length`
- reject/repair invalid ranges safely
- ensure ranges don't create impossible overlaps
- ensure every source region remains representable

Never let malformed highlight output crash the editor.

---

# 11. LANGUAGE REGISTRY

Create a centralized registry:

```text
SyntaxLanguageRegistry
```

which maps:

- canonical language identifier
- aliases
- file extensions
- MIME types
- display name

Example:

```text
dart
aliases: dart
extensions: .dart
```

```text
python
aliases: py, python
extensions: .py
```

Do not scatter language mappings throughout the codebase.

---

# 12. LANGUAGE RESOLUTION PRIORITY

Use this order:

## Markdown fenced code blocks

```text
explicit fence language
    ↓
normalized alias
    ↓
known grammar
```

If no language is specified:

```text
plain text
```

Do not guess a language from code when the fence explicitly says `text`.

---

# 13. ATTACHMENT LANGUAGE RESOLUTION

For attached code/text files:

1. explicit viewer override, if any
2. MIME type
3. file extension
4. content heuristic only if safely implemented
5. plain text fallback

Do not allow weak heuristics to override a strong explicit signal.

---

# 14. LANGUAGE OVERRIDE

For unknown text attachments, allow a temporary display override where useful:

```text
View as…
    Plain Text
    Python
    JavaScript
    JSON
    ...
```

This changes only presentation.

It does NOT:

- rename the file
- change MIME type
- change extension
- change file bytes

---

# 15. SUPPORTED LANGUAGE STRATEGY

Support a broad practical language set.

The exact availability must be verified against the selected `highlight` package version.

Target at least the following categories.

---

# 16. CORE MOBILE/WEB LANGUAGES

Must support where grammars exist:

```text
Dart
JavaScript
TypeScript
HTML/XML
CSS
JSON
YAML
SQL
Shell/Bash
```

---

# 17. GENERAL-PURPOSE LANGUAGES

Target:

```text
Python
Java
Kotlin
Swift
C
C++
C#
Go
Rust
PHP
Ruby
```

---

# 18. DATA/CONFIG LANGUAGES

Target:

```text
JSON
JSON5 if supported
YAML
TOML
INI
XML
CSV/plain data where applicable
GraphQL if supported
```

Do not claim a grammar exists unless verified.

---

# 19. DATABASE / QUERY LANGUAGES

Target:

```text
SQL
GraphQL
```

plus other well-supported query syntaxes available in the selected package.

---

# 20. WEB LANGUAGES

Target:

```text
HTML
CSS
SCSS/Sass where supported
JavaScript
TypeScript
```

---

# 21. SCRIPTING

Target:

```text
Bash
Shell
PowerShell where supported
Lua
Perl
```

where grammars are available and of acceptable quality.

---

# 22. MODERN LANGUAGES

Where supported:

```text
Rust
Go
Swift
Kotlin
Dart
TypeScript
```

These should receive high testing priority.

---

# 23. LEGACY/OTHER LANGUAGES

If the selected package provides stable grammars for additional popular languages, make them available through the registry without requiring a rewrite.

Do not manually implement grammars.

---

# 24. UNKNOWN LANGUAGE FALLBACK

If the language is unsupported:

```text
plain monospace text
```

must be shown.

No warning should make the code unreadable.

Do not display package-level error text inside the note.

---

# 25. SYNTAX THEME

Create a Quiet Paper-owned:

```text
SyntaxTheme
```

which maps:

```text
semantic token
    ↓
TextStyle
```

Do not put raw colors in the highlighter.

Example categories:

```text
keyword
string
comment
number
function
type
operator
punctuation
property
constant
```

---

# 26. RESTRAINED COLOR PALETTE

Do not use a rainbow syntax theme.

Quiet Paper's syntax highlighting must remain editorial and restrained.

Prefer approximately:

- primary text
- muted text
- accent emphasis
- secondary accent
- subtle comment
- subtle literal/string distinction

Avoid excessive saturation.

---

# 27. DARK THEME

Create a carefully tuned dark syntax theme.

Do not simply invert light-theme RGB values.

Verify:

- comments remain readable
- strings remain distinguishable
- keywords don't overpower the code
- search highlights remain visible
- selection remains visible

---

# 28. LIGHT THEME

The light theme should:

- preserve strong readability
- remain restrained
- fit the existing Quiet Paper palette
- avoid neon syntax colors

---

# 29. THEME SEPARATION

Keep:

```text
tokenization
```

separate from:

```text
theme styling
```

Changing themes must not require re-tokenizing source.

---

# 30. TOKEN CACHE

Cache tokenization results where useful.

Suggested cache key:

```text
language
+
source hash
+
highlighter version
```

Do not include theme in the tokenization cache key.

Theme changes should reuse tokens.

---

# 31. STYLING CACHE

If styling spans are cached, use a separate cache key that includes:

```text
theme version
```

Do not return stale colors after theme changes.

---

# 32. CACHE SIZE

Do not permit an unbounded cache.

Use:

- LRU
- bounded entry count
- bounded total memory

or the application's existing cache abstraction.

---

# 33. LARGE DOCUMENT PERFORMANCE

The application already has large-document safeguards because full-document Markdown parsing/styling becomes expensive for large notes.

Syntax highlighting must respect those safeguards.

Do NOT:

```text
every keystroke
→ tokenize every code block
→ rebuild entire note
```

---

# 34. ACTIVE CODE BLOCK HIGHLIGHTING

Prioritize the code block being edited.

If practical:

```text
active/visible code block
→ full highlighting

off-screen unchanged code blocks
→ cached/lightweight representation
```

---

# 35. INCREMENTAL INVALIDATION

When the user edits inside a code block:

- invalidate only the affected code block
- re-highlight that block
- preserve highlighting for unrelated blocks

Do not unnecessarily re-highlight the entire document.

---

# 36. LARGE CODE BLOCKS

Test:

```text
10 lines
100 lines
1,000 lines
10,000 lines
```

Do not assume code is always small.

---

# 37. VERY LARGE CODE BLOCKS

For very large blocks:

- use safe fallback behavior if tokenization becomes too expensive
- keep text editable
- preserve monospace
- preserve whitespace
- never freeze the editor

If highlighting is skipped temporarily, the user must still be able to edit the code normally.

---

# 38. BACKGROUND HIGHLIGHTING

Use background computation only when justified by profiling.

A practical strategy may be:

```text
small block
→ synchronous

large block
→ background isolate
```

Do not add isolate overhead to every tiny code fragment.

---

# 39. ASYNC HIGHLIGHT RACE PROTECTION

If highlighting is asynchronous:

```text
request #10
request #11
```

and #10 finishes after #11:

discard #10.

Use a monotonic request/generation ID.

Never allow stale highlighting to overwrite newer source.

---

# 40. SOURCE VERSION VALIDATION

An async highlight result must only be applied if the result corresponds to the currently displayed source version.

Use:

```text source hash
```

or:

```text editor generation
```

or equivalent.

---

# 41. EDITOR INTEGRATION

Integrate highlighting with the existing Markdown editor.

Do not replace:

- `TextEditingController`
- `MarkdownEditingController`
- `MarkdownTextInputFormatter`
- `MarkdownFormatter`
- selection logic
- undo/redo

The current architecture preserves Markdown source/cursor mapping and has explicit source-preserving formatting infrastructure. Extend it rather than replacing it.

---

# 42. CODE BLOCK PRESENTATION

For a Markdown code block:

````markdown id="o1c1p9"
```dart
final note = await repository.getNote(id);
```
````

visually:

- keep the code fence
- keep the language identifier
- make syntax markers subdued
- highlight code body
- use code font
- preserve whitespace

Do not completely remove fences from the editor.

---

# 43. FENCE STYLING

Opening/closing fences:

```text
```
```

should be muted.

Language label:

```text
dart
```

should also be visually secondary.

Code body receives syntax highlighting.

---

# 44. CODE BLOCK BACKGROUND

Use a subtle code-block surface.

Do not create a visually heavy IDE panel.

Do not use giant borders.

---

# 45. INLINE CODE

Do NOT run the full syntax highlighter on:

```markdown
`const x = 1`
```

This is inline Markdown code.

Use existing inline-code styling.

---

# 46. CODE BLOCK DETECTION

Use existing Markdown code-block semantics.

Do not rediscover fences with a second conflicting parser.

---

# 47. LANGUAGE LABEL EDITING

If the existing editor allows language identifiers or you add a contextual language selector:

Changing:

````markdown
```text
````

to:

````markdown
```dart
````

must:

- mutate only the fence/language portion
- be one undoable edit
- preserve code
- immediately update highlighting

---

# 48. LANGUAGE SELECTOR UI

Inside an active code block, allow:

```text
Language: Dart ▾
```

through the contextual UI.

Do not put the language selector permanently in the global formatting toolbar.

---

# 49. MOBILE LANGUAGE SELECTOR

Use a compact searchable bottom sheet.

Example:

```text
Code Language

Search…

Dart
Python
JavaScript
TypeScript
JSON
YAML
SQL
...
```

---

# 50. DESKTOP LANGUAGE SELECTOR

Use a compact popover/dropdown.

---

# 51. NO AUTO LANGUAGE REWRITING

Do not automatically change a user's explicit language identifier based on guessed source syntax.

Explicit user choice wins.

---

# 52. ATTACHMENT VIEWER INTEGRATION

Integrate the same highlighting service into the Phase 2A text attachment viewer.

For:

```text
server.dart
```

display:

```text
Dart Source

1  class Server {
2    ...
3  }
```

with syntax highlighting.

---

# 53. ATTACHMENT VIEWER MUST REMAIN READ-ONLY

The code attachment viewer must not become an editor.

Do not add:

- editing
- code formatting
- compilation
- execution
- linting

---

# 54. ATTACHMENT CODE VIEWER CONTROLS

Support existing Phase 2A controls:

- search
- copy
- select
- wrap toggle
- line numbers
- open externally
- share
- save as

Syntax highlighting is purely presentation.

---

# 55. ATTACHMENT LANGUAGE DISPLAY

Display detected language:

```text
server.dart
Dart Source
```

Unknown:

```text
server.xyz
Plain Text
```

---

# 56. ATTACHMENT LANGUAGE OVERRIDE

Allow presentation override only when useful.

Example:

```text
View as → Python
```

This must not alter attachment metadata.

---

# 57. ATTACHMENT SEARCH + HIGHLIGHTING

Search matches must overlay syntax highlighting.

Example:

```text
keyword styling
+
search match emphasis
```

Search must remain visually stronger.

Do not completely destroy syntax styling for the entire line.

---

# 58. SEARCH OFFSET INTEGRITY

Search match offsets remain offsets into source text.

Do not search token arrays.

Do not convert searches into visual coordinates.

---

# 59. SELECTION

Text selection must continue to operate on source offsets.

Syntax styling must not interfere with:

- cursor
- selection
- copy
- delete
- IME

---

# 60. COPY

Copy must return the original source text.

No colors.

No HTML.

No token markup.

No line numbers.

---

# 61. IME COMPATIBILITY

The current editor already has protections around Android composing text and whitespace/caret behavior.

Syntax highlighting must never rewrite the source merely to apply styling.

During IME composition:

```text
source remains unchanged
```

and only presentation updates.

---

# 62. COMPOSING REGION

Do not make highlighting transformations alter the `composing` range.

---

# 63. INCOMPLETE CODE

Highlight incomplete source safely.

Examples:

```dart
final value = "
```

```dart
/* comment
```

```python
def something(
```

No crashes.

---

# 64. INVALID CODE

Syntax highlighting is not compilation.

Do not:

- reject code
- show compiler errors
- rewrite invalid syntax
- refuse highlighting because code doesn't compile

Best effort is the goal.

---

# 65. MULTILINE STRINGS

Test languages with:

- multiline strings
- nested quotes
- raw strings
- template strings

where the grammar supports them.

---

# 66. COMMENTS

Verify:

- line comments
- block comments
- documentation comments

remain readable.

---

# 67. REGEX

Where supported:

```text
regex literals
```

should receive appropriate syntax categories.

---

# 68. EMBEDDED LANGUAGES

Do not manually reinvent embedded-language parsing.

Use whatever the verified `highlight` grammar correctly supports.

---

# 69. MARKDOWN SOURCE HIGHLIGHTING

Do not require full Markdown syntax highlighting in this phase unless the selected grammar supports it naturally.

The primary requirement is:

> code blocks inside Markdown notes.

Markdown source-view highlighting is useful later.

---

# 70. Markdown CODE BLOCK EXAMPLES

Test at minimum:

```markdown
```dart
final value = 42;
```
```

```markdown
```python
print("hello")
```
```

```markdown
```javascript
const value = 42;
```
```

```markdown
```typescript
interface User {
  id: string;
}
```
```

```markdown
```json
{"name": "Quiet Paper"}
```
```

```markdown
```yaml
name: Quiet Paper
```
```

```markdown
```sql
SELECT * FROM notes;
```
```

```markdown
```bash
echo "hello"
```
```

---

# 71. ATTACHMENT EXAMPLES

Test at minimum:

```text
server.dart
script.py
app.js
types.ts
config.json
config.yaml
query.sql
deploy.sh
Main.kt
server.go
main.rs
```

---

# 72. FONT

Use the existing code font configuration.

The application already distinguishes body and code fonts, including configurable bundled code fonts such as JetBrains Mono/Fira Code.

Do not add a new font just for syntax highlighting unless absolutely required.

---

# 73. FONT FALLBACK

If configured code font doesn't support a glyph:

use the existing font fallback strategy.

Do not replace Unicode characters with ASCII merely because highlighting is active.

---

# 74. TOKEN + FONT INTERACTION

Every token type must remain legible with the configured code font.

Don't assume a token category means the same visual weight across fonts.

---

# 75. LINE NUMBERS

For attached code files:

support line numbers.

For Markdown code blocks:

line numbers may remain off by default unless the existing UI has a clear place for enabling them.

Keep the note editor visually clean.

---

# 76. WORD WRAP

Code blocks:

Prefer no wrapping by default.

Attached source:

Prefer no wrapping by default.

Users can enable wrapping through contextual viewer settings where supported.

---

# 77. HORIZONTAL SCROLLING

When wrap is disabled:

- preserve long lines
- allow horizontal scrolling
- do not shrink font
- do not truncate source

---

# 78. CODE BLOCK HEIGHT

Do not impose a fixed height that clips content.

Long code blocks should flow naturally with the note.

---

# 79. MARKDOWN EDITOR PAGE FLOW

A code block must not create unnecessary blank space or page-like layout artifacts inside the editor.

The editor remains one continuous document.

---

# 80. ATTACHMENT VIEWER LARGE FILES

A 20 MB source file should not require:

```text
20 MB source
+
multiple full copies
+
multiple token arrays
```

simultaneously if avoidable.

Use bounded/lazy strategies for large files.

---

# 81. ATTACHMENT VIEWER VIRTUALIZATION

For large source files:

- use efficient rendering
- don't create one widget per line unnecessarily
- avoid rebuilding the entire visible document when search moves

---

# 82. HIGHLIGHTING LARGE FILE THRESHOLD

Define a configurable internal threshold.

For very large source files:

```text
large file
→ plain monospace fallback or bounded highlighting
```

provided the user can still read/search/copy the content.

---

# 83. GRACEFUL HIGHLIGHTING FAILURE

If the highlighter fails:

```text
plain monospace source
```

must immediately be available.

Never make the attachment inaccessible because highlighting failed.

---

# 84. PACKAGE EXCEPTION HANDLING

Catch grammar/tokenization exceptions.

Record safe diagnostics.

Do not show stack traces to users.

---

# 85. LANGUAGE GRAMMAR FAILURE

If one language grammar fails:

fallback to plain text for that block/file.

Do not break all syntax highlighting globally.

---

# 86. CACHE FAILURE

If cache operations fail:

highlight directly.

Do not make caching a prerequisite for functionality.

---

# 87. THEME CHANGE

When user switches:

```text
light ↔ dark
```

the code should update immediately.

Do not re-tokenize source unnecessarily.

---

# 88. TEXT SIZE CHANGE

When body/code font size changes:

rebuild presentation styles.

Do not re-tokenize source.

---

# 89. SEARCH CHANGE

Search highlight changes must not invalidate syntax tokenization.

---

# 90. SOURCE CHANGE

Source changes invalidate highlighting only for the affected region/block where practical.

---

# 91. ATTACHMENT HASH

For code attachment caching:

use the Phase 1 content hash.

Don't hash decoded strings if the goal is content identity.

Derived highlight cache may use:

```text
contentHash
language
highlighterVersion
```

---

# 92. ATTACHMENT MODIFICATION

If attachment bytes change in a future version:

new hash automatically invalidates highlight cache.

Phase 2A attachment content remains immutable.

---

# 93. NO DATABASE STORAGE OF TOKENS

Do not create:

```text
attachment_highlight_tokens
```

or equivalent.

Tokens are derived runtime data.

---

# 94. NO DATABASE STORAGE FOR CODE LANGUAGE OVERRIDE

If language override is temporary:

keep it UI state.

If persistent user preference is later desired, design it separately.

Do not modify attachment MIME/type merely because the viewer was overridden.

---

# 95. NOTE CONTENT SERIALIZATION

The Markdown source written to the database remains exactly the normal source string.

No syntax-highlight metadata.

---

# 96. NOTE SYNC

Syntax highlighting must have zero effect on sync payloads.

---

# 97. NOTE VERSION HISTORY

Syntax highlighting changes must not create revisions.

Changing a language fence identifier does create a normal Markdown revision.

---

# 98. SEARCH INDEX

Syntax highlighting must not modify FTS/search indexing.

Search continues to operate on canonical/derived searchable text.

---

# 99. TABLE INTEGRATION

Syntax highlighting must not break the hybrid Markdown table editor.

Inside table cells:

```text inline code
```

uses existing inline-code presentation.

Do not run full syntax highlighting across table cells.

---

# 100. IMAGE/CHECKLIST/OTHER BLOCKS

No regression to:

- images
- checklists
- links
- lists
- headings
- quotes
- tables

---

# 101. CODE-FENCE SAFETY

Existing code-fence rules must continue to control:

- list continuation
- quote continuation
- Markdown formatting suppression
- delimiter behavior

Do not duplicate those rules in the highlighter.

---

# 102. EDITOR TOOLBAR

If the editor already has a contextual code-block toolbar:

extend it with:

```text
Language
```

if appropriate.

Do not add syntax theme controls to the main toolbar.

---

# 103. SYNTAX HIGHLIGHTING TOGGLE

Do NOT initially expose a global toggle unless the product already has a suitable preference architecture.

Default:

> highlighting enabled.

A fallback mode may be used automatically on low-resource/large documents.

---

# 104. ACCESSIBILITY

Syntax coloring must not be the only way to distinguish code categories.

Text remains readable without colors.

Selection and search highlights must remain clear.

---

# 105. SCREEN READERS

The semantic text content should be exposed, not token names.

Do not announce:

```text keyword final string...
```

to users.

---

# 106. ACCESSIBILITY TEXT ORDER

Syntax highlighting must not alter reading order.

---

# 107. DESKTOP FOCUS

Highlighting must not affect normal keyboard focus behavior.

---

# 108. ATTACHMENT VIEWER SEARCH SHORTCUT

Where the existing viewer supports it:

```text
Ctrl/Cmd+F
```

searches the code/text.

---

# 109. COPY SHORTCUT

```text
Ctrl/Cmd+C
```

copies source text exactly.

---

# 110. LANGUAGE SELECTOR KEYBOARD ACCESS

The language selector must be keyboard accessible.

---

# 111. TEST LANGUAGE ALIASES

Test:

```text
js → javascript
py → python
ts → typescript
sh → shell/bash
yml → yaml
```

where the grammar supports those aliases.

---

# 112. TEST FILE EXTENSIONS

Verify resolution for each supported language's common extensions.

---

# 113. TEST MIME TYPES

Verify common MIME mappings where available.

---

# 114. TEST UNKNOWN EXTENSION

Example:

```text
mystery.foo
```

with text contents.

Expected:

```text plain text
```

---

# 115. TEST EXPLICIT UNKNOWN FENCE

````markdown
```foobar
some content
```
````

Expected:

```text plain monospace code block
```

No crash.

---

# 116. TEST PLAIN FENCE

````markdown
```
some content
```
````

Expected:

```text plain monospace code
```

No automatic guessing.

---

# 117. TEST INCOMPLETE FENCE

While typing:

````markdown
```dart
final value =
````

must remain editable and readable.

---

# 118. TEST CLOSED FENCE

Verify highlighting appears once the block becomes parseable.

Do not lose source characters during the transition.

---

# 119. TEST FENCE LANGUAGE CHANGE

Change:

````markdown
```python
````

to:

````markdown
```javascript
````

Verify:

- source changed only in language identifier
- highlighting updates
- undo restores Python
- code content is unchanged

---

# 120. TEST EDIT INSIDE CODE

Type into a highlighted block.

Verify:

- text correct
- caret correct
- composition correct
- highlighting updates
- no character loss

---

# 121. TEST SELECTION INSIDE CODE

Select text.

Verify:

- selection overlay is clear
- source offsets correct
- copy correct

---

# 122. TEST DELETE

Delete characters across token boundaries.

Example:

```text
keyword | identifier | operator
```

No stale token rendering.

---

# 123. TEST PASTE

Paste highlighted-looking code.

Do not paste colors.

Source remains plain text.

---

# 124. TEST UNDO/REDO

Typing and formatting must use the existing editor undo/redo system.

Highlighting itself must never add undo entries.

---

# 125. TEST SEARCH

Search inside:

- code block
- attached code file

Verify matches.

---

# 126. TEST SEARCH + SYNTAX

Search highlight must overlay syntax styling correctly.

---

# 127. TEST THEME SWITCH

Highlight code.

Switch dark/light.

Verify styles update without changing source.

---

# 128. TEST FONT SWITCH

Change code font.

Verify highlighting remains.

---

# 129. TEST LARGE BLOCK

Use a 10,000-line code block.

Verify:

- editor remains usable
- highlighter does not hang
- source can still be edited
- fallback works if necessary

---

# 130. TEST MANY BLOCKS

Create a note with 100 code blocks.

Verify:

- no massive startup delay
- only relevant blocks are highlighted eagerly
- cache works
- scrolling remains responsive

---

# 131. TEST ATTACHMENT FILES

Open:

```text
.dart
.py
.js
.ts
.json
.yaml
.xml
.sql
.sh
.rs
.go
.java
.kt
.swift
.cpp
.c
.cs
.php
.rb
```

where supported by the selected grammar set.

---

# 132. TEST MALFORMED CODE

Use intentionally malformed source.

Verify no crash/hang.

---

# 133. TEST UNICODE CODE

Example:

```dart
final greeting = "こんにちは 😀";
```

Verify:

- token ranges
- selection
- highlighting
- copy

---

# 134. TEST VERY LONG LINE

Use a line >10,000 characters.

Verify no pathological layout.

---

# 135. TEST LONG STRING

Test multiline/large string literals.

---

# 136. TEST COMMENTS

Verify comments don't interfere with the rest of the line.

---

# 137. TEST NESTED SYNTAX

Use representative code with:

- strings
- comments
- operators
- nested braces
- generics
- annotations

---

# 138. VISUAL QA — EDITOR

Inspect:

```text
Dart
Python
JavaScript
TypeScript
JSON
YAML
SQL
```

inside Markdown code blocks.

The result should feel consistent with Quiet Paper.

---

# 139. VISUAL QA — ATTACHMENTS

Inspect:

```text
server.dart
config.json
deploy.sh
```

in attachment viewer.

Same syntax theme.

---

# 140. VISUAL QA — DARK

Verify all core languages in dark mode.

---

# 141. VISUAL QA — LIGHT

Verify all core languages in light mode.

---

# 142. VISUAL QA — QUIET PAPER DESIGN

Avoid:

- neon colors
- huge code panels
- excessive borders
- VS Code clone styling
- terminal-like chrome

The code remains part of a writing application.

---

# 143. PDF/HTML FUTURE COMPATIBILITY

Do not implement export integration as a requirement of this phase.

However, keep token semantics independent from Flutter widgets so future export renderers can consume:

```text
semantic tokens
```

without depending on `TextSpan`.

---

# 144. CODE BLOCK EXPORT

The current PDF/HTML systems should continue to work.

Do not alter export architecture merely to add highlighting.

Future export integration can consume the same syntax-token model.

---

# 145. DEPENDENCY ISOLATION

Only the syntax-highlighter adapter should know about `highlight`.

This allows future replacement without touching:

- editor
- attachment viewer
- search
- theme

---

# 146. NO PACKAGE-SPECIFIC TOKEN LEAKAGE

Do not create application APIs such as:

```text HighlightJsMode
```

or:

```text HighlightJsToken
```

when the engine is abstracted as `SyntaxToken`.

---

# 147. HIGHIGHTER VERSION

Expose an application-level version constant for cache invalidation:

```text syntaxHighlighterVersion
```

When the grammar/package mapping changes:

invalidate cached tokens.

---

# 148. LANGUAGE REGISTRY VERSION

If supported language mapping changes:

bump registry version.

---

# 149. THEME VERSION

Changing token colors should invalidate styled output but not tokenization.

---

# 150. PERFORMANCE METRICS

Developer diagnostics may record:

- language
- source length
- token count
- duration
- cache hit/miss
- fallback

Do not log source contents.

---

# 151. SECURITY

Syntax highlighting must never:

- execute source code
- evaluate code
- make network requests
- invoke compilers
- execute macros
- load arbitrary resources

It is tokenization only.

---

# 152. HTML/Markdown SECURITY

Even if the language is HTML:

the source attachment remains text.

Do not execute HTML in the code viewer.

---

# 153. JAVASCRIPT SECURITY

JavaScript source files remain source text.

Do not execute them.

---

# 154. YAML SECURITY

Highlight YAML as text.

Do not construct arbitrary application objects.

---

# 155. SQL SECURITY

Highlight SQL as text.

Do not execute queries.

---

# 156. SHELL SECURITY

Highlight shell scripts as text.

Do not execute them.

---

# 157. SOURCE ATTACHMENT IMMUTABILITY

Syntax highlighting must never modify file bytes.

---

# 158. ATTACHMENT HASH INVARIANT

Opening/highlighting/searching a code attachment must never change:

```text
contentHash
```

---

# 159. VIEWER CACHE INVARIANT

Any highlight cache is disposable.

Deleting cache must not affect attachment functionality.

---

# 160. CACHE CORRUPTION

Corrupt cache entries must be ignored/rebuilt.

Do not treat cache corruption as source corruption.

---

# 161. TEST CACHE INVALIDATION

Verify:

```text source unchanged
+
theme changed
→ reuse tokens

source changed
→ re-tokenize

language changed
→ re-tokenize

highlighter version changed
→ re-tokenize
```

---

# 162. ATTACHMENT HASH CACHE TEST

Verify:

```text same file
→ cache hit
```

```text different bytes
→ cache miss
```

---

# 163. TEST UNKNOWN LANGUAGE CACHE

Unknown language should safely resolve to plain text without repeatedly causing errors.

---

# 164. TEST HIGHLIGHTER FAILURE

Force the highlighter to throw in a test.

Expected:

```text plain text fallback
```

and viewer/editor remains usable.

---

# 165. TEST ASYNC RACE

Start highlight A.

Modify source.

Start highlight B.

Make A finish after B.

Expected:

```text B displayed
A discarded
```

---

# 166. TEST DISPOSE RACE

Start highlighting.

Close editor/viewer.

Async result completes.

Expected:

- no setState-after-dispose
- no memory leak
- no stale render

---

# 167. TEST NOTE SWITCH

Switch notes while highlighting.

The previous note's result must never appear in the new note.

---

# 168. TEST ATTACHMENT SWITCH

Open attachment A.

Navigate to attachment B.

A's asynchronous highlight result must not appear in B.

---

# 169. DOCUMENTATION

Update `HANDOFF.md` or equivalent engineering documentation with:

- chosen `highlight` version
- architecture
- language registry
- supported languages
- aliases
- token model
- theme model
- cache model
- performance strategy
- fallback behavior
- editor integration
- attachment integration
- security rules

---

# 170. DO NOT DOCUMENT UNSUPPORTED LANGUAGES AS SUPPORTED

The language list must come from the actual verified grammar inventory.

---

# 171. TEST DEPENDENCY UPGRADE

If the dependency is upgraded later:

the test suite should detect unexpected grammar/token behavior changes where practical.

---

# 172. CODE ORGANIZATION

Prefer a structure conceptually like:

```text
lib/core/syntax/
    domain/
        syntax_language.dart
        syntax_token.dart
        syntax_token_type.dart
        syntax_theme.dart
        highlight_result.dart

    application/
        syntax_highlighter.dart
        syntax_language_registry.dart
        syntax_language_resolver.dart
        syntax_highlight_cache.dart

    infrastructure/
        highlight_package_adapter.dart

    presentation/
        syntax_text_spans.dart
```

Adapt this to the actual project structure.

Do not blindly create these exact files.

---

# 173. EDITOR INTEGRATION FILES

Integrate with the existing editor modules rather than replacing them.

Likely areas include:

- Markdown editor
- Markdown parser/presentation
- code block rendering
- formatting toolbar
- contextual toolbar
- search/highlight rendering

Inspect the actual code first.

---

# 174. ATTACHMENT INTEGRATION FILES

Integrate with:

- attachment capability resolver
- text attachment viewer
- source/code viewer
- attachment search
- attachment actions

Use the existing Phase 2A infrastructure.

---

# 175. DO NOT CREATE A SECOND TEXT VIEWER

If Phase 2A already has a reusable text viewer, extend it.

Do not create:

```text
CodeAttachmentViewer
TextAttachmentViewer
SyntaxAttachmentViewer
```

as three unrelated viewers.

Use capability-driven rendering.

---

# 176. DO NOT CREATE A SECOND SEARCH IMPLEMENTATION

Use existing viewer search.

Syntax highlighting only modifies presentation.

---

# 177. DO NOT CREATE A SECOND COPY IMPLEMENTATION

Use existing text selection/copy behavior.

---

# 178. DO NOT CREATE A SECOND FONT SYSTEM

Use existing typography configuration.

---

# 179. DO NOT CREATE A SECOND THEME SYSTEM

SyntaxTheme should integrate with existing app theme.

---

# 180. TESTING — UNIT

Unit tests must cover:

### Language registry

- canonical names
- aliases
- extensions
- MIME mappings

### Token normalization

- known token categories
- unknown token fallback

### UTF-16 ranges

- ASCII
- Unicode
- emoji
- combining marks

### Cache

- hit
- miss
- invalidation

---

# 181. TESTING — EDITOR

Widget/integration tests:

- code block highlighted
- language selector
- source unchanged
- typing works
- selection works
- search works
- undo/redo works
- theme switch works

---

# 182. TESTING — ATTACHMENTS

Widget/integration tests:

- Dart file highlighted
- JSON highlighted
- unknown file falls back
- search works
- copy works
- line numbers work
- wrap works
- open/share remain functional

---

# 183. TESTING — REGRESSION

Run complete suite.

Especially verify:

- Markdown editor
- table editor
- search
- OCR
- attachments
- sync
- backup
- export

---

# 184. NO REGRESSION TO HYBRID TABLES

The syntax highlighter must not interfere with the recently implemented hybrid table editor.

Tables use inline Markdown rendering, not full code highlighting.

---

# 185. NO REGRESSION TO OCR

OCR remains independent.

Do not send OCR text into syntax highlighting.

---

# 186. NO REGRESSION TO PDF

PDF export must continue to work even if syntax highlighting fails.

---

# 187. NO REGRESSION TO SYNC

Highlighting must have no effect on sync payloads.

---

# 188. NO REGRESSION TO VERSIONING

Presentation changes do not create note versions.

---

# 189. NO REGRESSION TO LARGE DOCUMENT MODE

Preserve the current high-performance mode for very large notes.

---

# 190. MANUAL QA FIXTURE

Create a representative Markdown note:

````markdown
# Syntax Highlighting Test

## Dart

```dart
final note = await repository.getNote(id);
print(note);
```

## Python

```python
def hello(name):
    return f"Hello {name}"
```

## JavaScript

```javascript
const value = {
  name: "Quiet Paper",
  enabled: true,
};
```

## TypeScript

```typescript
interface Note {
  id: string;
  title: string;
}
```

## JSON

```json
{
  "name": "Quiet Paper",
  "enabled": true,
  "count": 42
}
```

## YAML

```yaml
name: Quiet Paper
enabled: true
```

## SQL

```sql
SELECT id, title
FROM notes
WHERE deleted = 0;
```

## Bash

```bash
echo "Hello"
```

## Invalid Code

```dart
final broken = ;
```
````

Verify every block.

---

# 191. ATTACHMENT QA FIXTURE SET

Use:

```text
server.dart
script.py
app.js
types.ts
config.json
config.yaml
query.sql
deploy.sh
Main.kt
server.go
main.rs
```

where supported.

---

# 192. VISUAL ACCEPTANCE

The final code presentation should feel:

> **Quiet Paper + syntax-aware writing**

not:

> **VS Code embedded inside Quiet Paper**.

Code should remain visually subordinate to the document.

---

# 193. TOKEN COLOR ACCEPTANCE

Color should improve scanning without making the code visually noisy.

A user should still be able to read the code comfortably when converted to grayscale.

---

# 194. NO GIGANTIC SYNTAX PALETTE

Even if the tokenizer produces dozens of semantic categories, map many of them to a smaller set of coherent Quiet Paper styles.

---

# 195. FALLBACK ACCEPTANCE

Any unsupported language/file must remain readable.

The guarantee is:

```text
unsupported highlighting
≠
unsupported file
```

---

# 196. OFFLINE ACCEPTANCE

Syntax highlighting must work fully offline.

No remote grammar downloads.

No CDN.

No web service.

---

# 197. BUNDLE ACCEPTANCE

Verify application bundle/size impact is acceptable.

If the package includes many grammars, determine whether selective language registration or lazy loading is practical.

Do not sacrifice app startup unnecessarily.

---

# 198. STARTUP ACCEPTANCE

The application must not eagerly tokenize all possible languages or all documents at startup.

---

# 199. MEMORY ACCEPTANCE

Do not keep all grammar/token data and all highlighted documents permanently in memory.

---

# 200. FINAL DEFINITION OF DONE

The feature is complete only when:

### Shared system

- `highlight` is isolated behind Quiet Paper's abstraction
- semantic tokens are defined
- UTF-16 ranges are correct
- syntax theme exists
- language registry exists
- language resolver exists
- caching exists
- fallback exists

### Markdown

- fenced code blocks are highlighted
- declared language is respected
- language aliases work
- plain fences remain plain
- unknown languages remain readable
- incomplete code works
- invalid code works
- source remains unchanged
- cursor/selection work
- IME works
- search works
- undo/redo work
- theme changes work

### Attachments

- source-code attachments are highlighted
- JSON/YAML/etc. are highlighted where supported
- unknown text falls back
- language can be overridden for viewing where implemented
- line numbers work
- search works
- copy works
- wrap works
- original bytes remain unchanged
- hash remains unchanged
- Open With/Share/Save As remain functional

### Performance

- small blocks are fast
- large blocks do not freeze UI
- caching works
- stale async results are discarded
- many code blocks remain performant
- large attachments are handled safely
- large-note protections remain intact

### Security

- source is never executed
- no network grammar loading
- no HTML execution
- no shell execution
- no database persistence of tokens
- no token/content logging
- protected notes remain protected

### Regression

- tables remain functional
- Markdown remains functional
- attachments remain functional
- search remains functional
- sync remains functional
- backup remains functional
- export remains functional
- OCR remains functional

### Quality

- `flutter analyze` passes with zero errors/warnings
- full test suite passes
- new syntax-highlighting tests pass
- manual QA is complete
- light/dark mode is verified
- phone/tablet/desktop layouts are verified where supported

---

# 201. REQUIRED FINAL REPORT

After implementation provide:

```text
Quiet Paper Syntax Highlighting

Library:
- package:
- exact version:
- license:
- grammar inventory:

Architecture:
- abstraction:
- token model:
- language resolver:
- theme:
- cache:

Supported languages:
- ...

Markdown code blocks:
- ...

Attachment code files:
- ...

Fallback behavior:
- ...

Editor integration:
- ...

Attachment integration:
- ...

Search integration:
- ...

IME/selection integration:
- ...

Performance:
- ...

Async/race protection:
- ...

Security:
- ...

Files added:
- ...

Files modified:
- ...

Database changes:
- None / exact changes

Backend changes:
- None / exact changes

Dependencies:
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
```

Do not claim "all languages" or "most languages" without listing the actual verified language inventory.

Do not claim syntax highlighting works for a language unless it was tested or verified against the actual selected grammar.

---

# FINAL ARCHITECTURAL PRINCIPLE

The system must end up conceptually as:

```text
                     SOURCE
                       │
           ┌───────────┴───────────┐
           │                       │
      Markdown code             Attachment
          block                    file
           │                       │
           └───────────┬───────────┘
                       ▼
                Language Resolver
                       │
                       ▼
               Syntax Highlighter
                  (`highlight`)
                       │
                       ▼
                Semantic Tokens
                       │
                ┌──────┴──────┐
                │             │
                ▼             ▼
          Syntax Theme    Search Overlay
                │             │
                └──────┬──────┘
                       ▼
                Quiet Paper UI
```

The important boundaries are:

```text
Source ≠ Highlight tokens
Highlight tokens ≠ Colors
Colors ≠ Document data
```

The canonical Markdown/file bytes remain untouched.

The syntax-highlighting engine is replaceable.

The Quiet Paper theme is owned by Quiet Paper.

The editor owns cursor/selection/IME/undo.

The attachment viewer owns read-only presentation.

The result should make code feel like a **natural part of Quiet Paper's writing environment**, while remaining technically robust enough to support a broad set of popular programming, scripting, configuration, data, and query languages.