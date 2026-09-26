# Quiet Paper — WYSIWYG Editor Remaining Bug Fixes (P2–P3) Implementation Guide

> **Audience:** future coding agents working on the "Editor V4 / Semantic Document Architecture" (the WYSIWYG *Visual Document Editor*).
> **Status (updated 2026-09-26):**
> - **P0 / P1** — implemented, verified, committed (`HANDOFF.md` §118, commit `a96dc59`).
> - **P2 (parser fidelity)** — the actionable items are **DONE** (`HANDOFF.md` §119, commit `bc9b3fa`). P2-1, P2-3, P2-4, P2-5, P2-7 (balanced parens), P2-8, P2-9 shipped. **Deferred:** P2-2 (backslash escapes), P2-6 (setext — out of scope), P2-7 (nested `]` in label).
> - **P3 (autocomplete & UX)** — the actionable items are **DONE** (`HANDOFF.md` §120, commit `bc9b3fa`). P3-1, P3-2, P3-3, P3-4, P3-5, and the safe part of P3-6 shipped. **Deferred:** the three perf-sensitive P3-6 items.
> - **§4 (stable block IDs)** — still **DEFERRED** (not started).
>
> This document is now a **ledger of what remains** plus the original per-item specs (kept for the deferred items and as reference). Read §0.1 first for the short list of open work.

---

## 0. Orientation — read this first

The WYSIWYG editor keeps **canonical Markdown as the single source of truth**. It is parsed into a `SemanticDocument` AST in which every node carries a `SourceRange`, and each block renders into its own Flutter `TextField` driven by a per-block plain-text controller. Bugs cluster in four seams:

1. **Parser** — `lib/features/editor/application/semantic_markdown_parser.dart` (source-range & caret mapping).
2. **Mutation service** — `lib/features/editor/application/semantic_mutation_service.dart` (surgical source edits).
3. **Visual widget / controller** — `lib/features/editor/presentation/widgets/visual_document_editor.dart`, `semantic_editor_controller.dart` (focus, caret, rebuilds).
4. **Toolbar / autocomplete / dual-mode** — `formatting_toolbar.dart`, `markdown_editor.dart`, and the three `*_autocomplete_trigger.dart` / `slash_command_trigger.dart` files.

