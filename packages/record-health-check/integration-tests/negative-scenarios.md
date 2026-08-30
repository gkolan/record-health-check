# Negative conformance scenarios

This matrix keeps negative, boundary, and security verification in the integration-only source tree.
The diagnosis-first persistent catalog and its per-fixture verification steps are documented in
[bad-configuration-diagnostic-fixtures.md](./bad-configuration-diagnostic-fixtures.md).
The `RHC_Negative_Runtime` Check Set supplies manual record-page cases. Its valid row-cap Check is
active. Its intentionally malformed authoring Checks are inactive by default; activate only one at
a time, observe the expected fail-closed result, and deactivate it before continuing. The
`RHC_Negative_Conformance` Apex test suite supplies cases that require synthetic schema, currencies,
field permissions, or query shapes that cannot be made deterministic as persistent Custom Metadata.

| Scenario                                    | Reusable integration evidence                                                                         |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Missing object                              | `RHC_Negative_Missing_Object` Check and `RHCQueryClassificationRedTest`                               |
| Missing field                               | `RHC_Negative_Missing_Field` Check and `RHCAbsentSchemaRedTest`                                       |
| Field inaccessible in user mode             | `RecordHealthCheckEvaluatorBehaviorTest` and the existing `RHC_Persona_Access` harness                |
| Invalid SOQL                                | `RHC_Negative_For_Update`, `RHC_Negative_System_Mode`, and `RHCConfigCheckValidationTest`             |
| Row count above cap                         | `RHC_Negative_Row_Cap` and `RHCRowLimitOutcomeTest`                                                   |
| Row count exactly at cap                    | `RHCRowLimitOutcomeTest`                                                                              |
| Outer object with SELECT subquery           | `RecordHealthCheckSoqlTemplateTest`                                                                   |
| Literal/nested bulk clauses and correlation | `RecordHealthCheckBulkQueryDepthTest`                                                                 |
| Currency equality only in semi-join         | `RHCCurrencyAuthoringRedTest`                                                                         |
| Outer OR or NOT currency predicate          | `RHCCurrencyAuthoringRedTest`                                                                         |
| OR inside semi-join                         | `RHCCurrencyAuthoringRedTest`                                                                         |
| Mixed-currency aggregate/list refusal       | `RHCMixedCurrencyRedTest` and `RHCCurrencyAuthoringRedTest`                                           |
| Single-currency aggregate and fixed value   | `RHCCurrencyAuthoringRedTest`                                                                         |
| Missing required expected ISO code          | `RHCCurrencyAuthoringRedTest`                                                                         |
| Unsupported polymorphic path                | `RHCPolymorphicQuerySafetyTest`                                                                       |
| Sharing/FLS visible-scope preservation      | `RecordHealthCheckContractHarnessTest` and `RHC_Persona_Access`                                       |
| Invalid comparison/type/unit pairing        | `RHCConfigCheckValidationTest`                                                                        |
| Null and no-row policies                    | Existing `Account_QC_ERB_*`, `Account_QC_NullBehavior_*`, and `RHCEvaluatorEdgeBehaviorTest` fixtures |
| More than 25 active Checks                  | Existing `Example_Account_Over_25_Checks` Check Set                                                   |
| Unsafe keywords and malformed merge tokens  | `RecordHealthCheckSoqlTemplateTest` and `RecordHealthCheckAdversarialBoundaryTest`                    |
| Diagnostics permission gating               | `RecordHealthCheckConfigServiceTest`                                                                  |
| Diagnostic cap-plus-one query               | `RecordHealthCheckDiagnosticTraceTest`                                                                |
| Query plus expected-query budget exhaustion | `RecordHealthCheckScopePlannerTest`                                                                   |
| Trailing backslash in a SOQL token value    | `RecordHealthCheckSoqlTokenBinderTest`                                                                |
| Blank optional field in explicit Check load | `RecordHealthCheckConfigServiceTest`                                                                  |
| Literal `"null"` versus actual null token   | `RecordHealthCheckTemplateServiceTest`                                                                |
| Real missing Run Custom Permission          | `RecordHealthCheckRestrictedPersonaTest`                                                              |
| Browser completion payload and status trust | `RecordHealthCheckControllerTest`; events are advisory and must be re-evaluated before action         |

