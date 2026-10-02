# Evidence admission and worker synchronization

A submission is a proposal. It is not verified because an AI agrees, a model generated a plausible trace, or a contributor wrote “accepted”. Verification means independent reproduction of a precisely scoped result, with linked evidence and an accountable human reviewer.

## Existing findings

Seeded claims are historical source findings, not newly independently reviewed community results. Their exact statements are frozen in `legacy-claims.json` so a contribution cannot expand them while retaining seeded status. The eleven previously green, pending findings C32–C42 now remain orange until independently verified. Their evidence remains available. An unresolved claim keeps its stage orange.

## Admission requirements

An accepted claim or task attempt must reference a record in `data.json.verifications`. Records include separate author/reviewer human GitHub identities, precise scope and evidence kind, method, expected/actual results, controls, limitations, input environment, bundled raw artifacts with SHA-256 hashes, and the independent reproduction's method/results/artifacts. Hardware observations also need board identity, boot ID, BIOS/firmware hashes, kernel, timestamps and address space. Static, model, cryptographic and physical observations cannot substitute for one another.

A verification record uses the following fields:

```json
{
  "id": "V-example",
  "supports": ["C32", "T23"],
  "task_criteria": {"T23": "Exactly the task completion criterion"},
  "author_principal": "author-github-login",
  "reviewer_principal": "independent-reviewer-login",
  "kind": "static",
  "scope": "Exactly the claim's scope",
  "method": "Bounded procedure and input identities",
  "expected": "Predicted result",
  "actual": "Observed result",
  "controls": "Negative/positive controls and their outputs",
  "limitations": "Remaining uncertainty",
  "environment": {"inputs": "Revisions and hashes"},
  "artifacts": [{"path": "evidence/result.txt", "sha256": "64 lowercase hex digits"}],
  "independent_reproduction": {
    "principal": "independent-reviewer-login",
    "method": "Separate reproduction procedure",
    "actual": "Observed result",
    "artifacts": [{"path": "evidence/reproduction.txt", "sha256": "64 lowercase hex digits"}]
  },
  "review_url": "https://github.com/OWNER/REPO/pull/NUMBER#pullrequestreview-ID"
}
```

This is a field example, not an accepted verification. The validator checks record structure, matching scope/type, distinct human principals and actual artifact hashes. CI additionally checks the declared reviewer against the maintainer's trusted list and the real GitHub review, plus a current-HEAD approval. The trusted checker is read from the PR base, so changing its copy in a submission cannot bypass it. Governance changes require a separate maintainer-controlled update.

An AI reviewer belonging to the same human as the author is not independent. Reviewers must actually rerun or inspect the bounded evidence and retain their outputs; copying the submitter's conclusion is not reproduction. Hashes identify bytes; they do not prove a physical capture truthful. Trusted review reduces that risk but cannot eliminate collusion or fabricated observations.

## Connect a worker

1. Clone the community repository. Read AGENTS.md and select an available task. Download its task packet from the work board, or refresh a pinned snapshot using:

   ```sh
   ruby sync_worker.rb T23 my-worker my-github-login /tmp/vcn-T23-snapshot-001
   ```

   This fetches `origin/main` and copies the task plus hash-checked sources from one exact commit. It does not execute downloaded programs or alter shared ownership. Use a new output directory per sync to preserve old snapshots.
2. Open a worker-link issue recording the human coordinator, worker ID, task ID and source commit. Check existing claims and coordinate a bounded plan and expiry. Feed the task.json, AGENTS.md and sources to the worker you operate. Do not submit API keys or login tokens.
3. Include worker ID, human principal, source commit and ledger SHA-256 with the result. The human remains accountable for its claims.
4. A different human can assign their own worker to reproduce the result against the same snapshot. Capture separate output artifacts. Submit the verification record and request review from a trusted reviewer. If adding the review URL changes HEAD, the reviewer must approve that final revision too.
5. A maintainer merges only after both required checks and independent approval pass. Refresh your snapshot before the next task; an old packet does not describe current ownership.

## Required launch configuration

The site is authorized for public contribution in `proposals-only` mode. `review-policy.json` deliberately has no trusted reviewers; new verification approvals remain blocked. Public access to the map does not approve its submissions. Configure accountable reviewer usernames before accepting verifications. In GitHub, require PRs, the Evidence structure and Independent verification checks, current-branch checks, stale-approval dismissal, approval of the latest push, resolved review conversations and no bypass/force pushes. Protect governance files with designated code owners. Verify these settings in the actual repository before deployment; local files alone do not configure GitHub security.

GitHub documentation: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches

Keep counterevidence and rejected attempts visible. New verification records supersede previous records rather than silently rewriting their artifacts. Suspend an accepted claim when a reproducible contradiction appears; let reviewers resolve it with a narrower scope or a discriminating test.
