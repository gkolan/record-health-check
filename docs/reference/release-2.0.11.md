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
  their evidence contract. Comparison headings consistently read **Found / Expected**, and explicit
  Custom Metadata Value Format takes precedence over plugin formats while preserving plugin currency.

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

## Promoted package and validation

**2.0.11.4** was created from `5905f999dfee391bd4ff029611023f157e60e8ee` on October 6, 2026,
with package validation enabled. After the owner authorized promotion and both runtime validations
passed, Salesforce confirmed the version is released with 97% package coverage. Its immutable ID
and direct Production and Sandbox installation URLs are recorded in the
[release registry](../../config/package-releases.json). The owner’s public redirect update remains
pending; use the registry’s direct destinations for this package.

Both retained no-namespace subscriber orgs completed clean installation and upgrade from exact
base **2.0.10.1**. Every phase passed the four-class subscriber Apex inventory:

| Runtime | Phase         | Exact Apex run  | Business test methods |
| ------- | ------------- | --------------- | --------------------: |
| LWS     | Clean install | 707cU00000t1Msw |                    22 |
| LWS     | Upgrade       | 707cU00000t1TPZ |                    22 |
| Locker  | Clean install | 707Ru00002FQ9DC |                    22 |
| Locker  | Upgrade       | 707Ru00002FQT9d |                    22 |

Each run also reconciled three setup methods separately. Both upgrades preserved every field of
four subscriber Check Sets and 12 Checks, verified the hidden/manual configuration error and its
recovery, and passed live MCP requests and all 204 expected demo outcomes. All 50 packaged Example
Checks have null categories. Chromium and Firefox passed card rendering, fresh save-driven
refresh, navigation, configuration reread, App Builder and restricted Card User validation in
both security modes; each final browser process exited zero with ten passing reports and no
skipped or flaky tests.

LWS’s combined clean-install/upgrade verifier exited zero. Locker’s original processes stopped at
a Firefox Salesforce wire-refresh error; their successful earlier boundaries remain phase evidence,
not complete passing verifier processes. The browser test had allowed navigation while a save-driven
refresh was still running, because old completed totals satisfied its assertion. The corrected
verification waits for all 29 fresh evaluation responses from the populated cards before navigating,
retains strict page-error assertions, and passed the complete browser gate in both modes. Locker’s
remaining demo and final package-inventory checks passed independently. The source guard fails when
the fresh-response wait is removed. See the
[browser lessons](../quality-gates/agent-lessons.md#lesson-9-browser-prerequisites-and-failures-must-be-classified-accurately).

All 41 local release/source gates passed, including 406 Jest and 291 script tests. Required GitHub
CI passed on verification commit `768cbedd759a73dada9e6d28c3331d21b2c23932`, including both
Code Analyzer security scans. Verification-tooling changes do not alter the packaged source;
promotion ran from the exact creation commit with its immutable creation receipt and full preflight.
No new scratch org was created. Direct namespaced source-org and optional hosted Salesforce
validation remain separate, unexecuted evidence; package creation ran the packaged Apex tests.

The separately distributed MCP container initially failed its high-severity artifact scan and was
not published. Follow-up container work refreshes the pinned Debian runtime to fix the High
OpenSSL findings, preserves scan reports on failure, and replaces stale exceptions with reviewed
package/version/unfixed-state dispositions. The High/Critical failure threshold remains enabled;
new native reachability checks run against the built image before scanning. See the
[MCP operations review](../../packages/record-health-check-mcp/OPERATIONS.md#container-vulnerability-dispositions).
This container work does not change the immutable Salesforce package source or installation URLs;
container build/scan evidence remains distinct from installed-package validation.

## Earlier candidates

**2.0.11.3 must not be promoted.** It replaced plugin currency under explicit formatting and retained
populated categories on 25 packaged examples. Subscriber run `707cU00000sxsOW` reproduced the
currency defect against installed 2.0.11.3, preserving PASS/FAIL verdicts but returning null Found
currency instead of EUR. After upgrading to 2.0.11.4, `707cU00000sytFY` passed all 22 business methods
plus three setup methods, including the currency assertions. The promoted version includes both
corrections and their guards. The earlier 2.0.11.2 candidate also predates the fixed comparison
headings and explicit-format precedence corrections.

The separately distributed MCP server preserves `AUTHORIZATION` when Salesforce rejects a caller
before parsing the request body, retains the correlation ID, and does not retry the denied request.
Package creation records the exact Salesforce request and supports resuming interrupted attempts
without resubmission; see the [release runbook](../../.github/RELEASING.md).

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

The historical 2.0.11.1 version remains unpromoted. Its ID and installed results are immutable
evidence for that earlier candidate; the current promoted package is 2.0.11.4.

## Related

- [Upgrade and revalidate an installation](../install/upgrade.md)
- [Check Set field reference](./custom-metadata/check-set-fields.md)
- [Version 2.0.10](./release-2.0.10.md)
