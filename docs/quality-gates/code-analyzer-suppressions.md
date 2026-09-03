# Code Analyzer suppressions

Audience: package contributors reviewing pull-request security evidence. This page is never needed
to configure or run a Check. Administrators should use [Security and data access](../architecture/security-and-data-access.md).

> [!NOTE]
> On this page, find every inline Salesforce Code Analyzer suppression in the Record Health Check
> package, exactly where each one is, and why it is safe to leave in place.

## AppExchange security-review readiness

Record Health Check is **engineered for AppExchange security-review readiness**. Its release process
keeps Salesforce Code Analyzer rules enabled by default, fails on new unsanctioned findings, and
requires every narrow suppression to be documented and reviewable on this page. Those controls are
supplemented by clean-source CI, authorization-persona tests, adversarial tests, package-boundary
checks, and Salesforce runtime validation.

This readiness statement describes the repository's engineering controls. It is not a claim that a
specific package version has passed Salesforce AppExchange Security Review, and it does not replace
Salesforce's submission, automated scanning, manual review, clean-install, or integration-review
requirements. State that a release is AppExchange approved only after Salesforce has approved that
exact submitted solution and version.

Use this table to look up a suppression by file, rule, or category. Every suppression is a comment
placed directly above the line it covers:

```text
// code-analyzer-suppress-next-line <RuleName>: <reason>
```

The rule stays enabled for every other line in the package; a new violation anywhere else still
fails the release scan. Reproduce this count from a clean checkout:

```bash
grep -rn "code-analyzer-suppress-next-line" \
  packages/record-health-check/force-app \
  packages/record-health-check/integration-tests
```

27 lines, as of 2026-08-18: 18 in the core package, 9 in the integration test harness.

## Core package

18 suppressions across four rule categories.

### Custom Metadata reads

