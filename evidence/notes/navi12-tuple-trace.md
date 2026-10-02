# Navi12 loader sequence versus BC250 PMFW row-7 pairs

**Follow-up:** [Row-7 graphics-clock context](row7-gfx-clock-context.md) anchors the block to the named `QueryGfxclk` handler through an exact shared field and child-25 mapping. This favors clock configuration over the unproven VCN-clamp interpretation.

Static trace, 2026-09-28. No hardware writes were performed. The installed hybrid hash is user-reported; that full image and the pre-MMU bridge capture are not available here. This analysis does not demonstrate successful VCN enablement on that hybrid.

## Inputs and address conventions

- `/lib/firmware/amdgpu/navi12_sos.bin`: SHA-256 `a93ea08dfe4b6f90b241f713f8268392b2e0340898ab8d4800c02b4ee91a9223`.
- `firmware/smu/smu_fw_robin_1_trim`: SHA-256 `8c29cf0b1c5ea713f1f8ae95ed4c1dc547d00c530530c131950cfd5eb08c6675`.
- Navi12 instruction addresses below are **whole-file offsets**, not established runtime addresses. PMFW instruction addresses follow the existing zero-based import. SVC target arguments and SMU data addresses are separate namespaces; no host-accessible alias is implied.
- Independent LLVM and Ghidra Thumb decodes were used. Whole-file linear disassembly includes data and alignment errors; the focused Ghidra exports follow explicitly seeded code. Switch destinations were independently checked against raw TBB bytes in `exports/navi12-tuple-trace/verified-switches.json`. Seeded branch blocks are not necessarily independent functions despite export labels.

## The claimed preparation sequence is present

Navi12 `0xcbb0` dispatches case `0x13` through `0xccec` to `0xcd70`. Its operations are:

| File offset | Operation and arguments |
|---|---|
| `cd78` | SVC `7c(1f810, 0, 4)` |
| `cd80` | SVC `7b(1f810, stack_buffer, 4)` |
| `cd8a` | SVC `a6(21150, 1, 0)`; assertion uses the RMW primitive, **not** SVC 7c |
| `cd92` | SVC `7b(21150, stack_buffer, 4)` |
| `cd9a` | SVC `7c(21150, 0, 4)`; whole-word zero |
| `cda4`, `cdac` | Write `0ff00011` to `1e01c`, then read back |
| `cdb6`, `cdbe` | Write `3` to `1e01c`, then read back |
| `cdc8`, `cdd0` | Write `1` to `1e01c`, then read back |

The arm does not test returned SVC statuses or readback values before returning its initialized zero status. Readback is not a readiness predicate here. Public register names `UVD_POWER_STATUS` and `UVD_MMSCH_SOFT_RESET` are consistent with the local VCN header offsets; applicability of this secure mapping to BC250 still needs evidence.

Case `8` is a separate switch arm at `cc5c`: SVC `a6(3b000,0,1)`, then `a6(8020,4,0)`, poll bit 2 set, write the observed word with bit 2 cleared, poll bit 2 clear. Each poll has a `0xfa000` iteration budget, and exhaustion returns `ffff0000`. `8020` is constructed by MOVW, illustrating why literal-only absence tests are incomplete. No edge from the case-19 preparation arm to this case-8 arm has been established.

## Preparation is only part of the loader protocol

The loader at `ea20` obtains the firmware-type field at `ea5a`. On its generic path, call `eba4 → b94c` dispatches type 19 to `ba2e`, which calls `cbb0(0x13)`. The type-19 branch then supplies a `0x4000` length, stride 4, a SVC-7d mapping of `1e004`, zeros `1e000`, and supplies an `80000000` metadata flag. Type 13 takes a different branch, `b9ee`, supplying a 1 MiB memory-backed allocation.

The parent next calls `18e44` at `ec16`, and `14418` at `ec24`, with nonzero status paths bypassing completion. Following cleanup, the zero-status path calls `14d50` and then `10954(type, context, ...)` at `ecf0`. These are static control-flow facts; not all intervening helper semantics have been resolved, and they must not be elided into an unconditional write recipe.

Type **19 (`0x13`)**, consistent with `GFX_FW_TYPE_MMSCH` in local `psp_gfx_if.h`, selects completion block `10a32`:

```
1e01c <- 3; read back
1e01c <- 2
17c5e(2)             // counter-delta wait; not a verified duration in microseconds
1e01c <- 0
1e01c <- 80000000
122d0(type=19, context)
```

`17c5e` waits until the unsigned difference of two `96bc()` samples reaches argument+1. `96bc` reads a two-word counter through a runtime pointer and scales by `0x98`, shifting right 12. The clock source and units have not been established.

**There is a further, checked handshake after the completion writes.** `122d0` requires context `ffff` for type 19; otherwise it returns `ffff000a`. It constructs a 16-byte record at `00e5ffdc` and derives two 64-bit addresses from runtime bases, an offset, and helper `9708(13)`, subtracting `0x100000`. It passes one address to `18934`, which maps and copies the record, then passes the other to `123bc`:

1. Write address high word to `1e130`.
2. Write command `1` to `1e058` and poll `1e05c == 80000001`.
3. Write address low word to `1e130`.
4. Write command `2` to `1e058` and poll `1e05c == 80000001`.

Helper `12278` clears `1e05c` before each write and uses up to 1000 poll iterations for writes to `1e058`; mismatch returns `80000302`. Unlike the preparation readbacks, these reads gate progress. Exact hardware names and the destination-address semantics remain to be validated.

