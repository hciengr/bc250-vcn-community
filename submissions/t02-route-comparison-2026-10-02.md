# T02 follow-up: identify the route before diagnosing rejection

Human coordinator: hciengr. Worker: codex-t02-stage-audit. Review: pending.
Task/claim: T02, https://github.com/hciengr/bc250-vcn-community/issues/4 .
Main snapshot: `444c2d857470031a4f1c0a4adf20b9e5f6b52af9`.
Ledger SHA-256: `541cdc29d87939f6603851deefb31dfff4175e3b2881acd6e10a504ad4622f7a`.
Sources credited to Shalasere, pinned upstream revision `4a91ceb86275fbceeaf1fb3062f2f086e7f780c5`. This is source inspection, not independent reproduction of the author's hardware experiment.

## Findings that save repeated work

1. **The firmware identity is different or unresolved.** The upstream corrections report a 405,952-byte `vcn_2_0_3.bin`, with a 405,696-byte payload at offset 256. Our inspected Navi10 payload is 404,288 bytes; Van Gogh is 572,112 bytes. The reported payload is 1,408 bytes longer than our Navi10 candidate. Size establishes a mismatch in the recorded metadata, not lineage or incompatibility. No hash or bytes for the reported VCN image were available in this audit; upstream's sole firmware file at the pinned revision is a Van Gogh SMU image. Our first-header retry conclusion cannot be transferred to this unidentified VCN image.
2. **VCN registration is skipped unconditionally in the published source.** `code/direct-load/amdgpu_vcn.c` lines 1148–1182 show `amdgpu_vcn_setup_ucode` logging a skip and returning before the PSP registration block, with no conditional guard before the return. The source therefore does not provide stock VCN registration merely by setting `vcn_direct=0`. This is narrower than proving that no possible later path submits a request; runtime call-site evidence still matters.
3. **The published source does not include the documented mode-6 isolation.** `PATCHES.md` describes mode 6 skipping ring registration and hardware initialization. In the pinned `vcn_v2_0.c`, the decode ring initialization at lines 176–179 is unconditional, and the hardware-init function at lines 283–323 uses `if (!amdgpu_vcn_direct)` followed by a nonzero branch invoking `vcn_v2_0_start` and ring tests. The recorded parameter uses contain no numeric mode-6 checks. At these source sites, mode 6 follows the same nonzero branch as mode 1. This source snapshot cannot substantiate the documented mode-6 behavior; the exact experimental tree/module must be obtained before reproducing it.

These gaps do not invalidate the author's reported observations. They prevent equating a published source snapshot, a documented option and the actual module loaded during a recorded boot. They also make `vcn_direct=0` an unsuitable assumed stock control for this published tree.

## Route comparison

| Question | Our pinned PSP reference | Shalasere's pinned source/report |
|---|---|---|
| Is VCN registered for PSP loading? | Conditional on load mode, harvest and valid ucode metadata | Published setup function returns before registration |
| Where should firmware reside? | PSP-returned TMR fields feed the resume path | Nonzero direct option selects BO-based cache-address source |
| Does caller success prove acceptance? | No: audited bare-metal response handling can warn and return success | Successful module initialization is not a PSP acceptance observation when loading is skipped |
| Has VCPU/ring/media execution been established here? | No, not by this offline attempt | Upstream reports no decoding; our attempt does not reproduce runtime observations |
| Can the retry finding be shared across routes? | Only for the exact inspected input reaching the traced lookup | No request to that lookup is established for the direct route; reported input identity differs |

## Repeatable offline check

Obtain the public upstream Git repository with the pinned commit available, then run from the community clone:

```sh
ruby audit-tools/t02-upstream-route.rb /path/to/bc250-vcn-research
```

The checker reads six pinned Git objects with `git show`; it never builds or executes upstream code. It outputs source hashes, the full registration function, all direct-option uses in `vcn_v2_0.c`, and the reported firmware sizes. Expected: unconditional early return, no numeric isolation guards, and payload size 405696. Its source-layout assertions stop on unexpected input. Manual source inspection supplies the interpretation; the script is not a complete C control-flow parser.

Raw output, worker snapshot and hashes are under `evidence/exports/t02-route-comparison-2026-10-02/`. The community's saved Markdown snapshot omits the September 30 summary and corrections despite their presence in the cached Git commit. This audit read those exact Git objects rather than substituting older notes. Source input hashes cover all six objects. A fresh contributor needs the upstream clone; the cache is not bundled.

Controls: compare `vcn_direct=0` and nonzero branches in the same published function; compare documentation against code rather than treating it as executable evidence; compare reported size against both hash-pinned candidate metadata files. Negative result: no live PSP response, same-request trace, reported-image hash or actual loaded-module identity was obtained.

## Small next handoff

Ask the experiment owner to attach the VCN image SHA-256, exact patched tree/patch series, loaded module SHA-256, parameter value and timestamped boot log for the reported run. No new board probing is needed to establish these existing-file identities. Then classify that run as PSP-request, registration-skipped or unresolved before comparing errors.

For a genuine PSP request, continue the original T02 same-request capture checklist. For a direct/skipped request, investigate subsequent startup under its own route; it cannot locate a PSP rejection that was never submitted. Compare both paths only after matching board, firmware, policy and reset state. Proposed physical tests remain for board-owner review.

T02 remains open. Another accountable human must reproduce the bounded source inspection and review its scope. No proof status, ownership or governance changes are requested.
