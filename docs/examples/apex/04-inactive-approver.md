# 04 · Stalled Approval Identifies Inactive Approvers

> [!NOTE]
> On this page, build a defensive Apex Rule that identifies inactive users on pending approval steps, names the people blocking progress, and returns a safe outcome when approval data is unavailable.
>
> **Setup reference**
>
> Use the [Apex reference](../../reference/evaluation/apex-rule-contract.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> The supporting Apex class for this example lives under `integration-tests/`. It does not install
> with the Framework package. Deploy or copy the class when you want this Rule in an org.

## Scenario

A Salesforce administrator opens a record whose approval has stopped moving.

- A pending step may still belong to someone who has left the company.
- The approval history alone does not give the administrator a quick list of inactive assignees.
- The administrator needs the affected names before reassigning the work to active users.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check names inactive users assigned to pending approval steps, giving the administrator a specific reason the approval may have stopped and a clear reassignment task.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Inspect approval-related Salesforce data | Apex follows approval assignments to participating users. |
| Account for product-specific objects | The implementation isolates assumptions that depend on licensed Salesforce features. |
| Return a safe operational result | The Rule distinguishes inactive participants from an inability to inspect approval data. |
| Stop a Check Set after a system error | The Check Set can prevent later Rules from running after an unexpected `ERROR`. |

## What the card shows

| Card value | Healthy chain | Inactive assignee | Product/configuration unavailable |
| --- | --- | --- | --- |
| **Status** | `PASS` | `FAIL` | `UNABLE_TO_EVALUATE` |
| **Found / Expected** | `0 inactive` / `0 inactive` | `<N> inactive` / `0 inactive` | Not applicable |
| **Message** | None | Configured failure guidance; Found lists the inactive users | Configured unable-to-evaluate message |

## Why use Verify with Apex

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with Apex** | Best fit. The class uses the approval object and field names confirmed by the administrator and lists every inactive assignee it finds. |
| **Verify with a query** | Can count inactive assignees but cannot list all of their names in one result. |
| **Verify with a formula** | Cannot review related approval steps and the Active field on each assigned User. |

## What Record Health Check passes to Apex

Shared scope inputs are documented once in the
[Apex examples README](README.md#what-record-health-check-passes-to-apex). This Rule receives the
evaluated record Ids and package-specific object/field names in JSON.

```apex
List<Id> targetRecordIds = scope.recordIds;
```

This example uses dynamic SOQL because the Advanced Approvals package is optional. It still binds
the supplied record Id instead of joining it into the query text.

## Step 1:
## Step 1: Understand the parameters

This Rule uses one JSON object with the package-specific object and field names:

```json
{
  "approvalObject": "sbaa__Approval__c",
  "targetField": "sbaa__TargetRecordId__c",
  "userField": "sbaa__User__c",
  "statusField": "sbaa__Status__c",
  "pendingStatuses": ["Requested"]
}
```

After deploying the class:

1. In Object Manager, confirm every illustrative `sbaa__*` API name and status value in your org.
2. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
3. Create or edit the Rule record.
4. Paste the corrected object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON and supplies the named settings as `scope.parameters`.
Blank settings use the class defaults, and an empty status list uses `Requested`. See
[Parameter parsing patterns](../../reference/evaluation/apex-rule-contract.md#scope)
for validation and type-conversion guidance.

## Implementation summary

The class verifies that the object exists, executes bind-based dynamic SOQL in user mode, then
queries assigned Users for `IsActive = FALSE` with `WITH USER_MODE`.

No assigned users or only active users passes. Inactive users fail with a typed Found list; the
framework renders that list and applies its standard preview limit. A missing object returns
`OBJECT_NOT_FOUND`; invalid fields or SOQL return `INVALID_SOQL_TEMPLATE`. Both are unable to
evaluate, never a false pass. Blank settings retain defaults, and an empty status list retains
`Requested`.

## Step 2: Create the Apex class

This is the complete class deployed by the pack. Comments explain the Record Health Check inputs, administrator settings, user access, pass logic, and returned values.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example RecordHealthCheckRule that flags pending approval steps whose assigned
 * user is inactive, and names the offending user(s) in the failure message.
 * Built for Salesforce Advanced Approvals (managed package "sbaa"), but every
 * object and field API name is read dynamically and may be overridden through
 * ApexParametersJson__c. Because nothing references the managed package at compile
 * time, this class compiles and deploys in orgs that do NOT have Advanced
 * Approvals installed. It returns UNABLE_TO_EVALUATE when that object is unavailable.
 * {"approvalObject":"sbaa__Approval__c","targetField":"sbaa__TargetRecordId__c"
 * "userField":"sbaa__User__c","statusField":"sbaa__Status__c",
 * "pendingStatuses":["Requested"]}
 */
global with sharing class ApprovalInactiveApproverCheck implements RecordHealthCheckRule {
  @TestVisible
  private static final String DEFAULT_APPROVAL_OBJECT = 'sbaa__Approval__c';
  @TestVisible
  private static final String DEFAULT_TARGET_FIELD = 'sbaa__TargetRecordId__c';
  @TestVisible
  private static final String DEFAULT_USER_FIELD = 'sbaa__User__c';
  @TestVisible
  private static final String DEFAULT_STATUS_FIELD = 'sbaa__Status__c';
  private static final List<String> DEFAULT_PENDING_STATUSES = new List<String>{
    'Requested'
  };

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    List<Id> recordIds = scope.recordIds;
    Settings settings = resolveSettings(scope.parameters);
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();

    // Graceful degradation: the approval object is absent (Advanced Approvals
    // not installed, or a custom object name was mistyped). Every record in the
    // scope gets the same honest answer rather than a false PASS.
    if (
      !RecordHealthCheckDescribeCache.containsObject(settings.approvalObject)
    ) {
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('OBJECT_NOT_FOUND')
        );
      }
      return results;
    }

    Map<Id, Set<Id>> assignedByRecord;
    try {
      assignedByRecord = fetchAssignedUserIds(recordIds, settings);
    } catch (Exception ex) {
      // A bad field name or malformed dynamic query surfaces as can't-run,
      // never as a false PASS.
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('INVALID_SOQL_TEMPLATE')
        );
      }
      return results;
    }

    // One User query for every approver across the whole scope.
    Set<Id> allAssignees = new Set<Id>();
    for (Set<Id> perRecord : assignedByRecord.values()) {
      allAssignees.addAll(perRecord);
    }
    Map<Id, String> inactiveNames = loadInactiveNames(allAssignees);

    for (Id recordId : recordIds) {
      results.put(
        recordId,
        buildOutcome(assignedByRecord.get(recordId), inactiveNames, settings)
      );
    }
    return results;
  }

  /**
   * The only managed-package-dependent step: a dynamic query over the approval
   * object. Isolated so the rest of the logic stays unit-testable without the
   * package, and so a configuration error is caught and reported cleanly.
   *
   * The target field is selected as well as filtered on, because that is what
   * attributes each returned row back to the record it belongs to.
   */
  private Map<Id, Set<Id>> fetchAssignedUserIds(
    List<Id> recordIds,
    Settings settings
  ) {
    Map<Id, Set<Id>> byRecord = new Map<Id, Set<Id>>();
    for (Id recordId : recordIds) {
      byRecord.put(recordId, new Set<Id>()); // no pending approvals is a real answer
    }

    String soql =
      'SELECT ' +
      settings.targetField +
      ', ' +
      settings.userField +
      ' FROM ' +
      settings.approvalObject +
      ' WHERE ' +
      settings.targetField +
      ' IN :recordIds' +
      ' AND ' +
      settings.statusField +
      ' IN :pendingStatuses' +
      ' AND ' +
      settings.userField +
      ' != null';
    Map<String, Object> binds = new Map<String, Object>{
      'recordIds' => recordIds,
      'pendingStatuses' => settings.pendingStatuses
    };
    for (
      SObject row : Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)
    ) {
      Object target = row.get(settings.targetField);
      Object assignee = row.get(settings.userField);
      if (target == null || assignee == null) {
        continue;
      }
      Set<Id> bucket = byRecord.get((Id) target);
      if (bucket != null) {
        bucket.add((Id) assignee);
      }
    }
    return byRecord;
  }

  @TestVisible
  private static Map<Id, String> loadInactiveNames(Set<Id> assignedUserIds) {
    Map<Id, String> names = new Map<Id, String>();
    if (assignedUserIds == null || assignedUserIds.isEmpty()) {
      return names;
    }
    for (User assignee : [
      SELECT Id, Name
      FROM User
      WHERE Id IN :assignedUserIds AND IsActive = FALSE
      WITH USER_MODE
      ORDER BY Name
    ]) {
      names.put(assignee.Id, assignee.Name);
    }
    return names;
  }

  /**
   * Standard-object logic that is fully unit-testable without the managed package.
   * Takes the scope-wide inactive-user lookup and resolves one record's verdict
   * from it, so no query happens per record.
   */
  @TestVisible
  private RecordHealthCheckOutcome buildOutcome(
    Set<Id> assignedUserIds,
    Map<Id, String> inactiveNames,
    Settings settings
  ) {
    RecordHealthCheckValue expected = RecordHealthCheckValue.ofList(
      new List<String>()
    );
    if (assignedUserIds == null || assignedUserIds.isEmpty()) {
      return RecordHealthCheckOutcome.pass('APEX_PASS')
        .withFound(RecordHealthCheckValue.ofList(new List<String>()))
        .withComparison('EQUALS', expected);
    }

    List<String> inactive = new List<String>();
    for (Id assignee : assignedUserIds) {
      String name = inactiveNames.get(assignee);
      if (name != null) {
        inactive.add(name);
      }
    }
    inactive.sort();

    // The names ARE the finding, carried as a typed list so the engine can
    // render them. The check does not write the sentence itself: prose, and how
    // many names to show before truncating, are display decisions the core owns.
    RecordHealthCheckOutcome outcome = inactive.isEmpty()
      ? RecordHealthCheckOutcome.pass('APEX_PASS')
      : RecordHealthCheckOutcome.fail('APEX_FAIL');
    return outcome
      .withFound(RecordHealthCheckValue.ofList(inactive))
      .withComparison('EQUALS', expected);
  }

  @TestVisible
  private class Settings {
    public String approvalObject = DEFAULT_APPROVAL_OBJECT;
    public String targetField = DEFAULT_TARGET_FIELD;
    public String userField = DEFAULT_USER_FIELD;
    public String statusField = DEFAULT_STATUS_FIELD;
    public List<String> pendingStatuses = DEFAULT_PENDING_STATUSES.clone();
  }

  @TestVisible
  private Settings resolveSettings(Map<String, Object> parameters) {
    Settings settings = new Settings();
    if (parameters == null) {
      return settings;
    }
    settings.approvalObject = stringOr(
      parameters.get('approvalObject'),
      settings.approvalObject
    );
    settings.targetField = stringOr(
      parameters.get('targetField'),
      settings.targetField
    );
    settings.userField = stringOr(
      parameters.get('userField'),
      settings.userField
    );
    settings.statusField = stringOr(
      parameters.get('statusField'),
      settings.statusField
    );

    Object statusesRaw = parameters.get('pendingStatuses');
    if (statusesRaw instanceof List<Object>) {
      List<String> statuses = new List<String>();
      for (Object value : (List<Object>) statusesRaw) {
        if (value != null && String.isNotBlank(String.valueOf(value))) {
          statuses.add(String.valueOf(value));
        }
      }
      if (!statuses.isEmpty()) {
        settings.pendingStatuses = statuses;
      }
    }

    return settings;
  }

  private static String stringOr(Object raw, String fallback) {
    if (raw instanceof String && String.isNotBlank((String) raw)) {
      return (String) raw;
    }
    return fallback;
  }
}
```

<!-- END GENERATED APEX CLASS -->

## Context and result contract

Record Health Check calls the plugin once for a scope:

```apex
Map<Id, RecordHealthCheckOutcome> evaluate(RecordHealthCheckScope scope)
```

The context contains:

| Scope field | Type | What it contains |
| --- | --- | --- |
| `recordIds` | `List<Id>` | Detached, deduplicated IDs to evaluate; use the collection in bulk SOQL |
| `objectApiName` | `String` | API name shared by every ID in the scope |
| `parameters` | `Map<String, Object>` | Parsed **Apex Parameters (JSON)**; an empty map when JSON is blank |
| `ruleDeveloperName` | `String` | Qualified Rule identity (property name is historical; value is the Rule QualifiedApiName) |
| `checkSetDeveloperName` | `String` | Qualified Check Set identity (property name is historical; value is the Check Set QualifiedApiName) |
| `runId` | `String` | Correlation identifier for the evaluation run |

The returned map must contain exactly one entry for every requested ID. Build each outcome with a
status factory and typed values:

| Outcome field | What the class must return |
| --- | --- |
| `status` | An outcome created by `pass`, `fail`, `unableToEvaluate`, or `skipped` |
| `reasonCode` | A stable, nonblank code that explains the programmatic reason |
| `found` | A typed `RecordHealthCheckValue` describing what the class observed |
| `comparisonOperator` | The operator behind the decision, such as `EQUALS` |
| `expected` | A typed `RecordHealthCheckValue` describing the passing requirement |

For applicability, configure **Applies To** on the Rule so Record Health Check skips before Apex
runs. The framework supplies identity, label, severity, messages, display values, and diagnostics.
Missing or extra map keys, a null outcome, an invalid status, forbidden side effects, or an
unhandled exception produces `APEX_EVALUATOR_ERROR`, not a pass. See
[Returning an outcome](../../reference/evaluation/apex-rule-contract.md#outcome).


## Step 3: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Approval_No_Inactive_Approvers` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | No Inactive Approvers In Chain |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | No Inactive Approvers In Chain |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/fields-check-rule.md#apex-class-apexclass__c) | `ApprovalInactiveApproverCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/fields-check-rule.md#apex-parameters-json-apexparametersjson__c) | `{"approvalObject":"sbaa__Approval__c","targetField":"sbaa__TargetRecordId__c","userField":"sbaa__User__c","statusField":"sbaa__Status__c","pendingStatuses":["Requested"]}` (**Confirm in your org**) |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Fails when a pending Advanced Approvals step is assigned to an inactive user. Confirm all object and class API names before activation. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | One or more pending approval steps are assigned to an inactive user. Reassign the approver before submitting for approval. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Could not check approvers: confirm Advanced Approvals is installed and the object and field API names in Apex Parameters (JSON) are correct for this org. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank unless another Rule first proves an approval request exists. |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Reassign each inactive approver named in the failure message to an active user. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | Leave blank until the org's approval-management destination is verified. |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | Leave blank; managed-package pages and URLs can vary by installed version. |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `40` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Unchecked: activate only after confirming object and class API names and tests. |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

