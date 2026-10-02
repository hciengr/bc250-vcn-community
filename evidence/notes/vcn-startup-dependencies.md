# VCN2 startup dependency trace

Follow-up: [PSP load contract and harvest provenance](vcn-psp-load-contract.md)
finds nonzero PSP responses that can still yield C return zero and a copied
TMR address, plus distinct discovery-field, software-mask and sysfs meanings.

2026-09-29. Follow-up to [the gate audit](vcn-driver-gate-audit.md).
Attached VCN2 source is unchanged. Supplemental Linux master sources were
downloaded to `analysis/reference-sources/vcn/startup-followup/`, with SHA256SUMS.
They are a dated comparison, not an asserted single kernel revision or a build
of the user's installed driver. Exact installed-source confirmation is required.

## Firmware selection occurs before the power-on experiment

The local `vcn_v2_0_early_init` calls `amdgpu_vcn_early_init`. In the downloaded
common implementation, that routine derives a firmware prefix and requests
`amdgpu/<prefix>.bin` when no firmware pointer is already supplied.

`amdgpu_ucode_legacy_naming` handles VCN 2.0.0 and 2.0.2, but has no 2.0.3
case. The generic fallback formats `vcn_<major>_<minor>_<revision>`. Thus, for
an admitted 2.0.3 instance without pre-supplied firmware, this source requests
**`amdgpu/vcn_2_0_3.bin`**. A request failure returns from early initialization.

This does not demonstrate that such a file exists, that a particular file is
compatible, or that renaming Navi12 firmware would work. File acquisition,
host-side validation, PSP acceptance, memory mapping and VCPU execution are
separate milestones. The original discovery skip normally prevents reaching
this branch at all.

## A concrete consumer of software harvest bits

Local `vcn_v2_0_sw_init` calls `amdgpu_vcn_setup_ucode(adev,0)`. In PSP mode,
the downloaded implementation first checks:

```c
if (adev->vcn.harvest_config & (1 << i))
    return;
```

For instance zero, a value 3 in THIS VARIABLE causes it to skip registration
of the VCN firmware entry. A value zero passes this particular guard. The
later code registers the firmware pointer/ID and adds its aligned size to the
PSP firmware total; this is not the authentication operation itself.

This identifies a real downstream software gate. It does not identify the
community's observed `3` as this variable, prove ABL0 writes it, or establish
that clearing it enables silicon. ROM discovery harvest zero is yet another
observation; its relationship to the reported runtime field remains unresolved.

## Ring-test entry reaches power-on indirectly

The connected source path is:

```text
vcn_v2_0_hw_init
  -> amdgpu_ring_test_helper -> ring's decode test
     -> CPU seeds external scratch9 with 0xcafedead
     -> amdgpu_ring_alloc
        -> ring->funcs->begin_use = amdgpu_vcn_ring_begin_use
           -> lock vcn_pg_lock
           -> set_pg_state(UNGATE)
              -> cached-state check
              -> vcn_v2_0_start
                 -> DPM enable / selected startup branch
           -> unlock
     -> submit scratch9=0xdeadbeef ring packet
     -> poll exact result
```

Two consequences:

1. The scratch write precedes this ring allocation's power-on callback. This
   is not proof it precedes EVERY earlier startup operation: the surrounding
   device lifecycle may already have powered the block. A BC250 diagnostic must
   establish that lifecycle before assuming the test is safe on an inaccessible
   island. The test's pre-write is a useful instrumented boundary.
2. `amdgpu_vcn_ring_begin_use` returns void and discards `set_pg_state`'s
   integer result. Ring allocation does not propagate that startup error via
   this callback. An earlier VCPU startup failure can therefore be followed by
   a ring submission/test failure, concealing the first failure in a summary.

The explicit `vcn_set_powergating_state` IP callback, by contrast, accumulates
the per-instance return values. Record which caller actually initiated startup;
do not assume every route drops its error. Ring-test failure still sets
`ring->sched.ready=false` in the downloaded helper.

## Exact reference PGFSM predicates now resolved

The common header defines the previously symbolic constant as `0x000aaaa0`.
Together with the already derived request values:

| Non-DPG branch | CONFIG request, byte offset 0x1f800 | STATUS predicate, byte offset 0x1f804 |
|---|---|---|
| AMD_PG_SUPPORT_VCN set | `0x000aaaa5` | `(status & 0x000fffff) == 0x000aaaa0` |
| Flag clear | `0x00055555` | `(status & 0x000fffff) == 0` |

The mixed state deliberately leaves the other eight represented tiles at 2
while UVDM/UVDU report zero. Testing all-zero status for both branches would
misinterpret the driver. Both still require independently valid MMIO access.
These are reference predicates, not a claim of BC250 applicability or a write
recipe. The driver's original unchecked wait behavior remains unchanged.

## Reproducibility and test priorities

`perl tools/audit-vcn-driver-gates.pl` now passes 19 source checks and records
dependency hashes, the inferred firmware name and resolved power predicate.
Output: `exports/vcn-driver-gates/startup-followup.json`. The earlier
`audit.json` is preserved as the prior 12-check result. All seven downloaded
source checksums were verified. No kernel was compiled or hardware accessed.

For a physical test, add to the existing capture requirements:

- Firmware request filename and return code from early init, before power tests.
- `adev->vcn.harvest_config`, instance index and whether setup_ucode registers
  the firmware entry; correlate with the actual location of the reported `3`.
- Entry/exit of begin_use and the nested set_pg_state call, including its
  discarded return value and current/requested state.
- Whether an earlier lifecycle operation powered VCN before the scratch seed.
- Actual pg_flags and the matching CONFIG/STATUS pair above.

Primary source URLs for saved supplemental files:

- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/amdgpu/amdgpu_vcn.c
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/amdgpu/amdgpu_vcn.h
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/amdgpu/amdgpu_ucode.c
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/amdgpu/amdgpu_ring.c
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/amdgpu/soc15_common.h
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/amdgpu/soc15d.h
- https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/include/asic_reg/vcn/vcn_2_0_0_sh_mask.h
