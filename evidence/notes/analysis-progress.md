# BC-250 static analysis — 2026-09-24

## Strongest leads

**Loader destination exclusion (2026-09-29):** [Allocation/window proof](loader-window-backing.md) traces SVC67 -> CB4 -> C10 to the single free extent seeded by 3408: [B+104000,B+800000), B=04000000+(configuration[23C]&03FFFFFF). CB4 returns allocation+3000; direct window mappings preserve this high backing address. The main valid-pool loader copy cannot write 4F000. This is bounded to the initialized successful path, not arbitrary pool corruption or all copy call sites.

**Successful pre-F2 interval (2026-09-29):** [Destination audit](pref2-successful-interval.md) separates P-content writes from slot-neighborhood globals, registry clears, window writes and message construction. Progress calls gated by P+680 end in zero-return stubs. The remaining concrete bulk-alias question is loader 203DA4 -> 200CF4: destination comes from SVC 67 / kernel CB4 and is copied through VA 244000. No reach to target fields proven; allocation-range exclusion remains open.

**Application +4B8 timing (2026-09-29):** [Command-worker ordering](page4b8-read-order.md) traces the 202F0E reader through command selector 2D and previously unrecovered worker 200690. On successful startup, that worker is created at 20444E after the 204342 zero store and returned F2 initialization. The application-side read therefore does not establish a pre-F2 observation. Failure/alternate paths and original target-field writers remain unresolved.

**Kernel page aliases (2026-09-29):** [229-function kernel audit](kernel-page-alias-audit.md) reproduces K=load32(6030) reads and the K+200 source escape, plus newly classified fixed byte stores at A0FFC in 5B34 / SVC D0. The sink repeatedly writes one address with print-like bytes; it does not walk across target fields, and its active physical mapping remains unverified. No 41C/4B8 writer established.

**F2 embedded-pointer ABI (2026-09-29):** [Envelope-to-page trace](f2-page-pointer-abi.md) follows the fifth argument through M+48, target r2=M, the receiver's 78-byte local envelope copy, and E0956C argument+10. First explicit T28 extraction is E0960E, followed by retention E09612 and page-copy E09614. The sender zeroes the separate four-descriptor region, so those checks do not reach P. No pre-copy target-field normalization/write is demonstrated.

**T28 split-root audit (2026-09-29):** [Retained pointer versus snapshot](t28-retained-vs-snapshot-audit.md) keeps E189A4-derived P separate from E54178. The bounded 645-function sweep reproduces retained-source reads/copy and snapshot target-field reads. Instruction review corrects a misleading ordinary-call escape to an intervening SVC 51 with entry E13FE9; transient decoding of previously unrecovered E13FE8 finds a snapshot+674 consumer and E13F10 loop. No original-page target writer is established.

**Page alias follow-up (2026-09-29):** [Def-use audit](config-page-alias-audit.md) recovers the 234 store and P's fifth-argument escape into the tag-1000 handoff. T28 retains the incoming pointer in E189A4; E0FF04 later reads source+238 and copies source[388,3D8) into the corresponding local-copy fields. This adds a concrete retained-pointer consumer, not a producer of 41C/4B8. The 188-function application scan is bounded and does not establish a complete alias graph.

**Configuration content write (2026-09-29):** [Field +234 audit](config-page-content-write.md) confirms application instruction 204342 writes zero through the pointer from 2060E8, corresponding to backing address 4F234 on the mapped path. Helper 200E58 is a constant-zero return. This occurs before the tag-1000 T28 handoff and distinguishes payload mutation from address publication; first writers of 4F41C/4F4B8 remain unresolved.

**Type-1 producer boundary (2026-09-29):** [Directory-consumer audit](type01-consumer-boundary.md) confirms a type-1 dispatcher/loader in the comparative Zen2 ROM, but applying its first destination check to the byte-identical P2/P3 type-1 blob rejects +68=1B92012F before body loading. Its header read targets 4FA80, not the target fields 4F41C/4F4B8. This eliminates only that comparative path; no matching BC250 earlier consumer or first configuration-page writer has been established. [Raw directory audit](upstream-psp-header.md) supersedes the incomplete saved inventory: type 1 is present at ROM 8E0400, length A800.

