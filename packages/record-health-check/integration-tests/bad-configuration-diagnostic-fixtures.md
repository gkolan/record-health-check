# Bad-configuration diagnostic fixtures

These integration-only Check Sets make diagnostics failures repeatable without editing production
configuration. Every Check is intentionally broken. Never deploy this directory to a customer org.

## What is included

| Check Set                    | Check                           | Expected status | Reason code               | Category             |
| ---------------------------- | ------------------------------- | --------------- | ------------------------- | -------------------- |
| `RHC_Diagnostic_Bad_Formula` | `RHC_Diag_Formula_Missing`      | Unable          | `INVALID_FORMULA`         | `FORMULA`            |
|                              | `RHC_Diag_Formula_Syntax`       | Unable          | `INVALID_FORMULA`         | `FORMULA`            |
|                              | `RHC_Diag_Formula_Null_Rel`     | Unable          | `FIELD_NOT_RESOLVED`      | `FORMULA`            |
| `RHC_Diagnostic_Bad_Query`   | `RHC_Diag_Query_Missing_Object` | Unable          | `OBJECT_NOT_RESOLVED`     | `QUERY`              |
|                              | `RHC_Diag_Query_Missing_Field`  | Unable          | `FIELD_NOT_RESOLVED`      | `QUERY`              |
|                              | `RHC_Diag_Query_Bad_Token`      | Unable          | `INVALID_CONFIG`          | `QUERY`              |
|                              | `RHC_Diag_Query_System_Mode`    | Unable          | `INVALID_SOQL_TEMPLATE`   | `QUERY`              |
|                              | `RHC_Diag_Query_Max_Rows`       | Unable          | `GOVERNOR_LIMIT_RISK`     | `QUERY`              |
|                              | `RHC_Diag_Compare_Missing`      | Unable          | `INVALID_SOQL_TEMPLATE`   | `QUERY`              |
| `RHC_Diagnostic_Bad_Apex`    | `RHC_Diag_Apex_Missing_Class`   | Unable          | `APEX_CLASS_NOT_FOUND`    | `APEX_CONFIGURATION` |
|                              | `RHC_Diag_Apex_Wrong_Interface` | Unable          | `APEX_CLASS_NOT_FOUND`¹   | `APEX_CONFIGURATION` |
|                              | `RHC_Diag_Apex_Bad_Json`        | Unable          | `INVALID_APEX_PARAMETERS` | `APEX_CONFIGURATION` |
|                              | `RHC_Diag_Apex_Constructor`     | Unable          | `APEX_CLASS_NOT_FOUND`¹   | `APEX_CONFIGURATION` |
|                              | `RHC_Diag_Apex_Throws`          | System Error    | `PLUGIN_THREW`            | `APEX_EXCEPTION`     |
|                              | `RHC_Diag_Apex_Missing_Result`  | System Error    | `PLUGIN_RESULT_MISSING`   | `APEX_CONTRACT`      |

`RHCDiagnosticBadConfigurationTest` asserts every row above, including a nonblank Diagnostic ID,
plain-language summary, and recommended action. It is included in `RHC_Negative_Conformance`.

¹ Current configuration preflight collapses wrong-interface and constructor-failure classes to
`APEX_CLASS_NOT_FOUND` before the plugin resolver can return `PLUGIN_INTERFACE_INVALID` or
`PLUGIN_CONSTRUCTOR_FAILED`. These fixtures lock down that limitation so a future classification
fix can update the test and runbook together.

## One-time setup

1. Create or select a contributor scratch org. Do not use a packaging, customer, or production org.
2. From `packages/record-health-check`, deploy `force-app`.
3. Deploy `integration-tests` explicitly.
4. Assign `Record_Health_Check_Admin` to the verification user.
5. Create an Account named `RHC Diagnostic Manual Verification` with no Parent Account.
6. Add three Record Health Check components to that Account record page.
7. Configure them with `RHC_Diagnostic_Bad_Formula`, `RHC_Diagnostic_Bad_Query`, and
   `RHC_Diagnostic_Bad_Apex` respectively.
8. Save and activate the record page, then open the fixture Account.

Commands for steps 2–4:

```bash
sf project deploy start --source-dir force-app --target-org <alias> --wait 30
sf project deploy start --source-dir integration-tests --target-org <alias> --wait 30
sf org assign permset --name Record_Health_Check_Admin --target-org <alias>
```

Run the automated contract first:

```bash
sf apex run test \
  --tests RHCDiagnosticBadConfigurationTest \
  --target-org <alias> \
  --result-format human \
  --wait 30
```

All 15 fixture assertions must pass. Alternatively run the complete negative gate:

```bash
npm run test:war-room -- --alias <alias>
```

## Agentforce and MCP surface verification

`RHCDiagnosticAgentMcpSurfaceTest` executes every one of the 15 bad Checks through both public
surfaces:

- the native `RecordHealthCheckRunCheckAgentAction` Agentforce action; and
- the versioned REST adapter consumed by `run_record_health_check` in the MCP server.

It also executes all three bad Check Sets through the native Set action and the MCP REST adapter.
That is 36 cross-surface fixture evaluations: 15 Check × 2 surfaces plus 3 Check Set × 2 surfaces.
Every response must remain ERROR or UNABLE_TO_EVALUATE, set `success = true`, and include a
Diagnostic ID, category, summary, and recommended action. The Set cases additionally require a
nonzero unable/system-error count. Run it with:

```bash
sf apex run test \
  --tests RHCDiagnosticAgentMcpSurfaceTest \
  --target-org <alias> \
  --result-format human \
  --wait 30
```

Then verify the hosted MCP protocol adapter, response validation, and both registered tools:

```bash
npm run check:mcp
```

The MCP test matrix covers Check and Check Set results for Formula, Query, Apex exception, and Apex
contract diagnoses. It rejects any ERROR/UNABLE response that loses one of the four required
diagnostic fields. It also asserts that an inconclusive configured evaluation is distinguishable
from an adapter error: it retains `operation` and `status`, while authorization, validation, limit,
and transport/execution failures use `errorType` and `errorMessage`.

For the agent planner layer, generate a runnable suite from
`agentforce/Record_Health_Assistant-testing-center.yaml.template` with the Accounts created for the org; do
not import the tracked synthetic-ID template directly. Then
create and run the Testing Center suite:

```bash
sf agent test create \
  --spec /tmp/record-health-testing-center.yaml \
  --api-name Record_Health_Assistant_War_Room \
  --target-org <alias> \
  --force-overwrite
sf agent test run \
  --api-name Record_Health_Assistant_War_Room \
  --target-org <alias> \
  --wait 30 \
  --result-format json
```

The six seeded negative planner cases cover a Formula Check, Query Check, Apex Check, and all three
bad Check Sets. Confirm the expected action is invoked exactly once, the agent never translates an
inconclusive result into PASS/healthy, and its answer includes the safe diagnosis, first action,
and Diagnostic ID without exposing query text, formula text, field values, or stack traces.

## Verification pattern for every Check

For each fixture below:

1. Click **Run** on its Check Set card.
2. Find the named Check and confirm its visible status.
3. Confirm the gray diagnostic metadata contains the expected reason code.
4. On the card, read **Issue**, **Where**, and **Why**; none may be blank.
5. In the browser console, expand the named Check and confirm **Fix** and **Verify** are present.
6. Expand **Advanced diagnostics** and confirm a Diagnostic ID beginning with `RHC-` is present.
7. Confirm the named configuration field and values below are visible.
8. Expand **Support report for this check**. Confirm it identifies the Check and run, then review
   and redact any query text, record or user IDs, exception context, source values, or customer data
   before sharing it.
9. When event publication is enabled, correlate the same Diagnostic ID and Run ID in
   `Record_Health_Check_Log__e.DetailsJson__c`.

## Formula fixtures

### 1. Missing pass formula

1. Run `RHC_Diagnostic_Bad_Formula`.
2. Open **Missing Pass Formula**.
3. Expect Unable, `INVALID_FORMULA`, category `FORMULA`, phase `PASS_CONDITION_FORMULA`.
4. In Advanced evidence, verify `evaluationType = FORMULA` and that no
   `passConditionFormula` value exists.
5. The fix must direct the administrator to correct the Formula configuration.

### 2. Malformed formula syntax

1. Open **Malformed Formula Syntax**.
2. Expect Unable, `INVALID_FORMULA`, category `FORMULA`.
3. Advanced evidence must show `AND(NOT(ISBLANK(Name)),` as `passConditionFormula`.
4. Why must contain the Salesforce Formula parsing failure; Where must identify the pass-condition
   Formula phase.

### 3. Null relationship formula

1. Ensure the fixture Account has no Parent Account.
2. Open **Null Parent Relationship**.
3. Expect Unable, `FIELD_NOT_RESOLVED`, category `FORMULA`.
4. Advanced evidence must show `Parent.Name = "Required Parent"`.
5. Verify the diagnosis distinguishes an indeterminate Formula from a business Fail.

## Query fixtures

### 4. Missing object

1. Run `RHC_Diagnostic_Bad_Query` and open **Missing Query Object**.
2. Expect Unable, `OBJECT_NOT_RESOLVED`, category `QUERY`, source-query phase.
3. Advanced evidence must show `RHC_Definitely_Missing__c` in the template and a query-resolution
   error. The fix must point to object/schema configuration.

### 5. Missing field

1. Open **Missing Query Field**.
2. Expect Unable, `FIELD_NOT_RESOLVED`, category `QUERY`.
3. Advanced evidence must show both the query template and
   `sourceQueryField = RHC_Definitely_Missing__c`.
