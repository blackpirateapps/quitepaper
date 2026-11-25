# Investigation notes

The native 250-page random-jump sequence reached pages 2, 125, 200 and 50.
During the following jump to page 249, the audit state endpoint failed to respond
within its 15-second timeout. Earlier jumps were also slow. This is an observed
stress failure; classification as a viewer freeze is pending independent timing
and recovery checks. The first stress script stopped, so none of its later
search, annotation or concurrent-raster assertions have yet run.

The first Reload Document check retained one controller annotation. No reload
loss bug is established; inspect persistence/drawn content after full settling.
The first two reload probes did not activate the menu reliably; exclude them.


Final classification: native long-document timing is tracked as PDF-09, with
sidebar-closed control timings near the deliberate 950ms wait floor. PDF-02
reload loss was ruled out by a full-settle, Back/save/reopen repeat. Native text
drag probes remained inconclusive and are excluded from confirmed findings.
Native menu targeting and premature asynchronous search assertions are retained
in logs but excluded from passing coverage. The export probe's initial fake-clock
setup hang was corrected; repeat observations confirm both export findings.


Final log review found four pre-existing Drift multiple-database warnings in
OCR viewer tests. The tests provided an OCR processing service but allowed the
viewer to construct its real document-service provider and an extra AppDatabase.
A test-only fake annotation resolver now prevents that unrelated construction.
No production source was changed. Focused checks are rerun after isolation.
Archived text logs have trailing whitespace stripped; log content is preserved.


Making the OCR resolver immediate also allowed the PDF viewer to mount in these
legacy toolbar tests. Three tests then exposed an unflushed Syncfusion 500ms
startup timer. The fixture now uses a valid one-page PDF and 600ms pumps, so the
viewer is actually mounted and its startup timer completes before assertions/end.
This remains test-only setup correction, not a production PDF fix.
