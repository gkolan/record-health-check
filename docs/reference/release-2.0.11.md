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

The configured next candidate is **2.0.11.4**. It keeps a plugin-declared currency code when an
explicit Display: Value Format is configured. 2.0.11.3 replaced that code with the viewing user's
currency for Found, and for Expected when no Expected currency was configured. The subscriber
regression `RHCSubscriberFormatTest` reproduced this against installed 2.0.11.3 in the retained LWS
org: run `707cU00000sxsOW` kept the PASS and FAIL verdicts but returned a `null` Found currency instead
of `EUR`. Do not promote 2.0.11.3. The 2.0.11.3 results below remain evidence for that candidate
only.

Candidate **2.0.11.4** (`04tak000000nGjZAAU`) was created from
`5905f999dfee391bd4ff029611023f157e60e8ee` on October 6, 2026. Salesforce reports 97% package
coverage, validation enabled, and an unpromoted version. After upgrading the retained LWS org from
2.0.11.3, run `707cU00000sytFY` passed all 25 subscriber test methods, including the three currency
assertions that failed on 2.0.11.3. Clean installation, the 2.0.10.1 upgrade, Locker, browser,
restricted-user, MCP and demo-outcome validation of 2.0.11.4 are pending.

Candidate **2.0.11.3**, whose immutable ID is recorded in the
[package project aliases](../../packages/record-health-check/sfdx-project.json), was created from
`3f68a358ad4365813cbebe9b71d0b9cec6420e0b` on October 6, 2026. Salesforce reports 97% package
coverage, validation enabled, and an unpromoted version.

The candidate fixes **Found / Expected** card headings and gives explicit Custom Metadata Value
Format precedence over plugin formats. Automatic retains plugin formatting and structured
comparison content. The earlier 2.0.11.2 candidate predates both fixes. The stable public installer
continues to select 2.0.10.1 until an owner promotes and publishes a replacement.

Subsequent source work clears categories on all packaged example Checks and adds a CI/package
preflight guard against restoring them. **2.0.11.3 does not contain this correction and must not be
promoted as the final candidate.** A replacement build and its installed-package verification remain
pending the release owner’s decision.

The retained LWS and Locker subscriber orgs each completed clean installation and upgrade from
exact base 2.0.10.1. Every phase passed all 20 subscriber Apex test methods across four classes,
live MCP, and Chromium/Firefox card, rerun, App Builder and restricted Card User scenarios. The
installed activity row explicitly showed **Found / Expected**. Each upgrade preserved all four
subscriber Check Sets and ten Checks, passed compatibility recovery, and verified 204 expected
demo outcomes. Both end-to-end verifier processes exited successfully.

| Runtime | Phase         | Exact Apex run  | Business test methods |
| ------- | ------------- | --------------- | --------------------: |
| LWS     | Clean install | 707cU00000sxcL8 |                    20 |
| LWS     | Upgrade       | 707cU00000sy05T |                    20 |
| Locker  | Clean install | 707Ru00002FLY7s |                    20 |
| Locker  | Upgrade       | 707Ru00002FLY1g |                    20 |

Three setup methods are reconciled separately in each Salesforce result; they are not counted
as business tests. The comparison-format regression first failed against 2.0.11.2 with Expected
75% / Actual 0.75, then passed alone and in its mixed Set against the new candidate in both modes.
All 41 source gates passed, and both Code Analyzer security reports contained zero violations
with no engine processing errors.

No new scratch org was created. No suitable namespaced source org was available, so the new
packaged Apex tests ran through package creation; direct source-org and optional hosted source
validation remain distinct, unexecuted evidence. The installed-package matrix above used only
the retained subscriber pair. The verifier's live reset, metadata retrieval and maintenance-login
corrections are recorded in the [release runbook](../../.github/RELEASING.md) and
[browser lessons](../quality-gates/agent-lessons.md#lesson-9-browser-prerequisites-and-failures-must-be-classified-accurately).

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