4. Confirm the diagnosis does not incorrectly describe this as an Apex failure.

### 6. Malformed merge token

1. Open **Malformed Merge Token**.
2. Expect Unable, `INVALID_CONFIG`, category `QUERY`.
3. Advanced evidence must retain the unclosed `{!record.Id` template and show its resolution error.
4. The fix must direct the administrator to edit query configuration.

### 7. Forbidden system mode

1. Open **Forbidden System Mode**.
2. Expect Unable, `INVALID_SOQL_TEMPLATE`, category `QUERY`.
3. Advanced evidence must show `WITH SYSTEM_MODE` in the template.
4. Confirm no elevated query executes and the diagnosis says to correct the query.

### 8. Unsafe maximum rows

1. Open **Unsafe Maximum Rows**.
2. Expect Unable, `GOVERNOR_LIMIT_RISK`, category `QUERY`.
3. Advanced evidence must show `maxQueryRows = 2001`.
4. Confirm the Check stops before executing the Contact query.

### 9. Missing comparison query

1. Open **Missing Comparison Query**.
2. Expect Unable, `INVALID_SOQL_TEMPLATE`, category `QUERY`, comparison-query phase.
3. Advanced evidence must show the source query but no comparison query template.
4. Where or the evidence must identify the comparison side rather than the source side.

## Apex fixtures

### 10. Missing class

1. Run `RHC_Diagnostic_Bad_Apex` and open **Missing Apex Class**.
2. Expect Unable, `APEX_CLASS_NOT_FOUND`, category `APEX_CONFIGURATION`.
3. Advanced evidence must show `apexClass = RHCClassThatCannotExist`.
4. The fix must identify `ApexClass__c` and ask the administrator to verify deployment and name.

### 11. Wrong interface

1. Open **Apex Class Has Wrong Interface**.
2. Expect Unable, `APEX_CLASS_NOT_FOUND`, category `APEX_CONFIGURATION` under current preflight
   behavior.
3. Advanced evidence must show `RHCDiagnosticWrongInterface`.
4. Why must say the class does not implement `RecordHealthCheckPlugin`.

### 12. Malformed parameters JSON

1. Open **Malformed Apex Parameters**.
2. Expect Unable, `INVALID_APEX_PARAMETERS`, category `APEX_CONFIGURATION`.
3. Advanced evidence must show the malformed `{"broken":` parameters value.
4. The fix must identify `ApexParametersJson__c` and require a JSON object.

### 13. Constructor failure

1. Open **Apex Constructor Throws**.
2. Expect Unable, `APEX_CLASS_NOT_FOUND`, category `APEX_CONFIGURATION` under current preflight
   behavior.
3. Record the classification gap: target behavior is System Error, `PLUGIN_CONSTRUCTOR_FAILED`,
   with the deliberate constructor message and construction phase.
4. Confirm the current card still provides a corrective action and Diagnostic ID.

### 14. Runtime exception

1. Open **Apex Evaluate Throws**.
2. Expect System Error, `PLUGIN_THREW`, category `APEX_EXCEPTION`.
3. Where must identify `RHCDiagnosticThrowingPlugin.evaluate` and its source line.
4. Why must contain `Deliberate diagnostic fixture failure`.
5. Advanced evidence must show the configured class, and the event must retain exception type and
   stack trace.

### 15. Missing result contract

1. Open **Apex Omits Record Result**.
2. Expect System Error, `PLUGIN_RESULT_MISSING`, category `APEX_CONTRACT`.
3. Why must explain that no outcome was returned for the requested Account.
4. Fix must instruct the developer to return one outcome keyed by every requested record ID.

## Bad configurations that cannot be persistent metadata

Salesforce rejects some invalid picklist values or broken metadata relationships during deployment.
Those cases cannot coexist in a successfully deployed fixture catalog. They remain covered by
`RHCConfigCheckValidationTest` and `RecordHealthCheckMetadataValidatorTest`:

- unknown Evaluation Type, operator, applicability mode, null/empty policy, or display format;
- missing Check Title, Evaluation Order, Failure Message, or Severity;
- invalid prerequisite relationship, dependency outside the run, or dependency cycle;
- more than 25 active Checks;
- incompatible list/single-result operator combinations;
- invalid currency unit/type combinations; and
- unsupported template tokens in non-query message, action, and display fields.

To verify these, run both classes and inspect their one-scenario assertions:

```bash
sf apex run test \
  --tests RHCConfigCheckValidationTest \
  --tests RecordHealthCheckMetadataValidatorTest \
  --target-org <alias> \
  --result-format human \
  --wait 30
```

The correct expected behavior for this group is either a deployment/metadata-validation failure or
an `UNABLE_TO_EVALUATE` result with a stable configuration reason. It must never become Pass or Fail.
