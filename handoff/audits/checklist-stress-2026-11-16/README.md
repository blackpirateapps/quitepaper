# Checklist adversarial audit — November 16, 2026

Branch: `fix/visual-markdown-editor-input`. Application source: `daad621`.
**Status: fixes in progress; see individual resolutions below.**

Ten findings have native Linux reproductions. Two are confirmed through Flutter's
IME/composition test channel; real Android/iOS or CJK input-method sessions were
not run. Severity and platform limits below are part of each finding.

The most serious failures affect persisted content without raising Flutter errors:
rapid checklist creation loses/reassigns letters, paste uses the wrong position,
Visual drops nesting, Super Editor merges child tasks into parent text, and native
Super Editor Home duplicates a paragraph. Prioritize these before cosmetic work.

## Method and evidence

The actual EditorScreen was exercised through native Hyprland/Wayland pointer and
keyboard events in **three fresh isolated processes**. Each used synthetic notes,
an in-memory database, mock SharedPreferences, a private D-Bus session and temporary
XDG directories. Personal note data and the installed application were not changed.

- **93 recorded native observations across 50 synthetic cases**, including controls,
  exploratory steps and explicitly excluded observations. Case numbers restart in
  each phase; identify both phase and step.
- **34 temporary automated probe executions**: 21 Visual widget cases, 12 Super
  Editor widget cases, and one Markdown formatter matrix with eight inputs.
  Their 41 result records include expected-behavior failures; completion of a probe
  does **not** mean the application passed its checks.
- **82 existing relevant tests passed** across seven named files below. They do not
  cover all the newly failing sequences.
- All captured native and widget Flutter runtime error arrays were empty. The bugs
  below are observable behavior/content failures, not exception counts.

Start with `phase1-summary.jsonl`, `phase2-summary.jsonl` and `phase3-summary.jsonl`.
They show selections, focused fields, block counts and short saved contents.
`phase*-native-results.jsonl.gz` preserve full field geometry, source JSON/Markdown,
labels, task models and saved note content. Decompress with `gzip -dc <file>`.
`phase*-native-checks.jsonl` preserve the original expectations, including failed
or insufficient checks; the classification in this report takes precedence.

`visual-widget-results.jsonl` and `super-widget-results.jsonl` record authoritative
ASTs, round trips, selections, checks and timings. Probe sources are retained as
`visual-widget-probe.dart.txt` and `super-widget-probe.dart.txt`; they are audit
instruments, not committed behavior-locking regression tests. The scripts and
native harness are in `native-replay/`. `working-notes.md` and
`widget-preliminary.md` retain the investigation history and provisional claims
that were subsequently narrowed or excluded here.

## Findings and priorities

Resolutions are recorded under each finding. Historical evidence below describes the audited source.

| ID | Severity | Mode | Finding | Verification |
| --- | --- | --- | --- | --- |
| CL-09 | High: input integrity | Visual | Rapid Enter/type creation loses or moves task-label characters | Native fresh-process repeat and paced control |
| CL-10 | High: persisted structure | Visual | Paste at a task caret uses the wrong Markdown position | Native repeat, autosave and reopening |
| CL-02 | High: hierarchy loss | Visual | Nested tasks save as flat rows | Native edit/save and parser/serializer probe |
| CL-08 | High: task/state loss | Super Editor | Nested child tasks merge into parent text and lose completion state | Native fresh-process save plus widget parse |
| CL-11 | High: persisted text mutation | Super Editor | Home on a paragraph following a checklist inserts `. Tail` before Tail | Fresh native process and nonfolded control |
| CL-01 | Medium | Visual | Enter over a selection retains the selected letters | Native forward/reverse selection and widget probes |
| CL-04 | Medium | Visual | Toolbar Tag / Link Note lose their markers inside a task | Native Tag and Link Note typing/save |
| CL-05 | High for mobile input | Visual | IME Enter stays inside a single task instead of continuing/exiting | Flutter IME-channel widget probes only |
| CL-06 | Medium for IME input | Visual | Hardware Enter splits a task during active composition | Composing-range widget probe only |
| CL-03 | Medium | Visual | Forward Delete cannot join the following task | Native and widget probes; Super control passes |
| CL-07 | Medium | Markdown | Quoted and numbered task continuation loses the checkbox | Native and formatter probes |
| CL-12 | Medium, debug-native scope | Visual | Down navigation does not advance for each keypress in a long list | 250-row native repeats; small-list control passes |

