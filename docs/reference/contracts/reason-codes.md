# Understand Reason Codes

> [!NOTE]
> Use this page when a result, Flow output, metadata audit, or Lightning card returns a Reason Code.
> Find the code below to see what happened and which Salesforce configuration or access setting to
> check first.

Use this registry to translate a stable **Reason Code** into its status, meaning, and first useful
investigation. Reason Codes let administrators, Flows, Apex, and integrations identify a cause
without trying to interpret a message that an administrator can edit.

## How to use a Reason Code

| Where you see it | How to use it |
| --- | --- |
| Card or Setup investigation | Decide whether to inspect applicability, dependencies, field access, Formula configuration, SOQL, or Apex |
| Flow | Route a known non-normal result without treating display text as an API |
| Apex | Branch or log using a stable `UPPER_SNAKE_CASE` value |
| Support or release review | Connect the public result with authorized **Show Diagnostics** details and logs |

Reason Codes explain why a Check did not produce a normal `PASS` or `FAIL`, or why a card could not
load. Codes use `UPPER_SNAKE_CASE`, and future package versions can add new codes. Integrations must
use the code, never editable display text.

> [!IMPORTANT]
> **Public versus diagnostics-only:** `FIELD_NOT_ACCESSIBLE` and `RECORD_NOT_ACCESSIBLE` never appear
> as the public `reasonCode` on a result. Record Health Check replaces them with `CANNOT_EVALUATE`.
> When **Show Diagnostics** is on and the user has **Record Health Check View Diagnostics**
> (`rhc__Record_Health_Check_View_Diagnostics`), the specific code is available in
> `adminDetail.reasonCode`.

Record Health Check uses a neutral public code because revealing whether a hidden record or field exists
can disclose Salesforce access information to someone who is not allowed to see it. Authorized
administrators still receive the specific cause through Show Diagnostics, where they can distinguish
a missing record from missing field access without weakening the normal user's security boundary.

The Apex helper for this two-code list is `RecordHealthCheckReasonCodes`. Other codes can come from
the Apex classes that run Checks, merge-token handling, metadata validation, the Lightning card, or
a custom Apex Check.

---

## Applicability and prerequisites

| Code | Typical status | Meaning |
| --- | --- | --- |
| `NOT_APPLICABLE_BY_FORMULA` | `SKIPPED` | Applicability mode `WHEN_FORMULA_TRUE` returned false. |
| `NOT_APPLICABLE_BY_COUNT` | `SKIPPED` | Applicability count check was not met. |
| `PREREQUISITE_NOT_MET` | `SKIPPED` | Prerequisite Check did not return `PASS`. |
| `STOPPED_AFTER_ERROR` | `SKIPPED` | Client stopped the remaining checks after a system error. |
| `CLIENT_CALL_FAILED` | `ERROR` | The browser could not complete the Apex evaluation request. |
| `MALFORMED_RESPONSE` | `ERROR` | Apex returned a result that is missing required fields or uses an invalid format. |
| `UNKNOWN_RESULT_STATUS` | `ERROR` | Apex returned an unsupported result status. |
| `MISSING_TOKEN_VALUE` | `UNABLE_TO_EVALUATE` | A required merge-token value was unavailable. |
| `CIRCULAR_DEPENDENCY` | `UNABLE_TO_EVALUATE` | Two or more Checks depend on each other. The Lightning card can identify this before calling Apex. |
| `DEPENDENCY_NOT_IN_RUN` | `SKIPPED` | The Prerequisite Check was not included because it was inactive, missing, ordered after the Check that requires it, or outside the first 25 active Checks. Apex and the Lightning card enforce the same behavior. |
| `APPLICABILITY_NOT_MET` | `SKIPPED` | Query empty-result path chose skip via `NoRowsResult__c = SKIP` (distinct from applicability checks above). |
| `VALUE_IS_EMPTY` | `SKIPPED` | Row comparison skipped because a compared field value was empty under `EmptyValueHandling__c = SKIP_RECORD`. |

---

## Access and permissions

| Code | Typical status | Visibility | Meaning |
| --- | --- | --- | --- |
| `CANNOT_EVALUATE` | `UNABLE_TO_EVALUATE` | Public | Neutral substitute when a diagnostics-only access code is remapped. |
| `FIELD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only (remapped publicly) | Required field not readable in user mode. |
| `RECORD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only (remapped publicly) | A custom Apex Check or internal access check reported that the record could not be read. |
| `RECORD_NOT_VISIBLE` | `UNABLE_TO_EVALUATE` | Public | The requested record was not returned by the user-mode record query. Confirm that the record still exists and the running user can access it. |
| `NO_RECORD_CONTEXT` | `UNABLE_TO_EVALUATE` | Public | Evaluation called without a usable record Id. |

---

## Configuration and identity

