# VCN clamp probe boundary and omitted local clock mode programming

Author: workspace analysis prepared for community review. Date: 2026-10-01.
Review: pending. Method: offline comparison of hash-pinned local sources.
No hardware was accessed; no BIOS, firmware or third-party loader was modified.

The checked-in community loader returns before its PGFSM request and local clock-gating sequence when `UVD_POWER_STATUS` reads `0xffffffff`. Its reported all-ones ladder therefore does not test the subsequent PGFSM sequence. Separately, the later clock sequence omits a reference-driver `CGC_CTRL` update that clears twenty mode fields, including `REGS_MODE`. These are source-confirmed findings; neither establishes the physical cause of BC250 MMIO inaccessibility.

## Evidence and reproduction

Run from the BC250 workspace root:

```sh
perl tools/audit-vcn-clamp-boundary.pl
```

The [audit tool](../../../tools/audit-vcn-clamp-boundary.pl) verifies four input SHA-256 values, checks eleven ladder offsets and base indices against the official local header, and checks control flow and clock-programming differences. [Saved output](../../../exports/vcn-clamp-boundary/audit.json) contains all input identities, twenty passing checks, the address table and the derived masks. This is a source/arithmetic audit, not firmware emulation or a kernel build.

Inputs:

- [Community loader snapshot](../../../analysis/reference-sources/vcn/community_enable_vcn.py), SHA-256 `19f9a01c4183b3a1155a2eb161d4ba2e648ccc1e4ff6ba6d2d29fdbc60e88f3d`.
- [VCN2 driver snapshot](../../../analysis/reference-sources/vcn/vcn_v2_0.c), SHA-256 `753849c7c491b137913668f77b8a3a0f539c7cf5cd46423db22b8f1513d9d9f6`.
- [Offset header](../../../analysis/reference-sources/vcn/vcn_2_0_0_offset.h), SHA-256 `026dabdbf0f2b731db71cd99a4f617f347589a61d8015afe29abb82f94ad5eb7`.
- [Mask header](../../../analysis/reference-sources/vcn/vcn_2_0_0_sh_mask.h), SHA-256 `4c9ed19c3e744be938ada218d188c19ad7dc71e0dfb1652637ab116618bd489e`.

## What the all ones run actually tests

In the loader, the eleven-register ladder begins around line 2961. The `POWER_STATUS == 0xffffffff` branch ends with `return False` around line 3010. The PGFSM request follows at line 3021; local CGC programming follows at lines 3036–3037. Both the uniform-all-ones and partial-response subcases return before those writes.

Consequently, the reported failure establishes that this probe path did not obtain usable power-status readback after the earlier external clock work. It does not establish a failed PGFSM request, a failed local-CGC clear, or an exhausted local power-on sequence. The PGFSM code already exists in this snapshot; adding that code again would not change this execution boundary.

The audit verifies the ladder's eleven reference addresses, including `UVD_VERSION` at GPU MMIO byte offset `0x20f24`, PGFSM at `0x1f800`/`0x1f804`, and JPEG probes at `0x1e200`/`0x1e424`. These derive from `(segment_base_dwords + header_offset) * 4`, with stock discovery bases `0x7800` and `0x7e00`. They are not host physical addresses or established SMN aliases.

The [external report](../../../third_party/bc250-vcn-enable/README.md) describes uniform all-ones after clock work on 2026-08-25 and hangs before clock work in July. Those remain attributed reports, not newly captured measurements. Eleven samples across two segments support broad inaccessibility of the sampled register file; they do not prove every address is inaccessible or uniquely locate rail isolation, reset, fabric decode or another barrier. A non-all-ones version read alone would likewise require corroboration against default/clamped data.

## Concrete difference in local clock programming

The ordinary non-DPG driver helper `vcn_v2_0_disable_clock_gating` performs:

1. A `CGC_CTRL` update for dynamic mode and delay fields.
2. A `CGC_GATE` update clearing `0x000fffff`.
3. A second `CGC_CTRL` update clearing twenty mode fields, aggregate mask `0x7ffff800`.
4. SUVD gate and mode updates.

