# Reference: Verify an Apex Rule plugin

> [!NOTE]
> The bulk interface makes efficient plugins possible. It cannot inspect a subscriber's
> query loop or determine the access mode used by custom Apex at runtime.

## Four layers of protection

| Layer | Evidence | Limitation |
| --- | --- | --- |
| Contract | One plugin call receives the complete record scope | A plugin can still query inside its own loop |
| Verification | `RecordHealthCheckRuleContractTest` measures several scope sizes | External authors must run and maintain the test |
| Observation | A monitor can record query, row, CPU, and heap changes | One observation does not establish a growth pattern |
| Policy | Administrators can explicitly exclude a Rule or fail a scan | Exclusion must never happen silently |

The contract test checks scopes of 1, 10, 50, and 200 records. It checks approximate query
stability, complete result coverage, forbidden writes, and optional permission test data.
The shipped `AccountHasRecentActivityCheck` passes it. The self-test also includes
a deliberately inefficient plugin and proves that growing query use is rejected before it
reaches the platform query limit.

## Permission evidence

Three kinds of evidence must remain separate:

- Behavioral evidence comes from a test setup where a least-privilege user cannot read a
  chosen record or field. The expected outcome is `UNABLE_TO_EVALUATE` with no Found or
  Expected value.
- Source evidence comes from static analysis of plugin source that is available to scan.
- Custom subscriber Apex has no runtime access-mode counter. Neither the interface nor
  `System.runAs` alone proves that its queries use user access.

Plugin authors should override `permissionFixture()` only when the test data creates a real
visibility difference. A test that merely changes the running user is not permission
evidence.

Treat every plugin author and reviewer as a trusted-code role. Static source verification rejects
global `without sharing` implementations and requires explicit `with sharing`, but no runtime
counter can prove that a custom plugin avoided system-mode object or field reads. Review every
query for user-mode CRUD/FLS enforcement before deployment.

## Start from the templates

Copy these two files and replace the example names and data factory:

- `scripts/templates/RecordHealthCheckRule.template.cls`
- `scripts/templates/RecordHealthCheckRuleContractTest.template.cls`

The Rule template seeds every requested ID, performs one grouped user-mode query, overlays
the grouped results, and isolates record-specific failures. The test template is already
wired to the reusable contract test.

## Reporting rules

- Do not silently disable a Rule because monitoring looks suspicious. Fail clearly or use
  an explicit administrator setting.
- Do not infer a complexity class from one measurement. Report the measured resource
  change and whether the Rule has passed the multi-size contract test.
- Measure a full supported Check Set as well as each Rule before publishing a capacity
  claim.

## Related

- [Apex plugin contract](../evaluation/04-apex-rule-contract.md)
- [Apex API](../../api/01-apex-api.md)
- [Apex class catalog](README.md)
