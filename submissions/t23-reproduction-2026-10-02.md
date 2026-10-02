# T23: suite reproduction and community-checkout readiness

Author/human coordinator: hciengr. Worker: codex-t23-reproduction.
Date: 2026-10-02 UTC. Review: pending. Claim proposal: https://github.com/hciengr/bc250-vcn-community/issues/2 .
This worker shares the coordinator of the earlier analysis. This is a fresh rerun and reproducibility investigation, not independent acceptance of the prior claims. No board was accessed; no firmware was patched.

## Findings

1. All sixteen selected offline auditors passed in the larger research workspace. Their script hashes, stdout and stderr are identical to the bundled baseline for each command. All six recorded core input hashes also match. This reproduces the earlier recorded outputs under the available local inputs; it does not supply independent scientific review.
2. The community checkout at main commit `444c2d857470031a4f1c0a4adf20b9e5f6b52af9` contains hash-identical equivalents of only three suite auditors: load_completion, access_policy and access_policy_controls. The other thirteen auditor scripts and the suite runner are absent. All six recorded core inputs are also absent.
3. The included policy fixture suite runs standalone and passes six controls: spanning intervals, other management frames, preload separation, reversed ranges, malformed sizes and section counts. These are generated-input parser controls, not policy execution or hardware observations.

The missing inputs are documented prerequisites, not evidence that the historical sixteen-command result was fabricated. The useful distinction is **a reproducible workspace result versus a self-contained public reproduction package**. T23's independent-review completion criterion remains unmet.

## Reproduction

From the community clone, inventory prerequisites without running an auditor:

```sh
ruby audit-tools/check-suite-inputs.rb .
```

Expected exit: 1 for this checkout. JSON identifies matched, missing or changed script/input hashes. Three auditor aliases match; thirteen are missing, six core inputs are missing, and the runner is absent.

The recorded six inputs are a minimum inventory, not every transitive prerequisite. For example, the authentication auditor additionally reads installed Navi10 firmware, SOS and a PEM, plus extracted BC250 key tables. Other auditors read reference headers, comparison firmware and saved Ghidra exports. A successful minimum preflight must not be presented as proof that these additional inputs exist.

The standalone fixture control is:

```sh
ruby audit-tools/test-vcn-policy-coverage.rb
```

For a complete research workspace with the original scripts and input identities:

```sh
ruby tools/run-vcn-contribution-checks.rb NEW_OUTPUT_DIRECTORY
```

The saved rerun used `exports/vcn-clamp-boundary/t23-rerun-2026-10-02-0512`. Keep output directories distinct. Some auditors refresh workspace reports; the runner separately preserves their stdout/stderr. Do not remove hash guards or replace missing inputs with unrelated firmware.

## Evidence and controls

The raw sixteen-command outputs, fresh manifest, worker snapshot, baseline comparison, community/workspace prerequisite inventories and standalone fixture outputs are bundled under `evidence/exports/t23-reproduction-2026-10-02/`.

The worker snapshot records the main commit, exact ledger SHA-256 and source-note hashes. The historical manifest records its actual generation timestamp; its directory name is retained as provenance, not used to infer when it ran.

`audit-tools/test-suite-inputs.rb` exercises five controls: missing prerequisites, matching minimums, changed input hash, changed auditor hash and an exact bundled alias. The preflight never executes downloaded code and explicitly reports that full-suite execution was not performed.

## Limits and next contributor action

The underlying static, synthetic and offline-crypto scopes remain as recorded by each auditor. Do not sum their assertions as independent hardware validations. Signature verification is not PSP acceptance; static completion branches are not accepted physical writes; SSIP remains preferred static inference, not runtime configuration validation.

A different human should obtain the exact inputs, reproduce the bounded checks and inspect their scope. To make the suite accessible to a fresh public clone, publish the missing auditor sources and a complete dependency/provenance inventory, with legitimate acquisition instructions for firmware and saved exports. Do not redistribute firmware or the Cadence reference merely to satisfy this task. Keep T23 open until independent review accepts the scoped result.

Credit: the existing project notes and audit authors; daveconde's bc250-vcn-enable, rw-r-r-0644's bc250-smu-unlock and Shalasere's bc250-vcn-research remain attributed sources of community work. This rerun establishes none of those authors' runtime results anew.
