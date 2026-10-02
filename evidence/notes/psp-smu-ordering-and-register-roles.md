# PSP/SMU ordering and register roles: narrowed constraints

Follow-up: [handoff confirmation audit](psp-smu-handoff-confirmation.md)
traces SVC-0x7d window allocation, the type-0x12 readiness poll, and a
completion byte that can be set even when the mailbox exchange failed.

This pass uses new read-only instruction exports for stock P3. There is still
no verified end-to-end hardware sequence. The useful result is a concrete
mailbox protocol, a saved-register dependency, and a reason not to conflate
similar mailbox addresses with a proven VCN power command.

## PSP mailbox protocol recovered

`0xe1180c` maps target `0x03b10700` for 0x20 bytes. Within the mapped window:

| Target | Role established by instructions |
|---|---|
| `0x03b10700` | Argument before submission; optional returned argument afterward |
| `0x03b10704` | Response / availability word |
| `0x03b10718` | Command submission word |

It first waits for a nonzero response, clears that response, writes the argument,
writes the command, then waits for another nonzero response. Exactly 1 denotes
success. Mapping failure returns `0xffff000c`; timeout returns `0x80000306`;
other nonzero responses return `0x80000307`. Waiting uses SVC 0x56 with argument
1 and a loop bound; the time unit is not established here. A timeout argument
of 0xffffffff selects unbounded waiting.

`0xe0fa6c` sends command 0x10 / argument 1 when byte refcount `0xe182b4` is zero.
`0xe0fab4` sends command 0x10 / argument 0 when releasing the final reference
(also when called with count zero). First acquisition increments the byte even
if mailbox submission fails; an incremented count is not evidence of success.
Byte saturation returns `0xffff300f`.

Conditional protected-region removal `0xe0e344`, when its third argument is
nonzero, performs the acquisition before reading/clearing region fields and
the release afterward, with exceptions on particular errors. Another caller
is `0xe01ff4`. These establish a scoped synchronization contract, not its
physical meaning. No command-0x10 call was found directly in the already
exported VCN load/restore handlers. Indirect/SVC paths remain possible.

## Why the apparent SMU match is not yet a verified handoff

PMFW's actual queue-register table at 0x700c has queue 5:

```
argument  0x03010700
response  0x03010704
command   0x03010718
```

The roles are independently established by helpers 0xffc, 0xfa8 and 0xf90.
The identical low offsets suggest a PSP/SMU address-space alias, but the
0x00a00000 difference is not proved as a physical alias by this observation.
There is also a semantic mismatch:

- PSP's generic mailbox caller uses command 3 in the SMU-type completion branch,
  while stock PMFW queue-5 entry 3 is null.
- Queue-5 command 0x10 maps to 0x2fd74. Its instructions unpack an argument into
  byte/halfword configuration arrays, set a flag and return response 1.
  It does not itself execute the domain-6 power sequence or poll its status.

Thus treating PSP command 0x10 response 1 as proof of VCN power is unjustified.
Possible explanations include address-space differences, generic firmware
branches not used by this platform, or different runtime firmware/protocols.
This pass does not choose among them. Queue-5 message 0x0c, previously associated
with a state transition, is a different command and must not be substituted.

## Five-entry table: capture then replay, not fixed enable constants

The image at `0xe188d8` contains addresses `0x1f8c4`, `0x1f8c8`, `0x1f8cc`,
`0x1f8d0`, `0x1f8d4`, each followed by an initially zero word.

Newly traced `0xe11560` reads each target with SVC 0x7b **into the corresponding
value word in that table**, checking each return status. Its caller 0xe14144
selects this sequence for argument 0xffff0004, after earlier checks.

The resume-like branch in `0xe0ff04`, selected by argument 0xffff0005, first
checks other saved state, then calls `0xe0fec8`. That helper writes:

1. `0x0900c004 <- 1`
2. `0x1f8a4 <- 1`
3. Each of the five **previously captured** values back to its target, in order.

The first two SVC results are overwritten; table-write errors stop the loop.
It is not a polling loop over table contents: the apparent condition in older
decompiled C was a mis-modeled SVC return. Initial zero values are not prescribed
hardware configuration. This establishes a save-before-replay dependency and
removes the justification for blindly replaying the ROM's initial table.

## Register roles versus actual bit names

| Target | Established role/order | Still unverified |
|---|---|---|
| `0x0900c004` | Whole-word 1 before `0x1f8a4`; host-context load, restore and resume-like paths | Vendor field name, polarity, reset/isolation/power meaning |
| `0x1f8a4` | Whole-word 1 in the same late paths; before saved-register replay | Completion/clock/reset semantics; hardware acknowledgment |
| `0x1f820` | Whole-word `0x185103` during type-13 protected-region setup, before region attributes | Bit layout and PSP-to-host address equivalence |
| `0x1f8c4..0x1f8d4` | Five captured/restored configuration words | Vendor names and valid cold-start values |

The PSP SVC window path is known: slot 0 maps a target to
`0x01000000 + (target & 0xfffff)` and programs its high bits in window controls
at `0x03220000/0x03220050`. That proves how the PSP issues the access, not that
the numeric target can be used unchanged as a host MMIO offset.

The public VCN2 header still provides no names for segment-1 offsets 0x8 / 0x29
under the candidate host mapping of 0x1f820 / 0x1f8a4. Community descriptions
of 0x0900c004 as cold reset remain hypotheses in this workspace; the searched
sources did not supply an authoritative field definition or an independently
verified mapping. External scripts were inspected as text only, not executed.

## What this changes for testing

The model must keep three acknowledgments separate: mailbox response 1,
SMU row-status transitions, and VCN VCPU/ring execution. None substitutes for
the others. A valid restore also needs state captured from the appropriate
runtime context; static table defaults do not satisfy that requirement.

The missing evidence is now more specific: establish the PSP/SMU address alias
and applicable command namespace; identify the actual runtime code path; obtain
named register fields or paired observations showing their effect; then observe
power/clock/VCPU/ring milestones on the BC-250. This machine has no BC-250,
so the last step remains unavailable locally.

Reproduce with `perl tools/audit-psp-smu-ordering.pl`. It checks input hashes,
the raw saved-register and queue tables, and mailbox instruction ordering.
Machine-readable results and assembly are under `exports/psp-smu-ordering/`.
