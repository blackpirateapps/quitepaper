# Native Visual / Markdown re-audit — final report

Date: 2026-11-16. Branch: `fix/visual-markdown-editor-input`.
Audited application source: `1bc137c`. Status: audit complete. Fix progress is tracked in the table and resolution notes
below; the original audit evidence is retained. Original audit findings 1–4 and their fixes remain in
[`../../../EDITOR_TOOLBAR_AUDIT.md`](../../../EDITOR_TOOLBAR_AUDIT.md).

## Outcome and priorities

The actual Linux GTK/Wayland EditorScreen was exercised through Hyprland native
mouse and keyboard events in three isolated application processes. Notes used an
in-memory database, mock SharedPreferences, a separate D-Bus session and temporary
XDG directories. The evidence contains 119 recorded observations across the
three phases, including exploratory and excluded steps. Personal notes and the
installed application were not changed.

| Finding | Priority | Confirmed behavior | Status |
| --- | --- | --- | --- |
| 12 | Critical | Visual Math persists invalid JSON and raises Stack Overflow | Fixed |
| 8 | High | Active Visual → Markdown switch uses a disposed controller and breaks rendering | Fixed |
| 5 | High | Clicking a later Visual paragraph leaves the document caret on another block | Fixed |
| 11 | High for keyboard input | Empty Visual Math insertion reports focus but drops typing | Fixed |
| 6 | Medium | Visual code language selection loses typing focus | Open |
| 7 | Medium | Markdown toolbar undo/redo loses typing focus | Open |
| 9 | Medium | Visual Tag saves the name before `#` | Open |
| 10 | Medium | Visual Link Note saves the query before `[[` | Open |

## Durable evidence

Reproductions below refer to observations stored alongside this report:

- `phase1-results.jsonl`: original coverage, repeats and exploratory observations.
- `phase2-results.jsonl`: clean-process Tag, web-link, Link Note, Math, table
  insertion and minimal mode-switch checks.
- `phase3-results.jsonl`: a fresh process's valid saved JSON before Math insertion
  and corrupted saved JSON afterward.
- `phase1-errors.json`, `phase2-errors.json`, `phase3-errors.json`: captured
  exception messages and stacks.
- `snapshots/`: application-only screenshots containing synthetic notes.
- `harness.dart.txt`, `driver.py.txt` and the other `*.py.txt` files: exact session
  harness and native replay scripts, retained as reference artifacts.

Each phase restarts case numbering. Match both the phase and the observation's
`step`. Error arrays in observations are cumulative: match the error's own `case`
field before attributing it. Preliminary automation artifacts and post-crash
observations are excluded as described below.


## Confirmed new finding 5 — Visual click leaves the document caret on another block

**Fixed (2026-11-16).** RichTextEditor reconciles its field selection after native tap focus settles, covering selection-before-focus ordering while preserving programmatic caret destinations. A regression simulates that ordering in a later paragraph, inserts a divider without arrows, and types into its continuation through the existing input client. Regression validation: flutter analyze --no-pub: no issues; flutter test --no-pub test/editor/visual_editor_stability_test.dart: 15 passed Native evidence above/below describes the original failure; see the resolution log 289.


Severity: high; formatting/insertion can affect the wrong part of the note.

Reproduction:

1. Open a Visual note containing `Before`, a checklist item `task`, then `Tail`.
2. Click at the end of `Tail` without typing or moving the caret with an arrow key.
3. Click the toolbar Divider button, then type `after` without another click.

Actual: the focused Tail field reports a caret at offset 4, but the authoritative
document selection still points to block 0 (`Before`), offset 0. The divider and
`after` are inserted after `Before`, above the checklist and `Tail`.

Expected: insertion follows the visibly clicked Tail caret.

Evidence: case 11, steps `pointer frame flushed Tail click`, `pointer frame
flushed divider click`, and `pointer frame flushed divider typing`. These were
recorded with no runtime errors. Additional repeats exist, including case 46;
prefer case 11 because it precedes the later mode-switch crash.

