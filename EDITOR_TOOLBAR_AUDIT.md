# Visual and Markdown toolbar audit

Date: 2026-11-15
Branch: fix/visual-markdown-editor-input

## Scope and method

Exercise the actual EditorScreen in a native Linux window using an isolated
in-memory database and temporary preferences. Test Visual and Markdown modes;
Super Editor is excluded. Record confirmed failures here before fixing anything.

## Progress

- Native Visual and Markdown test windows exercised.
- Four confirmed findings recorded below; fixes intentionally not applied in this audit.

## Coverage checklist

- [x] Undo / redo — Visual failure recorded; Markdown equivalence not exhaustively checked
- [x] Heading / paragraph levels — all levels 1–6 and paragraph conversion in both modes
- [x] Bold, italic, strikethrough, inline code, highlight (both modes)
- [x] Checklist, bullets, numbering, quote, divider (both modes)
- [x] Table, web link, note link, code block, math, tag — insertion coverage; see limitations
- [x] Attachment / recording / dictation entry points — test recording discarded; no model downloads
- [x] Selection, continuation typing, saved content
- [ ] Mode conversion / complete export round trip — follow-up coverage

## Reproduction artifacts

Temporary harness: /tmp/qp_keyboard_smoke.dart

## Confirmed finding 1 — Divider insertion leaves typing above the divider

Severity: medium. Mode: Visual. Native reproduction on this laptop.

1. Write inline-formatted paragraphs and a checklist, followed by a bullet,
   numbered item, quote and an empty paragraph.
2. With the caret in that last paragraph, click the toolbar Divider button.
3. Type `after` without clicking elsewhere.

Actual: a divider and empty paragraph are inserted below, but focus stays in the
preceding text segment. `after` appears ABOVE the divider. The new paragraph
below the divider stays empty. Expected: insertion moves the caret into the
continuation paragraph below the divider.

Evidence: `/tmp/qp-toolbar-results.jsonl`, steps `visual divider` and
`visual typing after divider`. No fix applied during this audit.

## Confirmed finding 2 — Insert Code Block drops keyboard focus

Severity: high for keyboard workflow. Mode: Visual.

In the sample note, open Insert Options → Code Block, then immediately type
`print`. The code TextField is created empty, with selection -1 and no primary
focus. All body fields report no primary focus. The keystrokes produce no text.
Expected: the new code block receives keyboard focus and an insertion caret.
Evidence: native steps `visual insert Code Block`, `visual code typing` in
`/tmp/qp-toolbar-results.jsonl`.

## Confirmed finding 3 — Undo/redo can leave toolbar attached to a disposed controller

Severity: high. Mode: Visual. Native runtime exception observed.

After typing `undo probe` in a fresh Visual note, clicking toolbar Undo cleared
it. Ctrl+Z followed by toolbar Redo restored text but left all fields unfocused
and the editor rendered offstage (reported y≈100184). The subsequent reset into
Markdown could not render an editor. Runtime log reports:

```
A _RichTextEditingController was used after being disposed.
Container: formatting_toolbar.dart:1049:12
```

Evidence: `/tmp/qp-native-smoke.log` starting at line 122 and native result steps
`visual before undo`, `visual toolbar undo`, `visual keyboard undo`,
`visual toolbar redo`. Need a fresh-window repeat to separate the exact
undo/redo trigger from harness teardown; the exception itself is confirmed.
Do not count Markdown coverage after this point: the window was broken.

### Fresh-note confirmation

All three findings repeated with deliberate menu-animation waits. Minimal steps
for finding 3: new Visual note → type `undo probe` → toolbar Undo → toolbar Redo.
No extra Ctrl+Z or mode change is needed. The restored editor remains offstage
and unfocused after settling; the disposed-controller exception repeats. Thus
this is not merely an artifact of switching the harness between modes.

Visual highlight and catalog headings 1–3 successfully produced the matching
AST attributes/heading levels. Markdown inline styles, lists, quote, divider,
highlight and headings 1–3 produced the expected Markdown after correcting the
automation's menu waits. Table, web-link, note-link and tag insertion entry points
were exercised. One test URL was appended to the dialog's prefilled `https://`;
that malformed sample URL is an automation mistake, not an app bug.

Image/PDF/file picker entry points were opened and cancelled. Desktop scanning
correctly showed the no-camera fallback and import option. Actual attachment
import, camera capture, and remote link-title fetching are not verified by these
entry-point checks.

## Confirmed finding 4 — Markdown code insertion shows focus but drops typing

Severity: high. Mode: Markdown. Reproduced in a fresh process after hot restart.

1. Click in an empty Markdown body.
2. Insert Options → Code Block.
3. Immediately type `print`.

Actual: the body reports primary focus and a caret at offset 9, but its text and
saved content remain `\n```\ncode\n```\n`. All five typed characters are lost.
Expected: keyboard typing edits the inserted code placeholder.
Evidence: `fresh markdown code before typing` and `fresh markdown code after
typing` in `/tmp/qp-toolbar-results.jsonl` and `/tmp/qp-toolbar-finish.log`.

Suspected cause (not yet a proven fix): CodeBlockOverlay changes from returning
the TextField directly to wrapping it in a Stack when the first fence appears.
This replaces the EditableText subtree while reusing a focused FocusNode, which
can leave native text input disconnected. Inspect code_block_overlay.dart.

Math insertion and subsequent typing worked in this fresh probe. Actual math
rendering/conversion parity across modes has not been verified.


## Durable artifacts and validation

- [Captured Markdown sample](handoff/audits/toolbar-sample-markdown.md).
- [Captured Visual AST](handoff/audits/toolbar-sample-visual.json).
- [Visual headings/highlight AST](handoff/audits/toolbar-sample-visual-headings.json).
- Native entry points used the actual EditorScreen with an in-memory database.
  The installed app and personal notes were not changed.
- Recording started in the isolated window and was discarded. Dictation entry
  was invoked; actual transcription was not verified. No speech model downloaded.
- No production fixes are included in this audit. Reproduce/fix the four findings
  next, starting with the disposed-controller crash and both code-input failures.
- `flutter analyze`: no issues. Focused stability tests: all 12 passed. These
  existing tests do not cover the newly discovered toolbar sequences.


Final pass: headings 4–6 and paragraph conversion also passed in both modes.
The clean Markdown link/table sample is
[here](handoff/audits/toolbar-sample-clean-link-table.md); its URL was entered
correctly after clearing the prefilled prefix. Clicking its first table cell
opened the `Header 1` editor. Cell text mutation and table navigation remain
follow-up coverage. Additional Visual heading AST:
[levels 4–6](handoff/audits/toolbar-sample-visual-headings-456.json).

The temporary audit window was closed. The regular `lib/main.dart` Linux target
was rebuilt so the build directory does not retain the audit-only executable.
