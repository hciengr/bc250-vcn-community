# BC-250 offline acceptance checks

Both candidate families were tested against the extracted stock P3 BL and
TOS key tables. Reproduce from the project root:

```sh
perl tools/check-vcn-auth.pl navi10
perl tools/check-vcn-auth.pl vangogh
```

For both families, neither stock table contains the image's key ID. The
lookup model stops there with modeled status 0xffff0008, before signature
verification. This is not an observed PSP return code from hardware.

With each candidate's matching reference key, OpenSSL verifies the actual
image signature. An in-memory wrong-usage fixture is rejected by the
usage-enforcement model; a one-byte signed-message corruption fails actual
signature verification. All five expected outcomes passed for each family.

Navi10 hashes only the header and declared body, excluding the additional
region before the signature. Van Gogh hashes the full prefix to its signature.
The reports record message lengths, signature offsets and input SHA-256 hashes.

Hardware discovery was attempted with:

```sh
bash tools/test-bc250-vcn.sh exports/bc250-acceptance-hardware-inventory
```

It exited 2: `Expected one BC-250 (1002:13fe); found 0. No GPU test run.`
No BC-250 is exposed through this environment's PCI sysfs. No candidate
firmware was submitted to hardware, and no ROM or trust database was patched.
Runtime trust-table acceptance and candidate compatibility remain untested.
