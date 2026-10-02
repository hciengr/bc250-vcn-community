# VCN cold-start loader, ordering and acknowledgment evidence

2026-09-24. Static/read-only analysis of stock P3 and downloaded upstream driver
sources. No image was submitted and no hardware registers were accessed.

## A separate LOAD_IP_FW route exists

The strongest new result is that AUTOLOAD's error route is not the only loader.
The stock images contain this conditional normal firmware-load path:

```
ring command 6 / LOAD_IP_FW, firmware type 13 / VCN
  -> t02 case 0x202616 -> wrapper 0x2013ca
  -> SVC F2 service 1, internal message 0x1007
  -> t28 dispatcher -> 0xe0d9dc
  -> source mapping and destination allocation 0xe0a900
  -> image processing 0xe16d88
  -> bookkeeping / cleanup
  -> completion 0xe0fb18, type-13 case 0xe0fc0c
```

The wrapper and loader are instruction-backed. Raw table checks establish the
command-6 case and both type-13 allocation/completion cases. The dispatcher’s
0x1007-to-0xe0d9dc edge is also present in its existing decompilation; that edge
has not received a separate raw-branch audit in this pass.

For type 13, the missed Thumb case `0xe0a996` sets the memory-backed flag,
reserves `0x100000` bytes and computes its destination. The host-context sentinel
`0xffff` differs from indexed contexts. At completion, `0xe0fc0c` writes 1 to
`0x0900c004` only for that sentinel, then calls `0xe170e0` (the write of 1 to
`0x1f8a4`). These writes therefore participate in ordinary loading as well as
restore. Their precise bit meanings remain unknown.

The completion helper then calls `0xe0d6d0(...,0)`. It maps a 4 KiB area following
the loaded extent rounded up to 64 bytes, and clears words at offsets 0 and
0x40. These are memory initialization operations, not an observed VCPU-ready
poll. Its error handling is conditional on another firmware state byte, and
the late register-write results still do not establish hardware readiness.

## What a valid cold-start image must satisfy

The normal loader accepts an external address, size and type. Unlike the restore
buffer, it enters the image parser/authentication pipeline:

- For VCN, the outer load handler requires at least `0x100` input bytes.
- `0xe16d88` reads `0x400` bytes into a header workspace. Header-processing
  code examines up to four `0x100`-spaced records, including chaining byte +0x7f.
  The precise host-size contract for that initial read remains to be checked;
  the outer 0x100 guard alone is not proof a 0x100-byte image is sufficient.
- `0xe0a0e8 -> 0xe0a130` matches a 16-byte value from header +0x38 against
  a runtime table based at `0xe25834`. No match yields `0xffff0008`.
  SVC 0x87-dependent checks can return `0x80000205` or `0x80000206`.
- `0xe0b534` checks chained-record/payload lengths against supplied capacity.
  Its helper `0xe09de4` checks only that the requested type is below 0x44;
  do not infer a strict header-type equality check from its two apparent arguments.
- The selected verification-size values are `0x100` or `0x200`; processing
  uses bounded chunks and calls `0xe09c9c -> 0xe10730` before committing metadata.
  The latter has signature-verification-like padding/hash checks. The exact
  algorithm and trust policy have not been fully named or independently reproduced.

This narrows the missing input to a firmware image accepted by this runtime
trust-table and image-processing path. A raw instruction blob or manually
constructed restore buffer does not establish compatibility. No valid VCN
cold-start image was recovered or verified in this pass. The encrypted PS5 PUP
still does not supply a readable candidate, and the named local firmware inventory
contains no identified VCN image.

Crucially, this loader initializes the previously unexplained restore state:
`0xe16f68..0xe16f80` writes the per-type metadata at `0xe552cc + type*4`
(VCN: +0x34) and, for type 13, the loaded extent at `0xe35cc0`.
This closes the static link **ordinary load -> saved metadata -> restore**.
It does not establish that such a load has succeeded on a BC-250.

