# Harvest investigation: recovered table-driven secure writer

New upstream evidence: [stored source candidates](runtime-section-source-candidates.md) identifies matching type-0x24 and type-0x45 section layouts and their actual section-0x210 pairs. Runtime loading remains unresolved.

Follow-up: [startup and neighboring-buffer audit](harvest-runtime-producer-resume.md) separates the saved-record cache/scratch path from the unresolved table producer.

2026-09-29. Static stock-P3 analysis; no hardware operations.

This pass recovered an indirect write route that can obtain targets from
runtime data. It does NOT identify a CC_UVD_HARVESTING write or prove the
runtime table contains that register.

## Instruction-backed consumer chain

T28 `0xe02278(section_id)` calls `0xe1177c` to look up a section in a table
at mapped PSP address **B = 0xe5cbdc**. The layout consumed by the lookup is:

```text
B + 0x100 = section count                  (0xe5ccdc)
B + 0x140 = first section                  (0xe5cd1c)
section + 0 = section ID, u32
section + 4 = pair count N, u32
section + 8 = N pairs of {u32 target, u32 value}
next section = section + 8 + 8*N
```

At `0xe11794..0xe117a4`, a matching section returns its pair pointer and
count. An exhausted search returns 0xffff0008. The local lookup does not
visibly check an overall buffer bound; any validation by a producer remains
outside this trace.

For sections other than 0x203 and 0x217, the consumer executes:

```text
e022bc  r0 = pair[i].target
e022c4  r1 = pair[i].value
e022ba  r2 = 4
e022c6  svc 0x7c
```

Those instructions are ordered in the assembly export (r2 is set before r0).
Each pair is eight bytes. There is no address shift in this helper. The local
loop increments its index without testing each SVC return; a return from this
routine therefore cannot prove all writes succeeded.

For section IDs 0x203 and 0x217, `0xe022ac` directly stores the value through
the pair's target pointer instead of using SVC 0x7c. That is a distinct address
interpretation; do not treat all sections as secure-MMIO target lists.

The previously recovered kernel route for SVC 0x7c is `0x5a88` -> window
mapper `0x2fcc` -> width-4 store at `0x5ab8`. This completes a static table
consumer-to-store chain, not a proof of any particular target in the table.

## Inputs and reachability limits

Existing caller decompilations show section IDs 0x211 (0xe01ff4), 0x214
(0xe0cba4), 0x215 (0xe02184), and 0x221 (0xe0e2f4), plus a caller forwarding
its section argument (0xe02108). The callers contain platform/state guards;
their existence does not establish execution on BC250.

The B address is beyond the on-disk T28 payload's mapped extent. It is not an
embedded table that can be read directly from the payload. The runtime buffer
producer, contents, integrity checks and initialization state remain unresolved.
Raw literal references to B occur at 0xe02264 and 0xe117b8. The latter belongs
to the confirmed lookup. The former lies in a region not recovered as a
function in the current mapped project; a bounded Thumb decode shows another
section-caller sequence, not proof of buffer population.

Thus a useful runtime discriminator is a valid copy of this table, parsed
according to section kind. A normal secure-write section containing target
0x1f81c and value 3 would identify a candidate software request. It would still
require execution and address-space evidence to establish a physical harvest
write. No such record has been observed here.

Another writer, `0xe0a660`, shifts pair targets left by two before SVC 0x7c;
its recovered loader caller selects firmware type 0x16. Its format must not
be conflated with the byte-target table above or the VCN type-0x0d branch.

## Reproducible artifacts

- `scripts/ExportSecureWriteSites.java`: enumerates currently recovered SVC
  0x7c, 0xa6 and 0x7d sites, with preceding instructions and literal reads.
- `exports/psp-smu-ordering/secure-write-sites.txt`: 114 sites: 65 writes,
  22 RMW calls, 27 mappings. This is recovered-code coverage, not exhaustive
  firmware coverage. Preceding instructions are context, not symbolic slices.
- `exports/psp-smu-ordering/table-write-paths.asm`: instruction evidence for
  0xe02278 and 0xe1177c.
- `exports/psp-smu-ordering/table-source-xrefs.txt`: unresolved literal site.

PMFW's existing reference inventory was also checked for literals whose low
20 bits equal 0x1f000, 0x1f800 or 0x1f81c; no matches were returned. This does
not exclude synthesized addresses or another hardware address space.

## Follow-up: corrected Thumb decode and cached section 0x210 writer

