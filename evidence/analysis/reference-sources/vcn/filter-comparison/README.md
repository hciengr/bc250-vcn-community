# Pinned public filter-register comparison

Retrieved 2026-10-01 from AMD-contributed Linux register definitions at commit `704340f1cd0dcef829eb62f5b48ae95a2ce17bdf`.

- Offset source: https://raw.githubusercontent.com/torvalds/linux/704340f1cd0dcef829eb62f5b48ae95a2ce17bdf/drivers/gpu/drm/amd/include/asic_reg/vcn/vcn_3_0_0_offset.h
- Mask source: https://raw.githubusercontent.com/torvalds/linux/704340f1cd0dcef829eb62f5b48ae95a2ce17bdf/drivers/gpu/drm/amd/include/asic_reg/vcn/vcn_3_0_0_sh_mask.h
- Offset header SHA-256: `d1071cd768c0550abe3a8203c0e962ea9839254dfdaf6ba44f25e69e31ee53c7`.
- Mask header SHA-256: `4cb679e51338387e759e0bb9dde3ae1d0dee775ceaa0dd6bbdb0a875ebcd6ee1`.

VCN3 defines UVD_REG_FILTER_EN at offset 29, BASE_IDX 1. Combining that comparative offset with BC250 discovery segment 1 (7E00 dwords) gives `(7E00+29)*4=1F8A4`. Masks name bit 0 filter-enable, bit 1 MMSCH-high-privilege, bit 2 video-privilege-enable and bit 3 JPEG-privilege-enable.

Under this **VCN3 comparison schema**, 0B sets bits 0,1,3 and 01 sets bit 0 only. A change from the stored t24 preload 0B to the late t28 request 01 would keep the filter-enable bit set while changing privilege fields, rather than simply disabling the entire filter.

BC250 advertises VCN2.0.3, and the existing VCN2 header omits this field name. The arithmetic and comparison schema are established; target-generation equivalence, PSP/host address mapping, field polarity/access behavior and runtime effect are not. Do not promote this comparison to a verified BC250 field definition or a write recipe.

No authoritative cold-reset field definition for 0900C004 was established by the focused source search in this pass. Search absence is not a universal absence claim.
