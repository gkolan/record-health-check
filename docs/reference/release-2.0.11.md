# Version 2.0.11

Version 2.0.11 is a corrective patch for the card-heading controls introduced in 2.0.10. It does
not restore a second body-level Run action. Instead, it prevents an administrator from saving or
running a configuration whose only manual Run action is unreachable.

## Corrected behavior

- A Check Set with **Card Heading Display = Hide** and **Card Run Mode = Run on request** is invalid.
- The setup error names **Card Heading Display**, explains both supported remedies, and can be
  retried after correction without reloading the record page.
- Unexpected controller failures are redacted for ordinary users while authorized diagnostics
  users retain actionable details.
- Warning-only metadata findings remain visible without replacing valid evaluation results.
- The record-page card keeps the verdict, message, Found/Expected comparison, and remediation, but
  removes structured evidence summaries, Show details, Show all, evidence tables, and downloads.
  The card-specific JSON response no longer transmits evidence rows; typed evaluation APIs retain
  their evidence contract. Candidate 2.0.11.2 includes the evidence-viewer removal; the fixed comparison headings described below are subsequent source work.

## Upgrade action from 2.0.10.1

Run the compatibility audit before installing 2.0.11:

```bash
npm run audit:upgrade-2.0.11 -- --target-org <validation-org>
```

For each finding, make one of these changes:

1. Set **Card Heading Display** to **Show**, retaining manual Run/Rerun.
2. Set **Card Run Mode** to **Run when the page opens**, retaining the hidden heading.

Rerun the audit until it reports zero findings, then upgrade a representative sandbox. The audit
checks subscriber-owned Check Sets whether active or inactive so a later activation cannot
reintroduce an unreachable action.

## Current release preparation

Candidate **2.0.11.2**, whose ID is recorded in the [package project aliases](../../packages/record-health-check/sfdx-project.json), was created from `f988334` with
97% package coverage and installed in the retained LWS test org for owner testing. It is unpromoted.
That installation and its timing samples do not establish Locker, clean-install/upgrade, restricted
persona, or the complete browser/API release matrix.

The configured replacement candidate is **2.0.11.3**, pending creation. Its source adds fixed
**Found / Expected** card headings and gives explicit Custom Metadata Value Format precedence over
plugin formats. Automatic retains plugin formatting. Neither change is in 2.0.11.2. The stable
public installer continues to select 2.0.10.1 until an owner promotes and publishes a replacement.
Fresh package-build, installed-package and browser evidence must identify the replacement candidate.

The separately distributed MCP server now preserves `AUTHORIZATION` when Salesforce rejects a
caller before parsing the request body. It retains the caller's correlation ID and does not retry
the denied request. Package creation now records the exact Salesforce request and supports resuming
interrupted attempts without resubmission; see the [release runbook](../../.github/RELEASING.md).

## Regression and installed-package evidence

The source suite includes paired PASS/FAIL Check and Check Set fixtures for all heading modes,
server-side metadata validation tests, LWC retry and diagnostics tests, and browser fixtures. The
2.0.11 upgrade rehearsal additionally deploys a subscriber-owned 2.0.10.1 hidden/manual fixture,
proves the upgrade preserves it, verifies the exact `INVALID_CONFIG` result, applies the documented
recovery, and proves the preserved Check evaluates to `PASS` afterward.

Candidate `2.0.11.1`, whose immutable ID is recorded in the
[package project aliases](../../packages/record-health-check/sfdx-project.json), was created from
commit `b793c70` and installed by upgrading the retained no-namespace subscriber org from exact base
`2.0.10.1`. The rehearsal recorded all of the following:

- the audit found the one deliberately incompatible subscriber Check Set before upgrade and zero
  findings after the documented correction;
- all three subscriber-owned Check Sets and six subscriber-owned Checks retained their field values;
- the preserved hidden/manual configuration returned exact `INVALID_CONFIG`, and its corrected
  hidden/on-load form evaluated to `PASS`;
- the exact subscriber Apex inventory passed 3 classes and 17 test methods;
- live MCP `RUN_CHECK` and `RUN_CHECK_SET` requests passed;
- the installed card, rerun/reread contract, App Builder preview, and restricted Card User persona
  passed in Chromium and Firefox under Lightning Web Security; and
- the deterministic subscriber dataset produced all 204 expected Check results.

This package version is an unpromoted release candidate. Its ID and installed results are immutable
candidate evidence, not a claim that 2.0.11 is promoted or generally available.

## Related

- [Upgrade and revalidate an installation](../install/upgrade.md)
- [Check Set field reference](./custom-metadata/check-set-fields.md)
- [Version 2.0.10](./release-2.0.10.md)
