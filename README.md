# BC250 VCN community lab

A visual research project for connecting firmware authentication, platform access and VCN execution. The two-column map follows the existing VCN dependency diagram. Select a stage to inspect claim IDs, scope, source notes and tasks. The work board matches skills to ready, unowned tasks and exposes dependencies, shared ownership and completion criteria.

## Open

Open `index.html` for the simple starting page or `map.html` for the detailed evidence map. It has no external dependencies, analytics or network calls. A static web host can serve the same directory. `data.json` is the canonical shared state; `assets/data.js` is generated for file-based browsing.

```sh
ruby build.rb
```

The builder validates IDs, references, sources, dependency cycles and ownership/completion fields, then generates the browser data and source SHA-256 manifest. Source notes are bundled as immutable snapshots with original paths. Their relative links may refer to artifacts in the larger BC250 workspace; a bundled note is not a bundle of every underlying binary or log.

Evidence baseline: saved findings through 2026-09-29, the user-supplied domain-C report, and reproducible static audits on 2026-10-01. The latest audits check complete stored P3/SD policies, final load-error gating of completion writes, header retries and the staging-producer boundary. They are bundled under `evidence/exports/vcn-priority-audit/`; reproduction scripts are in `audit-tools/`. This is not a complete inventory of all Discord work. No Discord history was scraped. New community outcomes must be submitted and reviewed, including any hardware progress beyond this baseline.

## Colors and proof

- Green: the precise claim is established within its stated scope. A static instruction path can be green without any live execution.
- Orange: pertinent information exists, but the result or causal connection is unresolved.
- Red: no established result for the named outcome in this evidence baseline. Known test criteria do not constitute a ready/ring/media observation.

Every claim has a separate evidence kind: static, model, offline-crypto, hardware or community-report. Review status is separate from proof status. Seeded green claims cite prior project findings; community reviewer lists start empty. Hardware execution has not been established by the seeded records.

## Coordinate

Read `CONTRIBUTING.md`. Use issue templates or submit JSON/Markdown drafts. Local browser drafts do not reserve tasks for everyone. Shared ownership begins when the maintainer accepts a claim and updates `data.json`, ideally through a repository issue/PR. Keep one primary owner, an expiry/handoff date, exact scope and an independent reviewer for each active task. Explicitly mark useful independent reproduction rather than silently duplicating an investigation.

Priority is maintained by reviewers. The dashboard sorts ready unowned tasks by priority, then direct downstream dependency count. It does not measure impact or promise that one gate is the only blocker. New domain-C evidence adds high-priority table-coverage and reset/authentication-coupling audits.

Tasks with status `review` have a result awaiting independent review and are excluded from ready investigation recommendations. Use independent validation on those tasks. The initial P3/SD policy-coverage audit is in this state; RN/CZN comparison and independent review remain open in T16.

## Discord import

Export the authorized channel in JSON (DiscordChatExporter-style `guild`, `channel`, `messages`). Run:

```sh
ruby import_discord.rb /path/to/channel-export.json
```

The importer checks the target channel, retains message/author IDs, timestamps, edits, reply references, attachment URLs, export hash and permalinks, and skips duplicate message IDs. It does not log in, retrieve tokens, download attachment binaries, send messages or promote reports to proven claims. Reconcile edits to existing messages in a reviewed update; the deduplicating importer preserves the already-imported version. HTML exports can be reviewed manually but are not parsed by this importer. Review channel sharing permission before publishing message text and handles; an authorized read is distinct from redistributing the channel history.

## Publish as a community project

Public launch instructions are in `PUBLISHING.md`. `ruby package_public.rb` creates a static `_site` artifact; `.github/workflows/pages.yml` publishes it from a standalone repository. Each work card provides a downloadable AI task packet, and a shared issue link when `repository_url` is configured. All packets are also available in `agent-tasks.json`; `AGENTS.md` defines worker evidence and review requirements.

This directory is ready to become its own repository. Initialize Git here, choose a repository destination, and push it. Enable static hosting for the project root if desired. Configure `repository_url` in `data.json`, rebuild, and direct contributors to repository issues/PRs. The issue templates and workflow are included; the source repository is configured under hciengr and GitHub Actions records website deployment status.

The package includes project notes, the candidate metadata and public evidence references, not proprietary firmware images or a flash/write tool. A license has deliberately not been assigned to existing material; choose one after establishing rights to the content you intend to distribute.

## Files