| Code | Typical status | Meaning |
| --- | --- | --- |
| `CONFIG_NOT_FOUND` | `UNABLE_TO_EVALUATE` / setup | The supplied Check Set `QualifiedApiName` was not found. |
| `CONFIG_INACTIVE` | `UNABLE_TO_EVALUATE` / setup | Check Set is inactive. |
| `OBJECT_MISMATCH` | `UNABLE_TO_EVALUATE` / setup | Check Set object does not match the record. |
| `CHECK_NOT_FOUND` | `UNABLE_TO_EVALUATE` | The supplied Check `QualifiedApiName` was not found in the resolved Check Set. |
| `CHECK_INACTIVE` | `UNABLE_TO_EVALUATE` | Check is inactive. |
| `INVALID_CHECK_TYPE` | `UNABLE_TO_EVALUATE` | Evaluation Type missing or unrecognized. |
| `INVALID_CONFIG` | definition / unable | Invalid Check Set display or identity configuration. |
| `MISSING_REQUIRED_FIELD` | validation | A required Check Set or Check field (e.g. Base Object API Name, Card Title) is blank (deploy/CI validator). |
| `CHECK_LIMIT_EXCEEDED` | Lightning definition / validation warning | A Check Set has more than 25 active Checks. The Lightning card shows and runs the first 25; the metadata audit reports the excess. Direct Apex and Flow use `FRAMEWORK_MAX_CHECKS_EXCEEDED` instead. |
| `APEX_DISPLAY_TEXT_IGNORED` | validation warning | An Apex Check configures Display Found or Expected formulas/text. Custom Apex Check outcomes supply those values, so the metadata audit warns that these fields are ignored. |
| `USER_RUN_PUBLICATION_UNREACHABLE` | validation warning | An automatic card hides Run and Rerun while Check Set publication is enabled. Users cannot publish from the card, but Apex and Flow remain available. |
| `USER_RESULT_PUBLICATION_UNREACHABLE` | validation warning | An automatic card hides Run and Rerun while publication is enabled for one of its Checks. Users cannot publish from the card, but Apex and Flow remain available. |
| `INVALID_DEPENDENCY` | validation | Prerequisite metadata is invalid (deploy/CI validator). |
| `INVALID_OBJECT_API_NAME` | thrown request error | The selected Check Set has a blank or unknown Salesforce object API name. |

---

## Query and comparison

| Code | Typical status | Meaning |
| --- | --- | --- |
| `INVALID_SOQL_TEMPLATE` | `UNABLE_TO_EVALUATE` | SOQL template failed safety or parse checks. |
| `FIELD_NOT_RESOLVED` | `UNABLE_TO_EVALUATE` | A configured field does not exist on the resolved Salesforce object. Correct the API name or remove the Check from orgs where that schema is unavailable. |
| `FIELD_TYPE_NOT_SUPPORTED` | `UNABLE_TO_EVALUATE` | A selected field resolves but its value type cannot safely enter the Query comparison or result contract. Base64/Blob fields are refused before query execution; use reviewed user-mode Apex that owns binary handling without returning the binary value. |
| `RELATIONSHIP_NOT_RESOLVED` | `UNABLE_TO_EVALUATE` | A configured relationship segment could not be resolved safely. Correct the relationship API name or traversal. |
| `OBJECT_NOT_RESOLVED` | `UNABLE_TO_EVALUATE` | The root object in a supported Query shape does not exist in the org. Correct its API name or remove the Check from orgs where that schema is unavailable. |
| `MIXED_CURRENCY` | `UNABLE_TO_EVALUATE` / validation | In a multi-currency org, reachable query values use more than one unit, a fixed Currency threshold has no declared ISO basis, or a Currency aggregate discards unit evidence. Group by `CurrencyIsoCode`, constrain it to one literal ISO code with a conjunctive outer predicate, declare the fixed basis, or use Apex that explicitly owns unit handling. Predicates containing `OR` or `NOT` fail closed. No conversion occurs. |
| `INVALID_OPERATOR` | `UNABLE_TO_EVALUATE` | Comparison Operator is missing or cannot be used with the selected Evaluation Type and query-result setting. |
| `INCOMPATIBLE_COMPARISON_TYPES` | `UNABLE_TO_EVALUATE` | Ordered comparison cannot convert the two sides safely. |
| `MULTIPLE_ROWS_RETURNED` | `UNABLE_TO_EVALUATE` | `ONE_RESULT` expected one row/aggregate but got more. |
| `NO_ROWS_RETURNED` | `UNABLE_TO_EVALUATE` | Empty result handled as unable (`NoRowsResult__c = UNABLE_TO_EVALUATE`). |
| `MISSING_BIND_VALUE` | `UNABLE_TO_EVALUATE` | Merge token required for SOQL bind could not be resolved. |
| `ROW_LIMIT_EXCEEDED` | `UNABLE_TO_EVALUATE` | A query returned more rows than that Check's configured **Max Query Rows** cap. The result does not disclose the true row count. Narrow the query or raise the cap. |
| `GOVERNOR_LIMIT_RISK` | `UNABLE_TO_EVALUATE` | Record Health Check stopped before the query could use too much of the transaction's remaining Salesforce limits. Reduce **Max Query Rows**, narrow the SOQL, or check fewer records per transaction. |
| `UNSUPPORTED_BULK_QUERY_SHAPE` | `UNABLE_TO_EVALUATE` | The SOQL template cannot be converted to one query for all requested records. Rewrite it using a supported record-token pattern. |
| `SCOPE_ROW_CAP_EXCEEDED` | `UNABLE_TO_EVALUATE` | The bulk query returned more rows for the transaction than Record Health Check can safely process. Narrow the SOQL or lower the number of records checked per transaction. |