Control: case 13, `verified divider native caret movement before insertion` and
`verified divider continuation with synchronized caret`. Pressing Left then
Right after clicking Tail synchronizes the AST selection; the divider then lands
after Tail and continued typing works below it. The original divider continuation
focus fix passes with a synchronized document selection.

Likely investigation area, not a proven fix: `RichTextEditor._onFocusChanged`
publishes the active target, while selection reconciliation in
`_onTextControllerChanged` is gated on field focus. Check native click ordering.

## Confirmed new finding 6 — Visual code language selection loses typing focus

Severity: medium; subsequent keystrokes are silently dropped.

Reproduction:

1. Insert a Visual code block and type `print`.
2. Click its Plain Text language control and select Dart.
3. Immediately type `x` without clicking the code field again.

Actual: the language is saved as `dart`, but all body fields are unfocused and
the code remains `print`; `x` is lost. The initial code insertion/focus/save fix
itself passes.

Expected: the code field regains keyboard focus and its prior caret after the
language selector closes, allowing `printx` to be entered.

Evidence: case 15, `verified visual code immediate native typing` and `verified
visual code typing immediately after language choice`. Independently repeated
with an existing Dart block changed to Python in case 18, `confirmed visual
existing code language drops subsequent typing`.

Control: `confirmed visual code click restores typing after language choice`
shows that clicking the code field and typing x saves `printx` correctly.

Likely investigation area: `RichCodeBlock._changeLanguage` commits the selected
language but does not explicitly restore the code FocusNode.

## Confirmed new finding 7 — Markdown toolbar undo/redo loses typing focus

Severity: medium; subsequent keystrokes are silently dropped.

Reproduction:

1. In a fresh Markdown note, type `history probe`.
2. Click toolbar Undo, then toolbar Redo.
3. Immediately type `x` without clicking the body again.

Actual: Undo and Redo change and restore the saved content, but the restored body
is unfocused. The text remains `history probe`; the x is lost. Undo in the plain
note also reports selection -1 before Redo restores offset 13.

Expected: history leaves the body ready for keyboard input at the restored caret.

Evidence: case 17, steps `confirmed markdown plain before toolbar undo`,
`confirmed markdown plain toolbar undo`, `confirmed markdown plain redo loses
subsequent typing`. The same symptom occurs after code insertion in case 16,
`verified markdown code typing after history`.

Control: `confirmed markdown plain click restores subsequent typing` saves
`history probex`. The original first-code-insertion input failure is fixed:
`verified markdown first code typing` saves `codeprint` with native focus intact.

Likely investigation area: Markdown branches of `EditorScreen._undo` / `_redo`
restore values but do not explicitly restore the active body input focus.

## Confirmed new finding 8 — Switching an active Visual field to Markdown crashes

**Fixed (2026-11-16).** EditorScreen resets the active controller and focus target to the persistent source buffer before conversion can dispose Visual paragraphs or code fields. The destination body receives focus after mounting. Regressions edit both field types, switch through the actual menu, verify visible layout, type immediately, and check persistence. Regression validation: flutter analyze --no-pub: no issues; flutter test --no-pub test/editor/dual_mode_editor_screen_test.dart: 15 passed Native evidence above/below describes the original failure; see the resolution log 288.


Severity: high; the editor becomes unusable/offscreen.

Confirmed native reproduction from a healthy window:

1. Open a Visual note containing ordinary text and a fenced Dart code block.
2. Click the code field and type `x` after `print(1)`.
3. Open More options and choose Edit Markdown.

Actual: Flutter reports `A TextEditingController was used after being disposed`.
The stack includes `ChangeNotifier.addListener`, `_MergingListenable.addListener`
and `_AnimatedState.didUpdateWidget`. The restored title/body have global
y-coordinates around 100118 / 100185. The Markdown content is saved, but the
rendered editor is broken.

Expected: switching mode preserves the edited content and renders a usable
Markdown editor with live controllers.