Type **13 (`0x0d`)**, consistent with VCN, selects completion block `10a6a`. It tests state byte `[00e5fd78 + 19]`; if set it calls the same `122d0(13, context)`, which updates a context bit in the shared record and republishes it. This is a concrete **VCN/MMSCH software coupling**, not an established transition between PMFW row 7 and row 6. The completion state update skips only status `ffff0000`, so a set state byte alone is not proof of successful hardware operation.

## The four PMFW pairs have a different, precisely recoverable data flow

PMFW `24330` reads indexed fields through `1cc70` and writes pairs to `0115f850/854`, `858/85c`, `860/864`, and `868/86c`. These addresses belong to the previously mapped row-7 block. The final pair format is:

```
P = (a << 8) | (b << 12) | (c << 20) | (d << 25)
Q = e
widths(a,b,c,d,e) = (4,4,4,2,8)
```

All bits of the initial `06900000` literal are replaced by masks. `P` has allowed-bit mask `06f0ff00`; `Q` is at most `ff`. Thus these are not direct copies of the Navi12 address/value operations above. An undocumented hardware interpretation could connect them, but this trace has not identified such an interpreter.

`1cc70(index,width)` uses `q=(index>>3)&fffffffc`, reads high word at `0115d004+q` and low word at `0115d000+q`, then extracts `width` bits starting at `index-8*q`. The sign-extended immediate is `fffffffc`, even though the instruction printer renders it as `fc`.

| Pair | a index | b index | c index | d index | e index |
|---|---|---|---|---|---|
| 0 | `2b20` | `2b24` | `2b28` | `2b2c` | `2b2e` |
| 1 | `2b36` | `2b3a` | `2b40` | `2b44` | `2b46` |
| 2 | `2b4e` | `2b52` | `2b56` | `2b5a` | `2b60` |
| 3 | `2b68` | `2b6c` | `2b70` | `2b74` | `2b76` |

Only three source words contribute bits to these particular fields (the generic helper also reads the following high word). For **all four** pairs to equal the proposed `(06900900,e8)`, these conditions must simultaneously hold:

| SMU source address | Mask | Required masked value |
|---|---|---|
| `0115d564` | `3fffffff` | `027a3909` |
| `0115d568` | `0fffffff` | `0e427a39` |
| `0115d56c` | `3fffffff` | `3a3909e8` |

These are derived requirements, **not observed register values**. The fields need `[9,0,9,3,e8]` for each pair. Reproduce with `perl tools/decode-row7-pairs.pl`; optionally supply three captured hexadecimal words in address order to decode actual pairs. The script checks the PMFW hash and reads source-index literals from the binary. Synthetic inputs equal to the required masked values reproduced all four proposed tuples; this validates the decoder, not runtime behavior.

The existing row-7 initializer `29e44` calls `24330`, then `24614`, then child updater `23800(25, ...)`. Searches of known `171ec` base users revealed initialization/control operations, not an established software interpreter for the four pairs. Computed references and hardware consumers remain outside that negative result. The prior cleanup trace still establishes row-7 reapplication only; it does not show a row-7-to-row-6 write.

### How the programmed block is subsequently driven

The constructor itself has a hardware-facing tail **before** it returns to `24614`. After the final pair store at `24573`, it packs four additional 4-bit source fields into `0115f8b4` (`245cd`), writes a source-derived bit to `0115f808` (`245db`), then writes **1 to `0115f818`** (`245e4`). It polls bit 8 of **`0115f964`** at `245fa/245fd`, without a timeout in this loop. Once that bit is set it writes `00010000` to **`0115f958`** (`24606`) and zero to **`0115f974`** (`2460e`). The polling address resolves from the image's row-7 base `5f800` plus status offset `164`; runtime mutation of those table fields would change it.

This is evidence for a program-registers → request → status-poll → finishing-writes protocol. A hardware block consuming the pair fields is a plausible interpretation, but the exact latch trigger, individual field meanings, and hardware domain name have not been established. In particular, bit 8 is not first proven clear in this tail, so passing the poll alone does not establish a new operation completed or that the pairs affected it. No firmware loop reading the eight pair words as address/value commands has been recovered.

## Evidence and next discriminators

Focused instruction exports are under `exports/navi12-tuple-trace/`: `navi12-functions.asm`, `navi12-branches.asm`, `navi12-finalizer.asm`, and `pmfw-pair-producer.asm`. Source requirements are machine-readable in `row7-source-constraints.json`.

Follow-up destination proof: `perl tools/prove-row7-pair-stores.pl` independently decodes the eight raw S32I instructions using the stock Xtensa encoding, checks the input hash, reads the base literal and row records, and reports both row mappings. Its output is saved as `store-proof.json`. The two direct row-register reads at the start of subsequent initializer `24614` resolve to `0115f834` and `0115f870`; neither reads a pair word. Other known references to the direct `0115f600` base perform initialization/control operations. This scoped consumer check does not exclude computed accesses or a hardware consumer and does not prove VCN enablement.

The strongest next discriminators are an existing capture of the three PMFW source words and a trace of the **complete** type-19 protocol, including its checked `1e058/1e05c` handshake and associated buffer. The isolated preparation writes do not establish equivalent Navi12 behavior or working VCN. The hybrid's runtime mapping and pre-MMU retention must be checked against its actual bridge artifact; stock-image code and the reported installed-image hash do not supply that evidence.