### Invariants you must not break
- `canonicalMarkdown` is authoritative. Never persist the AST. Never use `block.plainText` (delimiter-free visible text) as *replacement content* — that strips inline formatting (this was P0 and is already fixed; don't regress it).
- `SourceRange.contains(offset)` is **inclusive** of `end` (`start <= offset <= end`); `containsStrict` is half-open `[start, end)`. Choose deliberately.
- Bidirectional mapping (`findPositionAtSourceOffset` ↔ `sourceOffsetAtPosition` ↔ `sourceRangeAtSelection`, all in `semantic_document.dart`) must round-trip. There is a round-trip regression test in `test/editor/semantic_document_model_test.dart` — extend it, don't weaken it.

### Mandatory workflow (from `AGENTS.md`) after every batch
1. `export PATH="$HOME/flutter/bin:$PATH"` then `flutter analyze` → **must be "No issues found!"**
2. `flutter test` (or at minimum `flutter test test/editor`) → **all pass**. Add regression tests for each fix in the named suite.
3. Update `HANDOFF.md` with a new numbered section.
4. `git add .`, conventional commit ending with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`, `git push origin main`.

### Line numbers
Anchors below were re-verified against the current tree, but treat them as *approximate* — always grep for the quoted code before editing, since prior fixes shifted line numbers.

---

## 0.1 What remains (open work) — start here

Everything with a concrete user-visible bug has shipped. The remaining work is deliberately deferred and each item needs a **product/architecture decision before coding**, not just implementation. Ordered by leverage:

| # | Item | Why deferred | Prerequisite before starting |
|---|------|--------------|------------------------------|
| **P2-2** | Backslash escapes (`\*not italic\*`) | An escaped char is **1 visible / 2 source** chars, which breaks the 1:1 text↔source assumption baked into `_findPositionInRuns`, `_sourceOffsetInRuns`, and `mergeAdjacentRuns`. `PlainRun` currently hardcodes `contentRange == sourceRange` and cannot carry an independent content span. | Extend the run model so `PlainRun` (and merge logic) support an independent `contentRange`; then escapes fall out. Best done **with** the run-model half of §4. |
| **P2-7b** | Nested `]` inside a link *label* | Only the balanced-parens-in-**URL** half shipped. Nested brackets in the label need a hand-written label scanner tracking `[`/`]` depth, not a regex. | Decide it's worth it (rare in real notes). If yes, add a small scanner invoked when the inline regex sees `[`. |
| **P2-6** | Setext headings (`Title\n===`) | **Out of scope** by product decision — the corpus uses ATX (`#`). | Reopen only if the user explicitly asks. Beware interaction with P2-5 spaced-HR (`---` under text). |
| **P3-6b** | Perf/lifecycle nits (the 3 non-leak items) | Perf-sensitive, no correctness bug, higher regression risk. Only the FocusNode leak was safe to ship now. | See the P3-6 subsection — the repaint short-circuit should be **co-designed with §4** (stable IDs make it trivial). Measure on realistic large docs first. |
| **§4** | Stable block identity (diff-based IDs) | Large cross-cutting refactor; the tactical P0/P1/P2/P3 fixes already neutralized the symptoms. | Own branch, editor suite as regression net **plus** new diff-stability tests. See §4. |

### Known unrelated failure (do not chase from editor work)
`test/editor`… all green (425 tests). But the **full** `flutter test` has a pre-existing hang in `test/speech/speech_recognition_service_test.dart` (`multilingual model automatically passes lang: auto to engine — did not complete`). It fails in isolation too and is unrelated to the editor. Don't let it block an editor batch; fix it under a speech-scoped task.

---

## 1. Recommended sequencing

1. ~~**P2 parser fidelity** — one focused pass.~~ **DONE** (commit `bc9b3fa`, `HANDOFF.md` §119). Shared test file: `test/editor/semantic_markdown_parser_test.dart` (group "SemanticMarkdownParser P2 fidelity") + caret assertions in `semantic_document_model_test.dart`.
2. ~~**P3 autocomplete & UX polish**~~ **DONE** (commit `bc9b3fa`, `HANDOFF.md` §120).
3. **Optional strategic refactor** — stable block identity (§4). **Still open.** Only after the deferred run-model work; it retires an entire class of latent bugs but is a larger change. Evaluate cost/benefit first.

The remaining coding work is the deferred set in §0.1. The P2/P3 specs below are retained: struck-through for shipped items (kept for context and regression understanding), live for the deferred ones (P2-2, P2-7b, P2-6, P3-6b).

Do **not** interleave the deferred run-model / P2-2 work and the stable-ID refactor blindly — they touch overlapping code; but note they are **complementary** (P2-2 needs the same independent-`contentRange` run model that §4 benefits from), so a combined design pass is reasonable.

---

## 2. P2 — Parser fidelity & edge cases

All in `lib/features/editor/application/semantic_markdown_parser.dart`. Add tests to `test/editor/semantic_markdown_parser_test.dart` (and caret assertions to `test/editor/semantic_document_model_test.dart` where a fix changes ranges).

Before starting, decide **product scope** for P2-6 (setext headings) and P2-3/P2-2 (full CommonMark flanking/escapes): Quiet Paper's parser is intentionally a *pragmatic subset*, not a spec-complete CommonMark implementation. Fix the ones that cause visible caret/formatting wrongness for realistic user input; gate the spec-completeness items behind an explicit product decision so you don't over-engineer.

### P2-1 · Greedy whitespace after a marker mis-maps every caret on the line — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** marker length is now `lineText.length - content.length` for heading/unordered/ordered/checklist/quote, exactly covering the marker + trailing whitespace. Tests in group "SemanticMarkdownParser P2 fidelity" (`expectMarkerRoundTrip`).
**Where:** heading marker `~:354`, unordered/checklist `~:415`, ordered `~:444`, quote `~:469`.
**Root cause:** `markerLen` is computed as a *constant* assuming exactly one space, e.g. heading:
```dart
final markerLen = hashes.length + 1; // hashes + space  <-- assumes ONE space
```
but the matching regexes use `\s+` / `\s*`:
```dart
static final _headingRegex     = RegExp(r'^(#{1,6})\s+(.*)$');
static final _unorderedListRegex = RegExp(r'^(\s*)([-*+])\s+(.*)$');
```
So `#   Title` (3 spaces), `-   item`, `- [ ]   task` produce a `markerRange`/`contentRange` that is *shorter* than the real marker+whitespace. Every caret in the content then maps to the wrong source offset (off by the extra whitespace).
**Fix:** derive the marker length from the **actual match**, not a constant. Use the match's group boundaries — e.g. for the heading, the content starts at `match.start(2)` (the start of group 2 = the text), so `markerLen = match.start(2) - lineStart`. Apply the same pattern to list / checklist / ordered / quote: compute `contentRange.start` from the captured content group's actual index rather than `indent + marker + 1`.
**Test:** parse `#   Heading` and assert `contentRange` covers exactly `Heading`; assert `findPositionAtSourceOffset` / `sourceOffsetAtPosition` round-trip for a caret inside the text. Repeat for `-   item`, `1.   item`, `- [ ]   task`, `>    quote`.

### P2-2 · No backslash-escape handling — ⏭️ DEFERRED (needs run-model change; see §0.1)
> **Blocker:** an escaped char is 1 visible / 2 source chars. `PlainRun.contentRange` is hardcoded to `sourceRange`, and `mergeAdjacentRuns` assumes 1:1 text↔source within plain runs. Implementing escapes correctly requires giving `PlainRun` an independent `contentRange` (and teaching the merge logic about it) — the same run-model change §4 wants. Do them together. The spec below is the intended approach once that lands.
**Where:** `_inlineRegex` `~:540-549`.
**Root cause:** the inline regex has no notion of `\` escapes, so `\*not italic\*` still renders italic and the literal backslashes leak/misalign.
**Fix:** honor backslash escapes for the Markdown metacharacters this parser recognizes: `* _ # [ ] ( ) ` ~ = ! \`. Two viable approaches:
- Pre-scan and mask escaped metacharacters before running `_inlineRegex`, then emit the unescaped literal in the resulting `PlainRun` while keeping source offsets aligned to the *original* (including the backslash) text; or
- Add a leading alternative to `_inlineRegex` that matches `\\(?<escaped>[*_#\[\]()`~=!\\])` and emits a `PlainRun` of the single escaped char.
The second is simpler and keeps ranges local. **Caution:** the emitted run's `text` is 1 char but its `sourceRange` is 2 chars (`\` + char) — that asymmetry must be reflected via `contentRange` so caret mapping stays correct.
**Test:** `\*a\*` → single plain run `*a*` (no italic); caret round-trips.

### P2-3 · Emphasis lacks flanking rules — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** added `_emphasisDelimiter` + `_isValidEmphasis` (rejects empty inner, opener-followed-by-space, closer-preceded-by-space, and intra-word `_`); rejected delimiters re-absorb as literal text. Tests: "P2-3 flanking rejects intra-word underscores and spaced emphasis" and "P2-3/P2-9 empty inline emphasis".
**Where:** `_inlineRegex` italic/bold alternatives `~:547-549`.
**Root cause:** `*`/`_` match anywhere, so `snake_case_var` italicizes `case`, and arithmetic like `2 * 3 = 6 ... 4 * 5` emphasizes the middle.
**Fix:** add CommonMark-style *flanking* checks — an emphasis opener must not be followed by whitespace and a closer must not be preceded by whitespace; intra-word `_` emphasis is disallowed (`_` only opens/closes at word boundaries, `*` is more permissive). This is hard to express purely in one regex; prefer a post-match validation step in `_parseInlineRunsInternal` that rejects a candidate emphasis run whose delimiters fail the flanking test and re-emits the delimiters as plain text.
**Scope note:** confirm this is wanted before implementing — it is the highest-effort P2 item. If deferred, at minimum special-case intra-word `_` (the most common false positive: `file_name_here`).
**Test:** `snake_case_var` → one plain run; `a * b * c` (spaced) → plain; `*real*` → italic.

### P2-4 · Inline images parsed as links — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** added an `imgAlt`/`imgUrl` alternative to `_inlineRegex` *before* the link alternative; matched images emit a literal `PlainRun` (no inline image run type exists in `semantic_nodes.dart`, so literal-render was chosen — it round-trips and the run switch renders PlainRun verbatim). Test: "P2-4 inline image is not parsed as a link and leaves no stray !".
**Where:** link alternative `~:543` (there is a *block-level* `_imageRegex` at `:24`, but no **inline** image handling).
**Root cause:** `![alt](url)` inline hits the link branch `\[(?<linkLabel>...)\]\((?<linkUrl>...)\)`, leaving a stray `!` before a link run.
**Fix:** add an inline image alternative **before** the link alternative in `_inlineRegex`:
```
r'!\[(?<imgAlt>[^\]\n]*)\]\((?<imgUrl>[^)\n]+)\)|'
```
and emit an `ImageRun` (or the project's inline-image node; check `semantic_nodes.dart` for an existing type — if none, decide whether to render as a non-editable atomic run or as literal text). Ensure `sourceRange`/`contentRange` cover the whole `![...](...)`.
**Test:** `![a](x.png)` inline → image run, no stray `!`.

### P2-5 · Space-separated thematic breaks misparse as lists — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** added `_spacedHorizontalRuleRegex = RegExp(r'^[ \t]*([-*_])(?:[ \t]+\1){2,}[ \t]*$')` and check it alongside the contiguous HR regex before the list branch. Test: "P2-5 space-separated thematic breaks parse as horizontal rules".
**Where:** HR regex `:18` (`^\s*(?:-{3,}|\*{3,}|_{3,})\s*$`) vs unordered list `:21`.
**Root cause:** `* * *`, `- - -`, `_ _ _` don't match the *contiguous* HR regex (`\*{3,}`), so they fall through to the list matcher and become list items.
**Fix:** broaden the HR detection to accept spaced runs of the same marker (`^\s*([-*_])(\s*\1){2,}\s*$`) and check HR **before** the list branch in the block loop.
**Test:** `* * *`, `- - -`, `_ _ _` → single `HorizontalRuleBlock`.

### P2-6 · Setext headings unsupported — ❌ OUT OF SCOPE (product decision, 2026-09-26)
**Decision:** not implementing. The corpus uses ATX (`#`). Reopen only on explicit user request; if reopened, beware the P2-5 interaction (a lone `---` under text must become setext H2, not an HR). Spec retained below for that eventuality.
**Root cause:** `Title\n===` / `Title\n---` parse as a paragraph followed by an HR (or paragraph + paragraph), not H1/H2.
**Fix (only if in scope):** in the block loop, look ahead: a non-empty paragraph line immediately followed by a line matching `^=+\s*$` (→ H1) or `^-+\s*$` (→ H2) becomes a `HeadingBlock` spanning both lines. Beware interaction with P2-5 (a lone `---` under text must become setext H2, not HR).
**Recommendation:** most note apps and the existing corpus use ATX (`#`). Default to **out of scope** unless the user confirms setext is needed; document the decision either way.
**Test (if implemented):** `Title\n---\n` → one H2 block; ensure `---` alone (no preceding text) still parses as HR.