Evidence: case 44, `coverage edited visual code before switching mode` and
`coverage mode conversion after active code edit`; corresponding case 44 stacks
are in `phase1-errors.json`. Earlier, the same case successfully completed a
Visual → Markdown → Visual round trip before any field was activated.

A completely fresh process independently confirmed the minimal paragraph
reproduction: type `mode probe` in an empty Visual note, then choose More options
→ Edit Markdown. Phase-two case 8 records zero errors before switching, followed
by a disposed `_RichTextEditingController`, a 99420-pixel RenderFlex overflow and
body y≈100185. See `phase2-results.jsonl`, `phase2-errors.json` and
`snapshots/mode-switch-clean-process.png`. Phase-one case 45 is retained as an
additional same-process observation, with the earlier crash already present.

Likely investigation area: `_switchEditingStyle` disposes Visual field controllers
without resetting `_activeTargetController` before the Markdown toolbar starts
observing it. This is a different trigger from the previously fixed Visual
toolbar undo/redo crash.

## Confirmed new finding 9 — Visual Tag inserts the name before the marker

Severity: medium; the toolbar creates malformed tag text.

Fresh-process reproduction (no Flutter errors): open an empty Visual note, click
its body, choose Insert Options → Tag, then type `nativeaudit`.

Actual: after marker insertion the body contains `#` with caret offset 0. Native
typing produces and saves `nativeaudit#` instead of `#nativeaudit`.

Expected: the caret follows the marker so the name becomes a valid hashtag.

Evidence: `phase2-results.jsonl`, case 1, `fresh-process visual tag caret after
insertion` and `fresh-process visual tag subsequent typing`. This confirms the
earlier provisional phase-one case 49. Markdown's corresponding insertion saved
`#nativeaudit` in phase-one case 52.

Likely area: `_triggerTagInsertion` writes the local field value while unfocused;
subsequent document/field reconciliation appears to restore an older selection.
Do not assume the fix is identical to finding 5 without testing both paths.

## Confirmed new finding 10 — Visual Link Note puts the query before `[[`

Severity: medium; the insertion workflow cannot form the intended note link.

Fresh-process reproduction (no Flutter errors): open an empty Visual note, click
its body, choose Insert Options → Link Note, then type `Other` (an isolated
reference note named Other note exists).

Actual: the inserted body is `[[` with caret offset 0. Typing produces and saves
`Other[[`; the query does not follow the opening marker and no note-picker
results are shown in the observed state.

Expected: the caret follows `[[`, forming `[[Other` and supporting note lookup.

Evidence: `phase2-results.jsonl`, case 3, `fresh-process visual note link caret
after insertion` and `fresh-process visual note link query`. This confirms the
earlier provisional phase-one case 53 independently of the mode-switch crash.

Likely areas: Visual `_handleNoteLinkPrompt` / `_insertSnippetAtCursor` and their
post-insertion document selection. The helper reparses Markdown and can reset
the AST caret to the document start.

## Confirmed new finding 11 — Visual Math insertion shows focus but loses native typing

**Fixed (2026-11-16).** The AST math insertion from finding 12 mounts the existing stable code input instead of restructuring a focused text field around raw math delimiters. Insertion now selects the equation placeholder. The empty-note EditorScreen regression types immediately through the input client, preserves IME composition, and verifies the saved formula. Regression validation: flutter analyze --no-pub: no issues; flutter test --no-pub test/editor/dual_mode_editor_screen_test.dart test/editor/rich_document_controller_test.dart: 31 passed Native evidence above/below describes the original failure; see the resolution log 291.


Severity: high for keyboard workflow; fresh-process confirmation, no Flutter
errors in the initial reproduction.

Reproduction: in an empty Visual note, click the body, choose Insert Options →
Math Formula, then immediately type `x` without clicking again.

Actual: the field contains `\n\\[\nequation\n\\]\n` and reports primary focus,
but its caret is at offset 0 and typing x changes neither its text nor saved
content. Expected: the inserted formula remains editable through native input.