## PSP/SMU ordering: host reference versus BC-250 evidence

The downloaded upstream `amdgpu_psp.c` disables AUTOLOAD for MP0 11.0.8.
Its ordinary `psp_execute_ip_fw_load` issues command 6 with firmware address,
size and type. This is consistent with the stock handler above, and means
the AUTOLOAD default error alone is not evidence that all loading is disabled.

PSP initialization creates a ring and sets up TMR before loading other IP
firmware. PMFW-before-TMR is conditional on centralized C-state management;
the reference switch does not include 11.0.8. Otherwise SMU loading occurs
through the non-PSP firmware list, subject to available firmware and skip rules.
Do not impose the PMFW-before-TMR sequence universally on this platform.

For ordinary non-DPG VCN startup, `vcn_v2_0_start` requests DPM enable when DPM
is active, performs local power/clock setup, programs firmware memory windows,
releases resets and waits for VCPU status. With PSP loading, its firmware cache
base comes from the PSP-returned TMR address. This supplies a reference dependency:
accepted PSP image/address -> VCN memory windows -> VCPU boot -> ring tests.
It does not supply a proven PSP-to-SMU domain-6 call edge.

The local Cyan Skillfish callback table has no VCN-specific powergate callback.
This is a source-level gap, not proof of the behavior of the user's actual driver.
The PMFW worker gate and its cached values remain as documented in
`pmfw-state-gate.md`; forcing a state byte would not establish correct sequencing.

## Concrete acknowledgment milestones

These are upstream VCN2 reference checks, not BC-250 measurements or a register
write recipe. DPG and virtualized paths differ.

| Milestone | Reference observable | Limitation |
|---|---|---|
| SMU row transition | Bit 8 at SMU-space `0x0116d190`, then bit 16 clears at `0x0116d184` | Row-6 relation to VCN rails/reset remains unverified |
| Local power state | `UVD_PGFSM_STATUS`, masked by `0xfffff`, compared with power-mode-specific expected value | Not the same address space as the SMU sequence |
| Clock setup | `UVD_CGC_GATE` gating controls and `UVD_VCPU_CNTL.CLK_EN` mask `0x200` | Readback does not measure an oscillating clock or its frequency |
| Reset release | `UVD_SOFT_RESET.VCPU_SOFT_RESET` mask `0x8` cleared by driver | Control state, not execution evidence |
| VCPU running | `UVD_STATUS & 2` becomes nonzero; bounded polling/reset retries | Actual firmware response needed |
| Decode ring works | Driver seeds SCRATCH9 with `0xcafedead`, submits ring packet, waits for `0xdeadbeef` | Must be executed by a compatible driver, not simulated writes |
| Encode rings work | Separate encode ring tests during hardware initialization | Decode success does not prove encode functionality |

`exports/vcn-cold-start/audit.json` records nine public register offsets and
candidate host byte offsets calculated from discovery segment 1 (`0x7e00`).
They are not proven PSP-window aliases. In particular, no public name has been
established for PSP targets `0x0900c004`, `0x1f820` or `0x1f8a4`.

The current environment has no BC-250, so none of these milestones was observed.
The existing upstream discovery skip for VCN 2.0.3 also remains a driver obstacle.

## Reproduction and next unresolved boundary

Run `perl tools/audit-vcn-cold-start.pl` to verify firmware hashes, raw tables,
selected load/completion instruction evidence, and public register offsets.
Instruction exports and literal users are in `exports/vcn-cold-start/`.
Read-only Ghidra sessions leave the original images and project analysis unchanged.

The next boundary is matching an actual image to the runtime trust table and
validating driver/SMU sequencing on a board. No parser success, software status,
or mock acknowledgment should be promoted to evidence of powered hardware.

Primary reference sources:
- https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/amdgpu/amdgpu_psp.c
- https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/amdgpu/vcn_v2_0.c
- https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/pm/swsmu/smu11/cyan_skillfish_ppt.c
