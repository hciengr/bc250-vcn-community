# Runtime harvest-table producer: startup and neighboring buffers

2026-09-29. Read-only Ghidra pass on stock P3 mapped T28. No hardware access, firmware patch, or runtime capture. This continues harvest-indirect-write-path.md without establishing a harvest writer.

## Neighboring saved-store path is now separated

The service initializer calls E0B830 at E09732. E0B830 checks E13CEC's output for 1, then iterates record IDs 0x100..0x1FF:

```
E0B830
  -> E13B70(record_id, 0xE5ABDC, 0x2000)
  -> on success E11EEC(scratch+8, byte[scratch+1], scratch+0x48, record_id)
```

E13B70 checks the record's unsigned 16-bit length at +0x16 against the supplied 0x2000 limit before E13A4C. E13A4C either copies record data at +0x30 directly or decrypts to scratch 0xE8C498 and then copies exactly that checked length to the destination. Its crypto branch references the previously known store key buffer 0xE9FC60; this does not supply a new key value or harvest relationship.

The resulting destination interval is bounded by `[0xE5ABDC, 0xE5CBDC)`: it ends at B and does not populate B in the recovered copy operation.

E11EEC indexes a different structure:

```
entry = 0xE553DC + (record_id - 0x100)*0x58
entry+0x54 = record_id
entry+0x50 = length byte
copy entry <- scratch+8, length byte
copy entry+0x40 <- scratch+0x48, 0x10 bytes
```

The 256-entry nominal array occupies `[0xE553DC, 0xE5ABDC)`, immediately before the scratch buffer. Its structure is an indexed saved-record cache, not the variable-size section/pair table at B. The variable copy lacks a visible local <=0x40 check; this pass does not certify record validation. Even its caller-supplied byte length (<=255) at the last slot cannot reach B. No physical register target is supplied by these cache population stores.

## Other initialization destinations

- E0956C copies 0x1000 bytes from initialization-message+0x10 to 0xE54178, ending at 0xE55178. It does not populate B.
- E09890 clears `[0xE67F48, 0xE69F48)` and clears the word at 0xE18B1C. Neither is B or the enable byte.
- E098AC maps from the SVC-0x73 returned base plus 0x7F8000. Its field+0x14 length must be <=0x880. It copies from mapped+0x100 to 0xE6B3E0, so the maximum end is 0xE6BC60. It copies mapped+0x4C to 0xE18B58 and writes 1 to 0xE18B5C. That 1 store is NOT the required byte at 0xE18AF8.

These are static bounds and local write destinations, not proof that initialization completed. ARM/Thumb instruction listings, rather than SVC-distorted decompiler values, support the source-base and destination calculations.

## Remaining producer gap

No new write to B=0xE5CBDC or enable byte 0xE18AF8 was established. No pair targeting candidate harvest offset 0x1F81C was observed. The recovered table consumers and section-0x210 cache remain the strongest downstream anchors; their upstream provenance is still unresolved.

This pass specifically eliminates the adjacent saved-record scratch/cache path as a normal direct population mechanism for B. It does not exclude different bulk copies, kernel loading/zeroing, computed aliases, other components, or runtime-only contents. A version-matched dump of B's section header and enabled state, with the producing call context, would discriminate these alternatives.

## Artifacts

- exports/psp-smu-ordering/runtime-producer-init.c / .asm
- exports/psp-smu-ordering/runtime-neighbor-xrefs.c
- exports/psp-smu-ordering/runtime-neighbor-init.asm
- exports/psp-smu-ordering/runtime-record-population.asm

The attached vangogh-candidate.json remains a package/ID inventory. Later offline signature verification strengthens the separate Van Gogh authentication reference, but neither artifact supplies this runtime table's producer.
