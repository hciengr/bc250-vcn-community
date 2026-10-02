# High-priority VCN audit — 2026-10-01

Read-only original-firmware analysis. No board attached, firmware modification, SPI access or new runtime observation. Community claims are narrowed to their demonstrated static scope below.

## T14: stored policy omission confirmed; runtime grants remain open

`ruby tools/audit-vcn-policy-coverage.rb` pins stock P3 ROM and saved Steam Deck F7A0116 capsule hashes, verifies PSP directory Fletcher checksums, decodes the entire bounded t24/t45 section streams and verifies BC250 extraction equality. Steam Deck directory-relative addresses are decoded independently; both directory copies produce identical policy objects.

| Object | Parsed pairs | Targets in 0900C000..0900CFFF | Values in [1E000,23000) | Direct targets in [1E000,23000) |
|---|---:|---:|---:|---:|
| BC250 P3 t24 | 1405 | 0 | 0 | 2 |
| BC250 P3 t45 | 144 | 0 | 0 | 0 |
| Steam Deck t24 | 1482 | 32 | 14 | 2 |
| Steam Deck t45 | 467 | 5 | 4 | 3 |

The two BC250 direct target rows are exactly **1F8A4=0B** and **1F820=00185103**, both in t24 section 201. They are not aperture ranges.

The Steam Deck section-201 frame-C endpoint rows reconstruct the reported three ranges: **1F82C..1F833**, **20470..2086F**, **219D0..21ACF**. The empirical start/end geometry is start offset 934 + slot*24, end +4, within each 4-KiB management frame. It is not an independently documented hardware descriptor schema or enable-state model.

Applying this candidate geometry to all BC frames produces no interval overlapping the numeric VCN range, including intervals whose endpoints lie outside and span the entire range. The scanner does not join endpoint rows across sections. Section-201 frame indices 096..09D have counts **71,69,69,69,69,69,69,69**, matching the community's row-count report. This inventory alone does not establish the hardware meaning of those DF ACL controls.

Some other Steam Deck frames contain values inside the same numeric range. Numeric overlap alone must therefore not be equated with a universal VCN grant without frame/path semantics. BC's zero-value inventory is still a useful, directly checked negative result.

**Proven:** these stored P3 policies omit explicit frame-C writes and VCN-valued rows. **Not proven:** no runtime component ever grants access; reset's field identity/live state; active master restrictions; PSP/LMA bypass scope; RN/CZN's eight windows. Those require additional artifacts or hardware. T14's local audit is submitted for independent review rather than silently declared fully complete.

Six fixture controls passed, including spanning intervals, non-C frame overlap, direct-preload separation, reversed range rejection, truncated section rejection and declared-count enforcement:

```sh
ruby tools/test-vcn-policy-coverage.rb
```

Artifacts: `exports/vcn-priority-audit/policy-coverage.json`, containing full pair inventories, input hashes, directory entries, candidate ranges and limits.

## T15: final image error prevents ordinary completion writes

A fresh read-only Ghidra export supplies complete functions. `ruby tools/audit-vcn-load-reset-gate.rb` verifies 26 raw Thumb instruction/branch checks against hash-pinned t28 and reports five scoped branch fixtures.

The exact normal-return error chain is:

```text
E0A130 key lookup
 → E0A0E8 header wrapper
 → E16DFA call / E16DFE retain result in r4
 → E16E00 BNE E16E4E → E16F82 cleanup
 → E16F9A return r4
 → E0DB9C image-processing call / E0DBA0 retain result in r7
 → E0DBA2 BNE E0DC02 cleanup
 → E0DC22 CBNZ r7,E0DC5C → return r7
```

Thus a **final nonzero image-processing status** skips E0DC56's call to completion E0FB18. This suppresses that route's conditional `0900C004 <- 1` and subsequent `1F8A4 <- 1` requests. It does not suppress every other writer in the system.

A qualification newly checked in this pass: E0A0E8 may try up to **four** header positions spaced by 100, depending on byte +7F and word +18. A missing key ID at one header does not necessarily determine the final return. Observe the wrapper result and complete attempted-header set, not merely one lookup.