## CL-09 — rapid creation loses/reassigns task-label characters

**Open. High. Native Linux debug build; release/device performance unmeasured.**

1. In a new Visual note, create a task containing `Seed` and place the caret at its end.
2. Repeat Enter followed immediately by `t1`, Enter followed by `t2`, and so on.
3. Continue until the note has dozens of tasks and scrolls; inspect both rows and saved JSON.

The driver waits 65ms after each dispatched key, plus subprocess/IPC overhead.
This is an input-rate reproduction, not a claim about exact human typing speed or
release-build latency. Forty repetitions in the first note of a fresh process
produce 41 task rows, but labels include `t1t2`, `t`, missing prefixes, and a final
`4018`/empty row instead of `t1` through `t40`. An independent earlier 81-row
sequence also retained the row count while corrupting labels. The wrong text is
in the authoritative AST and persisted JSON; this is more than a lagging display.

Control: adding 400ms after Enter and 150ms after each label preserves **all 31
expected rows exactly**. Widget tests that settle the frame before typing also
pass, explaining why ordinary regression coverage misses the native sequence.

Evidence: phase 2 case 1, `Fresh process 41 task rapid native creation`, and case 2,
`Paced creation control 31 tasks`. Phase 1 case 26 records the 81-task run and
progress snapshots. Its subsequent double-Enter result follows already-corrupted
input and is not counted as an independent empty-task termination bug.

Investigate the structural-reconciliation/input-focus interval in
`RichChecklistEditor`: edits are ignored while `_isReconcilingStructure` is true,
and the destination focus/selection is scheduled after a frame. The exact cause
and a safe way to preserve early input have not been established.

## CL-10 — paste lands at the wrong checklist position

**Open. High. Native repeat, persisted and reopened.**

1. Open Visual content `- [ ] Alpha` followed by `- [ ] Neighbor`.
2. Click Alpha and press End. Put `\n- [ ] Beta\n- [x] Gamma` on the clipboard.
3. Paste with Ctrl+V, wait for autosave, then reopen the saved content.

Expected task texts: `Alpha`, `Beta`, `Gamma`, `Neighbor`; Gamma is checked.
Actual task texts: empty, `Beta`, `Gamma Alpha`, `Neighbor`; Gamma Alpha is checked.
The caret resets to the first empty task. The fresh-process repeat waited four
seconds before inspecting persistence and reopened the saved JSON: the incorrect
structure survives.

Evidence: phase 2 cases 3–4, `Fresh paste after caret with long autosave wait` and
`Reopen native checklist paste saved content`; phase 1 case 25 is the first sample.
An early item-count-only assertion passed because four tasks existed, despite the
wrong text placement. The early unchanged saved-content snapshot was premature;
there is **no separate confirmed autosave failure** from that sample.

Source inspection explains the offset mismatch: `_insertSnippetAtCursor` uses
`RichDocumentController.globalCaretOffset` (plain AST offsets) as an index into
`rc.toMarkdown()` (which includes checkbox and formatting syntax). Its wholesale
`setMarkdown` also resets the selection. A correct fix needs a document/Markdown
position mapping or a proper AST replacement operation, including selections.

## CL-02 — Visual nested task hierarchy is lost on save

Resolution: ChecklistItemBlock now stores indentation with backward-compatible JSON defaults. Parsing, serialization, copies, equality, Enter continuation and row padding preserve nesting and completion state. Regressions cover Markdown/JSON round trips and nested editing. Validation: flutter analyze: no issues; parser/serializer and checklist tests: 31 passed.

**Fixed.** High. Native and parser/serializer confirmation.

Open this fixture in Visual, edit Sibling, and wait for autosave:

```markdown
- [ ] Parent
  - [ ] Child
    - [x] Grandchild
- [ ] Sibling
```

Expected: child/grandchild indentation survives saving and mode conversion.
Actual: the saved AST has four flat checklist rows and no indent metadata;
`toMarkdown()` returns every row at column zero. The checked flag survives, but
the hierarchy does not. Even loading and serializing the fixture through the
Visual controller loses indentation before any user edit.

Evidence: phase 1 case 13, `Visual edit nested checklist then save` and
`Visual nested checklist canonical Markdown`; widget case `visual-nested-roundtrip`.
`RichDocumentParser` captures leading whitespace for tasks but discards it;
`ChecklistItemBlock` has no indent field and its serializer always emits a flat row.

## CL-08 — Super Editor merges nested tasks and discards their checkbox state

**Open. High. Native fresh-process save and widget parse confirmation.**

1. Open the same Parent/Child/checked Grandchild/Sibling fixture in Super Editor.
2. Edit Sibling, then inspect the saved Markdown.

Expected: four task nodes, with indented Child and checked Grandchild.
Actual: there are only two tasks. The first reads `ParentChildGrandchild` and is
unchecked. The saved content after typing x in Sibling is:

```markdown
- [ ] ParentChildGrandchild
- [ ] Siblingx
```

Both two-space and four-space nesting were exercised. The separate runtime smart
sorting test that constructs indented TaskNodes directly passes; it does not
validate the Markdown loading/round-trip boundary. The custom task serializer
also emits two-space indentation, so this affects the app's own representation.

Evidence: phase 1 cases 27–28; phase 2 case 5, `Fresh Super nested task save`;
Super widget case `nested-roundtrip`. Investigate the math-aware Markdown
deserializer's task/list conversion, not only SmartTaskController's sorting guard.

## CL-11 — native Home mutates text after a checklist

**Open. High. Repeated in a fresh process; release/non-Linux behavior unverified.**

1. In Super Editor open a task followed by a plain paragraph `Tail`.
2. Click near Tail's left edge. Inspected selection is already offset zero.
3. Press Home without typing any characters and wait for autosave.

Expected: only the caret changes; the paragraph remains `Tail`.
Actual: the paragraph becomes `. TailTail`, the caret moves to offset 6, and the
extra text is saved. This also reproduces in the first note of a fresh process
where Tail follows a collapsed completed-list summary.

Evidence: phase 3 case 1, `Fresh folded Tail clicked` →
`Fresh folded Tail Home caret`; valid nonfolded control in phase 3 case 9,
`Valid nonfolded Tail click before Home` → `Valid Super Home paragraph control`.
The paragraph was exact immediately before Home. Root cause is not proven;
investigate native keyboard/IME buffer reconciliation in Super Editor.

This is **not** a confirmed folded-Backspace bug. When Home is omitted and the
click already sets offset zero, Backspace reveals the completed tasks and keeps
Tail intact (phase 3 case 10). Earlier Backspace checks followed the Home mutation.

## CL-01 — Enter ignores the selected replacement range

Resolution: Visual checklist Enter uses the ordered replacement range, preserving styled prefix/suffix spans and committing the split as one undo step. Forward and reverse widget regressions assert task text, focus selection and undo. Validation: flutter analyze: no issues; rich_text_checklist_editor_test.dart: 11 passed.

**Fixed.** Medium. Native and widget confirmation, both selection directions.

In task `AlphaBeta`, select offsets 2–7 (`phaBe`) and press Enter. Expected rows
are `Al`, `ta`; the selected letters should be removed. Forward selection produces
`Al`, `phaBeta`. Reverse selection produces `AlphaBe`, `ta`. Neighboring tasks
survive, but the selection is not replaced.

Evidence: phase 1 cases 5–6, before-selection and after-Enter observations;
widget cases `visual-enter-selected-range-reversed-false/true`. Super Editor's
native forward/reverse controls delete the selection correctly (phase 1 cases
29–30). Visual `_handleEnter` uses `selection.baseOffset` and calls a collapsed
split without deleting the selected range.