### P2-7 · Links break on `)` in URL or nested `]` in label — 🟡 PARTIAL (URL parens ✅ DONE; nested `]` in label ⏭️ DEFERRED)
**✅ Shipped:** `_inlineRegex` link **and** image URL groups now allow one level of balanced parens: `(?:[^()\n]|\([^()\n]*\))+`. Test: "P2-7 link URL keeps balanced parentheses".
**⏭️ Still open (P2-7b):** nested `]` inside the *label* still breaks (`[^\]\n]+`). Needs a hand-written label scanner tracking `[`/`]` depth — pure regex can't balance. Low priority (rare in real notes). Spec below.
**Where:** link alternative `:543` — `[^)\n]+` for the URL and `[^\]\n]+` for the label.
**Root cause:** the first `)` closes the URL, so `[x](https://en.wikipedia.org/wiki/Foo_(bar))` truncates; nested `]` in the label similarly breaks.
**Fix:** balance-aware matching. Pure regex struggles with balanced parens; a targeted approach: after the label, scan the URL manually tracking `(`/`)` depth until the matching close paren (CommonMark allows balanced parens in bare URLs; `<...>` angle-bracket URLs allow anything). Implement as a small hand-written scanner invoked when the regex sees `](`, rather than trying to encode balance in `_inlineRegex`.
**Test:** `[wiki](https://e.org/a_(b))` → link URL includes the inner `)`.

