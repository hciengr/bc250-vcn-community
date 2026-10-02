# Domain identity and recovered PSP handoffs

Follow-up: [PSP service chain](psp-service-chain.md) resolves t28's mapping and the SVC `0x74` binding step. It clarifies that `0x206118/0x20611c` hold a translated address pair and that the initial special loader path uses the SVC `0x73` staging base directly.

Static analysis, 2026-09-24. This supersedes the earlier unresolved row-6 clock identity, registry-base value, and SVC `0x7c` semantics. It does not demonstrate live VCN enablement.

## Row 6: VCLK/DCLK parent domain

The identification now has an independent firmware-to-driver ABI link:

1. Queue 0 message 6 selects the table-transfer handler `0x1ba5c`.
2. Table ID 6 has callback `0x29aec` at pointer slot `0xcb34`.
3. That callback copies `0xf4` bytes from metrics buffer `0xcb54`.
4. AMD's [Cyan Skillfish metrics interface](https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/amd/pm/swsmu/inc/pmfw_if/smu11_driver_if_cyan_skillfish.h) names table 6 `TABLE_SMU_METRICS`. Its `SmuMetrics_t` has the matching size, with current VCLK at offset `0x4a` and DCLK at `0x4c`.
5. Callback instructions read child 23's value at `0xfa1c` for offset `0x4a`, and child 22's value at `0xfa00` for offset `0x4c`. Both child records explicitly identify parent row 6. Average-field dataflow corroborates the same ordering.

| Identity | Child | Record | Register offset | Q3/Q4 setter selector | Reader selector |
|---|---:|---|---|---:|---:|
| VCLK | 23 | `0xfa14` | `0x6d128` | 16 | 15 |
| DCLK | 22 | `0xf9f8` | `0x6d100` | 15 | 14 |
| Unnamed sibling | 24 | `0xfa30` | `0x6d150` | 11 | 10 |

Selectors are decimal; setter is message `0x1d`, readers are Q3/Q4 `0x42` and Q0 `0x11`. This identifies software clock roles, not host-accessible register addresses. Child 24 cannot yet be named. Metrics are software-derived values, not independent measurements of a running video engine.

Verification: `tools/check-metrics-layout.c` compiles against the downloaded official header and asserts layout; `tools/identify-video-clocks.pl` checks firmware pointers, child offsets and parents. Results: `exports/domain-identity/identity.json`, `metrics-layout.json`, and `metrics-evidence.asm`. Source copies and hashes are under `analysis/reference-sources/vcn/`.

## PSP boot reaches the application and registry worker

The kernel's page-table setup `0x32bc` calls `0x2bb8` to map eight pages starting at payload/physical address `0xe000` to virtual address `0x200000`. Startup creates a context targeting `0x200000`; `0x744` restores a saved context and returns through its PC, rather than simply returning to its C caller.

The application was imported separately at its mapped address. Conversion is:

`application VA = t02 payload offset + 0x1f2000`

The extracted application begins at payload offset `0xe000`, has size `0x6150`, and SHA-256 `c414c382e2bc403052a122763fbf718cb5a612c1b726e2e7047e998ada7757ca`. Its Ghidra memory block starts at `0x200000`; the generic export's `image_base: 00000000` is not the block start. There are 179 exported functions in `exports/psp-t02-mapped/`.

Recovered sequence:

```
t02 reset → kernel initialization → application context at 0x200000
  → ARM application entry loads Thumb pointer 0x203609
  → 0x203608 maps application regions using SVC 0x62
  → successful path stores 0x280000 to [0x206080] at 0x2036f4
  → SVC 0x51 creates worker with entry pointer 0x2042c5
  → worker 0x2042c4 calls registry initializer 0x203840
  → initializer clears 32 × 0x54 bytes at base + 0x6000 = 0x286000
  → worker calls object loader 0x203a04 at 0x20430c
  → success path calls service wrapper 0x201792 at 0x20436e
```

SVC `0x51` is corroborated by the kernel dispatcher calling context constructor `0x189c`. The initial object-loader arguments come from `[0x206118]` and `[0x20611c]`; their runtime provenance and identification as t28 remain open. A matching `0x5244` header alone cannot close that gap.

Wrapper `0x201792` builds a message with first word `0x1030`, second word 2, and its two arguments at offsets `0x38/0x3c`. It invokes SVC `0xf2` with service selector 1 and the message pointer. At the worker call, those payload arguments are 13 and the returned slot byte. Thus 13 is a message argument here, not the SVC service selector; neither number establishes op-id 8.

The registry is a general loaded-object/driver registry. Its initialized address is now statically established **on the successful startup path**. Occupied entries, execution success and runtime handles remain unknown.

Evidence: `exports/psp-t02-mapped/entry-evidence.asm`, `worker-evidence.asm`, and `exports/domain-identity/psp-app-registry.asm`. Decompiled application C incorrectly removes branches around SVCs because return effects are not modeled correctly; these conclusions use instructions and kernel implementations.

## SVC identities and t28 writes

SVC dispatch `0x4444` routes ordinary calls to `0x45a0`. Case `0x7c` reaches `0x5a88(address, value, width, 0)`. This helper calls `0x2fcc` to select a programmable window, performs a byte/halfword/word store for width 1/2/4, then executes `DSB`. The width-4 store is at `0x5ab8`.

Window helper `0x2fcc` uses slot 0 here and returns `(address & 0xfffff) + 0x01000000`. Helper `0x42d8` programs window registers at `0x03220000` and `0x03220050` for that slot. This explains the access mechanism without assigning undocumented hardware field names.

| t28 SVC arguments | Recovered operation | PSP window address |
|---|---|---|
| `r0=0x0900c004, r1=1, r2=4` | 32-bit write of 1 to selected target `0x0900c004` | `0x0100c004` |
| `r0=0x0001f8a4, r1=1, r2=4` | 32-bit write of 1 to selected target `0x0001f8a4` | `0x0101f8a4` |

These are whole-word stores, not read/modify/write bit sets. Target field meanings, actual execution, and applicability to VCN isolation are unresolved. Do not use these PSP-local window addresses as host SMN addresses.

SVC `0xf2` routes through `0x4f48` to code at `0x1ab8`. It bounds the service selector to 0–15, looks up the target byte in table `0x8430`, checks access/context constraints, and loads a target entry from a `0x5c`-stride service record. It installs that entry into the saved context's PC at `+0x3c` and updates Thumb state. This is service invocation through a context transition; it is not itself proof of registration or a VCN-specific command. Ghidra currently folds this tail-called code into the `0x4f48` function body.

Evidence: `exports/domain-identity/psp-svc-evidence.asm`, plus earlier t28 instruction dumps. These syscall implementations are from the t02 payload extracted from the same stock P3 ROM.

## Remaining gaps to an enabled, powered, usable VCN

- Identify the runtime object supplied to the boot worker, its service registration and t28 relocation.
- Connect the service message format to AUTOLOAD/op-id 8, then its concrete callers and return conditions.
- Name the two target registers using matching hardware evidence; prove the relevant power/reset/isolation sequence completes.
- Establish that runtime requests activate feature bit 13 and advance the PMFW worker's state gate. Static presence of the path is insufficient.
- Resolve child 24 and the remaining numerical-helper decoding limits.
- Check the actual tested Linux driver: discovery reports VCN 2.0.3, while the downloaded upstream discovery code skips registration for that version.
- Obtain a readable, identified working Oberon comparison pair and eventually verify VCPU readiness and ring completion on hardware.

Original binaries and baseline exports were preserved. No firmware or register writes were executed on hardware.