## CL-04 — checklist Tag and Link Note markers disappear

Resolution: Checklist controller listeners now publish text edits and their selections even while the insertion menu owns focus; unfocused selection-only notifications stay ignored. Actual EditorScreen toolbar regressions verify Tag typing, Link Note autocomplete and saved rich JSON. Validation: flutter analyze: no issues; dual-mode editor and checklist tests: 37 passed.

**Fixed.** Medium. Two native menu/typing/save reproductions.

1. In a Visual task containing `Task `, click its end.
2. Choose Insert Options → Tag, then type `nativeaudit` without clicking again.
3. Repeat in a fresh task with Link Note, then type `Other`.

Expected: `Task #nativeaudit` or `Task [[Other` with autocomplete.
Actual saved task text: `Task nativeaudit` or `Task Other`; the marker is gone and
the corresponding autocomplete cannot operate normally.

Evidence: phase 1 cases 14 and 24. This differs from the previous toolbar audit's
paragraph fixes: checklist fields use their own controller listener.
`RichChecklistEditor._onTextChanged` ignores programmatic text mutations while
the menu owns focus; later reconciliation can restore the older task text.

## CL-05 — IME Enter never continues/exits the checklist

**Open. High for mobile workflow. Widget IME channel only; no native phone test.**

Through the platform text-input channel, send `Alpha\n` to a Visual task containing
Alpha. Expected: Alpha plus a new unchecked task. Actual: one task whose span
contains `Alpha\n`. Sending `\n` to an empty task similarly keeps a task containing
a newline rather than exiting to a paragraph.

Serialized JSON preserves the embedded newline, but conversion to Markdown and
back changes the block structure. Hardware Enter follows a different path and
creates/exits a task correctly when no selection is involved.

Evidence: widget cases `visual-ime-enter`, `visual-ime-empty-enter`, and
`visual-multiline-input`, including their `roundTrip` ASTs. The input update uses
`tester.testTextInput.updateEditingValue`, not direct controller mutation.
The dedicated checklist field does not apply structural newline handling to its
IME text changes. Native desktop structured paste follows another path and must
not be used as a passing control for this IME behavior.

## CL-06 — composition-confirming Enter splits a task

**Open. Medium. Widget composing-range simulation only.**

Focus a Visual task `Alpha`, set a nonempty composing range over its text, then
send hardware Enter. Expected: the IME can confirm composition without the app
intercepting it as a task split. Actual: a second unchecked task is created.

Evidence: widget case `visual-enter-during-composition`. `_handleEnter` is called
without checking the field's composing range. A real Linux CJK input method,
Android keyboard and iOS keyboard remain unverified; retain that scope rather
than claiming a native-language input test passed.

## CL-03 — forward Delete stops at task boundaries

Resolution: Forward Delete at a collapsed task-end caret merges the following task while retaining styled text, the current checkbox state, the join caret and one-step undo. Other Delete operations retain native text-field behavior. Validation: flutter analyze: no issues; rich_text_checklist_editor_test.dart: 13 passed.

**Fixed.** Medium. Native and widget confirmation.

Place the caret at the end of First in two adjacent tasks First / Second, then
press Delete. Expected: `FirstSecond` in one task. Actual: no document change.
Backspace at the start of Second does merge the tasks and preserves their letters.

Evidence: phase 1 case 11; widget case `visual-forward-delete-at-row-end`.
Super Editor's native Delete control joins these tasks (phase 1 case 31).
Visual checklist rows implement Backspace but no corresponding forward structural
Delete path across their separate text fields.

## CL-07 — Markdown continuation removes task status from the new line

**Open. Medium. Native and formatter confirmation.**

At the end of `> - [ ] Alpha`, press Enter. Expected continuation: `> - [ ] `.
Actual: `> `. At the end of `1. [ ] Alpha`, expected `2. [ ] `; actual `2. `.
The new line silently becomes a quote/numbered item rather than a task.