### P2-8 · `sourceRangeAtSelection` asymmetric affinity inflates a collapsed caret — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** `sourceRangeAtSelection` short-circuits collapsed selections to `SourceRange(offset, offset)` (both ends resolved downstream). Test: "P2-8 collapsed caret inside **bold** yields a zero-length range".
**Where:** `semantic_document.dart` — `sourceRangeAtSelection` (uses `downstream` for start, `upstream` for end).
**Root cause:** for a **collapsed** selection the two affinities can resolve to different source offsets that straddle a hidden delimiter (e.g. `**`), so a zero-width caret becomes a 2-char range. Downstream code that treats the range as a real selection then behaves as if `**` is selected.
**Fix:** when `selection.isCollapsed`, resolve **both** ends with the **same** affinity (or short-circuit to a zero-length `SourceRange(x, x)` computed once). Only apply the asymmetric downstream/upstream logic for genuine (non-collapsed) selections.
**Test:** collapsed caret inside `**bold**` → `sourceRangeAtSelection(...).length == 0`.

### P2-9 · Minor parser/range nits (batch) — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** empty emphasis (`a****b`/`a____b`) stays literal (covered in the P2-3 empty-emphasis test; `****` alone remains an HR block); the paragraph reverse-map fallback now uses `contentRange?.end ?? sourceRange.end` for consistency with the other block types, with a caret-at-end-of-paragraph round-trip test ("P2-9 caret at end of a paragraph round-trips within the block"). The inclusive-`contains` boundary pattern (`containsStrict` for non-last blocks) was left intact.
- **Empty emphasis:** `****` / `____` — verify these don't produce an empty-text infinite/degenerate run; add coverage.
- **Inclusive `SourceRange.contains` boundary overlap:** because `contains` is inclusive of `end`, two adjacent block ranges both "contain" the shared boundary offset. `findBlockAtSourceOffset` already disambiguates with `containsStrict` for non-last blocks — keep that pattern anywhere you add new range lookups.
- **Reverse-map fallback inconsistency:** `sourceOffsetAtPosition` uses `block.sourceRange.end` as the fallback end for `ParagraphBlock` but `contentRange.end` for the others (`semantic_document.dart:218-228`). Audit whether the paragraph case should also use `contentRange.end` for consistency; add a caret-at-end-of-paragraph round-trip test either way.

