# Release 2.0.7.2 record

This reference describes the released package, verification evidence, and approved exception.

Salesforce confirmed version **2.0.7.2** (`04tak000000f7VNAAY`) as released on
September 3, 2026. No installation password is required.

- [Production installation](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tak000000f7VNAAY)
- [Sandbox installation](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tak000000f7VNAAY)

## Permission change

Run is the only packaged Custom Permission. Diagnostics requires a direct, active
assignment of the packaged Admin or Diagnostics Viewer Permission Set; an installation
profile grant alone does not authorize diagnostics. See [Custom Permissions](../reference/custom-permissions.md).

## Verification performed

- Local release preflight passed, including 258 JavaScript tests and 49 script tests.
- Full Apex validation passed in existing namespaced and no-namespace scratch orgs:
  1,117 and 1,116 tests respectively, with no failures.
- Salesforce package validation was not skipped. Package Apex coverage was 99% and
  Salesforce's coverage check passed.
- A fresh Admins Only installation contained exactly one RHC Custom Permission:
  `rhc__Record_Health_Check_Run`. The System Administrator profile received Run;
  installation created no direct RHC Permission Set assignments.
- All Users installation was not separately exercised for this candidate.

## Approved release exception

The owner explicitly approved a one-time, irreversible promotion despite missing
exact-source hosted validation and formal representative-sandbox acceptance evidence.
The build included uncommitted source changes based on commit
`94c286929000c74df7053321df8a2925df4e3b5d`; it was not created from an exact hosted
validation commit. The tracked build patch SHA-256 was
`b95becabcbc996a4888966431e4f09fa0f747da0a0dd16d2fc1672c417b81663`.

This exception does not change the normal release gates and must not be represented
as missing checks passing. Public distribution configuration and Cloudflare redirects
were not updated by the promotion operation.

## Unresolved intermittent report

The owner reported the entire Risk card missing after a hard refresh when Guide ran
on page load and Risk was on demand, with no component visibility filters. A later
refresh restored both cards. The issue subsequently stopped reproducing for the owner.

Two isolated, mocked multi-card diagnostic tests retained both card frames with
delayed manual initialization, reversed placement order, and reconnecting the manual
card. They did not reproduce or explain the affected Salesforce page behavior.
The cause remains unknown; this is not a fixed issue or a passed hard-refresh regression.
Future browser validation should cover the exact Guide-on-load/Risk-on-demand pairing
and cold reload, not only the existing manual Guide/small automatic fixture and
save/navigation checks.

## Related

- [Manual release-owner checklist](./manual-release-owner-checklist.md)
- [Release runtime matrix](./release-runtime-matrix.md)
- [Permission Sets](../reference/permission-sets.md)