Evidence: phase 1 cases 18–19 and the formatter matrix. Flat `- [ ]`, checked
`- [x]`, and indented `  - [ ]` continuations pass their native controls.
The formatter recognizes quote and number prefixes separately, without the
embedded checkbox marker. Additional observed behavior: Enter replacing a
selection in a flat Markdown task deletes the selected letters but creates a
plain continuation line; unlike Visual CL-01 it does not retain selected text.
That selection-continuation behavior needs an explicit product decision/regression.

## CL-12 — long-list Down navigation loses focus advances

**Open. Medium, native debug build. Performance/release scope unresolved.**

Load 250 short Visual tasks, click Task 0000 and place the caret at its end.
Send ten Down keypresses with 350ms extra settling time after each.
Expected: Task 0010 has focus. Actual: Task 0002 has focus. A prior faster run
also reached only Task 0027 after 124 Down events.

Evidence: phase 3 case 2, `Slow Down navigation control 10 rows`; phase 1 case 34,
`Visual native arrows reach middle task`. Small-list control: three Down events
with one-second waits correctly reach B, C and D in a four-row list (phase 3 case 8).
This is a reproducible native focus/navigation discrepancy; this pass does not
attribute every unadvanced key to a specific handler or establish release timing.
Use focus/selection observability when writing a regression; simply assuming a
fixed number of Down events reached the intended row produced invalid later checks.

## Large-list results and coverage matrix

The supplied [250-task fixture](large-checklist-250.md) is the exact flat short-row
fixture used in the native large-list checks. Separate 50/250/1,000-task fixtures
are generated by the preserved widget probes.

| Area | Result and evidence |
| --- | --- |
| Load 50, 250, 1,000 short tasks | Visual and Super widget probes load every task without runtime exceptions; native EditorScreen also loads 1,000 Visual tasks |
| Middle Enter/Backspace | Widget probes at all three sizes preserve every original row after insertion/removal; native controlled 1,000-task first-row edit also preserves content |
| Last-row edit/undo | Widget probes genuinely reach the final row at 1,000 tasks and preserve content through undo; native actual final-row typing at 250 tasks changes only Task 0249 |
| Large-list completion/history | Super widget probes at 50/250/1,000 preserve task population and completion undo. Native final-row Visual history/completion remains inconclusive as described below |
| Create tasks from scratch | 81-row native run and fresh 41-row run expose CL-09; paced 31-row control preserves every label |
| Enter start/middle/end | Visual native and widget controls pass exact splits and focus; Super controls pass selections too |
| Empty and whitespace task Enter | Native Visual exits to paragraph; repeated Enter/history widget control passes. The whitespace row must be created by typing spaces, not by loading a trimmed fixture |
| Checked-task Enter | Markdown creates unchecked continuation; Super empty checked-task exit passes widget control |
| Backspace first/middle/empty task | Native Visual keeps all letters and a live field; widget controls also undo back to the exact original Markdown |
| Forward Delete | Visual failure CL-03; Super native control passes |
| Completion, sorting, folding | Existing relevant smart-task suite passes, plus large-task completion/undo probes. Native Super completion moves First below active tasks and toolbar Undo restores order/state |
| Folded boundary deletion | Valid native click-at-zero + Backspace reveals completed tasks and preserves Tail. Home-before-Backspace exposes separate CL-11 |
| Nested notes and conversion | Both Visual and Super loading/serialization fail (CL-02 / CL-08) |
| Paste | Native structured checklist paste exposes persisted wrong placement (CL-10); IME multiline input is separately covered by CL-05 |
| Arrows/wrapping | Existing wrapped-task regression passes; native large-list focus advances fail CL-12; small native Down control passes |
| IME/composition | Structural newline and composing Enter fail the widget probes. Real mobile/CJK input methods were not exercised |
| 1,250-line threshold | Native Visual falls back to Markdown while retaining all source text; subsequent typing is unresolved and not counted as a pass |
| Save/reopen | Wrong paste structure survives reopen; hierarchy loss is persisted after edit. Generic large-list integrity is verified in widget serialization and controlled native snapshots |

