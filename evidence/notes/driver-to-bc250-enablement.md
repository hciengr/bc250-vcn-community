# Driver prerequisites cross-referenced to BC250 firmware

Follow-up: [startup gate audit](vcn-driver-gate-audit.md) identifies unchecked
PGFSM waits, all-ones readiness false positives, separate DPG/VF paths and
the VCN state-cache bypass. Includes a reproducible source/predicate audit.

2026-09-28. Static analysis only. The earliest demonstrated source-level
obstacle is driver admission: the examined discovery switch deliberately adds
no VCN IP block for version 2.0.3. If a custom driver removes that obstacle,
the examined Cyan Skillfish power-management table still supplies no
`dpm_set_vcn_enable` callback. Neither finding establishes the behavior of the
installed custom kernel or the physical failure point on the user's board.

## Prerequisite, firmware action, acknowledgment

This table follows the ordinary non-DPG startup dependency chain. Firmware
loading is an initialization prerequisite, not a call inserted at the row where
its address is consumed. DPG and virtualized paths need separate treatment.

| Driver prerequisite/action | BC250 evidence or candidate | Required evidence / remaining gap |
|---|---|---|
| Register the VCN IP block | P2/P3 discovery identifies 2.0.3; local `amdgpu_discovery.c:2909` immediately breaks for it | Actual driver must admit and initialize the block. This is the earliest source-level blocker. |
| Request SMU power enable when DPM is active | `vcn_v2_0_start` calls `amdgpu_dpm_enable_vcn`; Cyan's installed callback table lacks `dpm_set_vcn_enable` | A real platform enable operation and its dispatch into firmware remain unestablished. A zero return alone is insufficient. |
| Establish parent domain accessibility | PMFW `23b14(6,1)` writes control, polls status bit 8, writes handshake bit 16, polls it clear | Fresh ordered observations at PMFW-local `0x0116d190` and `0x0116d184`; cache `f714=1` can bypass both. No proven equivalence to physical power-good or driver MMIO. |
| Disable local static power gating | Driver writes PGFSM_CONFIG and polls PGFSM_STATUS; derived GPU MMIO status offset `0x1f804` | Valid access plus mode-specific masked status. UVDM/UVDU zero indicates those tiles report on; root power-good remains unidentified. |
| Establish clocks and configure local gating | PMFW policy worker reaches child 22 DCLK and child 23 VCLK under row 6; driver disables local clock gating and sets VCPU CLK_EN | Child completion bits at PMFW-local `0x0116d124` / `0x0116d14c` differ from the parent handshake. No board capture or measured clock. |
| Supply compatible firmware and memory windows | PSP command 6/type 13 reaches the ordinary loader. Driver `mc_resume` uses PSP-returned TMR address for firmware cache0; stack/context/shared data have separate windows | An accepted cold-start image, valid returned address and matching programmed windows remain missing. Restore metadata or SMU DMA completion cannot substitute. |
| Release VCPU and memory-interface resets | Driver clears VCPU reset, enables memory channels and clears LMI resets after programming windows | Correct control state and valid memory access; PSP late writes are not demonstrated substitutes. |
| Observe running VCPU | Driver polls `UVD_STATUS & 2`, with bounded reset retries | Actual valid hardware status. No firmware-ready capture exists here. |
| Execute decode/encode work | Decode test seeds scratch9 with `0xCAFEDEAD`, submits a ring write of `0xDEADBEEF`, and polls for it; encode tests are separate | Ring-executed result, then workload validation. A host write of the expected value or a mock completion is insufficient. |

## Why enable can appear successful without enabling hardware

The current upstream `smu_dpm_set_vcn_enable` returns zero when VCN is deemed
disabled, when the platform callback is absent, or when its cached state says
no change is necessary. The local Cyan table explicitly installed by
`cyan_skillfish_set_ppt_funcs` has no VCN-enable callback.

The outer `amdgpu_dpm_set_powergating_by_smu` also has a cached-state bypass
and records the requested software state when its return value is zero.
`amdgpu_dpm_enable_vcn` returns void and logs an error if one is supplied;
`vcn_v2_0_start` does not branch on a returned enable status before local MMIO.
These paths explain why software success cannot serve as our power
acknowledgment. They do not prove which path a custom kernel executed.

This resembles the PMFW row-6 cache bypass, but the driver and firmware caches
are separate objects. There is no evidence that they stay synchronized.

## Connection to the offline state machine

The current convergence model proves ordering of synthetic conditions only.
Its fresh parent acknowledgment, physical-power acknowledgment, clocks, VCPU
ready and ring completion must remain separate. The driver comparison adds
two prerequisites to any future hardware adapter: demonstrated IP admission
and an implemented platform enable dispatch. Neither is satisfied by setting
a mock flag. The subsequent schema-3 model update represents these as explicit
hypothetical prerequisites, false by default, before the channel join. See
[the current model contract](parallel-channel-convergence.md). No driver code
was changed.

The earliest unresolved causal edge after those software prerequisites is:

`driver enable request -> actual BC250 platform operation -> accessible VCN island`

The independent firmware branch must also converge:

`accepted PSP image / TMR address -> firmware memory windows -> VCPU execution`

The recovered row-6 protocol is a candidate part of the platform operation;
its presence does not establish the missing dispatch, physical semantics,
PSP/SMU ordering, or correct address-space translation. The Navi12 case-0x13
write sequence likewise remains comparative evidence, not a verified BC250
startup replacement. An admission patch alone would expose these later gaps.

## Evidence and verification

Local source locations: `analysis/reference-sources/vcn/`. SHA-256 snapshots:

| File | SHA-256 |
|---|---|
| amdgpu_discovery.c | `076f5c3fb0a37ae041d7ee6b49b56dd850b3027c583a2744ce25f4d6c64e4ce1` |
| cyan_skillfish_ppt.c | `9259ad3ff6f660fe97ca7ea68f9b7e5f5d185982f0d3341180bd880442f030f1` |
| vcn_v2_0.c | `753849c7c491b137913668f77b8a3a0f539c7cf5cd46423db22b8f1513d9d9f6` |

Re-ran `perl tools/audit-vcn-cold-start.pl`: exit 0; verified input hashes,
three raw jump-table targets, load/completion evidence and nine register
offsets. Results: `exports/vcn-cold-start/audit.json`. Driver ordering and the
Cyan callback initializer were directly inspected. This is static verification,
not a hardware test. No SPI writes or device operations occurred.

Existing detailed evidence:

- [Cold-start path and acknowledgments](vcn-cold-start-and-acknowledgments.md)
- [Row-6 handshake and cache bypass](power-acknowledgment.md)
- [Local power-status address and read validity](vcn-physical-power-status.md)
- [Convergence model](parallel-channel-convergence.md)
- [ISA alignment/configuration limitations](isa-cross-reference.md)

Primary driver references (upstream master is mutable; checked 2026-09-28):

- [IP discovery](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/amdgpu/amdgpu_discovery.c)
- [Cyan platform table](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/pm/swsmu/smu11/cyan_skillfish_ppt.c), local snapshot used for callback inventory
- [SMU callback and cache guards](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/pm/swsmu/amdgpu_smu.c)
- [DPM wrapper and software power state](https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/pm/amdgpu_dpm.c)
- [VCN startup, memory windows and ring tests](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/amdgpu/vcn_v2_0.c)
