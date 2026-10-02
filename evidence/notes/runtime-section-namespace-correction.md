# Section IDs are not established packed directory identities

2026-09-29. Checked against `exports/psp-smu-ordering/section-source-requirements.asm` and the structural replay report.

The requested interpreter has already been recovered: **E1177C**. Its caller at E0A60A loads the literal 0x206 with MOVW, then calls E1177C at E0A612. This reader does not decompose the argument into Type/SubProgram or iterate PSP directory entries.

It reads a section count at B+0x100, starts at B+0x140 (B=E5CBDC), loads a 32-bit section ID and 32-bit pair count with LDRD at E11798, and compares the entire ID to the requested argument at E1179C. On a match it returns section+8 and the pair count through output pointers. On a mismatch it advances by 8+8*count. Absent ID returns FFFF0008.

The recovered local grammar is therefore:

```
u32 section_id
u32 pair_count
{u32 target, u32 value}[pair_count]
```

An upstream author might encode additional meaning inside section IDs, but no Type/SubProgram semantics or BIOS RTM/public-key/boot-loader association is demonstrated. Numerical decomposability is insufficient.

The two source candidates were supplied to the **same** structural replay, not independently observed executing separate dependency resolvers. E0A5E4 always asks for 206 first on the active non-100 path. Thus both stopping at 206 is a consequence of that fixed request and both inventories lacking it, not independent evidence of a shared authentication root.

Likewise E021D4 uses the same fixed sequence 201,205,203,20A,20B,210 for both hypothetical candidates. Their different first failures reflect different available sections, not candidate-specific requested dependencies.

“Cache” here denotes stored section pointers and counts at E66BDC; it is not an established authentication, trust, or directory cache. The original audit assumed each source copied unchanged to B, guards passing and present-section applications succeeding. None of those assumptions is an observed BC250 execution result.

The next useful trace remains the B producer and activation, including the tag-1000 configuration pointer at message+48. Raw directory Type/SubProgram searches would be a separate experiment and would not connect namespaces without code linking them.

Finally, FFFF0008 from this lookup and a reported FFFF0008 LOAD_IP_FW completion cannot be equated without a traced return path. Missing usage-6 inventory and authentication failure remain separate evidence from this table lookup.