**VCN size provenance (2026-09-27):**
[Exact accounting](../exports/vcn-size-accounting/README.md) traces the
Linux v6.12 reference copy/command path: file+declared payload offset,
declared payload length, then LOAD_IP_FW type 13 with that same length;
page alignment spaces BO slots but does not extend the submitted bytes.
The saved Navi10 candidate is file size 0x62c40, payload [0x100,0x62c40)
of size 0x62b40, and 4 KiB-aligned slot size 0x63000. None is the recalled
405696/0x630c0; its original log/input remains needed. SEC_LDR bodies are
399984 and 400320 bytes. The saved 0xffff0008 is modeled, not a captured
hardware response. No SEC_LDR conversion or VCN identity is established.

**0xb0 provenance and first receiver (2026-09-27):**
[Boundary check and observation target](../exports/sec-ldr-consumer-audit/field-b0-and-first-receiver.md)
confirms `b0 00 00 00` is stored at header+8, not derived by extraction.
Offset 0xb0 lies inside shared zeros [0x52,0xf0); no visible partition occurs
there. The old "entry field" wording was corrected. Broad stored-header
divergence starts at 0x120, with semantics still unassigned. Prioritize:
**who first opens or receives the intact SEC_LDR container at runtime?**
The 259/260 filenames are host-generated; observe PUP range reads or
matching staged buffers as well as file opens. No live update/install was
run and no runtime receiver is captured. An instrumented target session or
readable receive/dispatch implementation remains missing.

**SEC_LDR property/body pivot (2026-09-27):**
[264-input property search and full-body comparison](../exports/sec-ldr-consumer-audit/property-and-body-comparison.md)
found no magic, first-12-byte tuple, or exact +0x20-field matches. Eight
body-length hits resolve to ELF metadata, relocations, a branch-table LEA,
or unwind metadata. Three nearby 0x400/0xb0 pairs provide no container
provenance. C/D bodies diverge immediately at file+0x400: 1,575 equal bytes
over 399,984 compared, longest corresponding equal run two bytes, and no
shared 16-byte sequence at any alignment. This does not determine decoded
payload relatedness or target identity. No SEC_LDR class/target/routing
property has been assigned; seek a field-to-transformation/destination use.
Reproduce with `ruby tools/audit-sec-ldr-properties.rb`.

**Runtime ID/table search (2026-09-27):**
[Dispatch-table triage](../exports/sec-ldr-consumer-audit/dispatch-table-triage.md)
scans 261 readable PRX files plus three EAP inputs for nearby ID pairs,
packed flags, names and logging metadata. A promising aligned EAP Core
259/260 pair was traced through consumer 0xe7c48: it indexes 0x1c-byte
ASN.1 registry records named `id-qt` and `id-it`, not firmware handlers.
The update-service pair is an unaligned slice of ELF dynamic metadata.
KMS 0x103 remains explicitly excluded. Raw candidates are retained; broad
library triage is not exhaustive. No runtime component-to-handler or
destination edge was established, and the protected updater remains a
missing implementation. EAP crypto searches remain suspended.

**SEC_LDR component-routing pivot (2026-09-27):**
[ID-to-output trace](../exports/sec-ldr-consumer-audit/component-routing.md)
rechecks PUP entries 18/19: flags 0x10300006/0x10400006 select complete,
unblocked, uncompressed components, copied from source file offsets
0x029e858c/0x02a4a3fc into the existing host files. Byte identity passed.
The unpacker uses a 64 KiB temporary buffer and does not strip 0x400 or
call a subsequent firmware consumer. These offsets are not device addresses;
no target allocation/region/DMA destination has been recovered. The missing
edge is runtime component dispatch, not offline extraction. A KMS enum
0x103 was excluded as a different namespace. Suspend EAP-key searches absent
a new structural connection; prioritize a proven component-to-destination
or recipient edge before comparing PSP/SMU ownership maps.

