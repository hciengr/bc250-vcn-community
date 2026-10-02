# Feature registration and the row-6 worker state gate

The recovered worker has an indirect registration path, not just a direct Q3 request path. **Feature bit 13 installs it in callback slot 24.** Feature bit 13, callback slot 24, and parent row 6 are distinct firmware indices; none establishes a hardware block name.

## Registration chain

P3 feature table base is `0xcc98`. The dispatcher `0x1d940` uses enable callbacks at base `+0x10+4*bit` and disable callbacks at base `+0x110+4*bit`.

For bit 13 (`0x2000`):

| Item | Address/value |
|---|---|
| Enable pointer slot | `0xccdc` → `0x2e3e8` |
| Disable pointer slot | `0xcddc` → `0x2e43c` |
| Worker callback slot | `0xc760` = callback base `0xc700` + `24*4` |
| Registered worker | `0x2e448` |

`0x2e3e8` was absent from the original function export. After explicit seeding at its entry instruction, it calls `0x2e69c(0)` and `0x1b1e4(24, 0x2e448)`. The latter writes the callback pointer. It also initializes values and calls `0x247e8` for rows 0, 1, and 6. That helper is conditional on per-row bytes and invokes floating-point routines that are not fully modeled, so this alone does not prove row-6 hardware programming.

The disable hook calls `0x1b1f4(24)`, replacing the slot with the default callback. The consumer `0x1b154` walks pointers from `0xc700` up to `0xc7a0`, covering **40 slots**, including 24. Its invocation cadence remains unverified; the static loop establishes consumption of the slot.

The feature-mask handlers are present in queues:

| Operation | Handler | Q3/Q4 message | Q2 message |
|---|---|---|---|
| OR requested feature mask, run dispatcher | `0x1da78` | `0x3c` | `0x05` |
| Clear requested feature mask, run dispatcher | `0x1dac4` | `0x3d` | `0x06` |

They obtain a pointer through `0x1014` and operate on the word it points to. This is not the same argument-access helper as the child-value setter. The dispatcher compares requested and active bits; hook return value 1 updates active status. These are decoded protocols, not a recommendation to send hardware commands.

## What changes the worker gate

**Follow-up correction:** `2e69c` also contains a 20-iteration hardware loop loading clock-request floats from the BIOS interface policy table. Decompiled C hides the loop. The [ISA cross-reference](isa-cross-reference.md) corrects the earlier SSIU-only interpretation: SSIP shares the encoding under another configuration and has stronger static support. The [policy-to-video trace](gfx-to-video-path-trace.md) now distinguishes both source mappings. This function is not merely a gate-word setter.

The worker returns immediately when `*[0x13ed4] == *[0x13ed8]`. The image initializes these words to `[8,0]`. After processing, it copies the second into the first. Runtime values can differ from the image.

Recovered writer `0x2e69c(state)` stores the second word. Its confirmed direct callers are:

- `0x2e3e8`: the feature-enable hook supplies state 0.
- `0x2e190`: forwards a state argument; its recovered direct caller `0x2e0e8` supplies 0 after several checks.

`0x2e0e8` is queued as Q3/Q4 message `0x60` and Q5 message `0x0c`. It checks busy/configuration bytes, requires a zero request value, and checks `0x2e1b0` before its transition branch. The alternate branch is restricted to queue argument 5. No unconditional state transition is inferred from the existence of these queue slots.

The child-value setter `0x2e6c8` does **not** change the two gate words. Therefore a new requested value may remain unapplied while the words are equal, even when the setter reports success. Also, re-enabling the feature only writes the second word to zero: if both words are already zero, that operation alone does not force the worker through its processing loop. This follows from the decoded instructions; additional runtime writes or state transitions may exist.

## Reader/setter indexing mismatch

The setter uses one-based selectors 1–20. Both recovered readers use zero-based selectors 0–19:

| Row-6 child | Setter selector | Reader selector |
|---|---|---|
| 24 | 11 | 10 |
| 22 | 15 | 14 |
| 23 | 16 | 15 |

Setter: Q3/Q4 `0x1d`, handler `0x2e6c8`. Reader `0x2e734` is Q0 `0x11`; reader `0x2e7d4` is Q3/Q4 `0x42`. Both read the worker's cached float at `state_base + 0x5c + 12*reader_selector`. The setter writes requested data at `state_base + 0x140 + 12*setter_selector`, which is `state_base + 0x14c + 12*reader_selector`.

The first reader excludes entries mapping to children 19/20; the second lacks that exclusion. Row-6 entries pass both. **These are cached software fields, not direct hardware telemetry**, and their units remain unverified. Reusing a setter selector unchanged for a reader accesses a different entry.

## Analysis improvement and reproducibility

The separate experimental `CONST.SF` language was applied to a fresh full P3 import. Queue targets were seeded, followed by the two missed state-related function entries `0x2e3b8` and `0x2e3e8`.

- Functions: 1,290 → **1,297**.
- Functions containing `halt_baddata()`: 97 → **7**.
- **158 added direct-call edges** among entries present in both exports.
- Remaining truncated functions: `0x29a8`, `0x29d0`, `0x39698`, `0x39714`, `0x397e0`, `0x39ab8`, `0x3a9b8`.

The community-derived `CONST.SF` encoding remains experimental. In particular, `0x3a9b8`, used by numeric conversion paths, is still truncated. The extra output does not establish full decompiler correctness, exact numeric behavior, hardware reachability, or VCN enablement.

Use `exports/pmfw-p3-const-full/functions.jsonl` for the refined analysis; the attached `exports/pmfw-p3/functions.jsonl` remains the stock-decoder baseline. Full C and instruction evidence are in the refined directory. `exports/pmfw-state-gate/recovery.json` records source hashes, registration addresses, queue mappings, recovered functions and call edges; its companion JSONL contains 16 focused records. Run `perl tools/summarize-pmfw-recovery.pl` to regenerate that comparison from the existing exports.