The old export of 0xe02060 was decoded in ARM mode and ended in bad data.
Re-decoding 0xe02060..0xe020f7 as Thumb in a read-only headless session yields
a coherent mode dispatcher. The project and firmware were not saved/modified.
`scripts/SeedThumbRange.java` supplies the explicit mode/range; evidence is in
`table-flag-path.asm` and `.c` under `exports/psp-smu-ordering/`.

The routine first requires byte **0xe18af8 == 1**; otherwise it returns
0xffff0007. This byte is initially zero in the on-disk payload. Its runtime
writer is unresolved, so neither reachability nor permanent disablement is
established. The helper 0xe089fc reads a separate word at flag-base+8, not
the byte itself; callers compare that word against 0x100.

The corrected routine uses cache base **C = 0xe66bdc**:

| Input mode | Pair pointer | Count | Lookup producer identified |
|---|---|---|---|
| 1 | C+8 | C+0x1c | Not found in this pass |
| 2 | C+0 | C+0x14 | Section 0x206 |
| 3 | C+0xc | C+0x20 | Section 0x210 |

At 0xe0a5e4, after platform and enable-byte guards, the lookup 0xe1177c caches
section 0x206 in C+0/C+0x14, section 0x210 in C+0xc/C+0x20, and section
0x208 in C+4/C+0x18. These are cached pointers/counts into the original table,
not the producer of the original table contents. The selector==0x100 branch
clears 0x28 bytes of cache instead. The first two input modes have additional
checks/calls; the table above is not an unconditional execution sequence.

Mode 3 calls 0xe022d4 at **0xe020e0** with section 0x210's pointer/count.
At each target-page change, 0xe022d4 requests SVC 0x7d mapping of
`target & ~0xfff`, length 0x1000. At **0xe02316** it stores the pair's value to
`mapped_pointer + (target & 0xfff)`. This is a second mechanism for table-based
writes, separate from 0xe02278's per-pair SVC 0x7c. It still supplies no evidence
that section 0x210 contains 0x1f81c or that its physical register mapping is
the assumed host VCN mapping.

The previously unrecovered 0xe021d4 routine was also decoded. It uses the
table pointer to read B+0x60 for a reporting call and invokes section consumers
0x201, 0x205, 0x203, 0x20a, 0x20b and 0x210 under guards. It does not populate B
in the recovered local instruction flow. Its write of 1 is to **0xe18af0**,
a different byte from the required **0xe18af8**; these must not be conflated.
Evidence: `table-init-candidate.asm` and `.c`.

New concrete unresolved producers are therefore: original buffer B, enable
byte 0xe18af8, and cache slot C+8/C+0x1c. The corrected decoding connects a
section lookup to a mapped store but does not identify a harvest writer.

## Runtime-producer search, additional bounds

An all-byte-alignment raw scan (not just dword alignment) found exactly two
literal B references, eleven literal 0xe18af8 references, and one exact C reference
in T28. Output: `exports/psp-smu-ordering/runtime-writer-literals.txt`.
The exact flag references examined are readers/guards; the secondary helper at
0xe08a08 reads flag-base+4, while 0xe089fc reads flag-base+8. No direct flag
setter was established. MOVW low-half searches for 0x8af8, 0xcbdc and 0x6bdc
also found no candidates in T02/T28. This does not cover all computed pointers.

Nearby pointer literals were checked to avoid overlooking base-plus-offset
accesses. The e18a00 users (0xe09d24 and 0xe0dfbc) manipulate fields near that
base; their examined local stores do not reach +0xf8. The e18a80 user
0xe0ee1c supplies e18ae0 as an input to the crypto wrapper 0xe0c8c8 with a
0x80-bit key size. The wrapper reads 16 bytes from that input in its software
key branch; this ends at e18aef and does not write the flag at e18af8.
The surrounding crypto flow is not evidence of a harvest writer.

The user-selected README bytes 1354..2448 in
`analysis/key-inventory/ps5-devwiki-2026-09-24/README.md` are portions of two
unclassified 256-byte PS5 ROM material blobs. That passage supplies no writer,
table format or BC250 address association. No key application was attempted.

Result: the runtime producer is still not identified in the inspected static
paths. The existence of table consumers must not be promoted to evidence that
the table is populated, that the enable byte becomes 1, or that either path
executes on this BC250 image. Establishing those runtime facts requires a
version-matched capture/trace or recovery of an as-yet-unidentified producer.
