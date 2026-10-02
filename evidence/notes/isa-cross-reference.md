# ISA cross-reference of the recovered BC250 analysis

2026-09-28. Offline comparison against `tools/isa-summary.pdf`, Cadence
RI-2021.8, April 2022, 702 pages. SHA-256:
`474c4aaf2d429ff79c48127e738c4110cecd8072133169ad6d00a050edf244b7`.
The local PDF was text-extracted with MuPDF; opcode diagrams on pages 386,
475, 477, 594, 620 and 621 were also rendered and inspected. Page numbers
below are the document's printed pages (matching the PDF's one-based pages).
This is a focused audit of the recovered paths, not every firmware instruction.

## Main correction: the store opcode is configuration-dependent

**SSIP and SSIU have identical encoding diagrams.** Sections 8.3.312–313,
pages 620–622, give both the RRI8 encoding:

`imm8[23:16] | 1100[15:12] | s[11:8] | t[7:4] | 0011[3:0]`

SSIP belongs to the Floating-Point Coprocessor option; SSIU to the
Floating-Point 2000 Coprocessor option. SSIP stores through the old base,
then increments it by `4*imm8`. SSIU stores through `base+4*imm8`, then
updates the base. No AMD-specific override is needed for this distinction.
The previous claim that the raw opcode established SSIU was too strong.
Stock Ghidra selects SSIU; that choice is not evidence of BC250's configuration.

At `2e6c0`, bytes `03 c4 03` encode f0, a4 and increment 12 in **both**
configurations. At `2f1bc`, `03 c3 01` similarly encodes f0, a3 and increment 4.

| Evidence | SSIP / postincrement | SSIU / preincrement |
|---|---|---|
| Policy stores, 20 iterations | `14020..14104`, stride 12 | `1402c..14110`, stride 12 |
| Worker requests | All 20 align | First skipped; last beyond worker |
| Copy index 19 | `14104`, worker 19, child 12, parent row 1 | `14110`, no worker child |
| Neighbor stores in `2f190` | `14118`, `1411c` | `1411c`, `14120` |
| Neighbor's reader at `14118` | Matches first produced value | First produced value shifted |

Two independent layouts favor SSIP. Additionally, the instruction at
`2e451`, bytes `30 10 fa`, matches the manual's **CONST.S f1,0** encoding
(section 8.3.70, pages 386–387). Its four constants 0, 1, 2 and 0.5 match
the experimental `CONST.SF` extension. This is documented Floating-Point
Coprocessor behavior, further supporting that option over a decoder mixing
CONST.S with legacy SSIU. It is configuration evidence, not a runtime measurement.
The manual's CONST.S description says “double-precision” but its single-word
constant table and instruction title agree on the values used here.

**SSIP is now the preferred static interpretation.** Retain both alternatives
until the processor configuration or execution semantics are independently
established. No installed decoder was changed in this audit.

## Consequence for VCN and index 19

Under SSIP, source `7b54 + state*64 + 48 + 4*i` feeds worker index `i`.
All numbers in that expression are hexadecimal except the iteration variable.

| Role | Copy index (decimal) | State-zero source | Request | Child / parent |
|---|---:|---|---|---|
| Unnamed video sibling | 10 | `7bc4` | `14098` | 24 / 6 |
| DCLK | 14 | `7bd4` | `140c8` | 22 / 6 |
| VCLK | 15 | `7bd8` | `140d4` | 23 / 6 |
| Unnamed clock request | 19 | `7be8` | `14104` | 12 / 1 |

Thus index 19 has a plausible, structurally supported consumer: **the request
for child 12 on parent row 1**, not VCN's row 6. Its clock name and units are
not newly established by this audit. The previous “no consumer / adjacent
overwrite” finding is conditional on SSIU and must not be the sole result.
Independent metrics-derived child 22/23 identities are unchanged.

The common coordinator, table upload/validation and state-change gate still
apply. There is still no established transfer of row-7 tuple values into this
policy copy, nor a proven restart sequence that enables VCN.

## Other recovered semantics checked

