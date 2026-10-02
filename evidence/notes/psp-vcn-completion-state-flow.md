# Type-13 completion: predicate origin and RLC state comparison

2026-09-26. Read-only Ghidra analysis of stock P3. All addresses below are
runtime mapped addresses unless explicitly called payload offsets. For t28,
mapped address = payload offset + 0xe00100. The routine under examination is
0xe0fb18 (payload 0xfa18), and its conditional write is at 0xe0fc1c.
Other 0x0900c004 writers, notably the restore routine 0xe0cf90, are separate
entry paths and must not inherit this routine's predicate by assumption.

## Result

The conditional write is controlled by a request-context argument equal to
0xffff, traceable to a constant in t02's ring worker. No RLC state read gates
this branch. There is a shared per-firmware state array, but the relevant
slots differ: VCN reads slot 19 and writes slot 13; completion for types 21
and 22 writes slots 21 and 22. No cross-slot RLC dependency was found.

The type-22 sequence writes 2 and later 3 to RLC_SRM_CNTL, without an observed
readback or wait on that register in this path. Thus these are ordered
software writes, not evidence that VCN waits for a hardware 2-to-3 transition.

## Exact condition and forward flow

The prologue saves incoming r0/r1/r2. After its local stack allocation,
`[sp+0x14]` is the saved second argument, not a global hardware flag.
Type 13 selects 0xe0fc0c through the byte dispatch table at 0xe0fb4a.

```
e0fc0c  r0 = saved_argument_2
e0fc0e  r1 = r0 - 0xff00
e0fc12  r1 -= 0xff
e0fc14  if (r1 != 0) goto e0fc1e
e0fc16..1c  SVC 0x7c(target=0x0900c004, value=1, width=4)
e0fc1e  call e170e0
```

Therefore the write requires `fw_type == 13 && argument_2 == 0x0000ffff`,
plus successful arrival at this completion stage. It is not a 16-bit mask
test: 0xffffffff does not satisfy it.

Both outcomes then call 0xe170e0, which requests a width-4 write of 1 to
0x1f8a4 and returns zero unconditionally, discarding the SVC status. The
preceding 0x0900c004 SVC status is also not checked before that call.

Next, 0xe0d6d0 is called with mode zero. If the descriptor at 0xe35cc0 has
a nonzero size, it computes a buffer address using that descriptor and the
64-bit base at 0xe18b88, maps 0x1000 bytes via 0xe06900, and clears words
at mapped offsets 0 and 0x40. With a zero descriptor size it returns
0xffff0007; mapping failure is propagated. There is no RLC MMIO operation
in this helper's immediate instruction flow. Its generic mapping service
is not exhaustively proven free of all indirect hardware activity.

At 0xe0fc32 completion reads byte `0xe55178 + 0x13 = 0xe5518b`.
If nonzero, it overwrites the buffer helper's result with zero. If zero,
it retains that result. The common tail marks the current type's byte 1
unless the retained result is exactly 0xffff0000. Consequently these bytes
must not be described as rigorous hardware-ready or error-free flags.
The final hook 0xe13558 is just `bx lr` in this image.

## Where 0xffff comes from

This is an instruction-backed producer-to-consumer chain:

1. t02 worker 0x2022ac sets r9=0xffff at 0x2022b6. It supplies that value
   as the fifth argument to ring processor 0x203558 at 0x202388 and
   0x202396 (stack stores at 0x20237a and 0x20238c).
2. 0x203558 preserves that argument and forwards it as argument 5 to
   0x20243c at 0x20358e. The LOAD_IP_FW command-6 branch in 0x20243c
   forwards it in r3 to 0x2013ca at 0x202624.
3. 0x2013ca builds message 0x1007. At 0x2013e2 it stores arguments 3/4
   into message offsets 0x40/0x44. It submits service 1 through SVC F2
   at 0x201404. Both its message-layout branches preserve offset 0x44.
4. t28 ARM entry 0xe01a0c forwards incoming r2 to the Thumb wrapper
   0xe069b0. For message 0x1007 that wrapper copies the 0x78-byte message
   into a local context and dispatches to 0xe0bb98.
5. Handler 0xe0c17c constructs the request/response fields at context
   offsets 0x38/0x3c, then calls 0xe0d9dc(context+0x38) at 0xe0c186.
   It does not replace context+0x44 on this branch.
6. 0xe0d9dc loads r6 from its input record+0xc at 0xe0da24: this is
   original message+0x44. It passes r6 as completion argument 2 at
   0xe0dc52, calling 0xe0fb18 at 0xe0dc56 after the loader's success checks.

This establishes the constant source for the traced ring-worker route.
Other service submitters could provide another context value. The exact
vendor name for this field is not required for, or established by, this
data-flow result; its use as an index elsewhere is consistent with a
context identifier/sentinel, not a sampled RLC register.

