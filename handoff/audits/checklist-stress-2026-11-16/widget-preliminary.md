# Preliminary widget findings (native confirmation pending)

Source `daad621`, temporary adversarial probes. These are observational probes,
not passing regression coverage for the intended behavior. The 82 existing
relevant tests passed before these sequences were exercised.

- Visual Enter over a forward/reverse selection splits at the selection anchor
  and retains the selected letters. `AlphaBeta`, selected offsets 2–7, should
  replace `phaBe` with a new task boundary; actual rows are `Al` / `phaBeta`
  (forward) or `AlphaBe` / `ta` (reverse).
- Visual IME text updates containing Enter keep the newline inside one task
  instead of creating a new checkbox. Empty-task IME Enter also stays a task.
  Canonical JSON and subsequent Markdown conversion disagree about structure.
- Visual hardware Enter during active composition splits the row instead of
  letting the IME confirm the composition. Confirmed at the widget level only;
  a real CJK input-method session has not been exercised.
- Visual forward Delete at a task's end does not join the next task.
- Loading a nested checklist in Visual drops all child indentation during
  serialization; a later save/mode conversion can flatten the hierarchy.
- Multiline IME/plain input stays inside a single task; Markdown conversion
  turns its continuation lines into paragraphs. The exact desired multiline
  editing behavior needs distinguishing from structured checklist paste.
- Markdown Enter in a quoted task continues only `> `; numbered tasks continue
  only their number. In both cases the new line loses the checkbox marker.

One whitespace fixture was trimmed by the parser before the intended probe;
that probe is an invalid setup, not a confirmed application bug. Retest by typing
spaces into a mounted empty task. Native confirmation uses fresh synthetic notes.

Large-list probes at 50, 250 and 1,000 rows preserve the full original content
through middle Enter/Backspace and final-row edit/undo. No runtime exceptions.
The mounted surface probe takes roughly 1.5s, 5s and 16s respectively for the
whole sequence in this debug widget environment; these are not per-keystroke
latencies or release-build benchmarks.
