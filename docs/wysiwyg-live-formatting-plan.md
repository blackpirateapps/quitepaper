# WYSIWYG Live Inline Formatting — Implementation Plan

Status: Phase 1 + Phase 2 + Phase 2b implemented and tested (see HANDOFF §126)
Owner: editor
Scope: Typora-style live inline formatting in the visual (WYSIWYG) editor.

## Problem

In the visual editor (`SemanticEditorController` + `VisualDocumentEditor`), inline
emphasis only renders when the delimiters are **closed** (`**bold**`). The user wants
Typora-style behavior:

1. Typing `**` then text renders the text **bold immediately**, with the `**` hidden,
   before the closing `**` is typed. Same for `*`/`_` italic, `~~` strike, `==`
   highlight, `` ` `` inline code, `***` bold+italic.
2. Typing the closing delimiter (`**` again) finishes the span.
3. Pressing **Enter while a span is "running"** continues the formatting on the next
   line. **Current bug:** Enter inside a span inserts a bare `\n` between the
   delimiters, so the next line shows the raw `**` and the text is not bold.

Chosen approach (user selected): **Full Typora-style open spans** — an unclosed
opener renders styled with the opener hidden.

## Root causes

- `_inlineRegex` in `semantic_markdown_parser.dart` only matches **closed** emphasis,
  so an unclosed `**bold` falls through to the trailing base case and is emitted as a
  literal `PlainRun("**bold")` — the `**` is visible and nothing is styled.
- `SemanticMutationService.splitBlock` (paragraph case) delegates to
  `insertText(markdown, position, '\n')`, inserting a bare `\n` at the caret's source
  offset. Inside `**bold|text**` this yields `**bold\ntext**` — delimiters stranded
  across the newline (the reported Enter bug).
- `handleVisualBlockTextChange` reconstructs runs and re-serializes via
  `serializeRuns`, which always **closes** styled runs. Content typed while the caret
  sits in a styled run is re-wrapped, so it cannot represent an "open, still-growing"
  span from literal typed delimiters.

## Design

Two independent phases. Phase 2 alone fixes the reported Enter bug; Phase 1 adds the
live open-span rendering. They compose.

### Phase 1 — Parser open-span rendering

File: `lib/features/editor/application/semantic_markdown_parser.dart`

In `_parseInlineRunsInternal`, the `lastIndex == 0` trailing base case (no closed
delimiter matched) currently emits the whole chunk as a single run. Add
`_tryParseOpenEmphasis(content, baseRange, flags...)`:

- Scan for the first **valid unclosed opener**, longest-first:
  `***`/`___` (bold+italic), `**`/`__` (bold), `~~` (strike), `==` (highlight),
  `` ` `` (code), `*`/`_` (italic).
- Validity mirrors `_isValidEmphasis`: opener must be immediately followed by a
  non-whitespace char; `_`/`__`/`___` are rejected intra-word (alnum before the
  opener). Code needs a non-space char after the backtick.
- On a hit at index `i` with delimiter length `dl`:
  - emit `content[0..i]` recursively (inherited flags) as the plain prefix;
  - emit the remainder `content[i+dl..]` as a styled run with the opener **hidden**:
    `sourceRange = [start+i, end]` (includes opener), `contentRange = [start+i+dl, end]`
    (excludes opener). Recurse for nested openers (`outerSourceRange` = the styled
    source range), except `` ` `` which emits a single `InlineCodeRun` (no nesting).
- If no opener is found, keep the existing single-run fallback.

Caret mapping already keys off `contentRange` (`SemanticDocument._findPositionInRuns`
/ `_sourceOffsetInRuns`), so a hidden opener maps correctly: the visible text starts at
`contentRange.start` and the two opener chars occupy source before it.

Terminates: each recursion consumes ≥ `dl` chars or a strictly-smaller prefix.

### Phase 2 — Enter continuation (close + reopen)

File: `lib/features/editor/application/semantic_mutation_service.dart`

Add an early branch in `splitBlock`, before the type-specific branches, that fires
when the caret is **strictly inside a styled/code run in source**:

```
srcOff = doc.sourceOffsetAtPosition(position, downstream)
inside = any styled/code run with run.sourceRange.start < srcOff < run.sourceRange.end
```

`srcOff in (start, end)` (exclusive) is true only for a **closed** span whose closing
delimiter sits after the caret (open spans have `sourceRange.end == contentRange.end`,
so a caret at the visible end maps to `end`, which is not `< end`). Open spans keep
the existing bare-`\n` path — Phase 1 renders their continuation line styled.

When inside:

- split the block's runs at the visible caret offset into `leftRuns` / `rightRuns`;
- `line1 = serializeBlockMarkdown(block, leftRuns)` (keeps the block's own prefix:
  `## `, `- `, `> `, `1. `, `- [ ] `);