---

## 3. P3 — Autocomplete, dual-mode & UX polish

These are more independent than P2 and can be committed separately. Test files: `test/editor/slash_command_test.dart`, `test/editor/wysiwyg_autocomplete_test.dart`, and the relevant widget tests.

### P3-1 · Slash command fires inside fenced code blocks — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** `SlashCommandTrigger.detect` now early-returns when `isInsideFencedCodeBlock(text, cursor)` (the shared helper from P3-4). Tests: "P3-1 ignores slash inside a fenced code block" + "detects slash again after the code block is closed".
**Where:** `lib/features/editor/application/slash_command_trigger.dart` (`~:22-54`).
**Root cause:** the note-link and tag triggers both guard with an `_isInsideCodeBlock(...)` check; the slash trigger omits it, so typing `/` inside a fenced code block pops the command menu.
**Fix:** add the same `_isInsideCodeBlock(text, offset)` guard used by the other triggers and early-return when true. **Do not** copy-paste the helper — see P3-4, which asks you to extract one shared implementation. Add the guard now referencing the shared helper you create in P3-4 (do P3-4 first if batching).
**Test:** typing `/` inside ```` ```code``` ```` does not trigger the slash menu; still triggers in a normal paragraph.

### P3-2 · Checklist tap-toggle wrong in segmented (table) markdown mode — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** extracted a pure `_computeChecklistToggle(text, cursor)`; the master field and each `_TextSegmentField` now toggle against **their own** controller (`_handleSegmentTap`), and the segment's change listener propagates to the master via the existing `replaceRange` closure. `_TextSegmentField.onTap` signature changed to pass its controller.
**Where:** `lib/features/editor/presentation/widgets/markdown_editor.dart` (`~:319-361`, the checklist tap handler).
**Root cause:** when the document contains a table, markdown mode splits into multiple segment `TextField`s, each with its own offset space. The tap handler reads offsets from the *master* controller, so the computed line/checkbox is wrong (or off-by-segments) and it toggles the wrong `- [ ]`.
**Fix:** resolve the tap against the **segment's own** controller/selection and translate that segment-local offset back to a master-document offset before mutating the checkbox marker. Verify against a document with a table above and below a checklist.
**Test:** widget test — table + checklist, tap the checkbox, assert only the intended `- [ ]`↔`- [x]` flips.

