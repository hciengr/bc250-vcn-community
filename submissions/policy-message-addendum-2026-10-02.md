# Proposed addition to the policy comparison

Source note: the RN/CZN counts, matched hardware controls and usage-6 verification record in the accompanying message were supplied by the user. Their cited `output/video-decode-20260922/psp-analysis/` and `docs/video-decode-next-step.md` files were not found in this workspace during this review. Preserve the original investigator's credit and attach their source records when posting. The following addition uses independently available local static notes; it does not claim to have rerun those board tests.

## Pasteable addition

Our deeper t02/t28 tracing adds a specific next boundary to test. In the ordinary type-13 load path, t02's ring worker supplies the full `0x0000ffff` request context. The type-13 completion branch uses that context to request a write of `1` to `0x0900c004`, then requests a write of `1` to `0x1f8a4`. A nonzero final image-processing result bypasses this completion path. These are recovered software requests; the service return values are not checked in a way that proves either physical write took effect.

This gives us two distinct provisioning stages to correlate: policy-established access and later load-completion writes. The comparison shows missing policy rows; the recorded restoration controls show an accessibility effect; the static load path identifies a further conditional transition. Together they justify a bounded investigation, while leaving successful VCPU startup unresolved.

We also traced the postwrite bookkeeping: the VCN path reads state slot 19 and marks slot 13, while RLC completion uses slots 21/22. We found no RLC-state predicate gating this particular VCN completion branch. SAVE_RESTORE and AUTOLOAD_RLC are separate commands and paths; their results should be recorded separately from the ordinary type-13 load.

Useful contributor tests are:

1. Publish the matched stock/reference-policy logs with image hashes, board/kernel identity, boot boundaries and identical register sampling. Enumerate the changed policy rows so a complete-policy substitution is not mistaken for proof that one specific descriptor caused the effect.
2. In that same controlled sequence, correlate the actual type-13 request, full context, raw PSP completion status, and before/after samples of `0x0900c004`, `0x1f8a4`, PGFSM and VCN version/power registers. A caller returning success is insufficient when response errors can be suppressed.
3. After accessibility is established, compare clock-gating sequencing. Our source audit found an early all-ones POWER_STATUS exit before PGFSM/CGC writes, and a later CGC clear present in the reference driver but absent from the inspected community loader. That is a concrete sequencing difference, not a demonstrated cause of the clamp.
4. Record VCPU-ready and ring execution independently of register readability. Keep a signature verification result separate from runtime firmware acceptance, and keep successful service invocation separate from observed register change.

Credit belongs to the original policy-comparison and board-test authors for those observations, with the t02/t28 tracing and reproducible static audits identified as additional analysis. Attach their handles/permalinks rather than attributing an unidentified result to the entire community.

## Local sources

- `evidence/notes/psp-vcn-completion-state-flow.md`
- `evidence/notes/psp-vcn-restore-vs-autoload.md`
- `evidence/notes/vcn-contribution-review.md`
- `evidence/exports/vcn-clamp-boundary/audit.json`
