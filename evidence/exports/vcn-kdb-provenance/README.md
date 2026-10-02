# BC-250 KDB provenance: confirmed copy path, unresolved staging producer

2026-09-27. Read-only analysis; no PSP execution or hardware access.

The table producer inside t28 is identified. It copies from a staged object
into the same fixed buffer used by key lookup. The preceding producer that
fills that staging object is still missing, so the extracted P3 TOS KDB is
a candidate source, not yet the proven live table.

## Established chain

```text
t02 startup path: boot_context = 0xA0000
  -> u32[boot_context+0x23c]
  -> staging_base = 0x04000000 + (value & 0x03ffffff)
  -> kernel global 0x601c
  -> SVC 0x73 returns that global
  -> t28 0xe097e8 maps staging_base+0x784000
  -> checks $KDB at source+0x108
  -> copies 0x100+u32[source+0x100] bytes into 0xe25834
  -> lookup 0xe0a130 walks records in that buffer
```

The consumer does not take a caller-selected table pointer: it loads the
fixed address `0xe25834` itself. That address is an analysis VA in the
existing t28 mapping, not a host physical address to read directly.

Existing kernel evidence is in `../vcn-key-search/pre-staging-init.asm`,
`kernel-boot-context.asm`, and `kernel-svc.asm`; the earlier synthesis is
`../../notes/keydb-runtime-origin.md`. This pass rechecked the t02 SVC jump
table for both 0x73 and 0x87 and the shared producer/consumer address literals
against hash-pinned firmware bytes.

Fresh Ghidra export `initialization.asm` confirms:

- Startup `0xe0956c` calls the copy routine at `0xe09716`; nonzero return
  branches out at `0xe0971c`, before the initialization-complete store at
  `0xe09784`. Earlier failures or an already-initialized state can skip it.
- Mapping helper `0xe0679e` aligns the source to a page and invokes SVC
  0x88, adjusts the returned address, then calls SVC 0x68. Mapping success
  and source contents are runtime facts not supplied here.
- The copy routine checks magic and a total-length limit of 0x8000 and
  copies in up-to-0x1000-byte chunks via `0xe015e4`. Its copy source is the
  mapped object start, including the outer 0x100-byte header.
- This routine has no signature-verification call. Earlier authentication
  is neither proved nor disproved by that observation.

## Byte identity established locally

`report.json` verifies that both extracted objects exactly equal the ROM
slices described by the P3 directory inventory. This proves extraction
identity, not that the running board used this ROM or staged those bytes.

| Object | P3 ROM offset | Full file bytes | Bytes copied by initializer | Excluded trailer |
|---|---|---|---|---|
| BL / type 0x50 | 0x9dad00 | 0xdd0 | 0xbd0 | 0x200 |
| TOS / type 0x51 | 0x9dbb00 | 0x740 | 0x540 | 0x200 |

SHA256 of the exact copy ranges:

- BL: `86393582695a6b1473398458a22d2b7567c9a804ab873675a99b1872dcec742f`
- TOS: `b5c9319705c65679225b7b952cff79b3dbcdda7c195596845031c29808b722ba`

Compare a captured destination against these ranges, not the full extracted
file hash: the initializer does not copy the final 0x200 bytes. Separate
KDB-only hashes are also recorded for diagnosing outer-header differences.

The P3 extraction inventory contains no PSP_FW_BOOT_LOADER/type 0x1 entry.
The existing 4800S loader has an explicit type-0x51 branch targeting the same
staging offset, but that is another platform and its observed direct caller
selects type 0x50. It cannot establish the missing BC-250 producer edge.
See `../vcn-key-search/4800s-loader-trace.md`.

## SVC 0x87 remains conditional

The gate queries kernel byte `0x6007`: zero means enforce usage; nonzero
means skip these usage checks. The previously recovered startup writer
sets this from a sample of PSP-local `0x030101c0` bits selected by mask
`0x80002`, on the applicable startup path. Its byte checks and four-case
model were rerun successfully using `tools/audit-psp-policy-writer.pl`.
No live policy byte or register sample is available.

The t28 initializer also caches the boolean SVC 0x87 result at `0xe1890c`
(`0xe09592..598`). That is an initialization-time observation point, not a
substitute for observing the later lookup's SVC result.

Crucially, lookup calls SVC 0x87 only **after an ID match**. Therefore:

- Missing target ID: `0xffff0008`, independent of the usage gate.
- Matching target ID, requested usage 6, different record usage, gate
  enabled: `0x80000205`.
- Matching ID and usage: clears this check, not all authentication/policy.

For the Van Gogh candidate against the extracted P3 objects, the first
case applies in the offline model. A claim that SVC 0x87 actively rejected
it would contradict that modeled missing-ID path.

## Decisive next evidence

A capture must be tied to the same boot and failing request. Record the
actual boot-context/staging base, the staged object and post-copy destination
bytes, and the lookup's input ID, requested usage, and return status. If an
ID matches, record that record pointer, its usage, and the SVC 0x87 result.
For the supplied Van Gogh candidate, the expected ID is
`70ec3e2d8a694792ac7969ff8ac9caca` and requested usage is 6.

Destination identity at initialization alone does not exclude later writes;
prefer contents at the failing invocation or a trace covering intervening
writers. A different captured table redirects the investigation to its
producer. An exact copied-range match closes byte identity for that capture,
subject to address, timing, and boot provenance.

No such memory capture or BC-250 earlier-loader producer was established
in this pass. The result remains a static source formula and copy chain,
plus independently verified ROM/extraction identity.

## Reproduction

```sh
perl tools/audit-vcn-kdb-provenance.pl > exports/vcn-kdb-provenance/report.json
tools/ghidra-headless.sh ghidra/projects/t28-mapped PSP_T28_MAPPED \
  -process t28-payload.bin -readOnly -noanalysis -scriptPath scripts \
  -postScript ExportPmfwInstructions.java \
    exports/vcn-kdb-provenance/initialization.asm e0956c e097e8 e0679e e015e4
```

The audit optionally accepts a file beginning at the outer object start:
`perl tools/audit-vcn-kdb-provenance.pl /path/to/object-capture.bin`.
It checks magic/bounds and compares the exact copied range byte-for-byte.
Its positive control used the extracted TOS file and its negative control
flipped one copied byte; one match and zero matches were observed respectively.
These controls are files, not runtime captures. Ghidra completed without
ERROR/Exception matches in the saved logs.
