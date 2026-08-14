# Negative conformance scenarios

This matrix keeps negative, boundary, and security verification in the integration-only source tree.
The `RHC_Negative_Runtime` Check Set supplies manual record-page cases. Its valid row-cap Check is
active. Its intentionally malformed authoring Checks are inactive by default; activate only one at
a time, observe the expected fail-closed result, and deactivate it before continuing. The
`RHC_Negative_Conformance` Apex test suite supplies cases that require synthetic schema, currencies,
field permissions, or query shapes that cannot be made deterministic as persistent Custom Metadata.

| Scenario                                   | Reusable integration evidence                                                                         |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| Missing object                             | `RHC_Negative_Missing_Object` Check and `RHCQueryClassificationRedTest`                               |
| Missing field                              | `RHC_Negative_Missing_Field` Check and `RHCAbsentSchemaRedTest`                                       |
| Field inaccessible in user mode            | `RecordHealthCheckEvaluatorBehaviorTest` and the existing `RHC_Persona_Access` harness                |
| Invalid SOQL                               | `RHC_Negative_For_Update`, `RHC_Negative_System_Mode`, and `RHCConfigCheckValidationTest`             |
| Row count above cap                        | `RHC_Negative_Row_Cap` and `RHCRowLimitOutcomeTest`                                                   |
| Row count exactly at cap                   | `RHCRowLimitOutcomeTest`                                                                              |
| Outer object with SELECT subquery          | `RecordHealthCheckSoqlTemplateTest`                                                                   |
| Currency equality only in semi-join        | `RHCCurrencyAuthoringRedTest`                                                                         |
| Outer OR or NOT currency predicate         | `RHCCurrencyAuthoringRedTest`                                                                         |
| OR inside semi-join                        | `RHCCurrencyAuthoringRedTest`                                                                         |
| Mixed-currency aggregate/list refusal      | `RHCMixedCurrencyRedTest` and `RHCCurrencyAuthoringRedTest`                                           |
| Single-currency aggregate and fixed value  | `RHCCurrencyAuthoringRedTest`                                                                         |
| Missing required expected ISO code         | `RHCCurrencyAuthoringRedTest`                                                                         |
| Unsupported polymorphic path               | `RHCPolymorphicQuerySafetyTest`                                                                       |
| Sharing/FLS visible-scope preservation     | `RecordHealthCheckContractHarnessTest` and `RHC_Persona_Access`                                       |
| Invalid comparison/type/unit pairing       | `RHCConfigCheckValidationTest`                                                                        |
| Null and no-row policies                   | Existing `Account_QC_ERB_*`, `Account_QC_NullBehavior_*`, and `RHCEvaluatorEdgeBehaviorTest` fixtures |
| More than 25 active Checks                 | Existing `Example_Account_Over_25_Checks` Check Set                                                   |
| Unsafe keywords and malformed merge tokens | `RecordHealthCheckSoqlTemplateTest` and `RecordHealthCheckAdversarialBoundaryTest`                    |
| Diagnostics permission gating              | `RecordHealthCheckConfigServiceTest`                                                                  |
| Diagnostic cap-plus-one query              | `RecordHealthCheckDiagnosticTraceTest`                                                                |

The namespaced `RHC_Persona_Access` fixture is intentionally not deployable to a no-namespace org.
Run its Apex methods in the maintained namespaced scratch-org gate. Do not replace that test with a
system-mode comparison query; restriction and scoping rules are valid visibility controls.