**EAP crypto-object structure and xrefs (2026-09-27):**
[Independent object audit](../exports/sec-ldr-consumer-audit/crypto-object-layout.md)
confirms RSA descriptor 0xc0601238 as four words: modulus pointer/384-byte
length, exponent pointer/3-byte length; no algorithm tag. AES material at
0xc0601248 is a 16-byte key followed by a 16-byte IV, supported by downstream
0x80-bit key and 0x10-byte IV setup. Per-byte object xrefs plus raw-pointer
and bounded PC-relative scans recover no separate path obtaining these
objects outside callback 0xc0019458. A spurious overlapping-register
candidate was explicitly rejected. Exact object fingerprints across ten
inputs match only the duplicate kernel representation. **This establishes
the EAP metadata verification path; it provides no evidence that SEC_LDR
259/260 use these keys or this callback.**

**EAP key callback resolved (2026-09-27):**
[ABI and callback trace](../exports/sec-ldr-consumer-audit/root-key-callback.md)
resolves caller 0xc0018f94's r2 to 0xc0019458; stack argument 6 instead
supplies read callback 0xc0019480. The parser invokes the key callback at
0xc001b45c with header+8 and two output-pointer slots. This implementation
ignores the header value and returns fixed ELF-backed pointers: AES key/IV
at 0xc0601248 and RSA descriptor at 0xc0601238. No MMIO, hardware handle,
or service call appears in this callback. These are EAP metadata materials,
not a proven SEC_LDR root key. Fresh caller assembly also fixes header
capacity at 0x1000: the unchanged wrappers and stripped bodies fail size
checks before magic on this caller. Prior whole-body-capacity results were
conditional tests, not this caller's rejection order.

**SEC_LDR strip/transform discriminator (2026-09-27):**
[Body and size-fingerprint audit](../exports/sec-ldr-consumer-audit/transformation-check.md)
tests each unchanged body at file+0x400. Both pass EAP's two length minima
and combined bounds with body-sized capacity, but fail its first-byte magic
gate at 0xc001b374 before key selection. Thus stripping alone cannot make
either body an input accepted by this parser. Exact-size scans of 13 inputs
find only the original header body lengths; narrower rounded hits are
cross-word patterns or a different little-endian value, with coarse 0x70000
hits unclassified. No SEC_LDR-derived copy/allocation/secondary-header edge
was established. Continue seeking a proven transformation/handoff; do not
merge EAP and SEC_LDR key selection. Checks and first-0x100 body bytes are saved.

**SEC_LDR deeper pass (2026-09-27):**
[Constructed-magic and parser discrimination](../exports/sec-ldr-consumer-audit/followup.md)
extends the search to ARM/Thumb MOVW/MOVT constructions in eight inputs,
including the readable EAP kernel/bootloader and 4800S ROM: no matching
magic halfwords/pairs. A concrete EAP header consumer at 0xc001b278 reads
two u16 sizes at +0x0c/+0x0e. Both SEC_LDR headers would fail its +0x0e
minimum (6 < 0x140) at 0xc001b354, before the key-selector callback.
This counterfactual check is backed by raw instruction assertions; it is
not a recovered SEC_LDR route or runtime load. Thus the existing EAP
metadata AES/RSA path is excluded as a direct consumer at this entry.
No matching SEC_LDR field consumer or trust-boundary transfer was recovered.

**SEC_LDR next-evidence criterion (2026-09-27):** Resume consumer tracing
when one instruction sequence is shown to read a header field from a buffer
proven to contain component 259 or 260. Preserve the buffer's producer,
instruction address, field offset, and downstream use before naming the
field. A magic comparison is a useful anchor but is not required if buffer
provenance is independently established. Component enumeration/extraction,
an isolated 0x400 constant, or unbound crypto-call snippets do not meet this
criterion. Do not pursue a C/D consumer diff until a consumer is identified.
Parsing after a trust-boundary handoff is a working hypothesis consistent
with the bounded local results, not a recovered edge: the next supporting
evidence would be an actual transfer of the SEC_LDR buffer/length to a
recipient. Protected code, missing code, and unrecognized parsing remain
possible. No new parser or handoff is claimed by this checkpoint.

