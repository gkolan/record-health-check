# Contributor policy: Apex test-only access and architecture checks

> [!NOTE]
> On this page, follow the contributor policy for `@TestVisible`, `Test.isRunningTest()`, and the
> Apex architecture release check. This is not a Framework outcome or Evaluation Type reference.

This project treats `@TestVisible` and `Test.isRunningTest()` as a temporary workaround, not as a
testing strategy. Prefer testing production behavior through public Apex APIs or the class that
owns the behavior whenever possible.

The baseline file is
[`scripts/release/generated/apex-architecture-baseline.json`](../../../scripts/release/generated/apex-architecture-baseline.json).
`npm run check:apex-architecture` fails when a change:

- adds `@TestVisible` to an unapproved file or increases an approved file's count;
- adds a `Test.isRunningTest()` branch outside the two approved test-only branches;
- adds `System.debug` outside the structured logger or scratch-org exhaustive test class;
- adds a production Apex class above the 500-line review ceiling;
- places redundant `@TestVisible` on a public or global member; or
- introduces language implying private compatibility with an older implementation.

## Approved `@TestVisible` categories

| Category | Why it currently exists | Required direction |
| --- | --- | --- |
| Permission and setting override | Salesforce permissions and Custom Metadata cannot always be varied cheaply inside a focused unit test. | Replace with access or settings providers the test can supply when that layer is introduced. |
| Forced failure | Tests verify how the Framework maps errors without depending on an accidental platform failure. | Replace with evaluator, publisher, or logger dependencies the test can supply. |
| Transaction cache reset | Tests must isolate static describe and currency caches between cases. | Keep only reset or state access that cannot be observed through the public API. |
| Algorithm access | Parser, formatter, comparison, and field-planning tests still reach private implementation. | Extract focused helper classes and retarget tests; delete the original `@TestVisible` access. |
| Integration test support | Scratch-org test data exposes state used only to validate scale and plugin contracts. | Keep outside the subscriber package and remove access that is no longer asserted. |

The baseline records a maximum, not a standing allowance. Reductions should update the baseline in the
same change. Moving an annotation to another file is treated as new test-only access and fails the check.

## Current approved runtime branches

- `RecordHealthCheckAccess` permits a test-supplied permission answer.
- `RecordHealthCheckLogger` permits a test-supplied publication setting.

No other production method may branch on `Test.isRunningTest()`. These two branches remain queued
for dependency supply from tests and must not be cited as compatibility with an older org or API.

## Review evidence

Every pull request runs the architecture check before deployment. The release workflow then runs a
strict configured analyzer profile and a separately labeled neutral advisory scan. Reviewers can
therefore see both the enforceable project contract and the generic findings that the project has
chosen not to use as release thresholds. The neutral profile also disables suppression processing,
so every inline-suppressed finding remains visible in the advisory evidence.

## Related

- [Contributing](../../../.github/CONTRIBUTING.md)
- [Architecture](../framework/01-architecture.md)
- [Apex class reference](README.md)
