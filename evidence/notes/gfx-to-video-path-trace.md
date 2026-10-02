# GFX to video clocks: coordination and the actual policy-table path

**ISA correction:** The [local manual audit](isa-cross-reference.md) establishes that SSIP and SSIU share identical opcode bits under different configurations. SSIP is now the preferred static inference: all 20 stores align with the worker and index 19 feeds child 12 / row 1. Under SSIP, state-zero DCLK/VCLK sources are `7bd4/7bd8` (copy indices 14/15), and the unnamed row-6 sibling's source is `7bc4` (index 10). The SSIU mapping below is retained as a conditional alternative. VCLK/DCLK child identities remain independently established; runtime configuration remains unverified.

Static P3 trace, 2026-09-28. Original firmware hash `8c29cf0b1c5ea713f1f8ae95ed4c1dc547d00c530530c131950cfd5eb08c6675`. No hardware accesses. This closes a policy-data producer gap, not VCN hardware readiness or the PSP-to-clock ordering gap.

## Result

No transfer of the four row-7 pair values into video-clock requests has been established. The recovered input to the video-clock worker instead comes from an uploaded **BIOS interface table**. A common state coordinator invokes the graphics branch and loads clock policy, but does not gate the latter on graphics-initialization success.

## Shared coordinator, without a clock-value handoff

`2e190(state)` calls `2b018(state)` at `2e195`, then `2e69c(state)` at `2e19a`. The second call reloads the original argument; no returned clock value or status is tested. For state zero, `2b018` can return early on its configuration/busy conditions. If its later branch executes, `246c8` operates on row 7 and clears graphics caches. Either normal return path is followed by `2e69c` in the parent.

This is an ordered common state transition, not evidence that row-7 hardware success triggers VCN. Exported direct-call graphs from `24330`, `29e44`, and `2acb8` did not reach `2e448` or `2e69c`; indirect scheduling and hardware effects are not excluded. The post-GFX helper `2e1f0` also uses a clock value from child 15, parent row 3, not a row-6 child.

## Newly recovered 20-word policy copy

The decompiler loses the hardware loop in `2e69c` and displays only one iteration. Instructions establish:

```text
2e69f  count = 20
2e6ad  [0x13ed8] = state
2e6af  source_base = 0x7b54 + state*0x64
2e6b2  destination_base = 0x14020
2e6b5  LOOPGTZ, end 2e6c3
2e6b8    read u32[source_base + 0x48]
2e6bb    convert unsigned integer to float
2e6be    source_base += 4
2e6c0    SSIU: store at destination_base+12, then update destination_base
```

The SSIU preincrement behavior is explicit in the installed stock Xtensa SLEIGH definition (`xtensaInstructions.sinc`, lines 1256–1259). It matters: the first destination is `1402c`, not `14020`. The 20 stores span `1402c..14110`; the traced worker's 20 request entries span `14020..14104`. Thus the copy aligns with worker indices 1..19 and one word beyond that range. This is a static addressing observation, not a claim of a firmware bug; the reason for the asymmetry is unresolved.

The relevant destinations match the independent metrics-based VCLK/DCLK identity:

| Clock | Child | Worker index | Policy source, state S | Request destination |
|---|---:|---:|---|---|
| DCLK | 22 | 14 | `0x7b54 + 0x64*S + 0x7c` | `0x140c8` |
| VCLK | 23 | 15 | `0x7b54 + 0x64*S + 0x80` | `0x140d4` |
| Unnamed row-6 sibling | 24 | 10 | `0x7b54 + 0x64*S + 0x6c` | `0x14098` |

For state zero, DCLK/VCLK sources are `7bd0/7bd4`. Their zero values in the extracted image do not establish runtime zero requests: the table is populated separately. The worker scales nonzero requests by approximately `0.001`, computes a child setting and conditionally calls `2362c`; zero requests follow `23730`. Processing requires `[13ed4] != [13ed8]`, then copies requested state into current state. Updating request fields while those state words are equal does not force processing.

## BIOS table producer and validation

The table-transfer dispatcher `1bafc` accepts table ID from the request's low nibble and follows an allowed-queue/descriptor path to an indirect callback. Table-0 upload pointer at `ca58` is `1bbbc`; its export pointer at `ca5c` is `1bc34`. AMD's [Cyan Skillfish interface](https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/pm/swsmu/inc/pmfw_if/smu11_driver_if_cyan_skillfish.h) names table 0 `TABLE_BIOS_IF`, intended for BIOS.

`1bbbc`, when its `29cd4(8)` gate is zero:

1. Calls transfer helper `3a89c` with the input descriptor, staging address `7ff0`, and length `49c`.
2. Calls validator `1bc5c` on staging. A zero result returns failure.
3. Calls `1cb6c(staging=7ff0, active=7b54, length=49c)` to install the table.
4. Updates additional policy fields and invokes further setup helpers.

`1cb6c` is a word-copy hardware loop; decompiled C again shows just one iteration. At length `49c`, its actual loop count is `127` hexadecimal (295 words). The active object covers `7b54..7fef`, immediately before staging. When the initial gate is nonzero, the upload callback returns success without this copy, so success alone does not prove the active table changed. The dispatcher has additional short-circuit paths and permission checks.

The validator has eight-entry hardware loops too. Instruction evidence checks eight 16-bit values at `+4` against inclusive 80..160, eight bytes at `+14` against inclusive 8..48, and eight state records at stride `64`. State checks include eight bytes at each state `+38` below 8, a byte at `+40` below 4, nonzero `+41` and word `+44` except state 7, plus nonzero object word `+3ec`. These checks do not establish that VCLK/DCLK are nonzero or appropriate for VCN.

This recovers:

```text
BIOS interface table upload (ID 0)
 → stage/validate/copy 0x49c bytes to 0x7b54
 → state selection 2e69c(S)
 → policy words converted into VCLK/DCLK request fields
 → scheduled or explicitly called worker, if its gate differs
 → child 23/22 → row 6 transition and child-register programming
```

## Boundary to PSP VCN/MMSCH

The stock BC250 PSP VCN completion path separately uses request context `ffff`, writes the two candidate targets, and reads MMSCH state byte 19 after its buffer helper. That read suppresses a software error; it does not poll these PMFW request fields or establish clock readiness. The Navi12 MMSCH address handshake is a different image's path and cannot substitute for a BC250 call edge. See `psp-vcn-completion-state-flow.md` and `navi12-tuple-trace.md`.

The remaining missing edge is **actual BIOS policy and request application → acknowledged VCN/MMSCH operation**. A runtime capture of the active `0x49c`-byte table, the two gate words, and video-clock requests would distinguish a missing policy from a later hardware/PSP failure. The pre-MMU bridge artifact and such a capture are not available in this workspace.

## Reproduction

`perl tools/trace-video-policy.pl` reads the original bytes and emits all 20 copy destinations with state-zero source values, identities, and limitations. Output: `exports/navi12-tuple-trace/video-policy-flow.json`. Instruction exports: `gfx-video-coordination.asm` and `video-policy-upload.asm`. `perl tools/identify-video-clocks.pl` independently rechecks the ABI/child mapping.