Check Sets and Checks are stored as **Custom Metadata Types**
(`Record_Health_Check_Set__mdt`, `Record_Health_Check__mdt`). Salesforce always lets Apex read a
Custom Metadata Type record. It does not apply the same-object read permission or field-level
security it applies to Accounts, Contacts, and other business records. That is a Salesforce
platform behavior, not a gap in Record Health Check's own code
([Trailhead: Protect Custom Metadata Types & Records](https://trailhead.salesforce.com/content/learn/modules/custom_metadata_types_adv/cmt_manageability)).
Adding `WITH USER_MODE` to a query like this would have no effect, since Custom Metadata Type
reads bypass record and field access checks either way.

Most reads below happen after Record Health Check's own permission check confirms the user is
allowed to run Checks at all (`RecordHealthCheckAccess.canRunChecks()`).

| File | Line | Rule | What this line does |
| --- | ---: | --- | --- |
| `RecordHealthCheckDefinitionLoader.cls` | 52 | `ApexCRUDViolation` | Loads the Check Set Custom Metadata record shown on the card. |
| `RecordHealthCheckDefinitionLoader.cls` | 91 | `ApexCRUDViolation` | Loads the active Checks that belong to that Check Set. |
| `RecordHealthCheckDefinitionLoader.cls` | 402 | `ApexCRUDViolation` | Counts a Check Set's inactive Checks for the administrator tooltip. |
| `RecordHealthCheckDefinitionLoader.cls` | 418 | `ApexCRUDViolation` | Lists those inactive Checks' names for that same tooltip. |
| `RecordHealthCheckScopePlanner.cls` | 41 | `ApexCRUDViolation` | Loads the Check Set's own configuration. The Account, Contact, or other records it evaluates are queried separately, using the running user's real record access (`WITH USER_MODE`). |
| `RecordHealthCheckConfigService.cls` | 59 | `ApexCRUDViolation` | Finds which Check Set a given Check belongs to. |
| `RecordHealthCheckConfigService.cls` | 83 | `ApexCRUDViolation` | Checks which object every active Check Set targets, to find the ones that apply to the current record page. |
| `RecordHealthCheckConfigService.cls` | 223 | `ApexCRUDViolation` | Loads one Check's configuration immediately before it runs. |
| `RecordHealthCheckMetadataValidator.cls` | 54 | `ApexCRUDViolation` | Reads every active Check Set so an administrator's configuration can be validated. This runs for the person configuring Checks, not for a user viewing results. |
| `RecordHealthCheckMetadataValidator.cls` | 76 | `ApexCRUDViolation` | Reads every Check for that same administrator-facing validation. |
| `RecordHealthCheckSetPicklist.cls` | 51 | `ApexCRUDViolation` | Lists active Check Sets for the dropdown an administrator sees while building a Lightning page. |
| `RecordHealthCheckController.cls` | 363 | `ApexCRUDViolation` | Confirms a Check actually belongs to the Check Set the caller says it does. |
| `RecordHealthCheckSettingsProvider.cls` | 20 | `ApexCRUDViolation` | Reads one Record Health Check setting: whether a Check Set publishes its interactive run event. Not a subscriber's business record. |
| `RecordHealthCheckSettingsProvider.cls` | 35 | `ApexCRUDViolation` | Reads which Checks are enabled for that same interactive event publication. |

### Dynamic scope query

| File | Line | Rule | What this line does |
| --- | ---: | --- | --- |
| `RecordHealthCheckScopePipeline.cls` | 178 | `ApexSOQLInjection` | Builds the query that loads a record's field values for evaluation. The record IDs come in as a bind variable, the object and field names are checked against Salesforce's own schema first, and the query runs with the user's real record access (`WITH USER_MODE`). |

### Schema describe cache

| File | Line | Rule | What this line does |
| --- | ---: | --- | --- |
| `RecordHealthCheckDescribeCache.cls` | 36 | `AvoidMultipleMassSchemaLookups` | Looks up Salesforce's object and field metadata once per transaction and reuses it, instead of asking Salesforce again for every Check. |

### Deliberately-unsafe test fixtures

| File | Line | Rule | What this line does |
| --- | ---: | --- | --- |
| `RecordHealthCheckContractHarnessTest.cls` | 145 | `OperationWithLimitsInLoop` | This test deliberately checks records one at a time, instead of in bulk, to prove Record Health Check catches and rejects that pattern in a custom Apex Check. |
| `RecordHealthCheckScopePlannerTest.cls` | 208 | `OperationWithLimitsInLoop` | This test deliberately uses up all but two of the record-lookup slots, to prove the planner blocks a Check that would need three. |

### Fixed instead of suppressed

Not every finding here got a suppression comment. `AvoidHardcodedCredentialsInFieldDecls` matched
a field named `AUTHORIZATION_MESSAGE` in three classes; its heuristic matched the word
"AUTHORIZATION" in the field name, not its value, which was always a plain user-facing message
("You do not have permission to run Record Health Checks."). Since this was a naming collision and
not a real access-control question, the field was renamed instead of suppressed:

| File | Change |
| --- | --- |
| `RecordHealthCheckAgentRestResource.cls` | `AUTHORIZATION_MESSAGE` renamed to `PERMISSION_DENIED_MESSAGE` |
| `RecordHealthCheckRunCheckAgentAction.cls` | `AUTHORIZATION_MESSAGE` renamed to `PERMISSION_DENIED_MESSAGE` |
| `RecordHealthCheckRunSetAgentAction.cls` | `AUTHORIZATION_MESSAGE` renamed to `PERMISSION_DENIED_MESSAGE` |

The public `'AUTHORIZATION'` reason code these classes return to callers, documented in the
[Agent tool contract](../reference/contracts/agent-tool-contract.md), did not change. Only the private field
holding the message text did.

## Integration tests (not shipped)

9 suppressions. This package only runs in a scratch org during development. It is never packaged,
never installed in a subscriber org, and ships with none of the metadata described here.

### Benchmark telemetry

`RHC_Benchmark_Result__c` is a regular custom object, not a Custom Metadata Type. It holds
performance numbers from admin-run benchmark tests and nothing else. It is suppressed because it is
disposable test-org infrastructure that a subscriber never sees, not because record access rules
don't apply to it.

| File | Line | Rule | What this line does |
| --- | ---: | --- | --- |
| `RecordHealthCheckScaleBenchmark.cls` | 22 | `ApexCRUDViolation` | Writes a new row to the benchmark's own results object, which exists only in the test org. |
| `RecordHealthCheckScaleBenchmark.cls` | 29 | `ApexCRUDViolation` | Saves the async job ID on that same results row. |
| `RecordHealthCheckScaleBenchmark.cls` | 57 | `ApexCRUDViolation` | Writes benchmark results even when the running user's Permission Set intentionally has no access to the results object; the benchmark still needs to record what happened. |
| `RecordHealthCheckScaleBenchmark.cls` | 68 | `ApexCRUDViolation` | Saves the job ID on the results row for a specific benchmark run. |
| `RecordHealthCheckScaleBenchmark.cls` | 85 | `ApexCRUDViolation` | Reads the benchmark results report. Enforcing normal field-level security here would make the benchmark's own fields unreadable to the person running it. |
| `RecordHealthCheckScaleBenchmark.cls` | 120 | `ApexCRUDViolation` | Looks up one benchmark run's results row by its run ID. |

### Scratch-org exhaustive harness

| File | Line | Rule | What this line does |
| --- | ---: | --- | --- |
| `RecordHealthCheckExhaustiveSmoke.cls` | 20 | `OperationWithLimitsInLoop` | Starts one background (Queueable) job at a time, up to Salesforce's 50-job-per-transaction limit. Salesforce does not offer a bulk way to start Queueable jobs. |
| `RecordHealthCheckExhaustiveSmoke.cls` | 43 | `OperationWithLimitsInLoop` | Counts how many of those background jobs have finished, capped at that same 50-job limit. |
| `RecordHealthCheckExhaustiveSmoke.cls` | 69 | `QueueableWithoutFinalizer` | This one-time test harness saves its own result directly; it has no follow-up job, so it does not need Salesforce's Queueable Finalizer cleanup step. |

## Related

- [Security and data access](../architecture/security-and-data-access.md)
- [Agent tool contract](../reference/contracts/agent-tool-contract.md)
- [Architecture](../architecture/framework.md)
