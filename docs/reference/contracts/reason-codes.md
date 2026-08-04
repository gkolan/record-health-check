# Reference: Reason Codes

> [!NOTE]
> On this page, translate a stable Reason Code into the Framework decision that produced it and the first useful Salesforce configuration, access, query, Formula, Apex, or token check to perform.

Use this registry to translate a stable **Reason Code** into its status, meaning, and first useful
investigation. Reason Codes let administrators and integrations identify causes without interpreting
administrator-authored display messages.

## How to use a Reason Code

| Surface | Use the code to… |
| --- | --- |
| Card or Setup investigation | Decide whether to inspect applicability, dependencies, field access, Formula configuration, SOQL, or Apex |
| Flow | Route a known non-normal result without treating display text as an API |
| Apex | Branch or log using a stable `UPPER_SNAKE_CASE` value |
| Support or release review | Correlate the public result with authorized Show Diagnostics and logs |

Reason Codes explain why a Rule did not produce a normal `PASS` or `FAIL`, or why a card could not
load. Codes are additive `UPPER_SNAKE_CASE` strings. Integrations must key on the code, never on
display text.

> [!IMPORTANT]
> **Public vs diagnostics-only:** `FIELD_NOT_ACCESSIBLE` and `RECORD_NOT_ACCESSIBLE` never appear as the public `reasonCode` on a result. The engine remaps them to `CANNOT_EVALUATE`. When **Show Diagnostics** is on and the user has `Record_Health_Check_View_Diagnostics`, the specific code is available on `adminDetail.reasonCode`.

The Framework uses a neutral public code because revealing whether a hidden record or field exists
can disclose Salesforce access information to someone who is not allowed to see it. Authorized
administrators still receive the specific cause through Show Diagnostics, where they can distinguish
a missing record from missing field access without weakening the normal user's security boundary.

Registry helpers for the remapped pair live in `RecordHealthCheckReasonCodes`. Other codes are returned directly by the engine, evaluators, template service, LWC, or plugins.

---

## Applicability and prerequisites

| Code | Typical status | Meaning |
| --- | --- | --- |
| `NOT_APPLICABLE_BY_FORMULA` | `SKIPPED` | Applicability mode `WHEN_FORMULA_TRUE` returned false. |
| `NOT_APPLICABLE_BY_COUNT` | `SKIPPED` | Applicability count check was not met. |
| `PREREQUISITE_NOT_MET` | `SKIPPED` | Prerequisite Rule did not return `PASS`. |
| `STOPPED_AFTER_ERROR` | `SKIPPED` | Client stopped the remaining checks after a system error. |
| `CLIENT_CALL_FAILED` | `ERROR` | The browser could not complete the Apex evaluation request. |
| `MALFORMED_RESPONSE` | `ERROR` | Apex returned a result without the required shape. |
| `UNKNOWN_RESULT_STATUS` | `ERROR` | Apex returned an unsupported result status. |
| `MISSING_TOKEN_VALUE` | `UNABLE_TO_EVALUATE` | A required merge-token value was unavailable. |
| `CIRCULAR_DEPENDENCY` | `UNABLE_TO_EVALUATE` | Prerequisite cycle detected (LWC may pre-seed without calling Apex). |
| `DEPENDENCY_NOT_IN_RUN` | `SKIPPED` | The Prerequisite Rule was not included in the Framework run because it was inactive, missing, ordered after the Rule that requires it, or outside the first 25 active Rules. Apex and the Lightning component enforce the same behavior. |
| `APPLICABILITY_NOT_MET` | `SKIPPED` | Query empty-result path chose skip via `NoRowsResult__c = SKIP` (distinct from applicability checks above). |
| `VALUE_IS_EMPTY` | `SKIPPED` | Row comparison skipped because a compared field value was empty under `EmptyValueHandling__c = SKIP_RECORD`. |

---

## Access and permissions