---

## Formula

| Code | Typical status | Meaning |
| --- | --- | --- |
| `INVALID_FORMULA` | `UNABLE_TO_EVALUATE` | Formula failed to compile/evaluate or returned a non-boolean where required. |
| `DISPLAY_FORMULA_INVALID` | `UNABLE_TO_EVALUATE` | A Display Found or Display Expected formula could not be evaluated. Correct the formula and confirm its Formula Result Type. |
| `FORMULA_EVAL_LIMIT` | `UNABLE_TO_EVALUATE` | Record Health Check stopped before the transaction reached Salesforce's formula-evaluation limit. Reduce the number of records or Formula Checks evaluated together. |
| `FORMULA_DEPENDENCY_DEPTH_EXCEEDED` | `UNABLE_TO_EVALUATE` | A calculated-field dependency chain exceeded the planner's depth ceiling. Simplify the chain or replace the Check with a Query or Apex Check; Record Health Check will not evaluate against partially hydrated inputs. |

---

## Custom Apex Checks

| Code | Typical status | Meaning |
| --- | --- | --- |
| `APEX_CLASS_NOT_FOUND` | `UNABLE_TO_EVALUATE` | `ApexClass__c` could not be resolved to an `rhc.RecordHealthCheckPlugin`. Confirm the class API name, packaging namespace, and interface implementation. |
| `INVALID_APEX_PARAMETERS` | `UNABLE_TO_EVALUATE` | `ApexParametersJson__c` is not valid JSON object input. |
| `APEX_EVALUATOR_ERROR` | `ERROR` / `UNABLE_TO_EVALUATE` | Plugin returned an illegal status or omitted required Found/Expected on `PASS`/`FAIL`. |
| `PLUGIN_RESULT_MISSING` | `ERROR` (per record) or thrown Apex exception | The plugin returned no entry for a requested record, or returned a null map for the whole request. Cover every requested ID. An empty request should return an empty map. |
| `PLUGIN_RESULT_UNKNOWN_KEY` | Thrown Apex exception | The plugin returned an outcome for a record ID that was not requested. The complete custom Apex Check call fails. |
| `PLUGIN_THREW` | Thrown Apex exception | The plugin threw an unhandled exception that cannot be assigned to one record. |
| `PLUGIN_SIDE_EFFECT_DETECTED` | Thrown Apex exception | The plugin changed data, made a callout, sent email, published an event, or started asynchronous Apex. The transaction must not commit that action. |
| `RECORD_NO_LONGER_AVAILABLE` | Custom `UNABLE_TO_EVALUATE` / `ERROR` | A custom Apex Check can return this when a record disappears between applicability and evaluation. |
| `APEX_PASS` / `APEX_FAIL` | Custom `PASS` / `FAIL` | The installed `AccountHasRecentActivityCheck` example uses these codes. Custom Apex Checks may define their own stable Reason Codes. |
| `OBJECT_NOT_FOUND` | Custom | An example of a business-specific code that a custom Apex Check can return. Document every custom code used by your team. |

`PLUGIN_RESULT_UNKNOWN_KEY`, `PLUGIN_THREW`, and `PLUGIN_SIDE_EFFECT_DETECTED` are Apex exceptions raised by
`RecordHealthCheckPluginDispatch`. They are not ordinary per-record display outcomes. A null returned
map uses `PLUGIN_RESULT_MISSING` as a thrown fault; a missing key for one requested ID becomes a
per-record `ERROR` with that code.

---

## Tokens and message templates