The loader reproduces the low-field `CGC_CTRL` update with dynamic mode cleared and the `CGC_GATE` clear. It does not perform step 3 or the SUVD sequence. The driver's first update depends on `AMD_CG_SUPPORT_VCN_MGCG`; the loader hardcodes dynamic mode off. Its `0xfffff` gate-mask comment says 21 bits, but the mask contains twenty set bits and matches the driver's SYS-through-SCPU clear; this is a comment issue, not a missing MMSCH clear.

The omitted mode clear includes `UVD_CGC_CTRL__REGS_MODE_MASK = 0x00080000` at GPU MMIO byte offset `0x1ffb0`. The corresponding `CGC_GATE` register at `0x1ffa8` has a separate `REGS_MASK = 0x8`. Clearing the gate bits does not clear the control register's mode bits.

An arithmetic counterexample makes the difference explicit: with synthetic initial `CGC_CTRL = 0x00080000` and MGCG disabled, the loader leaves `0x00080104`; the reference helper's second update produces `0x00000104`. These values are synthetic, not board observations. If all omitted mode fields were already zero, this particular omission would make no difference. Its runtime relevance depends on independently valid initial register values and actual target behavior.

This mismatch concerns the path reached after the ladder succeeds. It cannot be the executed cause of the earlier all-ones return. It is a concrete correction to claims that the later sequence is fully kernel-exact, and a useful discriminator for future accessible-island testing.

## PGFSM error handling correction

The loader's failed-PGFSM message says the kernel treats the wait as fatal. In the attached reference driver, `vcn_v2_0_disable_static_power_gating` returns void and invokes both PGFSM waits as unchecked standalone statements. It proceeds to `POWER_STATUS` and the caller continues startup. The loader also explicitly continues on timeout. The installed kernel may differ and must be identified separately.

The reference non-DPG predicates are mode-specific: with static PG support, CONFIG `0x000aaaa5` expects `(STATUS & 0xfffff) == 0x000aaaa0`; without it, CONFIG `0x00055555` expects zero. These are comparative driver values, not an instruction to write into an inaccessible BC250 island. Clamped zero cannot establish power-on.

## Focused next experiment

Preserve the early-return boundary in the failing configuration. Record it as `stopped_before_local_pgfsm`, along with the complete ladder and a known-working non-VCN control read through the same access method. A working control read helps distinguish transport-wide failure but does not prove the VCN address path valid.

For a separately established accessible VCN configuration, capture the actual startup branch, MGCG/PG flags, raw PGFSM request/status and helper return, then compare `CGC_CTRL` before and after both driver updates. Record `REGS_MODE` and the other nineteen fields explicitly. Compare the complete ordinary helper with the loader's abbreviated sequence under matched board, BIOS, firmware, kernel and boot conditions. Do not splice DPG or VF sequencing into this comparison.

This experiment distinguishes an unexecuted local power sequence from a local-CGC discrepancy after accessibility. It does not require a broad MMIO sweep or guessing an isolation-clear register. Any later firmware boot claim still needs accepted firmware mappings, VCPU evidence and ring execution.

## Scope of this submission

This submission is ready for source review with a runnable artifact. Hardware causality and independent review remain pending. The user's latest stable pre/post results have not been attached to this submission because their raw artifacts and same-boot identities were not present in the request. No task ownership, accepted status or dashboard completion was changed.

Supporting context: [driver gate audit](../../../notes/vcn-driver-gate-audit.md), [startup dependencies](../../../notes/vcn-startup-dependencies.md), and [physical-test handoff](../../../notes/bc250-physical-test-handoff.md).

## Recovered firmware findings supporting this contribution

