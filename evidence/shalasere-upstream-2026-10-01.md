# Shalasere upstream reconciliation, 2026-10-01

Source repository: https://github.com/Shalasere/bc250-vcn-research
Pinned revision: `4a91ceb86275fbceeaf1fb3062f2f086e7f780c5`.

Read the September 30 corrections alongside the session summary; historical README sections do not establish current status.

- [Session summary](https://github.com/Shalasere/bc250-vcn-research/blob/4a91ceb86275fbceeaf1fb3062f2f086e7f780c5/research/SESSION_SUMMARY_2026_09_30.md) reports a patched direct-load route: firmware copied into a driver BO and VCN omitted from PSP registration. This avoids the LOAD_IP_FW call; it does not demonstrate VCPU execution, functioning cache BAR programming, rings or media. The report explicitly says no decoding and hangs when programming VCN registers. This adds an alternative provisioning branch to our PSP route, rather than disproving the PSP permission/KDB findings.
- The same report and [corrections](https://github.com/Shalasere/bc250-vcn-research/blob/4a91ceb86275fbceeaf1fb3062f2f086e7f780c5/research/CORRECTIONS_2026_09_30.md) report SMU 88.6.0, messages 0x2A/0x2B returning 0xFD and Van Gogh 0x09 returning 0xFE through SMN 0x3B10A20/A80/A88. An unmet prerequisite is a lead; exact handler identity and the cause require dispatch tracing. A response alone does not prove the specific BIOS sequence hypothesis.
- Corrections distinguish this mailbox from driver Q0; shared responses do not establish mailbox aliasing. Do not import the older Q0==Q3 conclusion.
- Reported SMN fuse mirrors 0x5d928/930/93c = 0x10C6 and earlier harvesting read 0x1f81c = 3 support a disable-bit hypothesis. Address identity, mask applicability, cold-reset effects, and whether the fuse causes 0xFD remain unresolved. Do not mark permanent physical disable as proven.
- Corrected filename is amdgpu/vcn_2_0_3.bin, reportedly manually placed and of unclear origin. Header appearance alone does not authenticate its provenance or prove board compatibility.

These are attributed reports, pending independent validation in this project. They do not supersede our hash-pinned static policy omission, final-loader-error reset coupling, or key-path audits. They redirect a high-priority parallel experiment toward direct provisioning plus SMU prerequisite/harvest validation. Existing ring/media outcome claims remain unknown.

## Supplied comparison binary

`/home/hci/Downloads/vangogh_smu_full.bin` is 524,800 bytes, SHA-256 `c4de5edc9eb2a9676b7c9a6811e71fee793192ba7bb340d7f6689c7b7eb89b25`, byte-identical by size and SHA-256 to upstream `firmware/vangogh_smu_full.bin` at the pinned revision. This establishes artifact identity. It is a Van Gogh SMU comparison artifact, not a validated BC250 VCN firmware or proof that its message IDs apply to BC250. No firmware was flashed or executed.
