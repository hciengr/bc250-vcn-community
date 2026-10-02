# T02: conditional header-retry narrowing and live-capture handoff

Human coordinator: hciengr. Worker: codex-t02-stage-audit. Date: 2026-10-02 UTC.
Review: pending. Proposed claim: https://github.com/hciengr/bc250-vcn-community/issues/4 .
Source commit: `444c2d857470031a4f1c0a4adf20b9e5f6b52af9`.
Ledger SHA-256: `541cdc29d87939f6603851deefb31dfff4175e3b2881acd6e10a504ad4622f7a`.

## Result

The two inspected candidate files have first-header byte `+0x7f = 0` and word `+0x18 = 0`. At analysis VA `0xe0a0e8`, a failed lookup branches to return when byte +0x7f is zero. **If this exact first payload header reaches that routine unchanged, a failed first lookup returns immediately; these headers do not request a retry after that failure.** The generic four-header wrapper remains real, but its retry possibility is conditional. No live request header or rejecting instruction was captured here.

| Input | SHA-256 | Payload offset | Payload length | First key ID |
|---|---|---:|---:|---|
| navi10_vcn.bin | ac5f2182b0ddee7a2886bf1239a47b4027becd0c37a1b0b6cac1f335393302c9 | 256 | 404288 | c37290c310e64a62b027c56695492368 |
| vangogh_vcn.bin | eafebdb4043b825b12826198a7d76d8acc4e251fb102329dc1c78cf7bdcc15e2 | 256 | 572112 | 70ec3e2d8a694792ac7969ff8ac9caca |

Fresh existing auditors passed: the lookup wrapper's failure status is retained through the image processing return; the staging-to-KDB copy contract is reproduced; and the pinned driver can preserve caller success despite some raw PSP response errors. These remain static findings. Missing IDs in extracted tables do not establish the live KDB contents. Signature verification does not establish runtime acceptance.

T01 has no accepted baseline. Read-only local PCI inventory found no AMD 1002:13fe device; that does not establish the availability of remote boards. No board was accessed. T02's same-request completion criterion is unmet, so it remains open.

## Reproduce

From the community clone:

```sh
ruby audit-tools/test-t02-header-retry.rb
ruby audit-tools/t02-header-retry.rb /path/to/navi10_vcn.bin ac5f2182b0ddee7a2886bf1239a47b4027becd0c37a1b0b6cac1f335393302c9
ruby audit-tools/t02-header-retry.rb /path/to/vangogh_vcn.bin eafebdb4043b825b12826198a7d76d8acc4e251fb102329dc1c78cf7bdcc15e2
```

Expected: both file results report a false retry predicate, flag zero, word zero and the identities above. Nine controls cover first failure with flag zero, word nonzero, retry then success, four failed attempts, first success, valid metadata, wrong hash, truncated outer header and invalid payload bounds. These controls are synthetic branch models and parser tests, not CPU execution.

Fresh static reruns in the larger research workspace:

```sh
ruby tools/audit-vcn-load-reset-gate.rb
perl tools/audit-vcn-load-contract.pl
perl tools/audit-vcn-kdb-provenance.pl
```

The raw outputs and input/tool identities are bundled under `evidence/exports/t02-stage-audit-2026-10-02/`. Only the load/reset auditor is bundled in the community checkout. The other scripts and firmware inputs are workspace prerequisites; missing inputs must be reported. Firmware binaries are not redistributed. Hashes identify this installed firmware, not a universal filename version.

## Proposed same-request capture for a board owner

Complete T01 first. Preserve board identity, boot ID, BIOS and candidate hashes, kernel commit/patches, startup route, timestamps, and original logs. Document and review any tracing method before hardware use.

For one ordinary LOAD_IP_FW request, correlate command, firmware type, byte length, submitted buffer/address and header bytes, submitted fence index and matching completion fence, raw response status and returned firmware address. Capture the actual header pointer, lookup wrapper return/status and retry index, plus a stage-specific path trace from that same request. Keep SAVE_RESTORE and AUTOLOAD_RLC paths separate.

Discriminating observations:

- Failure before the lookup wrapper: investigate prerequisites; a missing-key model cannot explain that captured path.
- Lookup entry: retain the exact header key ID and live KDB bytes with provenance. Validate the outer object and +0x108 magic; compare the copied object length, excluding the firmware trailer. Do not assume the analysis VA `0xe25834` is a usable host address.
- Wrapper exit: correlate its final status and retry index with image processor analysis VA `0xe16dfa` call / `0xe16e00` failure branch. For unchanged inspected root headers, failure predicts index zero and one attempt.
- Successful lookup: distinguish header processing, signature processing and later failures. A matching key or valid offline signature cannot locate those failures.

All VAs above are static analysis coordinates requiring runtime translation. Proposed traces are not authorized register writes or provided board instructions. Retain negative and contradictory observations. A response code alone is insufficient to distinguish multiple paths that can return it.

Credit: the existing project audit authors and source notes attached to T02. Community work by daveconde, rw-r-r-0644 and Shalasere remains attributed to its original repositories; this attempt does not independently reproduce their hardware observations. A different accountable human must reproduce and review this result before acceptance.