| Code | Typical status | Meaning |
| --- | --- | --- |
| `TOKEN_NAMESPACE_REQUIRED` | `UNABLE_TO_EVALUATE` | Token omits the required namespace. See the example below the table. |
| `UNSUPPORTED_TOKEN_NAMESPACE` | `UNABLE_TO_EVALUATE` | Token namespace is not on the allowed list. |
| `UNKNOWN_TOKEN_PROPERTY` | `UNABLE_TO_EVALUATE` | Token property path is not recognized. |
| `TOKEN_NOT_ALLOWED_ON_SURFACE` | `UNABLE_TO_EVALUATE` | Token is used in a message, URL, or SOQL field that does not allow that token type. |
| `TOKEN_NOT_AVAILABLE_IN_PHASE` | `UNABLE_TO_EVALUATE` | Token needs a value that is not available at that point in the health check. |
| `TOKEN_FORMAT_NOT_ALLOWED` | `UNABLE_TO_EVALUATE` | `format="..."` is used outside display text or on a token other than `record.*`. |
| `UNKNOWN_TOKEN_FORMAT` | `UNABLE_TO_EVALUATE` | `format="..."` does not use one of the supported uppercase Value Format API names. |
| `MALFORMED_TOKEN` | `UNABLE_TO_EVALUATE` | Token syntax is malformed. |
| `TOKEN_LIMIT_EXCEEDED` | `UNABLE_TO_EVALUATE` | One template contains more than 100 merge tokens. Split or simplify it so one message cannot create disproportionate field discovery and resolution work. |
| `RESOLVED_TEMPLATE_TOO_LONG` | `UNABLE_TO_EVALUATE` | Completed text exceeded 20,000 characters. Shorten the template or inserted Salesforce values; Record Health Check does not return partial guidance. |

`TOKEN_NAMESPACE_REQUIRED` identifies a token that names a field without one of the documented
namespaces:

```text
{!Id fallback="not available"}
```

Rewrite it with the namespace, as `{!record.Id}`. Append a fallback only when a blank value needs a substitute, such as `{!record.Name fallback="this record"}`.

---

## Lightning card setup and loading

These often appear in card-level setup guidance rather than on a single Check row:

| Code | Meaning |
| --- | --- |
| `SETUP_REQUIRED` | No Check Set selected, or availability check fell back to setup guidance. |
| `NO_ACTIVE_CHECK_SETS` | No Check Sets exist for the page object. |
| `INACTIVE_CHECK_SETS_ONLY` | Check Sets exist but none are active. |
| `NO_ACTIVE_CHECKS` | Selected Check Set has no active Checks. |
| `LOAD_FAILED` | Definition load failed without a more specific reason. |

---

## Request and transaction errors

These values appear in a thrown Apex exception or a Flow error response rather than as the Reason
Code for one record:

| Code | Meaning |
| --- | --- |
| `NOT_AUTHORIZED` | The running user does not have the **Record Health Check Run** Custom Permission. |
| `INVALID_EVENT_PUBLICATION` | Apex or Flow supplied a value other than `NONE`, `ACTIONABLE`, or `ALL`. |
| `MAX_RECORDS_PER_SCOPE_EXCEEDED` | One direct Apex or Flow request supplied more than 200 records. Use Batch Apex or divide the work. |
| `FRAMEWORK_MAX_CHECKS_EXCEEDED` | A direct Apex or Flow request selected more than 25 active Checks. Reduce the active Checks in the Check Set. |
| `MAX_FLOW_GROUPS_EXCEEDED` | One Flow action call supplied more than 10 distinct Check or Check Set and Platform Event combinations. Divide the Flow inputs into fewer calls. |
| `FLOW_RESPONSE_BUDGET_EXCEEDED` | The JSON results returned by one Flow action call exceeded 2,000,000 characters. Request fewer records or reduce display content. |
| `PLUGIN_SAVEPOINT_BUDGET_EXCEEDED` | The selected custom Apex Checks would require more savepoint operations than the transaction can support. Run fewer Apex Checks together. |
| `TRANSACTION_BUDGET_EXCEEDED` | The planned Checks and Platform Events would exceed a protected Salesforce transaction limit. Reduce the number of Checks or records in the transaction. |
| `HEAP_BUDGET_EXCEEDED` | The planned response would require too much Apex memory. Reduce the number of Checks or records in the transaction. |

---

## Consumer guidance

1. Branch automation on `status` first, then `reasonCode`.
2. A future package version can add codes. Send an unknown code to a safe review path, or reject it
   when your process intentionally permits only a fixed list.
3. Keep diagnostics-only codes out of unauthorized user views; trust the remapped public `reasonCode`.
4. Log lines may mention events such as `DEPENDENCY_NOT_PASSED`; that is a **log event name**, not the public Check `reasonCode` (`PREREQUISITE_NOT_MET` is).

## Related

- [Apex API](../../api/apex-api.md)
- [Flow actions](../../integration/flow-actions.md)
- [Lifecycle events](../../integration/lifecycle-events.md)
- [Troubleshoot Record Health Check](../../guides/troubleshoot-with-show-diagnostics.md)
- [Architecture](../framework/architecture.md)