### P3-3 · Tag overlay pops while typing an ATX heading (`##S` before the space) — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** the tag trigger suppresses the overlay when the line-up-to-caret matches `^#{2,6}[^\s#]*$` (two-or-more leading hashes, no space yet). A **single** leading `#` is intentionally left alone because `#foo` with no space is a genuine tag. Tests cover `##S`/`###Head` suppressed, `#flutter` and mid-line `##S` still detected.
**Where:** `lib/features/editor/application/tag_autocomplete_trigger.dart` (`~:76-147`).
**Root cause:** the tag trigger treats a leading `#` sequence as a tag prefix, so `##S` (a heading being typed before its space) is misread as a `#tag`.
**Fix:** suppress the tag overlay when the caret is within an in-progress ATX heading marker at line start — i.e. when the text from the line start to the caret matches `^#{1,6}$` or `^#{1,6}\S*$` with no space yet. Only offer tag completion for a `#` that is *not* the line-leading heading marker.
**Test:** typing `##S` at line start shows no tag overlay; typing `#tag` mid-line does.

### P3-4 · `_isInsideCodeBlock` miscounts multiple fences on one line and is duplicated verbatim — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** new `lib/features/editor/application/code_block_scanner.dart` exports top-level `isInsideFencedCodeBlock(text, offset)` — counts *fence lines* strictly before the caret's own line (odd = inside), ignoring inline `` `code` `` on the caret line. All three triggers (slash, tag, note-link) call it; the two duplicated copies were deleted. Unit tests in `test/editor/code_block_scanner_test.dart` incl. the multi-fence parity case.
**Where:** duplicated in `note_link_autocomplete_trigger.dart` and `tag_autocomplete_trigger.dart` (`~:29-65` each).
**Root cause:** the fence-counting loop miscounts when the logic sees multiple ```` ``` ```` occurrences and is copy-pasted (so a fix must be applied twice, inviting drift).
**Fix:** write one correct helper that counts *opening* fences before `offset` (a caret is inside a code block iff the number of fence lines strictly before the caret's line is odd), and extract it to a single shared location (e.g. a top-level function or a small `code_block_scanner.dart` utility). Update all three triggers (note-link, tag, slash) to call it.
**Test:** unit test the helper directly with fixtures: caret before any fence (outside), after one fence (inside), after two (outside), with an inline ```` `code` ```` on the same line (must not be counted as a block fence).

### P3-5 · Checklist Enter hardcodes the `-` marker — ✅ DONE (commit `bc9b3fa`)
**✅ Shipped:** `splitBlock` derives the continuation bullet from `markdown[block.boxRange.start]` (the item's original bullet char) rather than a hardcoded `-`, continuing with `[ ]`. Note: `ChecklistItemBlock` has **no** `marker` field (unlike `ListItemBlock`), so the bullet is read from source via `boxRange.start`. Tests: "P3-5 checklist Enter preserves the original bullet character" (`*` and `+`).
**Where:** `lib/features/editor/application/semantic_mutation_service.dart` (`~:174-175`, the split/continue logic for list items).
**Root cause:** continuing a list on Enter emits a literal `- ` even when the source used `*` or `+`, so `* item`⏎ produces a `- ` line, changing the marker mid-list.
**Fix:** reuse the current item's `block.marker` (the `ListItemBlock`/`ChecklistItemBlock` carries the actual marker char) when synthesizing the continuation line, instead of a hardcoded `'-'`. For checklists, continue with an unchecked `[ ]` and the original bullet char.
**Test:** `* one`⏎ continues with `* `; `+ one`⏎ continues with `+ `; checklist continues with the original bullet + `[ ]`.

### P3-6 · Performance & lifecycle nits (batch) — 🟡 PARTIAL (leak ✅ DONE; perf items ⏭️ DEFERRED)
- **✅ DONE — Undisposed throwaway `FocusNode`** (`visual_document_editor.dart`, `_focusBlockAt`): the `fn ?? FocusNode()` fallback allocated an undisposed node. Now guarded with `if (ctrl != null && fn != null)` so no throwaway node is created. (Shipped in commit `bc9b3fa`.)

The remaining three are **⏭️ DEFERRED** (perf-sensitive, no correctness bug, higher regression risk) — specs kept live:
- **Hardcoded viewport spacer estimate** — `~:445, :473`: block height is estimated at a fixed 28px/block for spacer/scroll math, which drifts for multi-line blocks and large headings. Measure actual block extents (e.g. via `RenderBox`/`LayoutBuilder`) or track per-block heights.
- **Duplicated competing focus-restore logic** — `~:110-120` vs `~:494-514`: two code paths restore focus and can fight each other. Consolidate into one path guarded by the existing `_isProgrammaticSelectionUpdate` flag (added during the P1 selection-loop fix — reuse it, don't add a second flag).
- **Full-reparse repaints all visible blocks** — `_RichBlockEditingController.updateBlock` treats every reparsed block as changed (identity inequality), so a single-block edit repaints the whole viewport. Add a value-equality / content-hash short-circuit so only genuinely changed blocks rebuild. **Coordinate with §4** — stable block IDs make this dramatically cleaner, so consider doing them together.

---

## 4. Strategic follow-up — stable block identity (optional, high-leverage)

**The single design choice behind a whole family of bugs is that block IDs are positional** (`block_${counter++}`, assigned in document order on every full parse). Because IDs are re-derived from position, any structural edit (split, merge, delete, external reparse) reassigns IDs, which is why the P0/P1 fixes needed reentrancy guards, `contentRange`-based caret remapping, and careful selection carry-over. The already-shipped fixes are **tactical** — they patch each symptom. The **strategic** fix retires the class.

### Approach
Give blocks **stable identity** that survives reparse:
1. Maintain a persistent ID registry on the controller/document keyed by a stable signature (e.g. content hash + approximate position), not by ordinal index.
2. On reparse, run a **diff** (LCS or Myers) between old and new block lists; carry forward the ID of a matched block, mint a new ID only for genuinely new blocks, and retire IDs for deleted blocks.
3. Selection, focus, and per-block controllers then key off stable IDs, so a downstream edit no longer invalidates upstream blocks' identity.

### Payoff
- `_RichBlockEditingController` reuse becomes trivial (P3-6 repaint fix falls out for free).
- Focus/selection restore no longer needs to defend against ID churn.
- `incrementalParse` (already re-id'd in P0) becomes robust to count changes generally.

### Cost / risk
- Touches the controller, the parser's ID assignment, and the widget's block↔controller map simultaneously — a large, cross-cutting diff.
- Diff heuristics need tests for adversarial edits (duplicate paragraphs, reordering, mass paste).

**Recommendation:** only undertake after P2/P3 are green and stable, on its own branch, with the existing editor suite as a regression net **plus** new diff-stability tests. If the app's documents are typically small, the P3-6 tactical repaint short-circuit may be enough and this refactor can stay deferred — decide based on measured performance on realistic large documents.

---

## 5. Definition of done (per batch)

- [ ] Every fix in the batch has a regression test in the named suite that **fails before, passes after**.
- [ ] The bidirectional caret round-trip test in `semantic_document_model_test.dart` still passes (extend it if you changed ranges).
- [ ] `flutter analyze` → "No issues found!"
- [ ] `flutter test` → all pass.
- [ ] `HANDOFF.md` gets a new numbered section describing the batch (follow the existing format: Overview → Bugs Fixed → File Inventory → Verification).
- [ ] Conventional commit ending with the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer; pushed to `main` (or the active branch).

## 6. Quick reference — file → bugs map

Legend: ✅ done · 🟡 partial · ⏭️ deferred · ❌ out of scope.

| File | Bugs (status) |
|------|------|
| `application/semantic_markdown_parser.dart` | P2-1 ✅, P2-3 ✅, P2-4 ✅, P2-5 ✅, P2-7 URL ✅ / label ⏭️, P2-9 ✅ · P2-2 ⏭️ · P2-6 ❌ |
| `application/code_block_scanner.dart` *(new)* | P3-4 ✅ (shared `isInsideFencedCodeBlock`) |
| `application/semantic_mutation_service.dart` | P3-5 ✅ |
| `application/slash_command_trigger.dart` | P3-1 ✅, P3-4 ✅ |
| `application/tag_autocomplete_trigger.dart` | P3-3 ✅, P3-4 ✅ |
| `application/note_link_autocomplete_trigger.dart` | P3-4 ✅ |
| `presentation/widgets/markdown_editor.dart` | P3-2 ✅ |
| `presentation/widgets/visual_document_editor.dart` | P3-6 leak ✅ · P3-6 perf items ⏭️ |
| `domain/semantic_document.dart` | P2-8 ✅, P2-9 ✅ (consumes P2-1) |
| `domain/source_range.dart` | P2-9 boundary semantics (unchanged) |
| `domain/semantic_nodes.dart` | Run-model change needed for P2-2 ⏭️ (independent `PlainRun.contentRange`) |
| Cross-cutting | §4 stable block IDs ⏭️ |

