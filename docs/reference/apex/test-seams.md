# Contributor policy: Apex test seams and architecture gates

> [!NOTE]
> On this page, follow the contributor policy for `@TestVisible`, `Test.isRunningTest()`, and the
> Apex architecture release gate. This is not a Framework outcome or Evaluation Type reference.

This project treats `@TestVisible` and `Test.isRunningTest()` as temporary design debt, not as a
testing strategy. Production behavior is tested through public contracts or the collaborator that
owns the behavior whenever possible.

The machine-readable baseline is
[`scripts/release/generated/apex-architecture-baseline.json`](../../../scripts/release/generated/apex-architecture-baseline.json).
`npm run check:apex-architecture` fails when a change:

- adds `@TestVisible` to an unapproved file or increases an approved file's count;
- adds a test-runtime branch outside the two approved dependency seams;
- adds `System.debug` outside the structured logger or scratch-org exhaustive harness;
- adds a production Apex class above the 500-line review ceiling;
- places redundant `@TestVisible` on a public or global member; or
- introduces language implying private compatibility with an older implementation.

## Approved seam categories

| Category | Why it currently exists | Required direction |
| --- | --- | --- |
| Permission and setting override | Salesforce permissions and Custom Metadata cannot always be varied cheaply inside a focused unit test. | Replace with injected access/settings providers when that layer is introduced. |
| Forced failure | Tests verify orchestration error mapping without depending on an incidental platform failure. | Replace with injected evaluator, publisher, or logger dependencies. |
| Transaction cache reset | Tests must isolate static describe and currency caches between cases. | Keep only reset/state access that cannot be observed through the public contract. |
| Algorithm access | Parser, formatter, comparison, and field-planning tests still reach private implementation. | Extract cohesive collaborators and retarget tests; delete the original forwarding seam. |
| Integration harness | Scratch-org fixtures expose state used only to validate scale and plugin contracts. | Keep outside the subscriber package and remove access that is no longer asserted. |

The baseline records a maximum, not an entitlement. Reductions should update the baseline in the
same change. Moving an annotation to another file is treated as a new seam and fails the check.

## Current approved runtime branches

- `RecordHealthCheckAccess` permits a test-supplied permission answer.
- `RecordHealthCheckLogger` permits a test-supplied publication setting.

No other production method may branch on `Test.isRunningTest()`. These two branches remain queued
for dependency injection and must not be cited as compatibility with an older org or API.

## Review evidence

Every pull request runs the architecture check before deployment. The release workflow then runs a
strict configured analyzer profile and a separately labeled neutral advisory scan. Reviewers can
therefore see both the enforceable project contract and the generic findings that the project has
chosen not to use as release thresholds. The neutral profile also disables suppression processing,
so every inline-suppressed finding remains visible in the advisory evidence.

## Related

- [Contributing](../../../.github/CONTRIBUTING.md)
- [Architecture](../framework/architecture.md)
- [Apex class reference](README.md)
