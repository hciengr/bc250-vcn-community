# PSP loader, service binding, and t28 entry

Follow-up: [VCN restore versus AUTOLOAD](psp-vcn-restore-vs-autoload.md) identifies the relevant t02 ring command 8, distinguishes it from AUTOLOAD `0x21`, and traces both routes. This supersedes the unresolved command-namespace discussion below.

2026-09-24, static analysis follow-up. This closes more control-flow gaps; it does not establish live VCN power or readiness.

## T28 mapping recovered

The signed image's base is `0x00e00000`. Our extracted payload omits the outer `0x100`-byte header, so its correct analysis mapping is:

**runtime VA = payload offset + `0x00e00100`**

This is corroborated independently by the loader and the entry wrapper:

- T02's special boot-object loader copies from the staging base including the outer header. It reads the inner object header at staged offset `+0x100`, selects virtual base `0xe00000`, and uses the inner header's entry field to construct the service context.
- Inner header entry `0xe01a0c` resolves to payload offset `0x190c`, which decodes as ARM `mov r0,r2; ldr r12,[pc,...]; blx r12; svc 0x75`.
- The literal is `0xe069b1`, resolving exactly to the known Thumb message wrapper at payload offset `0x68b0`.
- That wrapper passes ordinary messages to dispatcher `0xe0bb98` (old payload label `0xba98`).

The original base-zero export remains useful for file offsets. The new `exports/psp-t28-mapped/` has 645 functions from focused entry seeding; it does not replace the more broadly seeded 763-function baseline. Generic `summary.json` still reports program image base zero; the loaded memory block starts at `0xe00100`.

`tools/trace-psp-service-chain.pl` verifies source/payload byte identity, the ARM wrapper words, and the absolute Thumb target, then produces `exports/psp-service-chain/chain.json`.

## Boot source: correction and narrower uncertainty

The two words at `0x206118/0x20611c` are **low/high halves of a translated address**, not two independent object pointers. Application startup supplies their destination to SVC `0x80`; kernel helper `0x1f70` translates a window address into a 64-bit address.

For the initial loader call, the special-path flag is 1. That path actually sources bytes directly from `[0x2060c8]`, populated by SVC `0x73`. The kernel returns `[0x601c]`; initializer `0x50a8` computes it as `0x04000000 + (boot-data[0x23c] & 0x03ffffff)` while setting up the associated window descriptor using register `0x03230000`.

We now know how the boot source is selected. The live boot-data/window contents are unavailable, so identification of those bytes as the exact ROM t28 object remains conditional. The recovered t28 layout and entry match this loader contract.

## Registration is now linked to invocation

On the successful driver-object path in t02's mapped loader `0x203a04`:

1. SVC `0x71` installs a context description including the entry from object header `+0x10`. Kernel helper `0x35e0` writes the entry into the loaded-object record at `+4` (record stride `0x5c`).
2. At `0x2041ee`, the loader stores the service ID in its application registry record at `+0x18`.
3. At `0x2041f6`, SVC `0x74(service_id, object_slot)` calls kernel helper `0x37ec`, which validates the allocated slot and service-ID bound, then writes one byte to `0x8430 + service_id`.
4. SVC `0xf2` uses that same byte table, finds the object record's entry, and redirects the saved execution context. Its message pointer becomes the target's `r2`.
5. T28's ARM entry moves `r2` to `r0` and enters the Thumb message wrapper.

The special boot-object path sets service ID 1. Thus there is now a static **loader → entry installation → service binding → invocation → t28-compatible entry** chain. Success of the runtime loading and binding calls has not been observed.

## Initialization and the `0x1030` message

The boot worker calls wrapper `0x20134e`, which constructs message `0x1000` for service 1. T28 routes that message to `0xe0956c`, its service initializer. Its success path sets `[0xe18910] = 1`; the message wrapper rejects ordinary non-initialization messages unless that word equals 1. SVC-dependent return paths must be read from assembly, since the decompiler does not model their return values reliably.

After the initialization wrapper returns success, the boot worker sends service 1 message `0x1030`, with index 13 at message offset `0x38` and the newly returned object-slot byte at `0x3c`.

T28 dispatcher `0xe0bb98` routes `0x1030` to `0xe0e6a8`, which stores the supplied value according to the index:

| Index (decimal) | Destination |
|---:|---|
| 0 | `0xe18984` |
| 1 | `0xe18988` |
| 2 | `0xe18b34` |
| 3 | `0xe1898c` |
| 5 | `0xe189a8` |
| 7 | `0xe18998` |
| 8 | `0xe189b0` |
| 9 | `0xe189b4` |
| 10 | `0xe189b8` |
| 13 | `0xe189ac` |

These are general stored values; not every index is established as a handle. Index 13 receives the boot object's returned slot in the traced caller. Other recovered callers use indices 1, 3 and 5. No direct recovered wrapper caller supplies index 8; that is a bounded call-graph observation, not proof of impossibility.

## Three different meanings of “8”

- **Message `0x1030`, argument index 8:** a value store to `0xe189b0`. A corresponding query helper `0xe0d540` reads it. No VCN semantics established.
- **T28 message word 8 (also 9):** low-numbered dispatcher `0xe15324` calls `0xe14518`. It handles buffers, an object/algorithm selector and lengths. This is a separate namespace and is not established as the desired VCN/AUTOLOAD operation.
- **The original AUTOLOAD/op-id 8 hypothesis:** still needs a validated command format and a caller linking it to the relevant hardware path. Neither numerical match above closes it.

## Evidence and remaining work

Assembly is in `exports/psp-service-chain/`: `kernel-registration.asm`, `kernel-bind-service.asm`, `t02-init-message.asm`, `t28-entry-mapped.asm`, `t28-service-handlers.asm`, and `t28-init.asm`. Earlier loader instructions remain in `exports/domain-identity/psp-app-registry.asm` and startup instructions in `exports/psp-t02-mapped/`.

Next gaps: identify the bytes staged by the preceding boot loader; recover the intended AUTOLOAD command namespace and caller; connect its runtime conditions to the two known t28 writes and any additional power/reset/isolation sequence. Register meanings and VCPU/ring readiness remain unverified. Originals and baseline exports are preserved; no firmware was executed on hardware.