| Analysis | ISA reference | Result and limits |
|---|---|---|
| Policy loop `2e6b5` | LOOPGTZ, §8.3.150, pp475–476 | Raw `76 a3 0a` yields LEND `2e6c3`; count 20 gives 20 iterations in normal loop-enabled execution. Decompiler's single iteration is inadequate. |
| BIOS table copy `1cb72` | LOOPNEZ, §8.3.151, pp476–478 | Raw `76 95 07` yields LEND `1cb7d`; `49c >> 2 = 127` hex = 295 words. |
| Table lookup `3472e` | LOOPNEZ, same section | Loop repeats count times unless an exit branch is taken. A jump to LEND does not loop back; sequential arrival does. |
| Policy numeric conversion | UFLOAT.S, §8.3.331, p636 | Unsigned integer to single precision; immediate zero means scale 1. It is not a float bitcast. Rounding is configuration/state sensitive for large values. |
| Four row-7 pair stores | S32I, §8.3.284, pp594–595 | Eight raw instructions retain destinations `115f850..115f86c`, stride 4. S32I has no base update; SSIP/SSIU issue does not shift them. Hardware field names remain unresolved. |
| Ring counter low byte | EXTUI, §8.3.109, p429 | `shift=0,width=8` extracts low 8 bits. Full-word load/increment/store of the counter remains distinct from index extraction. |
| Table entry length | L16UI, §8.3.133, p453; ADDX4, §8.3.16, p336 | Length is unsigned 16-bit; next entry is `entry+4*length`, modulo 32 bits. Python's `<I` header followed by `>>16` matches aligned little-endian layout in the fixtures. |
| Transfer argument/return mapping | CALL8, §8.3.59, pp375–376 | ENTRY rotates the requested window: caller a10 corresponds to callee a2. Supports the recovered argument and return flow; does not assign mailbox meanings by itself. |
| Literal pointers | L32R, §8.3.139, pp461–463 | PC-relative interpretation is conditional on the relevant LITBASE mode. Configured extended literal-base addressing and runtime memory contents cannot be inferred from the instruction name. |
| Transfer ordering | MEMW, §8.3.164, pp490–491 | Orders processor memory operations. It does not prove DMA completion, host coherency, ownership or cancellation. |

LOOP/LOOPGTZ/LOOPNEZ are not interchangeable at zero: LOOP can iterate
2^32 times, LOOPNEZ skips zero, LOOPGTZ skips signed nonpositive counts.
Automatic loop-back is disabled with PS.EXCM set. These are execution-state
qualifications, not a reason to discard the normal 20/295-iteration reconstruction.

## Cross-reference to replay_unlock_offline.py

The attached script explicitly models host control flow, not an Xtensa CPU.
Its ring index extraction, 16-byte entry geometry, full 32-bit counter wrap,
little-endian header length, four-byte entry stride and byte/halfword/word
bookkeeping agree with the selected instruction listings and ISA operations.
Its accepted fixture sizes keep arithmetic within the modeled bounds; it is
not a general implementation of every 32-bit wrap, alignment exception or
coprocessor state. No SSIP/SSIU instruction is executed by this script, so the
policy correction does not require changing its transport model.

DMA success, synthetic probe results, startup ownership and lack of concurrent
firmware activity remain model assumptions. The ISA cannot turn
`mock_completed` into observed DMA completion or a gate-byte write into VCN
enablement. The existing image-conditioned cleanup regression in
`startup-memory-regression.md` remains material: returned True does not mean
all scratch/dispatcher bytes were restored. Existing historical Python test
counts were not rerun or reasserted in this audit.

PSP ARM/Thumb SVC implementations and Navi12 power/reset register identities
are outside this Xtensa manual's scope. It cannot validate SVC #0x7c behavior,
PSP-to-SMU address aliases, firmware-type handoffs, or VCN readiness.

## Reproduction and artifacts

`perl tools/audit-isa-cross-reference.pl` pins both manual and firmware hashes,
independently checks selected instruction fields, and reports both layouts.
Result: `exports/navi12-tuple-trace/isa-cross-reference.json`.
`perl tools/trace-video-policy.pl` now emits **both** 20-entry interpretations
in `video-policy-flow.json`, with SSIP marked as the preferred static inference.
The original Ghidra instruction exports are retained as decoder evidence.
No Python execution, decoder rebuild, hardware access or SPI write was performed.
