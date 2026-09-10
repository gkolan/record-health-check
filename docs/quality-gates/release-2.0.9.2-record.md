# Release 2.0.9.2 record

This reference records the promoted package, verification evidence, and release-owner decision for
Record Health Check 2.0.9.2.

Salesforce confirmed version **2.0.9.2** (`04tak000000gX9FAAU`) as released on September 9, 2026.
No installation password is required.

- [Production installation](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000gX9FAAU)
- [Sandbox installation](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000gX9FAAU)

## Release contents

- Custom Apex Check loading uses a guarded interface cast after constructor side-effect checks and
  preserves exact missing, load, constructor, interface, and parameter reason codes.
- AI drafting guidance emits deployable Formula Result Type metadata and rejects `N/A` as a stored
  restricted-picklist value.
- All packaged examples are portable to an ordinary org and ship with diagnostics and event
  publication disabled.
- The Advanced Approvals inactive-approver example is no longer part of the public example library.
- Executable release gates prevent diagnostic or event publication from being enabled on packaged
  examples and retain the Apex plugin boundary regression checks.

## Verification performed

- The exact creation commit was `407dfe6f31c6281d4771b56db36978e89144b410`.
- All 41 tracked-source CI gates and the guarded local release preflight passed.
- The complete namespaced source run passed 1,257 Apex test methods and 44 setup methods with no
  failures. Production-source coverage was 99.60% (11,826 of 11,874 executable lines).
- Salesforce package validation was not skipped. Package coverage was 99%, and Salesforce's
  coverage check passed.
- Clean installation of the exact candidate succeeded in retained LWS and Locker subscriber orgs.
- Locker subscriber test run `707E200002AydMm` proved a namespace-free subscriber implementation of
  `rhc.RecordHealthCheckPlugin` was constructed and evaluated once and returned the expected PASS,
  FAIL, SKIPPED, and UNABLE_TO_EVALUATE outcomes. Subscriber plugin coverage was 100%.
- A real foreign managed namespace was exercised with DLRS 2.25. Its incompatible global class
  resolved and returned `PLUGIN_INTERFACE_INVALID`, rather than being mislabeled as a missing class
  or constructor failure.
- The release owner reviewed and approved the 2.0.9 documentation and separately confirmed the
  originally reported subscriber plugin scenario works correctly.

## Approved release exception

The release owner explicitly approved promotion after the installed subscriber-plugin test passed.
The retained Locker browser lifecycle test could not find Salesforce's Edit dialog, so that run did
not continue through reset and the exact 2.0.8.1-to-2.0.9.2 upgrade. The hosted LWS run had earlier
stopped on a subscriber-only FlexiPage field that was corrected after package creation; that field
is not part of the promoted package.

These incomplete automation stages are not represented as passing. The package artifact itself is
immutable, and the later corrections affect release tooling and subscriber verification fixtures,
not the contents of `04tak000000gX9FAAU`.

## Retained release orgs

The 2.0.9 LWS and Locker subscriber orgs were created on September 9, 2026, and expire on October 9,
2026. They are retained under the rolling two-release policy and must be reused rather than replaced
during any follow-up 2.0.9 verification.

## Related

- [Subscriber Apex plugin compatibility evidence](../contributing/subscriber-apex-plugin-compatibility-evidence.md)
- [Manual release-owner checklist](./manual-release-owner-checklist.md)
- [Release runtime matrix](./release-runtime-matrix.md)
- [Scratch org lifecycle](./scratch-org-lifecycle.md)
