# VCN firmware restore and the separate AUTOLOAD path

2026-09-24. This pass identifies the previously ambiguous operation 8 and traces both it and the actual ring AUTOLOAD command. These are static results for the extracted stock P3 t02/t28 pair.

## Main result

**Ring command 8 is firmware SAVE/RESTORE, not AUTOLOAD.** Its VCN restore branch reaches the two previously identified PSP-window writes. **Ring AUTOLOAD command `0x21` sends a different internal message, `0x1059`, which selects t28's default error return `0xffff0009`.**

AMD's [official PSP interface](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/amdgpu/psp_gfx_if.h) identifies command 8 as SAVE_RESTORE, `0x21` as AUTOLOAD_RLC, and firmware type 13 as VCN. The command, payload, response and save/restore type offsets match the recovered firmware accesses. `tools/check-psp-command-layout.c` compiles against the downloaded header and asserts these matches; output is `exports/psp-op8/abi-layout.json`.

This corrects the earlier unverified association between “op-id 8” and AUTOLOAD. It does not establish that another boot/resume mechanism is absent, or that a running board executed either path.

## Boot to the ring consumer

The application boot worker creates a task using entry pointer `0x2022ad` at `0x2043da`. Seeding the missing Thumb entry `0x2022ac` recovers its calls to ring consumer `0x203558` at `0x202388` and `0x202396`.

The consumer checks ring state and producer position, processes 64-byte ring frames, advances the consumer position by 16 dwords and wraps at the configured ring length. It calls `0x20243c`, which maps/copies a `0x400`-byte command buffer, reads its command ID at `+8`, and uses its payload at `+0x1c` and response at `+0x360`.

This links a boot-created worker to the command handlers. Ring setup, host submission, valid buffers and successful runtime checks are still required.

## Command 8 → VCN restore writes

```
boot-created ring worker 0x2022ac
  → ring consumer 0x203558
  → command dispatcher 0x20243c
  → command 8 case 0x20264e
  → wrapper 0x20118c, message 0x1024, SVC 0xf2 service 1
  → t28 entry / message dispatcher 0xe0bb98
  → jump-table trampoline 0xe0be76
  → argument setup 0xe0c196
  → restore helper 0xe0cf90
  → type 13, restore selector 0, prerequisite operations successful
  → SVC 0x7c: write32(0x0900c004, 1)
  → helper 0xe170e0: write32(0x0001f8a4, 1)
```

Raw-byte validation: t02's TBB at `0x20257e` has table base `0x202582`; index 8 targets `0x20264e`. T28's table at payload offset `0xbbc8` uses `0x1024 - 0x1014 = 16`; the target branches to payload offset `0xc096`, whose call at `0xc0a0` reaches `0xce90`. Runtime addresses add `0xe00100`.

The command payload's first word selects save versus restore. The type word is at payload `+0x10`. Type 13 now has an ABI-backed VCN identity, rather than just a community label. The restore branch performs mappings, transfers and checks before the writes; it is not a two-write enable recipe. The wrapper also queries internal protocol capabilities through message `0x103b` and chooses its argument packaging accordingly.

One additional limitation is explicit in assembly: `0xe170e0` executes SVC `0x7c`, then overwrites its return value with zero. The preceding direct SVC result is likewise not tested before calling that helper. Therefore this path's apparent success is not independent confirmation that either hardware write succeeded. The target register fields and their reset/isolation meanings remain unverified.

## Actual ring AUTOLOAD → default error

The same t02 command dispatcher routes `0x21` through case `0x2026e0` to wrapper `0x200f38`. That wrapper sends **message `0x1059`** to service 1. This is separate from the register/mailbox dispatcher, whose numeric `0x21` path sends `0x1034`; command numbers cannot be transferred across interfaces indiscriminately.

For `0x1059`, t28 computes table index `0x29` relative to `0x1030`. Table byte at payload offset `0xbc27` is `0x35`. TBB therefore targets `0xe0bd68`, followed by:

```
0xe0bd68 → 0xe0be3e → 0xe0c04a → 0xe0c82c → 0xe0c8a8
  → load literal 0xffff0009 into return register
  → return
```

`tools/audit-psp-op8.pl` independently checks the table bytes, every unconditional branch above, and the terminal literal load against the firmware bytes. Earlier service/permission/state validation can reject the request sooner; if dispatch reaches this table, this stock message follows the error path. This is evidence of an unsupported/default route in this image, not proof that every possible VCN startup path is disabled.

## Correction to the alleged registration walker

Payload offset `0x12b08` contains a literal; the next function starts at `0x12b0c` (VA `0x204b0c`). The boot worker creates it as another task. Its recovered loop obtains completion records, matches pending work, updates response state and releases/completes requests. It does not establish the previously proposed “register op-id-8 array” mechanism. The separately verified loaded-object registry and SVC `0x74` binding remain valid.

The mapped t02 export now contains 188 functions. Zero decompiler failures does not imply correct SVC return modeling; the conclusions above use instruction dumps and raw branch checks.

## Evidence and next gaps

`exports/psp-op8/paths.json` records the verified command identities, jump targets, write arguments and limits. Assembly includes the ring worker, command dispatcher, wrappers, t28 trampoline, restore helper and second-write helper. The older wider t28 dispatcher dump is included in the evidence bundle to show the full default branch chain.

The next useful trace is the VCN save/restore prerequisites: staging-buffer provenance, expected initialized firmware/TMR state, and the helpers preceding the writes. Hardware register identities, powered-state acknowledgment, VCPU readiness and ring completion remain open. No firmware was patched or executed on hardware; originals remain unchanged.
