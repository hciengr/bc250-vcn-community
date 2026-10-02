# Verified Navi10 VCN public key

2026-09-26. A real usage-6 public key was extracted from installed AMD PSP
firmware and verified against the installed Navi10 VCN image.

**This is the Navi10 candidate-image key, not a proven native Oberon key.**
Neither BC-250 acceptance nor hardware compatibility is established.

PEM: `navi10-vcn-c372-public.pem`.

## Source and layout

- Source: `/lib/firmware/amdgpu/navi10_sos.bin`.
- Source SHA-256: `3112ea8519545ac89c1623e2e08e841a6a9bc31c2aab2f9b787979e51277e395`.
- Record start: file offset `0x2CAD0`; size `0x150`.
- Usage: 6. RSA bits: 2048. Public exponent: 65537.
- Raw key ID: `c37290c310e64a62b027c56695492368` at record+0x10.
- Modulus: 256 little-endian bytes at record+0x50, file offset `0x2CB20`.

Matching records were located in navi12_sos at 0x31830 and navi14_sos at
0x2C980. Hashes and full-modulus comparisons are in `source-comparison.json`.
A raw search across 550 distinct installed amdgpu firmware files located
these records; firmware aliases were deduplicated by device/inode.

## Actual cryptographic result

Target: `/lib/firmware/amdgpu/navi10_vcn.bin`.
SHA-256: `ac5f2182b0ddee7a2886bf1239a47b4027becd0c37a1b0b6cac1f335393302c9`.

- Inner payload begins at package file offset 0x100.
- Signed message: payload `[0, 0x60F00)`, 397,056 bytes.
- Additional region: payload `[0x60F00, 0x62A40)`, 0x1B40 bytes.
- Signature: payload offset 0x62A40, 256 bytes, big endian.
- Successful algorithm: RSA-PSS, SHA-256, MGF1-SHA256, salt length 32.

The extra pre-signature region is not included in the message that verifies
under this signature. This does not establish whether it is checked separately.
Hashing the entire prefix through 0x62A40 fails. The earlier Van Gogh-only
message extent must not be generalized to all VCN firmware packages.

An independent Perl modular-exponentiation/PSS check succeeds for the
header+declared-body extent. OpenSSL independently reports `Verified OK`.
Changing one byte at signed-message offset 0x100 produces `Verification failure`.
Logs: `openssl-positive.log`, `openssl-negative.log`.

Reproduction from project root:

```sh
perl tools/verify-navi10-vcn.pl > exports/navi10-vcn-key/signature-verification.json
openssl dgst -sha256 \
  -verify exports/navi10-vcn-key/navi10-vcn-c372-public.pem \
  -signature exports/navi10-vcn-key/signature/signature.bin \
  -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:32 \
  -sigopt rsa_mgf1_md:sha256 \
  exports/navi10-vcn-key/signature/message.bin
```

## Consequence for BC-250

If the experiment uses `navi10_vcn.bin`, this is its verified signing public
key. The attached 70ec PEM verifies a different firmware family. Stock
BC-250 tables still lack this c372 ID and usage 6. Obtaining the correct
candidate-image PEM does not establish that inserting its record would
produce an accepted trust database or a functioning VCN engine.

No firmware was modified, signed, flashed or executed. A corrupted copy was
used only for the offline negative control.