The full Visual probe sequence takes about 1.5s / 5.1s / 15.8s for 50/250/1,000
rows; Super takes about 1.1s / 2.7s / 8.2s. These include mounting, multiple edits,
settling, history and checks. They are **not** per-keystroke latencies, release
benchmarks or frame-time claims. The measurements do indicate increasing work
with document size; CL-09/CL-12 need investigation under release profiling.

## Unresolved observations and excluded checks

These are retained rather than counted as either new confirmed bugs or successes:

- At the actual final Visual row of 250 tasks, editing succeeded, but a subsequent
  Ctrl+Z and approximate checkbox click did not change the captured document.
  A later toolbar retry had already lost its intended final-row precondition:
  the focused field was Task 0000 and no last-row edit existed. That retry's
  apparent successful Undo and unchanged Redo are not meaningful final-row history
  coverage. The large-list widget history/completion checks do pass. Reproduce
  with focus, selected block, canUndo and geometry asserted before every action.
- At 1,250 rows, fallback source loading is correct. The first typing attempt
  clicked the center of a very tall Markdown field outside the viewport and is
  excluded. A corrected visible click/End attempt saved a newline plus x rather
  than the expected suffix. Native input/focus and line-ending behavior needs a
  separate fresh control; no successful fallback typing claim is made.
- Phase 3 cases 6–7 were invalid control fixtures containing literal backslash-n
  text, not real newlines. They had one node rather than the intended task plus
  paragraph. Discard those checks; valid controls are cases 9–10.
- The initial whitespace widget fixture was trimmed by parsing, so its lookup
  failed before editing. The native typed-whitespace test replaces that invalid setup.
- The first Super probe did not compile because a nullable callback was invoked
  directly. It was corrected before collecting valid Super results. A native
  script had an import-order error before it sent events; a fresh-process driver
  also started before its window existed. Those are harness errors.
- A Text-only label collector could not locate a Super paragraph. Its geometry
  was inspected in a synthetic screenshot, and valid subsequent cases used
  native pointer coordinates. No missing-label exception is an app crash.
- Navigation-dependent phase-one final-row checks actually targeted Task 0062,
  not Task 0249, and stopped before the missing expected field. The later
  scrollbar-based actual last-row typing is the valid native edit evidence.
- No Flutter runtime failure was captured. Fresh process boundaries were still
  used to independently verify content/input failures and avoid reset artifacts.

Uncovered or limited: real Android/iOS devices and keyboards; real CJK input
methods; release-mode latency profiling; cross-row pointer drag selection,
document-wide Ctrl+A/cut/copy semantics; extended Unicode/grapheme stress;
checkbox clicks during simultaneous autosave/route changes; complete export;
very large Super Editor native scrolling; all possible mixed table/code/task
boundaries. These remain follow-up work, not implied passes.

## Validation and environment cleanup

`flutter analyze --no-pub`: **no issues**, recorded in `analysis.log`.

Only these existing relevant tests were run; **82 passed** (`baseline-tests.log`):

```text
flutter test --no-pub
  test/editor/rich_text_checklist_editor_test.dart
  test/editor/visual_editor_stability_test.dart
  test/editor/markdown_smart_editing_test.dart
  test/editor/smart_task_super_editor_test.dart
  test/core/markdown_checklist_helper_test.dart
  test/editor/editor_preview_checklist_integration_test.dart
  test/editor/wysiwyg_large_document_performance_test.dart
```

Temporary audit probes were run separately and then archived as `.dart.txt`.
They intentionally record failed application expectations without turning the
normal regression suite into a set of tests for broken behavior. Their results
must be read alongside each finding. No full test suite was run locally.

All three isolated audit process groups were terminated. The ordinary
`lib/main.dart` Linux debug target was rebuilt successfully after the audit;
the normal bundle no longer contains the audit server/harness. Source files for
the app and normal executable tests were not changed.

Suggested next pass: fix persisted input/paste/nesting/Home failures first, then
selection and IME handling, then continuation and navigation. Add a true
regression for each intended behavior, mark its finding fixed only after testing,
and keep the native reproductions as acceptance checks.
