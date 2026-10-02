# Community report: RSMU domain C and VCN

Received in the project conversation on 2026-10-01. User supplied a Discord discussion excerpt; the final reset discussion is attributed to Rukkus, “6:11 PM”. Original message date, IDs, permalinks, binary hashes, scripts and hardware logs were not supplied. Channel reference: https://discordapp.com/channels/1315924807128449065/1537956545881444382 . The channel was not scraped. This is reported evidence awaiting validation, not a verified transcript of the full channel.

## Reported claims

- VCN discovery hw_id 12 / version 2.0.3 / bases 7800,7e00,2403000. VCN MMIO and RSMU management frame 0900c000 are separate address spaces.
- Domain C frame offsets: +004/+008 resets; +784/+790 PGFSM; +234 security; +910/+914 master masks; +920..a50 aperture descriptors.
- RN/CZN domain C grants eight ranges: 21800..218ff,20300..206ff,1f844..1f84f,20180..20183,20108..20117,21078..2107f,20eb0..20eb7,1f860..1f863.
- SD grants three ranges: 1f82c..1f833,20470..2086f,219d0..21acf.
- BC250 t24 has zero aperture rows whose target falls in 1e000..23000; reported direct preloads are 1f8a4=0b and 1f820=00185103. Report says domain C is absent from t24/t45. Full decoded inventory and parser semantics need review.
- Other gates named: DF fabric-present 50d6c[12:11], DF ACL domains 096..09d (reported 69–71 rows each), SMU dom6 6d0a0=00082100, internal register filter, harvest latch, usage-6 key lookup. Register sample is reported; source and timing are missing.
- Report identifies 0900c004 as RSMU_COLD_RESETB_VCN and states value 0 holds the whole IP in reset. It attributes all-ones reads to reset and distinguishes policy omission from writability/fuses.
- Report proposes VCPU, PSP SVC7c and DPG/LMA paths as paths outside the RSMU aperture filter. Bypass scope and address translation are not demonstrated by the excerpt.

## Alignment with saved evidence

Discovery geometry, harvest MMIO candidate 1f81c and LMA offsets 1f844/848/84c align with saved reference-header work. Cold-reset field naming and RSMU aperture counts are new community claims. Saved analysis previously left 0900c004 and 1f8a4 field meanings unresolved.

Saved type-13 completion traces a conditional SVC7c write of 1 to 0900c004 after loader success, then a write of 1 to 1f8a4. This gives a concrete possible coupling between firmware acceptance and reset release if the field identification is independently confirmed. Those SVC statuses are not rigorously checked. Restore/replay are separate writers. Missing policy rows therefore do not imply that no later writer exists.

Do not infer root power readiness from one dom6 value, reset from all-ones reads alone, unrestricted filter bypass from a store instruction, or hardware acceptance from an offline KDB fixture. Keep reported t24 preload 0b separate from the saved later t28 value 1; register bit semantics and stage ordering must be recovered.

## Required validation

1. Hash-pin BC250 and RN/CZN/SD input objects; publish bounded t24/t45 decode and every aperture target range, including overlapping ranges and computed mechanisms.
2. Supply authoritative or independently reconstructed field definitions and verified address-space translation.
3. Correlate same-boot cold-reset samples, actual PSP request/rejection, invocation or omission of the late write, status and VCN accessibility.
4. Validate each master/path's filter behavior separately; establish physical clocks/power independently.
