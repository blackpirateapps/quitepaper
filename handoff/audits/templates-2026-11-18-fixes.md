# Template audit remediation — November 19, 2026

The eight confirmed findings from the [November 18 audit](../../audits/templates-2026-11-18.md)
have been addressed in order on `audit/templates-2026-11-18`, with separate commits,
`HANDOFF.md` updates, static analysis and selected regression tests for each fix.
The original audit remains a historical assessment of `bbe720c`.

| Finding | Fix | Commit |
| --- | --- | --- |
| QPT-001 | Immutable content/security write inputs; serialized revision drain; protection and lock await persistence | `47dd444` |
| QPT-002 | Await exit flushing before Back/Close; retain notifier during saves; keep dirty editor on failure | `d37248f` |
| QPT-003 | Decode and inspect rich resource fields and rendered Markdown/HTML destinations, including tables | `430d687` |
| QPT-004 | Inspect actual resources/metadata rather than literal code or escaped text | `76abfc1` |
| QPT-005 | Refuse drag/barrier dismissal for template modals; respect busy Back/Escape guards | `d7e48ad` |
| QPT-006 | Preserve CRLF offsets, unrelated bytes and inline title comments during normalization | `bf36a27` |
| QPT-007 | Return committed notes despite ancillary errors; retry notification only; retain identity for failed opening retries | `a8b7478` |
| QPT-008 | Scroll header/search/catalog together; keep action footer reachable in constrained viewports | Commit containing this report |

Regression coverage includes real SQLite save/security races, actual route exit
and failed-save retry, encoded resources in Markdown/rich ASTs/tables, literal
technical snapshots, mobile/desktop dismissal during pending save/use, LF/CRLF
metadata preservation and synchronous/asynchronous postcommit failures.

Constrained picker tests exercise 320×568 with a 300-pixel keyboard inset,
568×320 landscape with a 150-pixel inset, a small desktop window, doubled text
size and both themes. They scroll to search/rows and create exactly one note;
controls are checked above the keyboard. Catalog rows remain lazy.

All test invocations select relevant paths and use one worker. The complete
suite is intentionally excluded by the repository instructions. Native-device
smoke testing, release-mode performance, exhaustive editor conversion fidelity
and process-kill/crash recovery remain outside this remediation's verification;
this report does not claim unrestricted production certification.

Per-finding commands/results are recorded in the corresponding root HANDOFF
entries. Final combined verification is recorded there after all fixes.