- `line2 = line2Prefix(block) + serializeRuns(rightRuns)`, where `line2Prefix` is:
  paragraph/heading → `''` (heading splits into a paragraph); quote → `> `;
  list → `{indent}{marker} `; checklist → `{indent}{bullet} [ ] `;
  ordered → `{indent}{n+1}{delim} ` and subsequent siblings are renumbered `+1`;
- replace `block.sourceRange` with `line1 + '\n' + line2` (renumber siblings, which
  are at higher offsets, first so `block.sourceRange` stays valid);
- caret goes to the start of `line2`'s content
  (`blockStart + line1.length + 1 + line2Prefix.length`).

Both halves are now **closed** spans (`**bold**` / `**text**`), which the existing
parser already renders with hidden delimiters — no Phase 1 needed for this path.

### Phase 2b — Active-format carry-over

File: `lib/features/editor/application/semantic_editor_controller.dart`

`splitBlock` captures `_currentFormatsAtCursor` (or `_activeTypingFormats`) before the
mutation and, if styled, re-applies it as `_activeTypingFormats` after the caret moves
to line 2 — so an **empty** continuation line (nothing between the delimiters yet)
still types styled. A one-shot `_retainActiveFormatsOnce` flag makes the `selection`
setter and `updateSelectionFromBlock` skip their usual `_activeTypingFormats = null`
reset for this single transition.

### Typing path — open-span literal insert

File: `semantic_editor_controller.dart`, `handleVisualBlockTextChange`

When `_activeTypingFormats == null` (user did not toggle the toolbar) **and** the caret
sits in a Phase-1 open-ended run (last run is styled/code with
`sourceRange.end == contentRange.end`), bypass run reconstruction for that keystroke
and do a **source-level literal edit**:

```
srcStart = doc.sourceOffsetAtPosition(pos(blockId, editStart))
srcEnd   = doc.sourceOffsetAtPosition(pos(blockId, editEnd))
newMarkdown = markdown.replaceRange(srcStart, srcEnd, insertedText)
updateMarkdownAndRetainSelection(newMarkdown, srcStart + insertedText.length)
```

This keeps `**bold` open through content typing (so a later `**` closes it) instead of
`serializeRuns` auto-closing after the second char. All other cases (toolbar formats
active, plain/closed context) keep the existing run-reconstruction path, which is what
normalizes fragmented markdown and drives the toolbar tests.

## Tests

File: `test/editor/wysiwyg_inline_formatting_test.dart`

- `**x**` renders one bold run, no visible `**` (regression).
- Unclosed `**x` renders a bold open span, no visible `**` (Phase 1); same for
  `*`/`_`, `~~`, `==`, `` ` ``, `***`.
- `**a` + Enter + `b` → both lines bold (Phase 2 continuation via carry + Phase 1).
- Caret inside closed `**bo|ld**` + Enter → `**bo**` / `**ld**` (Phase 2 close+reopen).
- Literal `2 * 3` and a lone `*` stay literal (flanking validity).
- Existing toolbar/normalization tests still pass (run-reconstruction untouched when
  formats are active).

## Workflow (AGENTS.md)

`flutter analyze` + `flutter test` (zero warnings/errors) → update `HANDOFF.md` →
`git add .` → conventional commit → confirm before `git push origin main`.
