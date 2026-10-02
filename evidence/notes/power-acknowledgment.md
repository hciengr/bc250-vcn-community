# Power acknowledgment: recovered row-6 handshake and its limits

Named hardware-status follow-up: [VCN local power status](vcn-physical-power-status.md)
identifies UVD_PGFSM_STATUS at GPU MMIO byte offset `0x1f804`, with driver-defined
tile power-on predicates. It is not a demonstrated alias of this row-6 status
or an always-on root-supply power-good register.

Implemented follow-up: the [second convergence run](parallel-channel-convergence.md)
now requires fresh modeled state-one parent completion as its fourth channel.
It retains the separate physical-power and ordering assumptions; completion of
this protocol does not silently set either acknowledgment.

The concrete candidate is the parent-domain handshake in `23b14(6,state)`.
It is stronger evidence than a mailbox reply or cache byte, but its physical
meaning is not yet established as VCN power-good, reset release or isolation
release. Row 6 is independently identified as the parent of DCLK/VCLK.
Those facts do not identify every bit in its control/status block.

## State-one transition

All addresses below are PMFW-local, not established host SMN aliases.
The row record at `f700` supplies base `6d000`, status offset `190`, control
offset `17c` and handshake offset `184`. The mapper adds `01100000`.

| Order | Instruction site | Operation / completion predicate |
|---|---|---|
| 0 | `23b22..23b2b` | If cache byte `f714` equals requested state, return without hardware observation |
| 1 | `23b4a`, `23b4f..23b52` | Read control `0116d17c`; write sampled control OR `1` |
| 2 | `23b5c..23b62` | Poll `0116d190` until `(value & 0x100) != 0` |
| 3 | `23b65..23b6a` | Write whole word `0x10000` to `0116d184` |
| 4 | `23b72..23b78` | Poll `0116d184` until `(value & 0x10000) == 0` |
| 5 | `23b7b` | Store 1 to cache byte `f714`, then return |

Neither poll contains a timeout. The routine does not require observing the
status bit change from zero to one, or reading handshake bit 16 as set before
it clears. Immediate matching samples permit success. Thus the precise
acknowledgment is **ordered predicates after writes**, not proof of measured
edges or a unique transaction token. The handshake write is not an RMW that
preserves all other bits.

`233e8` implements direct mapped stores for these row-6 offsets. Its alternate
mailbox path applies only to `(5afff,5b7ff]`, excluding row 6. No additional
PSP acknowledgment is returned by this writer.

## Why cached state is insufficient

The original image has `f714=1`. `23b14(6,1)` can therefore return at `23b80`
without either poll. Caller `2362c` also skips the parent call if this cache is
nonzero. The inspected startup initializer does not refresh that byte from
hardware. These are two distinct bypass points.

After the child-setting write, `2362c` independently waits for bit 16 set at
DCLK `0116d124`, VCLK `0116d14c`, or child 24 `0116d174`. Those waits are not
the parent handshake-bit-clear test at `0116d184`. A child-setting acknowledgment
does not prove the parent transition ran during the same operation.

## State-zero transition is a different protocol

With a differing cache, state zero writes `1` to handshake `0116d184`, waits
for bit 0 to clear, writes the **entry-sampled** control value OR `0x10`, waits
for status `0116d190` bit 12 to become set, then stores zero to the cache.
It is not simply the inverse polarity of the state-one status bit. Calling it
power-off would require independent register semantics. The row-6 wrapper
`24764` reaches this path after setting three child-mask bits at `0116d0f8`.

## Offline model and convergence implication

`tools/trace-row6-ack.pl` derives the addresses from the hash-pinned image and
independently checks five bit-branch encodings against Cadence ISA BBCI/BBSI
sections 8.3.28/31, pp345–346/348. It then evaluates ordered fixture samples.
Cases cover successful two-stage completion, immediate matching predicates,
cache bypass, each stalled wait, and the distinct state-zero protocol.

The model distinguishes `fresh_parent_ack` from `physical_power_ack`.
Only a completed modeled protocol sets the first; the second remains unknown
in every fixture. Cache bypass records no fresh observation. Exhausted samples
mean observation stopped while firmware would continue polling, with no cache
update, cancellation or inferred rollback.

Consequently, the convergence model's `mock_power_ack` must not automatically
be replaced by this cache or one successful poll. The next justified refinement
is a row-6 protocol-completion gate **plus** an explicit physical-meaning/ordering
assumption. Power, clock application, reset/isolation and VCPU readiness stay
separate until their hardware relationship is established.

Reproduction:

```sh
perl tools/trace-row6-ack.pl --self-test
perl tools/trace-row6-ack.pl
```

Artifacts: `exports/power-ack/row6-transition.asm` (fresh read-only Ghidra export),
`trace.json`, and `tests.tap`. Existing supporting traces are
`exports/xref-convergence/row6-cache-provenance.md` and `row6-child-evidence.md`.
No firmware, registers or hardware state were changed.
