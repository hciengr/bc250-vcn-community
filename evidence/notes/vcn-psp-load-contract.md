# VCN PSP submission success is not firmware acceptance

2026-09-29. Static analysis of the saved driver sources. No hardware access.
Reproduction: `perl tools/audit-vcn-load-contract.pl`; output saved as
`exports/vcn-driver-gates/load-contract.json`. Eight source checks pass, with
five synthetic response cases and four software harvest-bit examples.

## Connected data flow

```text
runtime discovery harvest information
  -> vcn.harvest_config / vcn.inst_mask / aggregate harvest_ip_mask
  -> amdgpu_vcn_setup_ucode instance guard (PSP mode)
  -> firmware.ucode[AMDGPU_UCODE_ID_VCN] pointer and size bookkeeping
  -> firmware staging supplies mc_addr and ucode_size
  -> fw_load_skip_check rejects missing fw or zero ucode_size
  -> psp_execute_ip_fw_load
     -> command LOAD_IP_FW, source mc_addr, ucode_size, type VCN (13)
     -> psp_cmd_submit_buf, ring submission, indexed completion fence
     -> response handling and fw_addr_lo/hi copy into tmr_mc_addr_lo/hi
  -> vcn_v2_0_mc_resume consumes tmr_mc_addr_lo/hi
  -> reset release and execution tests
```

The staging step is a dependency, not a newly audited allocator/format
implementation. This trace identifies request/response consumers; it does not
establish a compatible VCN image or successful authentication on the board.

## Nonzero PSP response can coexist with C return zero

In local `amdgpu_psp.c`, `psp_cmd_submit_buf` at line 725:

- `no_hw_access` returns zero without submitting anything.
- Actual submission allocates an incrementing fence index and waits for that
  value, invalidating HDP while polling.
- When a nonzero response is returned, bare-metal initialization generally
  warns rather than returning an error. The comment explicitly describes PSP
  versions that fail to clear that status field.
- In this error branch, a firmware-bearing VF request or exhausted timeout
  becomes `-EINVAL`. Unsupported-command VF exceptions are separate.
- If execution continues, response `fw_addr_lo/hi` are copied into the ucode
  TMR address fields. Nonzero firmware status does not by itself prevent that
  copy on the bare-metal path.

Narrow synthetic examples assume successful ring submission, a non-null ucode,
and no unsupported-command exception:

| Situation | Modeled C result | Reaches address copy |
|---|---|---|
| Bare metal, completed fence, response 0 | 0 | Yes |
| Bare metal, completed fence, response `0xffff0008` | 0, warning path | Yes |
| VF, completed fence, response `0xffff0008` | `-EINVAL` | No |
| Timeout exhausted, no RAS interruption | `-EINVAL` | No |
| RAS interruption with timeout counter still nonzero | Can remain 0 | Yes |

The RAS case follows the explicit break from the fence loop and the
`!ras_intr` error-handler guard. It is not proof of fence completion or stable
device state; other reset/recovery machinery remains outside this narrow audit.
The `0xffff0008` value is used as a branch counterexample, not a captured board
response or a newly identified error in the user's driver.

This result means **C return zero and a populated TMR field are insufficient
evidence of an accepted image**. Conversely, because compatibility handling is
intentional, a nonzero status should be investigated in context rather than
blindly changing this shared driver path to reject every such response.

## Harvest provenance: three different representations

The local discovery code establishes distinct representations:

1. Per-IP discovery field: the legacy parser checks `ip->harvest == 1`, not
   simply nonzero. That parser is selected only under specific GC/discovery
   version and PCI-ID/revision conditions; it is not universal.
2. Instance mask: the harvest-list parser ORs `BIT(inst)` into
   `vcn.harvest_config` and clears that bit from `vcn.inst_mask`. In the software
   harvest_config bitmask, 3 means bits 0 and 1 are set. The PSP setup guard
   then skips instance 0 and instance 1 if visited.
3. Sysfs per-instance harvest display: for VCN without legacy VCE, the inspected
   getter derives a boolean from `inst_mask`. It is not a raw hardware register
   read and does not expose the whole harvest_config bitmask.

An aggregate `harvest_ip_mask` also records all-instance harvesting when the
harvest count equals the VCN instance count. A separate quirk concerns Navy
Flounder versions, not the identified BC250 VCN 2.0.3 configuration.

Therefore a reported value 3 must be accompanied by the exact source:
register/address, discovery field, driver variable, or output file. A 3 in a
raw per-IP nibble is not processed identically to a 3 in harvest_config. No
ABL0 writer or hardware disable-control field has been recovered by this work.
Editing one software mask also does not necessarily restore the other masks,
IP registration, firmware metadata or physical availability.

## What a physical capture must contain

Before treating a load as accepted, retain:

- Exact driver/BIOS/firmware hashes and whether `no_hw_access` is set.
- Harvest source data and all three derived masks, before/after parsing.
- Whether the VCN ucode entry was registered or skipped, and whether its
  pointer, ucode size and staged device address are valid.
- LOAD_IP_FW command/type/size/address, submission return, expected fence and
  observed fence, timeout counter and any RAS/reset event.
- Raw response status and returned firmware address, correlated to this command.
- The actual firmware memory-window values and later VCPU/ring observations.

Status zero without a matching fence can be an untouched zero-filled response;
returned address data alone is not proof of trust or execution. Physical
accessibility and execution checks remain independent of this load contract.

Sources: local `analysis/reference-sources/vcn/amdgpu_psp.c` (SHA-256
`4eb9ce8a315de3812a18aa28b412cde9b86749cdf7b9906cf3383f60abdfab7b`),
`amdgpu_discovery.c`, `psp_gfx_if.h`, `vcn_v2_0.c`, and the separately hashed
`startup-followup/amdgpu_vcn.c`. These are reference snapshots, not a claim
that the installed kernel matches them. See [startup dependencies](vcn-startup-dependencies.md)
and [cold-start firmware trace](vcn-cold-start-and-acknowledgments.md).
