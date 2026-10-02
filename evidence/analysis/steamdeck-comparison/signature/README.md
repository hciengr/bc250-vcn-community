# Positive cryptographic comparison: Steam Deck key / Van Gogh VCN

2026-09-26. Actual offline signature verification, not a mocked success.

## Result

The public key at F7A0116_sign.fd record 0x2d1850 verifies the installed
vangogh_vcn.bin payload with RSA-PSS, SHA-256, MGF1-SHA256 and 32-byte salt.
An independent OpenSSL invocation returns `Verified OK`. A copy with one
bit changed at signed-message offset 0x100 fails verification (exit 1).
Original package and BIOS bytes were not modified.

Inputs are pinned by hashes in `../signature-verification.json`.
The extracted public key is `public-key.pem`; the signed data and signature
are `message.bin` and `signature.bin`. These are public verification inputs.

## Verified layout

| Field | Meaning supported by the successful verification |
|---|---|
| KDB record +0x08 | Usage 6 |
| KDB record +0x0c | RSA exponent, little-endian 0x00010001 = 65537 |
| KDB record +0x10 | ID matching Van Gogh payload +0x38 |
| KDB record +0x20 | 2048 key bits |
| KDB record +0x50 | 256-byte little-endian RSA modulus |
| Payload +0x00000..+0x8b9cf | Signed message, 571856 bytes |
| Payload +0x8b9d0..+0x8bacf | 256-byte signature, big-endian |

The outer Linux package header/padding ends at file offset 0x100 and is
excluded. The inner 0x100-byte PSP header is included in the signed message.
Hashing only the inner body fails the recovered PSS digest comparison.

**Correction:** earlier reports named record +0x0c "flags". For this record
it is used successfully as the RSA exponent. The BC-250 lookup's argument
construction independently selects record+0x0c with length 4 and the modulus
at record+0x50. Retain this correction when interpreting older inventory JSON.

## Reproduction

```
perl tools/verify-vangogh-vcn.pl > analysis/steamdeck-comparison/signature-verification.json
openssl dgst -sha256 \
  -verify analysis/steamdeck-comparison/signature/public-key.pem \
  -signature analysis/steamdeck-comparison/signature/signature.bin \
  -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:32 \
  -sigopt rsa_mgf1_md:sha256 \
  analysis/steamdeck-comparison/signature/message.bin
```

The Perl verifier tests byte-order hypotheses, recovers the RSA encoded
message, checks PSS structure, unmasks DB, recovers salt, and compares its
digest. OpenSSL supplies an independent complete verification check.
The negative-control file is a separate copy, never a hardware input.

The public algorithm reference is RFC 8017 section 9.1:
https://www.rfc-editor.org/rfc/rfc8017.html#section-9.1

## Ghidra comparison and scope

Fresh read-only BC-250 t28 exports in `ghidra-verifier.asm` cover
0xe0a130 (key parameters), 0xe09c9c (verification wrapper), 0xe10730
(PSS-shaped verification), and 0xe0b534 (image bounds/signature offset).
The verifier's trailer 0xbc, top-bit constraint, mask/XOR, separator/salt,
and final digest comparison agree with the independently verified format.
This is a comparison to the BC-250 verifier's code, not execution of it or
a Ghidra analysis of the Steam Deck PSP executable.

This closes the signature stage for the Steam Deck/Van Gogh reference pair.
It does not establish that BC-250 provisions this key, accepts this image,
or can execute its VCN 3.0 firmware. The BC-250 inventory still lacks usage 6
and this key ID. Neither key insertion nor firmware patching was performed.
The LOAD_IP_FW success path, hardware mapping/transfer, and actual VCN
readiness remain separate from this offline cryptographic result.
