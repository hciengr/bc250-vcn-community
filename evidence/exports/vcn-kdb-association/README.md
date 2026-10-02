# VCN key-to-KDB association audit

2026-09-27. The verified Van Gogh key is absent from the extracted BC-250
P3 BL and TOS KDBs. In the Steam Deck reference it belongs to a bounded
record with usage 6. The BC-250 consumer maps firmware type 13 to usage 6;
it does not search a per-key list for the literal number 13.

## Reproduction and fingerprint

From the project root:

```sh
perl tools/audit-vcn-kdb-association.pl > exports/vcn-kdb-association/report.json
perl tools/check-vcn-auth.pl
```

Both commands were run. The authentication check again verified the original
Van Gogh image with OpenSSL and rejected the corrupted-image control. Its
lookup/usage fixtures are models, not execution of PSP firmware. Inputs and
outcomes are in `../vcn-auth-check/report.json`.

Target: RSA-2048, exponent 65537, ID `70ec3e2d8a694792ac7969ff8ac9caca`.
Big-endian modulus SHA256:
`e953f8d8d300d746a33306563588a6c43abf3eab3a04b57d0cf6cdbd95e81126`.
PKCS#1 DER SHA256:
`96bac424e34fbe9ca341c1e909b447bd30971b716390f5fa1a4269a0fc9fd1fe`.
The audit checks the complete PEM DER against the reference modulus and
exponent, rather than identifying a key solely by its 16-byte ID.

## Structural association

The parser starts at KDB size-field base +0x50 and advances by each record's
declared size, checking record and modulus bounds against the table end.
Four bounded tables are found in F7A0116_sign.fd; four additional `$KDB`
byte occurrences fail structural validation and are recorded separately.

In table `0x2d1170`, the target record spans `[0x2d1850, 0x2d19a0)`:

| Record-relative field | Absolute offset | Value |
|---|---|---|
| +0x00: size | 0x2d1850 | 0x150 |
| +0x08: usage | 0x2d1858 | 6 |
| +0x0c: exponent | 0x2d185c | 65537 |
| +0x10: ID | 0x2d1860 | Target ID |
| +0x20: key bits | 0x2d1870 | 2048 |
| +0x50: modulus | 0x2d18a0 | Complete 256-byte little-endian target modulus |

The duplicate table at `0xad1170` contains the same key and usage in record
`0xad1850`. Thus the association is structural, not proximity-based.

| BC-250 P3 extracted table | Records | Usage values | Target key/ID |
|---|---:|---|---|
| BL_PUBLIC_KEY~0x50_1 | 8 | 14,32,30,42,47,31,44,35 | Absent |
| TOS_PUBLIC_KEY~0x51_1 | 3 | 10,44,17 | Absent |

Whole-file scans of both BC-250 objects also find no full modulus in either
byte order, raw/mixed-endian ID, PKCS#1 DER, or raw/lowercase-hex SHA256 of
either modulus representation or DER. This is a bounded representation
search, not exclusion of encrypted contents or every conceivable encoding.

## Consumer evidence

The audit pins t28 SHA256 and checks the actual Thumb jump-table bytes.
Using the existing analysis base `0xe00100`, TBB at `0xe08a1e` uses table
base `0xe08a22`. Index 13 is byte `0x24` at file offset `0x892f`, selecting
`0xe08a6a`: bytes `06 20 70 47`, or `movs r0,#6; bx lr`.

The existing instruction export `../vcn-load-ipfw-simulation/auth-audit.asm`
ties this mapping to lookup and metadata:

- `0xe16ddc` calls the mapper; `0xe16dea` passes its result on the stack to
  the header lookup wrapper called at `0xe16dfa`.
- `0xe0a130` walks the table at analysis VA `0xe25834`, starting records at
  table-object +0x150 and advancing by `[record+0]`.
- `0xe0a150..158` compares 16 bytes at `record+0x10` with the header ID.
- On that exact match, `0xe0a176..178` loads `[record+8]` and compares it
  with the requested usage. The same r4 record pointer then supplies the
  exponent at +0x0c, modulus at +0x50, and bit count at +0x20.
- SVC `0x87` gates usage enforcement. Zero bypasses usage checks; requested
  usage -1 bypasses equality. An enforced mismatch selects `0x80000205`.
  The enforced path also rejects usage 0x22 with `0x80000206`.
- No matching ID retains `0xffff0008`, before the usage comparison.

These are static consumer instructions, not an observed runtime result.

## Decision and remaining gap

For this Van Gogh candidate, the extracted BC-250 tables take the **key
absent** branch. There is no matching BC-250 entry whose metadata could
support the claim "this key is present but lacks type 13 authorization."
The prior missing-list observation should be described as an inventory
missing usage 6, not as a per-key fw_type list missing 13.

The Steam Deck reference contains the key with the usage required by the
BC-250 mapper. That clears this specific usage mismatch for the reference
record; it does not establish acceptance by other policy checks.

The unresolved causal step remains proving which producer populates the
live table at `0xe25834`, its contents during the failing LOAD_IP_FW path,
and the actual lookup/check result. The static P3 objects have not been
shown to equal that live table. Nor is the verified Van Gogh key/image
established as the expected Oberon-compatible pair. No hardware was changed.

Follow-up: `../vcn-kdb-provenance/README.md` traces the initializer's staging
source, verifies ROM/extraction byte identity, and records hashes of the
exact copied ranges. The preceding staging producer and live byte identity
remain unresolved. Missing-ID rejection precedes SVC 0x87; only a matched
record reaches its conditional usage check.