Evidence: phase-two case 4, `fresh-process visual math caret after insertion into
empty note` and `fresh-process visual math subsequent typing into empty note`.
An additional clean-process repeat in phase-two case 7 confirmed that clicking
the body, moving to its end and typing x restores input and saves it.
This is distinct from the fixed Markdown first-code-block input loss.

The separate nonempty-JSON path was subsequently confirmed in a third healthy
native process as finding 12 below.

## Confirmed new finding 12 — Visual Math corrupts persisted RichDocument JSON

**Fixed (2026-11-16).** Visual toolbar and keyboard Math actions now insert a supported editable math fenced block through RichDocumentController. Source JSON is never passed to Markdown insertion helpers. Malformed JSON-like input falls back to Markdown parsing once instead of recurring between setContent and setMarkdown. Controller and EditorScreen regressions cover saved JSON, reopening, and undo/redo. Regression validation: flutter analyze: no issues; flutter test test/editor/rich_document_controller_test.dart test/editor/dual_mode_editor_screen_test.dart: 28 passed Native evidence above/below describes the original failure; see the resolution log 287.


Severity: critical for data integrity. Prioritize this before the focus issues.

Fresh-process reproduction:

1. Open an empty Visual note and type `Math existing body`.
2. Wait for autosave; confirm the saved content is valid RichDocument JSON.
3. Choose Insert Options → Math Formula.

Actual: Flutter reports `Stack Overflow`. The visible body remains `Math existing
body`, but the saved content becomes the original JSON followed by raw Markdown
math delimiters and the equation placeholder. Parsing the saved content with a
JSON parser fails with `Extra data` at line 2, column 1. The mutation is persisted;
it is not merely a transient rendering failure.

Expected: Math insertion modifies the rich document through a valid AST mutation
or another supported representation, without corrupting its persisted JSON.

Evidence: `phase3-results.jsonl`, case 1, `fresh-process saved visual JSON before
math insertion` and `fresh-process saved visual JSON after math insertion`;
`phase3-errors.json`; `snapshots/math-existing-note.png`. This was the first action
sequence in a newly launched process (PID 47664), with zero errors before the
Math action. The before state passes `json.loads`; the after state does not.

The observed suffix is `\n\\[\nequation\n\\]\n` appended after the JSON object.
The error stack alternates `RichDocumentController.setContent` and `setMarkdown`.
Inspection explains the failure: the Visual toolbar supplies the canonical
source controller, Math uses the generic Markdown formatter fallback, and
JSON-like decode failures recurse between the two controller entry points.

Do not exercise this against personal notes. The reproduction used only an
isolated in-memory synthetic note. No production fix has been applied here.

## Work completed and coverage limits

| Area | Native result / coverage |
| --- | --- |
| Original Visual divider continuation fix | Continued typing below the divider passes when the document caret is synchronized; click-only placement is finding 5 |
| Original Visual code insertion fix | New block gains focus, accepts native `print`, and saves code and language |
| Original Visual undo/redo crash fix | Toolbar/keyboard history, saved content, visible editor and subsequent typing pass in phase-one case 14 |
| Original Markdown first-code insertion fix | Native typing after the first code fence is saved correctly |
| Headings | Levels 1–6 and conversion back to paragraph exercised in both modes; fresh Visual H1 repeated after excluding a reset artifact |
| Inline formatting | Bold, italic, strike, inline code and highlight exercised in both modes |
| Lists / quote | Checklist, bullet, numbered and quote conversion plus Enter continuation exercised in both modes |
| Tables | Cell activation, two-cell edits, Tab navigation, Done and saved surrounding content pass in both modes; default table insertion also passes in phase two |
| Mode conversion | Mixed heading/emphasis/checklist/code content round-trips before an active Visual field is edited; active-field switching fails as finding 8 |
| Web links | Visual web-link attribution and persisted URL pass in a fresh process; Markdown web-link insertion also passes |
| Tags / note links / math | Visual failures documented as findings 9–12; Markdown tag and math insertion samples captured |