**SEC_LDR structural consumer search (2026-09-27):**
[Parser-candidate audit](../exports/sec-ldr-consumer-audit/README.md) follows
the requested shift from header offsets to consumers. Nine input scans and
1,137 exported function records yielded no exact-magic code anchor; the two
offset-zero hits are the containers themselves. Inspected 0x400 uses in the
generic ROM and EAP update path resolve to queue/table arithmetic, status bits,
and string/path buffers, not a demonstrated body pointer. PUP extraction is
outer-container handling; the traced EAP request endpoint returns a constant
error. A readable matching SEC_LDR parser is still missing, so no 259/260
consumer diff or +0x20-to-crypto flow can yet be established. Prioritize the
matching parser and recipient; do not resume offset guessing. Reproduce with
`ruby tools/audit-sec-ldr-consumers.rb`.

**259/260 header recheck (2026-09-27):** Inspected both local SEC_LDR
containers directly. Both start with magic `0x027cdbe4`, encode header size
`0x400`, and have file lengths equal to that header plus the +0x0c body
length. The differing 32 bytes at +0x20 remain unidentified; a 16-byte
slice at +0x38 crosses into the shared ASCII label at +0x40 and is not
an established AMD VCN key-ID field. Neither full header contains an exact
raw match for the verified Navi10 c372 ID or any extracted P3 BL/TOS ID.
[Saved byte recheck](../exports/oberon-header-kdb/recheck-2026-09-27.json).
These SEC_LDR headers do not yet identify an Oberon VCN signing key;
their relationship to an inner VCN image remains unproven.

**Candidate correction and Navi10 retest (2026-09-27):** Per user instruction,
do not use Van Gogh for subsequent firmware-load tests. Ran the existing
model with its default candidate instead:
`perl tools/simulate-vcn-load-ipfw.pl /lib/firmware/amdgpu/navi10_vcn.bin`.
Package CRC passed. Both BL/TOS fixtures produced modeled key-ID failure
`0xffff0008`; signature verification and completion were not reached.
[Saved Navi10 result](../exports/vcn-kdb-provenance/state-machine/navi10-retest-2026-09-27.json).
Using the model's default does not establish Navi10 compatibility with
BC-250. This remains an offline test, with no live firmware submission.
The Van Gogh results below are historical and superseded as the active
candidate choice.

**VCN LOAD_IP_FW retest (2026-09-27):** Ran
`perl tools/simulate-vcn-load-ipfw.pl /lib/firmware/amdgpu/vangogh_vcn.bin`.
The offline model completed successfully, but the modeled firmware load
failed with `0xffff0008` (missing key ID) against both BL and TOS KDB
fixtures. Package CRC passed; signature verification and completion were
not reached. [Saved retest](../exports/vcn-kdb-provenance/state-machine/vangogh-retest-2026-09-27.json).
This is a file-driven model, not a live firmware submission. `/dev/dri`
is absent in this environment; the live KDB and hardware result remain
unverified.

**Bridge/window checkpoint (2026-09-27):**
[Address-window review](bridge-window-checkpoint.md) keeps the candidates
separate. Under the recovered slot model, type-13 targets 0x0900c004 and
0x1f8a4 do not coincide with PMFW row-6 targets 0x6d17c/184/190, and those
row-6 addresses cannot take the writer's 0x5b000..0x5b7ff mailbox route.
PMFW's two 0x0113b200 literal users access mailbox offsets, not the control
register at offset zero. The RLC shared-block link remains supported, but
no VCN-to-RLC readiness dependency is established. Caller correction:
the preparation helper supports types 21/22, while ordinary type 21 does
not invoke its write-2 arm. Raw window literals and completion-switch
destinations were rechecked; physical routing and the RLC response producer
remain unresolved. No hardware operation was performed.

