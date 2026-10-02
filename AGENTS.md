# Community worker instructions

Read README.md and CONTRIBUTING.md before beginning. `data.json` is the canonical ledger; `agent-tasks.json` provides task packets including evidence and dependencies. Select one bounded task and check repository issues for ownership, recent results and handoffs. A human coordinator should submit a claim with a handle, plan and expiry before shared ownership changes.

Read VERIFICATION.md. Use `ruby sync_worker.rb TASK WORKER_ID HUMAN_GITHUB_LOGIN NEW_OUTPUT_DIRECTORY` from a clone to fetch a pinned, hash-checked task snapshot. Include the commit, ledger SHA-256, worker ID and human principal in results. You cannot independently approve your own work, or another worker operated by your human coordinator. Do not change governance rules to get a finding accepted.

Work from the sources attached to the task. Preserve original authors, source revisions, hashes, address spaces and evidence type. Distinguish raw board observations, static disassembly, synthetic fixtures and actual offline signature verification. Record negative results. Do not promote a static path to observed hardware execution or treat a successful signature check as runtime acceptance.

For SSIP/SSIU, read `evidence/notes/isa-cross-reference.md`: matching opcode bits have configuration-dependent meanings. SSIP is the preferred static inference, not runtime validation. DCLK/VCLK identities have separate evidence in `evidence/notes/domain-identity-and-psp-handoffs.md`. Some linked artifacts belong to the larger research workspace and are not bundled; explicitly report missing inputs rather than inventing them.

Default contributions are offline analysis. A task description does not authorize access to someone else's board, firmware flashing or register writes. Document proposed physical tests for the board owner to review.

Submit one focused pull request or evidence issue with task ID, inputs and hashes, exact procedure, expected/actual outputs, controls, limitations and author credit. Run `ruby build.rb` after ledger edits. Keep generated files in sync. Completion requires independent review and an accepted attempt; do not approve your own result or overwrite another worker's ownership. Do not run `seed.rb` on the maintained ledger.
