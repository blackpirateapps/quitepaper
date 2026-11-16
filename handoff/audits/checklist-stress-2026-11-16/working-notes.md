# Checklist adversarial audit — November 16, 2026

Branch: `fix/visual-markdown-editor-input`. Source under audit: `daad621`.
Status: in progress. Audit only; confirmed bugs are recorded before any fixes.

Scope: Visual and Markdown checklist editing, with separate Super Editor checks
for its smart task implementation. Synthetic notes only. No personal note data.

Planned coverage: large-list creation and loading; first/middle/last item editing;
Enter at start/middle/end, empty/whitespace/checked rows, forward/reverse selections,
repeated Enter; Backspace and forward Delete at character and item boundaries;
multiline paste and IME updates; wrapping, Unicode, nested tasks and alternate
markers; arrows, Home/End, selection and select-all; completion/folding and rapid
toggles; undo/redo, saved content, reopening and editor-mode conversions.

Confirmed findings and measured limits will be appended as the audit proceeds.


## Findings confirmed so far

All native reproductions below used `daad621`, synthetic notes, real Hyprland
mouse/key events, and saved-content inspection. No Flutter errors in these cases.
Evidence steps are in the native observation stream being preserved with the
final report. Status for all findings: **Open — audit only**.

| ID | Mode | Severity | Confirmed behavior |
| --- | --- | --- | --- |
| CL-01 | Visual | High | Enter with a forward/reverse selection retains selected text and splits at the selection anchor, not the replacement range (native cases 5–6) |
| CL-02 | Visual | High, data structure | Editing/saving a nested checklist persists flat tasks with no indentation; parent/child hierarchy is lost (native case 13) |
| CL-03 | Visual | Medium | Forward Delete at the end of First does not join the following Second task (native case 11) |
| CL-04 | Visual | Medium | Tag insertion inside a checklist silently loses `#`; immediate typing saves Task nativeaudit (native case 14) |

Preliminary IME/composition and Markdown continuation observations are recorded
in `widget-preliminary.md`; their scope and native confirmation are still being
worked through. Probe compilation/setup mistakes are excluded from app findings.


Additional observations awaiting final reproduction/classification:

- Native batch creation of 81 tasks produced 81 rows but dropped/reassigned
  letters during continued typing after Enter, beginning around the first
  viewport scroll. Reproduce at slower pace and with a freshly opened long list
  before treating input timing as a confirmed root cause.
- Native checklist paste placed content before Alpha rather than after it, and
  an early saved-content snapshot still held the original note. Recheck after a
  longer autosave wait and reopening; an item-count-only assertion was too weak.
- Super Editor nested Markdown collapsed Parent/Child/Grandchild into a single
  ParentChildGrandchild task for both two- and four-space indentation. Native
  and widget observations agree; confirm after editing/saving and reopening.
- Markdown quoted and numbered task continuation loses the checkbox marker in
  native cases 18–19. Visual Link Note inside a checklist loses its [[ trigger
  in case 24, matching the checklist Tag focus/persistence problem.

Harness exclusions: the first Super probe did not compile because its callback
was nullable; corrected before collecting results. One native script stopped on
an import-order error before sending events; corrected before replay. A folded
paragraph was not represented by the harness's Text-only label collector; its
position was inspected visually and the check resumed with native coordinates.
These are audit-tool errors, not application bugs.


Phase-one limits requiring confirmation: rapid Down navigation in the 250-row
list reached task 27 after 124 Down events and task 62 after 249, so the script's
assumption that each event completed a focus transition was false. Its supposed
last-row edit/redo/completion checks are invalid and will not be reported as
final-row coverage. Enter/Backspace at the reached row preserved all 250 tasks;
undo preserved all original content. The separate widget probe genuinely reaches
and checks the final row at 1,000 tasks. A slower native navigation control and
scroll-thumb targeting will be used for the actual final-row audit.

The first native folded-boundary check also produced unexpected paragraph
content after synthetic input, whereas the existing and additional widget
boundary checks pass. It is not counted as a confirmed product bug without a
fresh-process repetition. Phase one is closed; phase two has a clean native
process to separate genuine product failures from reset/input timing effects.


## Fresh-process confirmations

- Rapid Enter/type creation reproduces immediately in phase two, case 1. Forty
  new tasks (`t1` through `t40`) yield 41 rows but persist merged/truncated labels
  such as `t1t2`, missing prefixes, and stale suffixes. The driver's base delay is
  65ms after each dispatched key plus command overhead. The control waits 400ms
  after Enter and 150ms after each label: all 31 tasks are exact (phase two,
  case 2). **Confirmed high-severity input-routing bug in the Linux debug build**;
  release builds and other devices remain unmeasured.
- Paste after Alpha reproducibly gives `empty`, `Beta`, `Gamma Alpha`, `Neighbor`
  rather than Alpha/Beta/Gamma/Neighbor. Four seconds of autosave and reopening
  confirm the wrong placement is persisted (phase two, cases 3–4). The earlier
  apparent missing autosave was a premature snapshot, not a separate save bug.
- Super Editor parse/save collapses nested child rows and their completion state:
  persisted text becomes `- [ ] ParentChildGrandchild` / `- [ ] Siblingx`
  (phase two, case 5). This is confirmed data-structure loss, separate from
  Visual mode's flattening.


Phase-three confirmations/limits:

- Native Super Editor Home at a clicked paragraph's offset zero changes Tail
  into `. TailTail` and moves the caret to offset 6 (phase three, case 1), before
  Backspace is pressed. The earlier folded-boundary symptom is therefore a
  Home/input mutation, not evidence that folded Backspace itself is broken.
- Ten Down events with a 350ms extra wait between them reach Task 0002 rather
  than Task 0010 in a 250-row Visual list (phase three, case 2). The navigation
  anomaly persists with a slower control; extra focus/state isolation is still
  being checked.
- Clicking the custom scrollbar track correctly reaches the actual last row.
  Editing Task 0249 preserves every other row. The subsequent Ctrl+Z and
  checkbox click did not change the recorded document; those observations are
  retained as unresolved, not silently counted as passing history/completion.
- 1,000 short tasks load as Visual and a controlled Enter/Backspace leaves all
  content intact. At 1,250 lines, the expected Markdown fallback retains the
  complete source. The first fallback typing attempt clicked the midpoint of a
  very tall text field outside the viewport; that check is excluded and the
  actual visible first line is used for the corrected control.
