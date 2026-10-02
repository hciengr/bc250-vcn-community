# Reproducing the 2026-10-01 static audits

These scripts are included for peer review. The data audit scripts expect the larger BC250 workspace inputs at their recorded relative paths, not only the standalone dashboard directory. They read public/source firmware artifacts but no firmware binaries are distributed here. Obtain the exact inputs from their provenance and verify the pinned SHA-256 values.

From the BC250 workspace root:

```sh
ruby tools/audit-vcn-policy-coverage.rb
ruby tools/test-vcn-policy-coverage.rb
ruby tools/audit-vcn-load-reset-gate.rb
ruby tools/audit-vcn-staging-candidates.rb
```

Equivalent copies are in this directory. The policy fixture tests can run standalone with `ruby test-vcn-policy-coverage.rb` because they construct their own inputs and require the sibling auditor without invoking its ROM scan.

Read the included evidence note for results, limits and expected artifacts. The load/reset auditor also requires the fresh function export listed in the report. A Ghidra refresh uses read-only processing of the existing mapped t28 project; no firmware patch is required.

Review requested: independent interpretation of complete policy rows and descriptor geometry, an RN/CZN comparison with source provenance, and independent load/reset branch validation. Fixture models must remain labeled as models. No static audit establishes cold-reset hardware field identity or live execution.

## Check full-suite prerequisites first

T23's fresh reproduction report is in `submissions/t23-reproduction-2026-10-02.md`. Run `ruby audit-tools/check-suite-inputs.rb .` from a community clone to inventory the historical suite's script hashes and six recorded core inputs without executing auditors. Exit 1 means at least one recorded prerequisite or the runner is missing/changed. Exit 0 only confirms this minimum inventory; additional firmware, reference headers and saved exports remain necessary. Run `ruby audit-tools/test-suite-inputs.rb` for the preflight's five synthetic controls.
