# Contributor checks for Apex test-only access

> [!IMPORTANT]
> **Audience: package maintainers and Salesforce developers.** This class-level reference is not a
> Setup or Flow walkthrough. Administrators should use the Flow, configuration, and evaluation
> guides; subscriber developers should use the public Apex API or Apex Check contract.

> [!NOTE]
> Use this page when changing Apex in this repository. It explains when test-only access is allowed
> and what `npm run check:apex-architecture` enforces.

Use `@TestVisible` or `Test.isRunningTest()` only when a test cannot verify the behavior through a
normal method call or returned result. Existing uses are recorded as a maximum, not as permission to
add more.

The baseline file is
[`scripts/release/generated/apex-architecture-baseline.json`](../../../scripts/release/generated/apex-architecture-baseline.json).
Run this command after changing Apex:

```bash
npm run check:apex-architecture
```

The command scans Apex in `force-app` and `integration-tests`. It fails when a change:

- adds `@TestVisible` to an unapproved file or increases an approved file's count;
- adds a `Test.isRunningTest()` branch outside the two approved test-only branches;
- adds `System.debug` outside the structured logger or scratch-org exhaustive test class;
- takes an Apex class above the normal 500-line review ceiling without a named per-file ceiling in
  the baseline;
- places redundant `@TestVisible` on a public or global member; or
- introduces language implying private compatibility with an older implementation.

## Approved `@TestVisible` categories

| Category | Why it currently exists | Required direction |
| --- | --- | --- |
| Permission and setting override | A focused test cannot always change Salesforce permissions or Custom Metadata. | Replace the override with a replaceable access or settings provider when that class is introduced. |
| Forced failure | A test must verify a known error path without causing an unrelated Salesforce failure. | Replace it with an evaluator, publisher, or logger that the test can supply. |
| Transaction cache reset | Tests must isolate static object, field, and currency information between cases. | Keep only reset or state access that cannot be verified through the public API. |
| Internal calculation access | Parser, formatter, comparison, and field-planning tests still call private methods. | Move the calculation to a focused helper, test that helper, and remove the original `@TestVisible`. |
| Integration test support | Scratch-org examples expose state used only to verify scale and custom Apex Check behavior. | Keep it in `integration-tests` and remove access that no test still verifies. |

When you remove an approved annotation, reduce its baseline count in the same change. Moving an
annotation to a different file counts as new test-only access and fails the check.

## `Test.isRunningTest()` branches

Production authorization no longer changes when Apex tests run. Restricted-persona integration
tests exercise the real Custom Permission assignment or absence. Focused unit tests may still use
the private `@TestVisible` override to force an authorization branch that is unrelated to the test's
metadata setup.

No production method may branch on `Test.isRunningTest()`. Do not add a branch to preserve behavior
from an older org or API.

## Review evidence

Continuous integration runs the architecture check before Salesforce validation. Release checks
also run the repository's required Salesforce Code Analyzer configuration and a separately labeled
advisory scan. The required scan enforces this project's rules. The advisory scan reports additional
findings without turning them into release thresholds and ignores inline suppressions so reviewers
can still see those findings.

## Related

- [Contributing](../../../.github/CONTRIBUTING.md)
- [Architecture](../framework/architecture.md)
- [Apex class reference](README.md)
