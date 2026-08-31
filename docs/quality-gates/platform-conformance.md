# Platform conformance evidence

Use this quality gate when a change affects schema planning, result identity, numeric or currency
values, applicability, user-mode access, or an execution adapter. It records the product-neutral
evidence for the platform data-shape and execution-context contracts. Industry packages are not
required and their business semantics are not evidence for core behavior.

## Data-shape matrix

| Shape | Required behavior | Automated evidence | Support boundary |
| --- | --- | --- | --- |
| Optional object, field, or relationship is absent | Unresolved schema produces a stable unavailable result and never enters a user-mode query | `RHCAbsentSchemaRedTest`, `RHCFormulaRelationshipPlanningTest`, `RecordHealthCheckDescribeCacheTest` | Product-neutral describe behavior; no licensed fixture required |
| Multiple managed-package namespaces | Qualified identities and configured API names resolve without assuming one product prefix | `RecordHealthCheckApexAdapterTest`, `RHCFieldPlannerNamespaceTest`, `RHCDefinitionDependencyIdentityTest`, plus `RHCForeignNamespaceFieldIT` in the licensed two-package gate | The dedicated gate uses RHC (`rhc`) and Salesforce CPQ (`SBQQ`) to prove Formula, Query, and merge handling; CPQ semantics remain out of scope |
| Self-reference, dependency cycle, or missing parent | Evaluation remains deterministic and results stay associated with the requested root | `RHCReleaseBoundaryCoverageTest`, `RecordHealthCheckMetadataValidatorTest`, `RecordHealthCheckBulkQuerySupportTest` | A malformed dependency cycle keeps input order; unresolved relationship data fails safely |
| Negative or scaled Decimal | Sign and scale survive typed-value storage and JSON; display retains the meaningful signed value | `RHCPlatformDataShapeConformanceTest`, `RecordHealthCheckContractTypesTest`, `RHCComparisonDisplayEdgeBehaviorTest` | Display can trim insignificant trailing zeroes after evaluation |
| Snapshot field versus current source | Core reports the value it evaluated and does not claim that an arbitrary stored snapshot is current | Typed Found/Expected contract tests plus [platform limitations](../reference/platform/limitations.md#derived-values-snapshots-and-freshness) | The generic freshness primitive was withdrawn; existing Checks express neutral policies and product-specific recipes belong in extensions |
| Large child collection | A row-cap or transaction-cap boundary returns an unavailable outcome instead of a partial collection-wide verdict | `RecordHealthCheckBulkQuerySupportTest`, `RHCEvaluatorEdgeBehaviorTest`, `RHCReleaseBoundaryCoverageTest` | The documented framework and query caps still apply |
| Different currency ISO codes | Currency evidence remains attached to its row; unsafe aggregation is rejected | `RHCMixedCurrencyRedTest`, `RHCCurrencyAuthoringRedTest`, `RHCCurrencyEvidenceBoundaryTest`, `RHCDisplayCurrencyResolutionTest` | Core does not convert currencies |
| Legitimate null for one record shape | Applicability determines whether the check applies; null alone is not automatically a defect | `RecordHealthCheckScopeApplicabilityTest`, `RecordHealthCheckScopeEvaluationTest` | The check author owns the applicability rule |
| Binary/Base64 field | The field is refused before evaluation and cannot leak into results or diagnostics | `RHCBase64FieldRedTest` | Deliberately unsupported |

All bulk assertions use product-neutral Account, Contact, synthetic ID, or metadata fixtures. Tests
must assert root IDs or map keys when order alone could hide cross-record evidence.

## Execution and visibility matrix

| Context | Access contract | Automated evidence | Additional verification |
| --- | --- | --- | --- |
| Lightning record page | The interactive user's sharing, CRUD, FLS, restriction rules, and scoping rules apply | `RecordHealthCheckScopeEvaluationTest`, `RecordHealthCheckContractTest` | Test representative users in the target org |
| Flow | The user and execution context Salesforce assigns to that Flow transaction apply | `RecordHealthCheckAutomationFlowTest`, `RecordHealthCheckApiTest` | Validate the actual Flow type and invoking user before rollout |
| Queueable | Authorization is checked for the asynchronous transaction and one request cannot cross-contaminate another root | `RecordHealthCheckAsyncTest`, `RecordHealthCheckAutomationAsyncTest` | Monitor the resulting Apex job independently of health outcomes |
| Batch | Each scope runs under the executing user's current access and respects bulk limits | `RecordHealthCheckAsyncTest`, `RecordHealthCheckBatchScopeTest`, `RecordHealthCheckAutomationAsyncTest` | Validate representative sharing and scope size in the target org |
| Scheduled Apex | Authorization is checked when the schedule fires and the scheduled adapter delegates to Batch | `RecordHealthCheckAsyncTest`, `RecordHealthCheckAutomationAsyncTest` | Confirm the scheduling user's current permission and data access |
| Queue-owned or polymorphic record | Ownership and relationship types are resolved without assuming a User owner | `RHCOwnershipHonestyTest`, `RHCPolymorphicQuerySafetyTest` | Only explicitly supported polymorphic paths are accepted |
| Restriction or scoping rule filters | Results describe rows visible to the user-mode transaction; core performs no elevated comparison query | `RecordHealthCheckScopeEvaluationTest`, `RHCFieldPlannerSecurityTest`, `RecordHealthCheckSecurityAndOpsTest` | Rule provisioning is org-specific, so verify enforcement manually in a representative org |
| Guest or Experience Cloud user | Inaccessible records and fields must not leak | Shared user-mode and diagnostic-redaction tests enforce the core boundary | The component is not exposed to Experience Builder; this is not an automated support claim |

An authorized empty result and an access failure remain distinct. Zero visible rows follow the
configured no-rows policy and never prove org-wide absence. Diagnostics permission can reveal
approved troubleshooting detail, but it does not elevate the business-data query.

## Change gate

When a pull request changes one of these contracts:

1. Run the named focused Apex tests for the affected rows.
2. Run the package-level Apex test and coverage gates required by CI.
3. Validate the current package in both namespaced and non-namespaced release orgs when the change
   affects namespace resolution or public package behavior.
4. Run the [foreign-namespace field gate](../../packages/record-health-check/integration-tests/foreign-namespace/README.md)
   when a change affects field scanning, describe resolution, query fields, or record merge tokens.
5. Mark licensed or org-specific cases as manual or not tested. Never count a skipped fixture as
   automated support evidence.
6. Keep [platform compatibility](../reference/platform/compatibility.md) and
   [security and data access](../architecture/security-and-data-access.md) aligned with this matrix.

## Related

- [Platform compatibility](../reference/platform/compatibility.md)
- [Platform limitations and safe patterns](../reference/platform/limitations.md)
- [Security and data access](../architecture/security-and-data-access.md)
- [Package testing and upgrades](./package-testing-and-upgrades.md)
