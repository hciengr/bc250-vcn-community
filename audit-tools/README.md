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