> [!IMPORTANT]
> Leave the Rule **inactive** while you configure and test this example. Before activation, verify
> `approvalObject`, `targetField`, `userField`, `statusField`, and `pendingStatuses` against the
> installed product's fields in **Setup → Object Manager** (**Confirm in your org**).

The class supplies a failure message that names inactive users, so it replaces **Message When
Failed** when the Rule fails. Keep the metadata message as a safe general message in case the class
cannot provide names. Formula, Query, and Compare two queries fields do not apply.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Apex_Readiness` |
| **Object** | `Account` |
| **Card Title** | `Account Readiness` |
| **Card Subtitle** | Confirm pending approval assignees are still active users. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Checked; later Rules do not run after this Rule returns `ERROR` |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

The Check Set can remain active while you build this example, but leave this Rule inactive until
you verify its Advanced Approvals API names and complete the tests below.
**Stop after a system error** affects only `ERROR`; it does not stop the Check Set after `FAIL`,
`SKIPPED`, or `UNABLE_TO_EVALUATE`.

## What the user sees

The Apex class result becomes these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | No inactive assignees are assigned to pending approval steps. |
| **`FAIL`** | One or more inactive assignees shows Needs attention with Critical severity and names the affected users. |
| **`SKIPPED`** | This configuration applies to every Account and has no prerequisite, so it does not produce `SKIPPED`. |
| **Found** | Found names the inactive assignees discovered on pending steps or confirms that none were found. |
| **Expected** | Expected states that every pending approval assignee must be active. |
| **`UNABLE_TO_EVALUATE`** | Missing Advanced Approvals metadata or incorrect API names prevents a reliable result instead of creating a false `PASS`. |

## Security and access

The approval and User queries run in user mode, so the result follows the running user's Salesforce access.

- The configured approval object, assignment and status fields, and the matching User records.

- Hidden approval rows or User records do not appear in the result. Queries run in user mode so hidden rows stay out of the card.

- The plugin can name inactive Users. Confirm that the running user is allowed to see those names.

- Missing approval-object or User access must show **Unable to evaluate** rather than a false Pass.

- Use the real end-user Permission Sets and approval-row visibility.

## Step 4: Test the Rule

1. In Object Manager, verify and replace every illustrative `sbaa__*` API name in Apex Parameters (JSON).
2. Deploy the pack (or class), activate the Rule, and open a record with a pending step assigned to an inactive user. Confirm Critical and the named approver.
3. Reassign to an active user, rerun, and confirm a pass.
4. In an org without Advanced Approvals (or with wrong API names), confirm unable to evaluate.
5. Repeat with the intended end-user profile and confirm row and User visibility follow its access.

### Execute Anonymous

Run this from **Developer Console → Debug → Open Execute Anonymous Window**. Replace the ID with a
record supported by the confirmed Advanced Approvals target-field configuration:

```apex
Id targetRecordId = '006XXXXXXXXXXXXXXX';
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forRule(
    'Approval_No_Inactive_Approvers',
    targetRecordId
  ).withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(response));