**Unlocker route clarified — GitHub/source review (2026-09-27):**
The [upstream unlocker](https://github.com/rw-r-r-0644/bc250-smu-unlock)
provides arbitrary SMU access on BIOS 3. Its
[primitives](https://github.com/rw-r-r-0644/bc250-smu-unlock/blob/main/bc250_smu/primitives.py)
include both SMU-local `smu_read`/`dump_sram` and `smn_read32`, backed by
Q3 message `0x2a`. Our [existing mapped-read audit](debug-gate-and-sram-reads.md)
already follows that handler through `0x27cf8 -> 0x29f8`, mapping register
`0x03220038`, and local aperture `0x02c00000`. Thus unlock plus mapped reads
is a concrete candidate transport for the KDB capture, not merely a generic
SMU-debug suggestion. The unresolved step is mapping the PSP staging source
into this interface's address space and establishing accessibility. Neither
upstream source nor our replay establishes that PSP VA `0xe25834` can be
passed directly to it. The replay lacks the actual fabric translation and
PSP backing memory. No live unlock or KDB dump was executed in this review.

**Next experiment — runtime KDB identity (2026-09-27):**
[Targeted capture procedure](vcn-kdb-capture-experiment.md): capture the
initialized t28 object at analysis VA `0xe25834` during the failing lookup,
or the staging object at the actual SVC 0x73 base + `0x784000`, using a
verified PSP-memory reader. [The provenance audit](../exports/vcn-kdb-provenance/README.md)
establishes the staging-to-consumer copy path and local ROM/extraction byte
identity, but not the earlier staging producer or live contents. The
offline comparator is ready; the live capture has **not** been performed.
The local machine has no BC-250 and board access/read mechanism is pending.
`fw_type 13` maps to usage 6. Missing-ID rejection precedes SVC 0x87;
usage-mismatch rejection requires a matching ID and active enforcement.

**Existing state machine checked (2026-09-27):** The Van Gogh candidate was
run through `tools/simulate-vcn-load-ipfw.pl`; both BL/TOS fixtures return
modeled `0xffff0008` at ID lookup, before SVC 0x87. The
[saved run](../exports/vcn-kdb-provenance/state-machine/vangogh.json) pins the
same candidate hash as `vangogh-candidate.json`. This model reads the
extracted KDB files directly; it has no independently populated PSP staging
or destination memory. `MemorySmu` in `tools/replay_unlock_offline.py` models
0x40000 bytes of SMU SRAM, with synthetic/image-conditioned initialization,
not the PSP table. Neither backend supplies a live KDB capture; comparing
their supplied ROM fixtures back to the ROM would not prove provenance.

**Latest prerequisites/comparison:** [restore prerequisites and package audit](restore-prerequisites-and-comparison.md) identifies `0xe18b70` as SETUP_TMR state, recovers region programming before VCN restore, verifies the downloaded PS5 4.03 package, and shows why it is not yet readable comparison firmware. Exact reset/isolation register names and hardware validation remain open; no BC-250 is attached locally.

**Latest command identity:** [VCN restore versus AUTOLOAD](psp-vcn-restore-vs-autoload.md) verifies command 8 as SAVE_RESTORE and type 13 as VCN using the official PSP ABI. Its restore branch reaches the known writes. The separate ring AUTOLOAD command `0x21` sends t28 `0x1059`, which takes a byte-verified default error path returning `0xffff0009`. The boot-created ring consumer is now recovered.

**Latest PSP chain:** [service registration and t28 entry](psp-service-chain.md) establishes the missing `+0x100` runtime mapping adjustment, SVC `0x74` service binding, the `0x1000` initializer and `0x1030` value-store message. It also corrects the boot argument pair to a translated 64-bit address. AUTOLOAD/op-id 8 remains distinct from two unrelated uses of index/message 8.

**Latest identity and gap closure:** [domain identity and PSP handoffs](domain-identity-and-psp-handoffs.md) identifies row-6 child 23 as VCLK and child 22 as DCLK through the official metrics ABI; proves startup initializes the registry base to `0x286000` on its success path; recovers the application worker and SVC `0x7c` write / `0xf2` service-invocation implementations. This supersedes the corresponding unresolved statements below. Live VCN enablement is still unproven.

**Boot-forward trace:** [boot to VCN evidence map](boot-to-vcn.md) recovers PMFW entry → runtime → startup/hardware initialization and PSP ARM reset → Thumb startup. Runtime feature requests and unresolved PSP handoffs remain explicit gaps; powered/usable VCN is not demonstrated.

**PSP producer recovered:** [registry trace](psp-registry-trace.md) links t02 `0x11a04`'s type-field store to `0xfc50`'s registry scan. T28 has the matching header tag at `+0x14`; the evidence supports a general driver/object registry, not a VCN-specific table or completed AUTOLOAD chain.

**VCN identity and driver gap:** [new verification](vcn-identification.md) confirms identical checksum-valid P2/P3 discovery records for VCN 2.0.3 with no harvest entries. The downloaded upstream amdgpu source skips multimedia IP registration for 2.0.3. The user's tested kernel and the row-6 hardware identity remain unverified.

**Latest registration trace:** [feature registration and the state gate](pmfw-state-gate.md) identifies feature bit 13 → enable hook `0x2e3e8` → callback slot 24 → worker `0x2e448`. The refined P3 export recovers 158 direct-call edges and reduces truncated functions from 97 to 7. Reader selectors differ by one from setter selectors.

**Latest:** [row-6 reachability](pmfw-row6-reachability.md) recovers a generic Q3 `0x1d` path hidden by unsupported `CONST.SF` decoding. Selectors 11/15/16 map to row-6 children in both P3/P5. A worker state-equality check can suppress writes despite a successful handler response.

**Follow-up correction:** the four candidate pairs below map to firmware table **row 7**, not row 6. A separate row-6 transition routine and two child request wrappers exist but have no recovered direct callers, queue slots, or exact 32-bit pointers in P3. See [the deep trace](pmfw-deep-trace.md) for register mappings, queue paths, and limitations.

**PMFW constructs four candidate control-word pairs at runtime.** P3 `FUN_00024330`, called by `FUN_00029e44`, combines fields from `FUN_0001cc70` into four words and follows each with an 8-bit value. Destinations in the SMU address space are `0x0115f850/854`, `858/85c`, `860/864`, and `868/86c`. A shared literal is `0x06900000`; masks replace fields in it. This explains how full descriptor values could be absent from a literal byte scan. It does **not** establish actual runtime values `0x06900900/0xe8`, nor identify domain 6. Do not assume these SMU addresses are host-accessible SMN addresses.

The accessor reads words using bases `0x0115d004` and `0x0115d000` and extracts indexed fields. Input values are not present in the static export. The four sets of indices, masks, and widths are recorded in `exports/static/power-path-evidence.json`.

**The PSP type-13 path is present.** Header-stripped t28 offsets `0xc096–0xc0a0` prepare a call to `0xce90`. At `0xd178`, that loader checks `r4 == 13`. At `0xd182`, it invokes `svc 0x7c` with `r0=0x0900c004`, `r1=1`, `r2=4`. A helper called at `0xd184` invokes the same SVC with `r0=0x0001f8a4`, `r1=1`, `r2=4`. A second function at `0xfdc8` makes those two calls and walks up to five 8-byte entries at a table pointer of `0x00e188d8`. These arguments were checked in assembly, not inferred solely from decompiled C. The SVC implementation and actual hardware effect remain to be established.

**T02 scans 32 table slots, not necessarily 31 entries.** `FUN_0000fc50` scans indices 31 down to 0 and 0 up to 31. Each slot is `0x54` bytes; magic `0x5244` is checked at slot offset `+8`, and the field at `+0x18` is supplied to `svc 0xf2`. Table address is `*[0x00206080] + 0x6000`. The runtime pointer value and occupied slots are not known here. `0x286000` would require a runtime base of `0x280000`; this was not verified. Raw t02 contains no four-byte magic literal because code constructs the comparison constant as an immediate. Raw t28 has one at file offset `0x114`, but that alone does not identify the runtime table.

## PMFW queues and version comparison

P3 dispatcher `FUN_00000ebc` loads a handler from `queue_base + 8*message_id`; the following word contains metadata. The limit check is exclusive. This differs from blindly interpreting the upstream helper's gate/handler pairs and deduplicating queue pointers.

- Eight queue slots. Q3 and Q4 share one table; IDs must be preserved.
- P3 pointer/count tables: `0x7a8c` / `0x7aac`.
- P5 pointer/count tables: `0x7a94` / `0x7ab4`.
- Exclusive bounds P3: `[62,17,48,169,169,21,4,3]`; P5: `[62,17,49,169,169,21,4,3]`.
- Q0 IDs 8 and 9 are null in both versions.
- Q2 gains slot 48 (`0x30`) in P5, handler `0x1bdc4`. Its C reads three request words, validates them, invokes two helpers, updates state, and returns status. Its purpose is not established.
- Q3 has 128 distinct non-null handlers in both versions; all were recovered and exported. Six per version required explicit queue-target seeding beyond stock auto-analysis.
- Q3 normalized text comparison: 36 same, 92 different, 41 null/unavailable. This is a triage filter, not semantic equivalence: symbol normalization hides addresses, including callee/data identity, and auto-analysis can differ.

## Exports

| Directory/file | Contents |
| --- | --- |
| `exports/pmfw-p3/` | 1,290 function records and decompiled C |
| `exports/pmfw-p5/` | 1,293 function records and decompiled C |
| `exports/psp-p3-t02/` | 361 function records, C, focused records and assembly |
| `exports/psp-p3-t28/` | 763 function records, C, focused records and assembly |
| `exports/pmfw-p3/q3-functions.jsonl` | All 128 Q3 handler records |
| `exports/static/queue-tables.json` | Queue slots, message IDs, handler addresses, metadata |
| `exports/static/queue-comparison.csv` | Handler presence changes by queue/message ID |
| `exports/static/normalized-queue-comparison.json` | Text-normalization triage with links to C files |
| `exports/static/power-path-evidence.json` | Focused machine-readable findings and limitations |
| `exports/static/input-patterns.json` | Independent raw-pattern scans and input hashes |
| `exports/logs/` | Analysis logs, including warnings and original-file verification |

Function JSONL includes entry, references to the two original constants, calls, called_by, indirect call sites, constants, references with literal values, and memory reads/writes. Memory-access records are raw p-code with unresolved address varnodes; they are not a list of verified hardware side effects. Direct-call exports are incomplete where code/function boundaries were missed; targeted assembly independently confirms the t28 call at `0xc0a0`.

## Quality limits and next work

Stock Xtensa definitions produce decompiler warnings (including unresolved floating-point/special-register instructions). All functions produced C output, but **zero failed decompilations does not mean clean or correct C**. The upstream language patches remain uninstalled. PSP t28 function seeding used Thumb prologue heuristics; t02 contains both ARM vectors and Thumb code. Evidence ranges were explicitly decoded as Thumb in a read-only project transaction.

PSP payloads exclude the 0x100-byte header and trailing 0x100 bytes according to header signed-size fields, with provenance in `ghidra/inputs/psp-p3/manifest.json`. PSP analysis uses base zero for payload offsets; t28 runtime relocation remains unresolved.

Next useful steps: validate the SMU register block and field reader against matching hardware definitions; recover the runtime PSP table producer and registration state; establish SVC 0x7c semantics; then compare with identified readable PS5 payloads. The supplied PS5 PUP is still pending. No firmware was executed on hardware, no original was modified, and no VCN enablement is claimed.