The namespaced `RHC_Persona_Access` fixture is intentionally not deployable to a no-namespace org.
Run its Apex methods in the maintained namespaced scratch-org gate. Do not replace that test with a
system-mode comparison query; restriction and scoping rules are valid visibility controls.

## One-command war room

From the repository root, run the committed negative suite plus persistent row-cap setup and
verification against an already deployed contributor org:

```bash
npm run test:war-room -- --alias <alias>
```

Useful additions:

- `--deploy` deploys `force-app` and `integration-tests` first.
- `--combined-features` also seeds and tests Person Accounts with active USD and EUR. Use it only
  with the combined-feature scratch definition below.
- `--full` follows the focused war room with all local Apex tests and code coverage.

The runner assigns `Record_Health_Check_Admin` only to the scratch org's default test user. It reads
the target org's namespace and the committed suite membership before passing class names to
Salesforce CLI. In a namespaced org, restricted-persona tests create separate users and prove the
real assigned and unassigned Custom Permission boundaries. In a no-namespace org, the runner skips
only `RecordHealthCheckRestrictedPersonaTest`, whose fixture deliberately references namespaced
schema, and runs the remaining negative suite. It never performs a system-mode comparison query.
The `RHC_Negative_Conformance` ApexTestSuite metadata remains available for no-namespace org UI runs;
Salesforce cannot deploy an unqualified source suite directly into a namespaced org.

## Combined Person Account and multi-currency gate

Create this namespaced gate from `packages/record-health-check`, activate EUR, deploy the framework
and integration fixture source, and seed persistent manual-test records:

```bash
sf org create scratch --definition-file config/pa-multicurrency-scratch-def.json --alias <alias>
sf data update record --sobject CurrencyType --record-id <eur-currency-type-id> --values "IsActive=true" --target-org <alias>
sf apex run --file integration-tests/scripts/setup-pa-multicurrency-scenarios.apex --target-org <alias>
```

The script fails closed unless Person Accounts are enabled and both USD and EUR are active. It then
replaces only its two exact-name fixtures and creates one EUR business Account and one EUR Person
Account for repeatable manual verification.

## Repeatable row-cap data

Run these scripts from `packages/record-health-check` after deploying the Framework and the negative
fixtures:

```bash
sf apex run --file integration-tests/scripts/setup-negative-scenarios.apex --target-org <alias>
sf apex run --file integration-tests/scripts/verify-negative-scenarios.apex --target-org <alias>
```

The setup creates three clearly named Accounts with zero, one, and two Contacts. Because the Check
cap is one, the public facade's scope-wide query path returns `FAIL`, `PASS`, and
`UNABLE_TO_EVALUATE / SCOPE_ROW_CAP_EXCEEDED`, respectively. The focused evaluator test suite also
proves the per-record `ROW_LIMIT_EXCEEDED` contract. Setup is idempotent: it replaces only Accounts
using those exact fixture names. Verification resolves the Check's `QualifiedApiName`, so the same
script works in namespaced and no-namespace orgs.

Remove the data when finished:

```bash
sf apex run --file integration-tests/scripts/cleanup-negative-scenarios.apex --target-org <alias>
```

The missing-object, missing-field, `FOR UPDATE`, and `WITH SYSTEM_MODE` fixtures need no record data;
their failure happens before a row can be read. Currency-mode, field-access, polymorphic, and hidden-
scope cases remain deterministic Apex-suite fixtures because their required org configuration cannot
be manufactured safely by an anonymous data script.