| Code | Typical status | Visibility | Meaning |
| --- | --- | --- | --- |
| `CANNOT_EVALUATE` | `UNABLE_TO_EVALUATE` | Public | Neutral substitute when a diagnostics-only access code is remapped. |
| `FIELD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only (remapped publicly) | Required field not readable in user mode. |
| `RECORD_NOT_ACCESSIBLE` | `UNABLE_TO_EVALUATE` | Diagnostics only (remapped publicly) | Record not readable in user mode / missing context. |
| `NO_RECORD_CONTEXT` | `UNABLE_TO_EVALUATE` | Public | Evaluation called without a usable record Id. |

---

## Configuration and identity

| Code | Typical status | Meaning |
| --- | --- | --- |
| `CONFIG_NOT_FOUND` | `UNABLE_TO_EVALUATE` / setup | Check Set DeveloperName not found. |
| `CONFIG_INACTIVE` | `UNABLE_TO_EVALUATE` / setup | Check Set is inactive. |
| `OBJECT_MISMATCH` | `UNABLE_TO_EVALUATE` / setup | Check Set object does not match the record. |
| `RULE_NOT_FOUND` | `UNABLE_TO_EVALUATE` | Rule DeveloperName not found in the Check Set. |
| `RULE_INACTIVE` | `UNABLE_TO_EVALUATE` | Rule is inactive. |
| `INVALID_CHECK_TYPE` | `UNABLE_TO_EVALUATE` | Evaluation Type missing or unrecognized. |
| `INVALID_CONFIG` | definition / unable | Invalid Check Set display or identity configuration. |
| `MISSING_REQUIRED_FIELD` | validation | A required Check Set or Rule field (e.g. Base Object API Name, Card Title) is blank (deploy/CI validator). |
| `CHECK_LIMIT_EXCEEDED` | definition / validation | More than 25 active Rules selected for a run (runtime omit + validator). |
| `INVALID_DEPENDENCY` | validation | Prerequisite metadata is invalid (deploy/CI validator). |

---

## Query and comparison

| Code | Typical status | Meaning |
| --- | --- | --- |
| `INVALID_SOQL_TEMPLATE` | `UNABLE_TO_EVALUATE` | SOQL template failed safety or parse checks. |
| `INVALID_OPERATOR` | `UNABLE_TO_EVALUATE` | Comparison operator missing or illegal for this Rule shape. |
| `INCOMPATIBLE_COMPARISON_TYPES` | `UNABLE_TO_EVALUATE` | Ordered comparison cannot convert the two sides safely. |
| `MULTIPLE_ROWS_RETURNED` | `UNABLE_TO_EVALUATE` | `ONE_RESULT` expected one row/aggregate but got more. |
| `NO_ROWS_RETURNED` | `UNABLE_TO_EVALUATE` | Empty result handled as unable (`NoRowsResult__c = UNABLE_TO_EVALUATE`). |
| `MISSING_BIND_VALUE` | `UNABLE_TO_EVALUATE` | Merge token required for SOQL bind could not be resolved. |
| `GOVERNOR_LIMIT_RISK` | `UNABLE_TO_EVALUATE` | The Framework stopped before the query could consume an unsafe share of the transaction's remaining Salesforce limits. Reduce the Rule's row limit or narrow its SOQL. |

---

## Formula

| Code | Typical status | Meaning |
| --- | --- | --- |
| `INVALID_FORMULA` | `UNABLE_TO_EVALUATE` | Formula failed to compile/evaluate or returned a non-boolean where required. |
| `FORMULA_EVAL_LIMIT` | `UNABLE_TO_EVALUATE` | The Framework stopped before the transaction reached Salesforce's hard formula-evaluation limit, preserving a controlled result instead of risking an uncatchable transaction failure. Reduce the Rules evaluated together. |

---

## Apex plugins

| Code | Typical status | Meaning |
| --- | --- | --- |
| `APEX_CLASS_NOT_FOUND` | `UNABLE_TO_EVALUATE` | `ApexClass__c` could not be resolved to a `RecordHealthCheckRule`. Confirm the class API name, packaging namespace, and `RecordHealthCheckRule` implementation. |
| `INVALID_APEX_PARAMETERS` | `UNABLE_TO_EVALUATE` | `ApexParametersJson__c` is not valid JSON object input. |
| `APEX_EVALUATOR_ERROR` | `ERROR` / `UNABLE_TO_EVALUATE` | Plugin returned an illegal status or omitted required Found/Expected on `PASS`/`FAIL`. |
| `PLUGIN_RESULT_MISSING` | `ERROR` (per record) or thrown contract fault | The plugin returned no entry for a requested record, or returned a null map for the whole scope. Cover every requested ID, including empty scopes. |
| `PLUGIN_RESULT_UNKNOWN_KEY` | Thrown contract fault | The plugin returned an outcome for a record ID outside the requested scope. Fails the whole Rule for the scope. |
| `PLUGIN_THREW` | Thrown contract fault | The plugin threw an unhandled exception the engine cannot attribute to one record. |
| `PLUGIN_SIDE_EFFECT_DETECTED` | Thrown contract fault | The plugin performed DML, a callout, email, event publication, or asynchronous work. The transaction must not commit that effect. |
| `RECORD_NO_LONGER_AVAILABLE` | Plugin-authored `UNABLE_TO_EVALUATE` / `ERROR` | Stable code plugins may return when a record disappeared between applicability and evaluation. |
| `OBJECT_NOT_FOUND` | plugin-defined | Example plugins may return domain-specific codes such as this. |

`PLUGIN_RESULT_UNKNOWN_KEY`, `PLUGIN_THREW`, and `PLUGIN_SIDE_EFFECT_DETECTED` are contract faults raised by
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
| `TOKEN_NOT_ALLOWED_ON_SURFACE` | `UNABLE_TO_EVALUATE` | Token used on a message/query surface that forbids it. |
| `TOKEN_NOT_AVAILABLE_IN_PHASE` | `UNABLE_TO_EVALUATE` | Token requires data not available in this resolution phase. |
| `MALFORMED_TOKEN` | `UNABLE_TO_EVALUATE` | Token syntax is malformed. |
| `TOKEN_LIMIT_EXCEEDED` | `UNABLE_TO_EVALUATE` | One template contains more than 100 merge tokens. Split or simplify it so one message cannot create disproportionate field discovery and resolution work. |
| `RESOLVED_TEMPLATE_TOO_LONG` | `UNABLE_TO_EVALUATE` | Completed text exceeded 20,000 characters. Shorten the template or inserted Salesforce values; the Framework does not return truncated guidance. |

`TOKEN_NAMESPACE_REQUIRED` identifies a token that names a field without one of the documented
namespaces:

```text
{!Id fallback="not available"}
```

Rewrite it with the namespace, as `{!record.Id}`. Append a fallback only when a blank value needs a substitute, such as `{!record.Name fallback="this record"}`.

---

## Card setup / load (LWC and definition response)

These often appear on the card chrome rather than a single Rule row:

| Code | Meaning |
| --- | --- |
| `SETUP_REQUIRED` | No Check Set selected, or availability check fell back to setup guidance. |
| `NO_ACTIVE_CHECK_SETS` | No Check Sets exist for the page object. |
| `INACTIVE_CHECK_SETS_ONLY` | Check Sets exist but none are active. |
| `NO_ACTIVE_CHECKS` | Selected Check Set has no active Rules. |
| `LOAD_FAILED` | Definition load failed without a more specific reason. |

---

## Consumer guidance

1. Branch automation on `status` first, then `reasonCode`.
2. Treat unknown future codes as additive: route unrecognized codes to a safe review path (or keep an intentionally strict allowed list when your process requires one).
3. Keep diagnostics-only codes out of unauthorized user views; trust the remapped public `reasonCode`.
4. Log lines may mention events such as `DEPENDENCY_NOT_PASSED`; that is a **log event name**, not the public Rule `reasonCode` (`PREREQUISITE_NOT_MET` is).

## Related

- [Apex API](../../api/apex-api.md)
- [Flow actions](../../integration/flow-actions.md)
- [Lifecycle events](../../integration/lifecycle-events.md)
- [Troubleshoot with Show Diagnostics](../../guides/troubleshoot-with-show-diagnostics.md)
- [Architecture](../framework/architecture.md)