On completion arrival, the management write requires full context value **0000FFFF**, not FFFFFFFF. Accepted image processing is necessary but other checks can still prevent completion. The late helper overwrites its SVC result with zero; neither apparent completion nor a requested store proves a physically accepted reset release.

If community identification of 0900C004 as active-low cold reset is verified, these instructions provide a concrete authentication-to-reset-release dependency on this ordinary host-context load path. The field name, actual state, bus effects and alternate writers remain open. This is a static connection, not a live blocker attribution.

Artifacts: `load-reset-functions.asm`, `load-reset-ghidra.log`, `load-reset-gate.json` under `exports/vcn-priority-audit/`.

## T03: earlier producer remains beyond the known consumer

`ruby tools/audit-vcn-staging-candidates.rb` scans 22 unique extracted P3 objects, five expanded ABL payloads, extracted t02/t28, and the known 4800S comparison loader. It hash-records all inputs, searches exact 784000/784100 words at every byte and bounded Thumb MOVW/MOVT candidate constructions at halfword alignment.

The only BC250 hits are the known t28 consumer literal (full object +987C / payload +977C). The 4800S control detects both known loader literals +68D4 / +68D8. No new earlier BC250 producer was identified by this bounded scan.

This is not a producer-exclusion proof: ADD-based constructions, computed aliases, encoded/opaque code, another address space and runtime-only staging remain possible. The P2/P3 type-1 blob is present and byte-identical; it does not have a validated plain executable/header interpretation. The comparative 4800S association of t51 with staging+784000 remains comparison evidence, not BC250 provenance.

Next useful input is the matching earlier BC250 loader / validated transformed type-1 artifact, or a staged object plus boot context observed before t28's copy. Repeating the literal scan or inserting a public key does not establish this missing edge.

Artifact: `exports/vcn-priority-audit/staging-candidates.json`.

## Live task handoff

Fresh local PCI sysfs inventory found **no 1002:13FE BC250**. No remote endpoint or same-boot board capture has been supplied. T01/T02/T04/T06 and the live half of T15 therefore remain unresolved.

For one coordinated board capture, preserve:

1. BIOS hash, board/boot identity, exact kernel patches and submitted firmware hash; driver admission, requested filename and actual software harvest variable.
2. Command/type/length, raw PSP return/address, every attempted header ID, final header-wrapper/image status and whether ordinary completion ran.
3. Verified translation and timing for runtime KDB at analysis VA E25834, or staged source at actual SVC73 base+784000; correlate consumer bytes and input ID to the failing invocation.
4. Authoritative reset-field mapping and same-boot 0900C004 samples; distinguish successful accepted store from requested SVC and other writers.
5. Actual platform callback/dispatch, fresh parent/child observations and independently valid clock/access state.

Existing read-only inventory helper: `bash tools/collect-bc250-inventory.sh <new-output-directory>`. It does not provide PSP-memory access or validate reset. Existing capture procedure: `notes/vcn-kdb-capture-experiment.md`. No unverified address is presented as a host read/write recipe.

## Additional primary-source lead: late filter write is not a simple filter-off operation

Pinned AMD-contributed Linux VCN3 headers name register offset 29 / segment 1 as UVD_REG_FILTER_EN. Applying that comparative offset to BC250's segment-1 discovery base yields 1F8A4, matching the firmware target. The masks name bits 0/1/2/3 as filter enable / MMSCH high privilege / video privilege / JPEG privilege.

Under that VCN3 schema, **0B → 01 keeps filter-enable set** and changes privilege fields. This supports the community register-name candidate, but does not establish cross-generation equivalence for BC250's advertised VCN2.0.3 or runtime effect. It is not justification to describe the late write as disabling all filtering.

Pinned sources, complete headers and SHA-256 values are in `analysis/reference-sources/vcn/filter-comparison/README.md`. The focused primary-source search did not establish an authoritative cold-reset definition for 0900C004.