## Every recovered external xref into completion

The audit enumerated references to every address in the recovered function
body, excluding its internal references. Exactly three external references
were present; all are direct calls to its entry, with none to its interior.

| Call site | Caller | Type argument | Context argument |
|---|---|---|---|
| 0xe0dc56 | 0xe0d9dc | Request field, including 13/21/22 | Message+0x44 |
| 0xe0fea0 | 0xe0fe00 | Restricted to 9 or 10 | Literal 0xffff |
| 0xe1709c | 0xe16fbc | Literal 0x33 (51) | Literal 0xffff |

Only the first caller can select the type-13, 21, or 22 completion blocks.
The other calls do not make the RLC and VCN switch arms mutually reachable.
Raw scans found no embedded mapped entry pointer, with or without its Thumb
bit, in t02 or t28. Computed pointers and unresolved calls are not excluded.

## RLC preparation, data writes, and completion

The shared loader 0xe0d9dc dispatches preparation through 0xe0a900.
For type 22, preparation calls 0xe0b91c(22) at 0xe0ac98, which requests
`0x3b200 <- 2` at 0xe0b9c4. Later, the type-22-only branch at 0xe0dbc6
calls 0xe0a660 with buffer 0xe35840 and the loaded data length.
That helper consumes pairs `(DWORD register index, value)`, shifts each
index left two, and issues width-4 SVC 0x7c writes. It performs no reads
or polls and returns zero independently of the individual SVC results.
The runtime contents of this loaded table are not established by this pass.

After cleanup and success gating, completion type 22 selects 0xe0fcac,
which requests `0x3b200 <- 3` via 0xe0fc54/56, then marks state[22]=1.
There is no RLC_SRM_CNTL readback between the literal writes in this flow.

Correction to a possible overreading of the earlier report: 0xe0b91c
*supports* both types 21 and 22 for the write of 2, but the recovered
ordinary type-21 preparation branch in 0xe0a900 goes through 0xe0ac6e
and does not call that helper. It maps the data port at 0x3edd0 and
writes zero to 0x3edcc. Type-21 completion only marks state[21]; it does
not perform the type-22 write of 3. A helper's supported input is not
proof that the caller supplies that input.

Type 8 has a separate conditional RMW of RLC_CNTL at 0x3b000 and a cache
at 0xe188c4. Neither the type-13 arm nor the type-21/22 completion arms
consumes that cache. Generic type-switch membership is not a state edge.

## Shared state array, with distinct slots

| Slot (decimal) | Address | Observed completion role |
|---|---|---|
| 13 | 0xe55185 | Set by VCN tail, subject to result rule above |
| 19 | 0xe5518b | Read by VCN to suppress buffer helper error; set by type-19 tail |
| 21 | 0xe5518d | Set by type-21 tail |
| 22 | 0xe5518e | Set after type-22 control write |

The local ABI header names type 19 MMSCH. This is the actual cross-type
state read uncovered here, but it occurs after the conditional 0x0900c004
write and does not govern it. No read of state[13], state[21], or state[22]
was recovered in the compared completion paths.

Additional recovered array users: initializer 0xe0956c zeros 0x44 bytes;
restore 0xe0cf90 writes a type-indexed byte; region-removal 0xe0e344 clears
the byte indexed by the removed region's firmware type. Sharing that
bookkeeping array does not prove a shared hardware state transition.

## Evidence and limits

All new artifacts are under `exports/psp-vcn-state-flow/`:

- `t02-producer.asm`: constant creation, forwarding, and service message.
- `input-wrapper.asm`, `dispatch.asm`, `completion-xrefs.asm`: t28 argument flow.
- `state-array-xrefs.asm`, `helpers.asm`: state writes/reads and VCN buffer work.
- `rlc-control-xrefs.asm`, `global-audit.txt`: register candidates and all
  recovered external references into completion.
- `raw-address-audit.txt`: exact little-endian target/pointer search results.

`scripts/ExportStateFlowAudit.java` reproduces the whole-body xref and
scalar/literal candidate audit. It does not perform general symbolic
execution. The mapped Ghidra project has incomplete function coverage;
the broader baseline decompilation and raw switch bytes were also checked.
The exact 0x3b200 target appears only in the two t28 literal words already
resolved to writes; no exact t02 literal or encoded local-window alias was
found. Computed register addresses, loaded control-table contents, other
controller firmware, and runtime changes remain outside that negative result.

No dynamic hardware observation was made. The requested VCN -> shared flag
-> RLC transition -> PMFW mailbox chain is not established. The evidence
instead separates the request-context predicate, per-type bookkeeping, and
RLC control writes. The concrete new cross-type dependency to investigate is
VCN's read of state[19], not an assumed read of the RLC 2-to-3 transition.