Limits: this pass did not repeat attachment chooser, camera, microphone or
dictation entry-point checks. Real attachment import, recording, transcription,
model downloads, full export, complete math rendering parity and non-Linux
platforms remain unverified. Earlier entry-point coverage is historical evidence
in the original audit, not new verification in this pass.

## Excluded automation and post-crash observations

- Early synthetic mouse releases were not flushed until the next pointer motion.
  Preliminary delayed-action observations are excluded. The driver was corrected
  to send native down/up events followed by pointer motion; authoritative steps
  identify the corrected replay.
- Phase-one case 20's first heading action overlapped an artificial reset while
  a prior heading popup was pending. Its disposed RichDocumentController error
  did not repeat when popups were closed before reset; fresh H1 passed in case 39.
  This is excluded as a harness teardown artifact.
- Phase-one cases 47–53 followed the mode-switch crash. Their ancestor / duplicate
  GlobalKey assertions are not counted as independent bugs. Visual web-link
  insertion passed in phase-two case 2 with zero errors, excluding the earlier
  apparent web-link save failure. Tag and Link Note failures were independently
  confirmed in a clean process as findings 9–10. Math input loss was independently
  confirmed in phase two, and persisted JSON corruption in phase three.

## Future work

1. **Fix finding 12 first.** Route Visual Math through a supported document edit
   and keep saved RichDocument JSON valid. Eliminate recursive fallback on malformed
   JSON. Add regressions for nonempty autosaved notes, corrupted-input handling,
   saved-content JSON validity and reopening the note.
2. **Fix finding 8.** Replace/reset active toolbar targets before disposing Visual
   fields on mode changes. Cover both ordinary paragraphs and code blocks, then
   verify rendering, saved content and continued typing after a native mode switch.
3. **Fix findings 5 and 11.** Synchronize native click selection with the document
   before toolbar edits, and preserve/reconnect input after Visual Math insertion.
   Verify the visible caret, canonical selection, composition and actual typing.
4. **Fix findings 6, 7, 9 and 10.** Restore caret/focus after language selection and
   Markdown history; place caret after tag/note-link markers before accepting a
   query. Test immediate typing without another click, plus persisted content and
   note-link autocomplete.
5. Add a regression for each confirmed sequence, update HANDOFF, run analysis and
   relevant tests, and commit each bug fix separately as requested. Repeat native
   Linux checks after fixes; an existing passing widget suite does not cover all
   the failing native sequences recorded here.
6. Complete the unverified coverage above separately: attachment/speech workflows,
   export, math rendering/conversion parity, broader table operations and other
   platforms. Use isolated data and fresh processes after any runtime failure.

## Validation and final environment state

- `flutter analyze`: **no issues**.
- **55 relevant tests passed** across `visual_editor_stability_test.dart`,
  `dual_mode_editor_screen_test.dart`, `code_block_overlay_test.dart`,
  `desktop_toolbar_and_shortcuts_test.dart` and `markdown_table_widget_test.dart`.
  These are existing automated checks; the eight recorded native bugs remain open.
- Full test suite was not run, following the current `AGENTS.md` for this task.
- `flutter build linux --debug --no-pub -t lib/main.dart`: **passed**. The ordinary
  bundle at `build/linux/x64/debug/bundle/` has replaced the audit executable.
- All three isolated audit windows/processes were closed. The probe server was
  part of those processes and is no longer needed; no live audit session remains.
- Documentation and evidence are committed to the active editor branch. The
  intermediate checkpoint is commit `89de2af`; the final follow-up records this
  completed report and phase-two/three evidence.

For future reproduction, copy `harness.dart.txt` to a temporary `.dart` target,
rebuild/launch with isolated XDG directories and D-Bus, and obtain the current
window address/PID before adapting the preserved driver. Never reuse an old
recorded window address without verification. Close the harness and restore the
ordinary `lib/main.dart` build afterward.