Credit: daveconde's [bc250-vcn-enable](https://github.com/daveconde/bc250-vcn-enable), rw-r-r-0644's [bc250-smu-unlock](https://github.com/rw-r-r-0644/bc250-smu-unlock), and the community contributors behind the sequences and hardware reports. The analysis below expands those leads; it does not replace their attribution.

The existing Ghidra work went beyond identifying a table. Firmware metrics dataflow and the named driver ABI independently identify child 22 as DCLK, child 23 as VCLK, and row 6 as their parent. Child 24 remains unnamed. The policy upload/worker trace locates DCLK and VCLK at copy indices 14 and 15 under preferred SSIP semantics. Current/requested state equality can skip worker application. SSIP and SSIU share opcode bits under different Xtensa configurations; both layouts remain in the trace output, and the preferred layout is not runtime validation.

For row 6, the recovered state-one sequence writes entry-sampled control OR 1, polls status bit 8, writes handshake 0x10000, and polls handshake bit 16 clear. It then caches state 1. Cache gates can bypass this sequence, and immediately matching poll values can satisfy it without measured edges. DCLK/VCLK child completion polls are separate. The address-helper trace establishes direct mapped stores for row 6 and rejects an apparent mailbox-forwarding edge whose offset bounds exclude row 6.

On the PSP side, the analysis follows ordinary type-13 loading through image processing to completion. A final nonzero image-processing result skips this route's completion call and therefore its conditional requests to write 1 to 0900C004 and 1F8A4. The header wrapper can try four positions; one failed key lookup need not determine the final status. The late writer discards its SVC result, so requested writes are not proof of accepted hardware writes. This does not identify every writer or establish physical reset/isolation semantics.

The five-entry PSP table for targets 1F8C4 through 1F8D4 is captured runtime state and later replayed. Its initial zero words are not a recovered cold-start configuration. Comparative VCN3 headers support a filter-register naming lead for 1F8A4; under that schema, a write of 1 keeps filter-enable set. Cross-generation applicability to BC250 VCN2.0.3 remains unverified, so the write should not be called a proven filter disable.

## Repeatable offline checks for contributors

These commands require this workspace's scripts, pinned source files, extracted stock-P3 firmware and saved instruction exports. They are not commands supplied by either upstream repository alone. Some existing auditors refresh their own JSON reports. None of these commands unlocks a board or accesses MMIO. Execute from the workspace root:

```sh
perl tools/audit-vcn-clamp-boundary.pl
perl tools/trace-row6-ack.pl --self-test
perl tools/trace-video-policy.pl
perl tools/audit-vcn-driver-gates.pl
perl tools/audit-psp-smu-ordering.pl
ruby tools/audit-vcn-load-reset-gate.rb
```

Rerun on 2026-10-01: all six commands completed successfully. Expected results are twenty clamp/source checks; nineteen row-6 fixture assertions; both policy layouts with SSIP preferred; nineteen driver source checks; verified PSP table/queue/instruction ordering; and twenty-six raw Thumb checks with five scoped branch fixtures. Record input identities when comparing another firmware or driver version rather than removing hash guards.

An independent source review should verify the loader return precedes PGFSM writes; derive 7FFFF800 from the twenty named driver fields; follow the metrics callback to the named VCLK/DCLK layout; follow both cache branches in the instruction listing; and inspect the final error path that bypasses the PSP completion call. The instruction exports and source locations are linked in the supporting notes. Passing these checks establishes the stated static contracts and fixture behavior, not live handshake completion or VCN readiness.

For board comparisons, retain raw samples and stage outcomes even when the experiment stops early. Classify PGFSM/local-CGC as not reached when the ladder returns; classify values as unavailable when access is invalid; capture a known-working transport control alongside the existing bounded ladder. Once access is independently established, preserve PG/MGCG flags and the mode-specific predicate, compare both CGC_CTRL updates, and retain the first failed wait result. For PSP correlation retain the final image-processing result, completion-call outcome and accepted-store evidence separately. VCPU and ring results remain subsequent milestones.

## Wider test review and correlated evidence

The [contribution runner](../../../tools/run-vcn-contribution-checks.rb) now executes sixteen selected offline auditors with separate stdout/stderr, exit codes, script/output hashes and core input hashes. Its [fresh manifest](../../../exports/vcn-clamp-boundary/community-review-2026-10-01/manifest.json) records sixteen successful command executions. Counts within each auditor describe different kinds of checks and must not be summed as independent hardware validations.

```sh
ruby tools/run-vcn-contribution-checks.rb exports/community-review-NEW-RUN
```

The output directory must be new. Inputs include the original extracted firmware, comparison capsule and saved Ghidra exports in their workspace paths; the script is not standalone. Existing auditors refresh some report files. No Python toolchain or hardware commands are run.

### SSIP correction joins independent layouts and named metrics

Cadence's configuration-dependent SSIP/SSIU encoding explains the misleading stock-decoder mapping without inventing an AMD semantic override. Fresh ISA arithmetic gives twenty worker matches for SSIP at 14020..14104, versus nineteen for SSIU at 1402C..14110. A second initializer's SSIP stores at 14118/1411C align with its readers; SSIU shifts them to 1411C/14120. CONST.S independently supports the applicable option. Index 19 is child 12, parent row 1 under SSIP; it must not be promoted into a VCN row-6 request.

This was a major static-analysis advance: it resolved a false-looking overflow and connected the uploaded BIOS policy to the independently named clock requests. The policy loader stages 49C bytes at 7FF0, validates them, and installs them at 7B54. Instruction-level loop reconstruction supplies twenty request stores and a 295-word table copy that decompiled C lost. It does not establish the runtime uploaded values.

The separate decoder recovery comparison reproduces 1290 -> 1297 functions, 97 -> 7 functions containing halt_baddata, and 158 added direct-call edges among entries present in both exports. More output is not a complete decoder-correctness proof. The experimental CONST.S extension and the SSIP/SSIU configuration inference are distinct qualifications.

### Policy mapping plus worker gates identifies an actionable capture

Feature bit 13 installs worker 2E448 in callback slot 24, consumed by the forty-slot callback walker. Feature bit, callback index, parent row and child number are different namespaces. The worker checks current 13ED4 against requested 13ED8; the child setter does not change those words. Thus mapped, nonzero requests alone do not establish application. Re-enabling the feature does not force a transition if both gate words are already zero.

Setter/read selectors are also different: DCLK setter 15/read 14, VCLK setter 16/read 15, sibling setter 11/read 10 (decimal). Readers return cached fields. A useful matched capture therefore includes active BIOS policy, both worker gate words, request fields, callback registration, and parent/child observations. Reusing a setter selector for its reader inspects another entry.

### Stored access policy and late PSP writes converge on targets, not yet physical effect

The full stored-P3 audit parses 1405 t24 pairs and 144 t45 pairs, verifying directory checksums and extraction equality. Neither object contains frame-C target rows or values in numeric interval [1E000,23000). The two direct VCN-range preloads are 1F8A4=0B and 1F820=185103. The pinned Steam Deck comparison supplies frame-C rows and the previously reported three candidate ranges. Six controls cover spanning ranges, other frames, preload separation and malformed streams.

The comparison joins the stored preload 1F8A4=0B with the ordinary-load completion request 1F8A4=01. Under comparative VCN3 definitions, both keep filter-enable bit 0 set while privilege fields differ. This is a focused field/sequence lead, not a proven BC250 filter disable, a runtime ACL inventory, or an absence proof for all dynamic grants. There are two distinct policy objects here: the PMFW BIOS clock policy and PSP stored access/configuration policies.

### Authentication controls narrow the load hypothesis

Fresh Navi10 tests reproduce all five expected cases: key ID missing in extracted stock BL and TOS tables; actual signature verification succeeds with the matching reference key; an enforced wrong-usage fixture rejects; one-byte signed-message corruption fails actual OpenSSL verification. The lookup statuses are modeled, not captured PSP returns. The firmware may use a runtime-populated trust table that differs from either extracted fixture.

Combining this with the raw type-13 error/completion trace establishes a conditional hypothesis worth testing: if the live final image-processing result fails, this ordinary route will skip its completion writes. It does not establish live rejection of this candidate, all alternate writers, or physical reset polarity. A useful test retains final status after all attempted headers, completion-call reachability, context, and accepted-store evidence from one invocation.

### False success indicators recur across independent layers

The reference driver can return zero without actual VCN enable dispatch; the examined Cyan table lacks the VCN-enable callback. PGFSM wait results are ignored in the ordinary helper. All-ones UVD_STATUS satisfies the bit-1 readiness predicate but cannot satisfy the exact DEADBEEF decode-ring result. The reference PSP submission code can also warn on a nonzero firmware response and still return zero/copy returned address fields on a bare-metal branch. These source findings do not prove the user's patched kernel takes those paths.

Likewise, a PSP completion bookkeeping byte may be set after mailbox error, and both DMA directions use channel zero. The audited DMA return contract requires synchronous mode-zero mailbox/internal results (1,3) plus independent payload verification; neither cache-synchronization instructions nor an idle status zero replace transaction evidence. These correlations support preserving the first failed stage, raw response, matching fence, and payload/guard results rather than promoting a final success flag.

### Historical model tests retain their scope

Saved Python logs report 44 tests for the image-conditioned startup regression, 64 for the DMA-era suite, 75 for schema-2 convergence, and 78 for schema-3 driver prerequisites. These overlapping evolving suites are historical, not rerun by the new runner and not additive. The stronger startup fixture reproduces a True return with dispatcher residue; the convergence fixtures preserve hardware_operations=0 and physical readiness unknown. They are useful negative controls against false-success interpretations, not observed board failures or VCN enablement.

The strongest remaining contributor targets are matched capture of policy application and sequencer observations, the actual installed driver's admission/dispatch path, and final PSP load outcome/completion writes. Local clock-sequence comparison becomes meaningful only once valid access is independently established. Functional ring and codec tests remain separate milestones.

## Deeper late completion and table consumer findings

The late PSP writes were traced beyond isolated addresses. In stock P3 type-13 completion, the 0900C004 write requires full context 0000FFFF. That value was traced back through message+44 to a literal created by the T02 ring worker, rather than a sampled hardware flag. Both context branches then reach E170E0's 1F8A4 write; that helper discards its SVC status.

The subsequent E0D6D0 helper performs mapped-buffer initialization. Completion then reads MMSCH bookkeeping state[19]. A nonzero byte suppresses this buffer helper's error; this read occurs after the late writes and does not gate the earlier 0900C004 write. VCN completion marks state[13], while RLC types use distinct slots 21 and 22. Whole-body recovered xrefs and instruction traces reject conflating those slots into a proven VCN-to-RLC readiness chain. See [completion predicate and state flow](../../../notes/psp-vcn-completion-state-flow.md).

The comparative Navi12 trace goes further: type-19 completion calls a checked address-publication handshake. It sends high/low address words through 1E130, commands 1/2 through 1E058, and requires exact 1E05C=80000001 for each stage; exhausted polls return 80000302. Its type-13 path checks MMSCH state[19] and can republish the same shared record. This establishes software VCN/MMSCH coupling in the comparison image, not an interchangeable BC250 enable sequence or established PMFW row-7/row-6 transition. See [Navi12 full protocol trace](../../../notes/navi12-tuple-trace.md).

The table-driven PSP writer was also expanded through corrected Thumb decoding. Ordinary sections feed target/value pairs into SVC 7C; sections 203/217 instead use direct pointer stores. A cached section-210 path uses SVC 7D page mapping and writes mapped_pointer+(target&FFF). Byte targets in this route differ from the type-22 loader's dword-index pairs, which shift targets left two. The runtime table producer and enabling byte remain unresolved. See [table consumer and mapped-store trace](../../../notes/harvest-indirect-write-path.md).

These findings provide specific next discriminators: retain request context, state[19], buffer-helper result and final completion result separately; for the comparison protocol retain the full record/address arguments and both checked responses; for table-driven writes establish runtime section contents and section kind before naming a target or claiming a hardware write.
