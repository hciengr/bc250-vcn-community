# Contributing

Read `VERIFICATION.md` for enforced evidence admission and AI worker synchronization. Worker outputs remain proposals until a different accountable human reproduces the result and a trusted reviewer approves it. Record worker ID, human GitHub principal, source commit and ledger SHA-256. Download task packets from the work board or run `sync_worker.rb` for a pinned, hash-checked snapshot.

1. Choose a task in the work board. Read its claims, dependencies, previous attempts and completion criterion.
2. Check its shared owner and linked issue before starting. Claim unowned work with a handle, bounded plan, input identities and planned handoff date. For claimed work, coordinate a handoff or explicitly propose independent validation. Browser drafts are local until accepted.
3. Preserve provenance: BIOS and firmware hashes; kernel revision/patches; board and boot; exact address space; instruction/table location; source message permalink; commands, expected and actual results. Hardware read validity and timing are part of the observation.
4. Submit the evidence, including negative controls, failed attempts and counterevidence. Cite artifacts rather than replacing them with a summary. Never label a modeled status as a captured hardware response.
5. An independent reviewer checks reproducibility and scope. Record that reviewer and the accepted submission. A finding can be proven statically while its runtime connection remains orange.
6. Close the task only when its stated criterion is met. Update the claim, source links, attempt history and downstream dependencies; release ownership or publish a handoff when work pauses.

## Shared updates

The dashboard is a static shared baseline with local draft creation. Export a draft and open an issue or PR in the chosen community repository. A maintainer updates canonical `data.json`, retains submission records under `submissions/`, runs `ruby build.rb` and publishes the rebuilt state. Two competing claims are resolved before assigning one primary owner. Claim expiry flags work for reassessment; it does not automatically transfer ownership.

For each task attempt record include: author, date, environment/input hashes, question, method, raw artifact links, result, limits, and review (`pending`, `accepted` or `rejected`). A `done` task requires an accepted attempt. A new hardware proof should include an independent reviewer and same-boot provenance.

Accepted attempts additionally require `author_principal` and `verification_id`. Accepted claims require `verification_id` and the reviewer's principal in `reviewers`. The referenced verification must support the exact claim scope and evidence type; for a task, its `task_criteria` entry must match that task's `done_when`. The builder rejects acceptance without these records. CI verifies real GitHub review identities from trusted base code; repository protection must enforce these checks before merge.

## Scope rules that matter here

- SSIP and SSIU share opcode bits. SSIP is the preferred static inference, not runtime validation.
- A missing image key ID, usage mismatch and signature failure are different branches.
- An extracted KDB fixture is not proven equal to a live KDB.
- RSMU domain C, PMFW row 6, DF ACL domains and VCN-local controls are distinct namespaces/mechanisms.
- A t24/t45 omission is not proof that all later writes are absent, that a field is fused or that a write is accepted.
- All-ones reads do not uniquely prove cold reset. One cached value does not prove physical power or clocks.
- Package CRC, valid signature, PSP acceptance, VCPU execution, ring execution and correct media output are separate milestones.

New claims from Discord stay pending until their underlying evidence is reviewed. Preserve conflicting results rather than deleting them; narrow their environments and state what experiment discriminates them.