- `index.html`: focused contributor starting page.
- `map.html`, `assets/`: detailed evidence map and guided submission forms.
- `data.json`: canonical claims, stages, tasks, dependency graph and reviewed report inbox.
- `build.rb`: validation, browser-data generation and evidence manifest.
- `import_discord.rb`: offline channel export ingestion.
- `evidence/`: source-note snapshots and reported community findings.
- `submissions/`: place reviewed contribution records here and reference them from claims/attempts.
- `.github/`: issue/PR templates and build validation workflow.

`seed.rb` records the initial source inventory and seed generation. Do not run it on an updated project: it resets canonical data to the original seed and would discard accepted updates. Ordinary builds use only `build.rb`.

## Keep current with Shalasere

`ruby sync_upstream.rb` fetches the public repository HEAD, records its commit and Git blob inventory, saves research Markdown snapshots under `upstream/snapshots/<commit>/`, and creates one pending change report per new revision. Deleted paths are recorded too. The binary identity is SHA-256 checked without executing it. `ruby sync_upstream.rb --offline` refreshes from cached HEAD without network access.

The dashboard displays checked revision and pending-review count separately from the evidence baseline. Review `research/CORRECTIONS_2026_09_30.md` alongside the September 30 summary; earlier README conclusions are historical. Initial reconciliation is in `evidence/shalasere-upstream-2026-10-01.md`. Upstream Markdown retains its source attribution and GPL license in `upstream/LICENSE`; snapshots are source material, not automatically accepted findings.

On this workstation, `bc250-vcn-upstream.timer` is enabled for daily refresh with up to 15 minutes jitter and catch-up after inactivity. It runs while the user service manager is available; this is not an always-on hosted service. Check it with `systemctl --user list-timers bc250-vcn-upstream.timer` and inspect results with `journalctl --user -u bc250-vcn-upstream.service`. Refresh now with `systemctl --user start bc250-vcn-upstream.service`; stop automatic refresh with `systemctl --user disable --now bc250-vcn-upstream.timer`. Reload the dashboard to see the updated status.

Portable unit templates are in `automation/`; adapt their absolute paths on another machine. The timer only fetches public research and writes local tracking files. It never runs downloaded scripts, contacts research boards, changes canonical claims/ownership, flashes firmware, or posts externally. Do not commit or distribute `upstream/cache.git` or `upstream/sync.lock`.

For each pending `upstream/<commit>.json`, inspect changed paths against the previous snapshot, reconcile contradictions using dated corrections and raw evidence, add attributed pending claims/tasks, then obtain independent review before changing proof status. Set the revision report status to `reviewed` only after that reconciliation. Run the updater and `ruby build.rb` afterward. Automatic tracking and completed evidence review are separate states.

## Verification gate

Read VERIFICATION.md before public launch. New accepted claims and completed tasks require structured, independently reproduced evidence; CI checks actual trusted GitHub review identities. Pending static findings C32–C42 are orange until that review. Historical seeded claims are frozen source findings, not independently reviewed community approvals. `sync_worker.rb` links a worker/human identity to one exact repository snapshot and hash-checks its evidence. Public hosting is authorized in proposals-only mode; acceptance of new verified findings remains blocked until trusted reviewers are configured.

## Guided contributions

Use Submit evidence for a short form that prepares a GitHub issue with the finding, artifact link or attachment reminder, evidence type and ledger identity. Reproduction details can be added before posting or during triage; incomplete intake is never verified automatically. The review handoff clearly distinguishes a draft from a posted issue and provides a copy fallback for long submissions.

Use Link my AI worker to choose a task, identify its human coordinator, copy task-specific instructions, download its snapshot packet and prepare a worker registration issue. Check existing issues before starting. The site supplies instructions and coordination records; contributors run their own AI workers. No API credentials are requested.

## Community contributors

- [daveconde](https://github.com/daveconde): [bc250-vcn-enable](https://github.com/daveconde/bc250-vcn-enable), VCN enablement tooling and investigation.
- [rw-r-r-0644](https://github.com/rw-r-r-0644): [bc250-smu-unlock](https://github.com/rw-r-r-0644/bc250-smu-unlock), BC250 SMU access and unlock tooling.

- [Shalasere](https://github.com/Shalasere): [bc250-vcn-research](https://github.com/Shalasere/bc250-vcn-research), BC250 VCN research, experiments and documentation.

These contributors are recognized as confirmed by hciengr. These links credit their respective projects; individual results retain their own evidence scope and review requirements.