```

The `006` prefix is only an Opportunity illustration. Use the object configured for this Rule.
Confirm `status`, Found, Expected, message, and any Reason Code.

### Lightning record page

1. Add **Record Health Check** to the target object's Lightning record page.
2. Select `Account_Apex_Readiness` only if its Check Set object matches that page; otherwise create a
   Check Set for the confirmed target object and assign the Rule to it.
3. Save and activate the page, click **Run** or **Rerun**, and compare the result with Execute Anonymous.

## Failures, remedies, and customization

| Reason or symptom | What to verify |
| --- | --- |
| `OBJECT_NOT_FOUND` | Install the Framework or correct `approvalObject`; keep the Rule inactive. |
| `INVALID_SOQL_TEMPLATE` | Correct field names, field types, and pending statuses in Object Manager. |
| Too few inactive users | Check approval-row sharing, User visibility, and the status list. |
| The Found list is truncated | The framework limits list previews for readability. Use authorized diagnostics or the approval records to review the complete assignment set. |

You can adapt the class to another approval product when its rows provide a target record ID,
assigned User ID, and status. Verify those types and repeat pass, fail, unable, and access tests
before activation.

## Related

- [← Prev: Strategic readiness](03-strategic-readiness.md)
- [Browse Apex examples](README.md)
