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

## Regression and installed-package evidence

The source suite includes paired PASS/FAIL Check and Check Set fixtures for all heading modes,
server-side metadata validation tests, LWC retry and diagnostics tests, and browser fixtures. The
2.0.11 upgrade rehearsal additionally deploys a subscriber-owned 2.0.10.1 hidden/manual fixture,
proves the upgrade preserves it, verifies the exact `INVALID_CONFIG` result, applies the documented
recovery, and proves the preserved Check evaluates to `PASS` afterward.

The immutable package ID and final installed-package results are recorded only after a candidate is
created and verified; a locked source design is not package evidence.

## Related

- [Upgrade and revalidate an installation](../install/upgrade.md)
- [Check Set field reference](./custom-metadata/check-set-fields.md)
- [Version 2.0.10](./release-2.0.10.md)
