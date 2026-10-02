# T22: reset/restart versus policy reload and worker application

Date: 2026-10-02 UTC. Human coordinator: hciengr. Worker: codex-t22-reset-policy. Review: pending.
Claim proposal: https://github.com/hciengr/bc250-vcn-community/issues/6 .
Snapshot commit: `444c2d857470031a4f1c0a4adf20b9e5f6b52af9`. Ledger SHA-256: `541cdc29d87939f6603851deefb31dfff4175e3b2881acd6e10a504ad4622f7a`.
Worker snapshot identities are in `evidence/exports/t22-reset-policy-2026-10-02/worker-snapshot.json`; its commit, ledger SHA-256 and source hashes identify the task baseline. No shared ownership changes or accepted claims are requested.

## Result

The recovered code supports a **state-transition → policy reload** connection. It does not establish a **soft reset → policy reload → VCN enablement** sequence.

- The two recorded direct callers of policy copier `0x2e69c` are feature-enable hook `0x2e3e8` and coordinator `0x2e190`.
- The conditional request handler `0x2e0e8` reaches `0x2e190(0)`, which calls graphics-state helper `0x2b018` and then policy copier `0x2e69c` using the original state argument. The copier call does not depend on a tested graphics-helper return status. This caller has busy/configuration and request checks; no unconditional transition is established.
- The copier writes requested-state word `0x13ed8` and performs twenty float stores through the SSIP/SSIU opcode. It does not invalidate current-state word `0x13ed4`.
- Feature enable also installs the worker pointer in callback slot 24. Neither that hook nor the coordinator reaches the worker by recovered direct calls. The callback consumer is a separate indirect path whose runtime cadence remains unknown.
- The resolved WRITE-reference inventory identifies current-state store `0x2e4ff` in the worker and requested-state store `0x2e6ad` in the copier. This is not exhaustive alias analysis and does not exclude other runtime writers.

The original firmware image initializes `[current, requested]` to `[8,0]`. Synthetic gate cases distinguish the hypotheses:

| Starting current state | Copy policy state | Words after copy | Worker gate |
|---:|---:|---|---|
| 8 | 0 | [8,0] | Unequal: processing permitted if invoked |
| 0 | 0 | [0,0] | Equal: processing skipped even with new requests |
| 1 | 0 | [1,0] | Unequal: processing permitted if invoked |

These are arithmetic/control-flow models, not execution observations. A soft reset has not been shown to restore `[8,0]`, reinstall the callback or otherwise invalidate applied state. Re-enabling feature bit 13 is not by itself a demonstrated way to force reapplication from `[0,0]`.

## Cleanup/restart comparison

The existing cleanup audit was rerun. Direct-call walks from `0x2ad78`, `0x29d04`, `0x2b018` and `0x2c10c` contain 3, 84, 36 and 100 nodes, respectively, with no recovered path to the policy copier or worker. Larger walks contain unresolved indirect calls; these negatives are bounded, not exclusion of all paths.

The thirteen resolved cleanup stores do not overlap the known row-6 state, its worker-state words, callback slot or requested-clock fields. The positive cleanup/reapply consumer targets child 25 / parent row 7. Its existence therefore cannot be used as the missing row-6 reset connection.

The coordinator/request path reaches the copier through a 45-node direct closure; feature enable reaches it through a 26-node closure. These are positive reachability controls, not argument-feasible execution proofs.

## SSIP / SSIU interpretation

Cadence pp620–622 documents identical opcode bits under different floating-point configurations. SSIP postincrement is preferred static inference because it aligns both reviewed producer/consumer layouts and is supported by CONST.S evidence. Under that interpretation the twenty stores populate indices 0–19, including DCLK/VCLK requests. SSIU remains the conditional shifted alternative. Neither mapping has been runtime validated.

This store is not itself a reset instruction. The hypothesis concerns its callers and the worker gate. PMFW policy/request fields do not establish PSP-local `0x6007` or KDB modification.

## Reproduce

From a community clone, with the original research workspace available:

```sh
ruby audit-tools/t22-reset-policy.rb /path/to/BC250
```

The checker refuses missing or changed firmware, refined function inventory or state instruction export. It emits input hashes, resolved writes, direct paths, indirect/missing boundaries, raw bytes at the two stores and three explicitly synthetic state cases. No imported or downloaded code is executed. Graph paths are derived from saved Ghidra exports and do not constitute a new disassembler.

In the research workspace, the companion existing audit is:

```sh
perl tools/audit-cleanup-restart.pl
```

Fresh outputs are bundled under `evidence/exports/t22-reset-policy-2026-10-02/`. The underlying firmware, refined graph, instruction export and cleanup auditor are not all included in a fresh community checkout; report those missing inputs. Root source notes: `notes/isa-cross-reference.md`, `notes/pmfw-state-gate.md`, `notes/gfx-to-video-path-trace.md`, `notes/cleanup-restart-dataflow.md`. The local Cadence reference was consulted; its status says the PDF is available, but it is not redistributed here.

## Callback scheduling follow-up

The offline follow-up narrows one previously unresolved edge. Literal `0x0ba4` contains dispatcher address `0x1b154`; routine `0x1024` passes that pointer to `0x26b4` with second argument 4. The recovered `0x26b4` stores its first argument into a queued 12-byte record. This supports a queued callback-dispatch mechanism, not a proven invocation on the board.

The feature hook `0x2e3e8` calls `0x1b1e4(24, 0x2e448)`. The registrar stores the pointer at callback base `0xc700 + 24*4 = 0xc760`. Dispatcher `0x1b154` walks from `0xc700` to `0xc7a0`, a 40-slot range containing that slot, and makes an indirect call through each pointer. These matching producer/consumer addresses provide a static route from feature registration to the policy worker, conditional on the installed pointer remaining present and the dispatcher actually executing.

There is also shared queue bookkeeping: literals `0x0b8c` and `0x17050` both point to `0x7ad8`. Routine `0x1024` attempts to enqueue only when that word is zero and sets it to one on a zero return from `0x26b4`; the dispatcher decrements it when nonzero. This is consistent with limiting outstanding dispatch requests. The source of entry into `0x1024`, queue consumer and cadence are unresolved; this is not evidence of a reset trigger.

`callback-followup.json` retains source hashes, literal bytes and the five recovered decompilations for review. The current-state word `0x13ed4`, requested-state word `0x13ed8` and bookkeeping word `0x7ad8` are distinct. Neither this queue registration nor the SSIP/SSIU store establishes invalidation of applied state. A queued worker could still skip processing when current equals requested.

## Bounded next step

Identify one specific reset entry or command with input revision and call-site evidence. Test whether it writes the worker current state, changes requested state or reinstalls/invokes callback slot 24. Stop at an unresolved indirect edge rather than labeling it a reset-to-enable connection.

Only a board-owner-reviewed capture of the actual reset event, active policy, both state words, correctly indexed requests, callback state and physical outcomes can establish runtime application. T22 remains open. No board was accessed and no firmware or registers were modified.

Credit: original project analysis and audit authors, the upstream SMU reversing contributors and Cadence ISA documentation. This worker shares the prior analysis's human coordinator; separate human reproduction is required before acceptance.
