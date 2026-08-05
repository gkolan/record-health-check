# 01 · Account Is Ready for Customer Follow-up

> [!NOTE]
> On this page, build one Apex Rule that brings completed Tasks and Events into a single Account follow-up result while keeping the activity window configurable in Custom Metadata.
>
> **Setup reference**
>
> Use the [Apex reference](../../reference/evaluation/04-apex-rule-contract.md) for the complete setup fields and behavior.

## Scenario

An account manager opens an Account before a customer call and wants to know whether anyone has completed follow-up recently.

- The answer should include completed Tasks and logged Events without making the manager interpret two separate card rows.
- Customer follow-up may be recorded as either type of activity.
- Opening and comparing both activity lists takes attention away from preparing for the conversation.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check combines completed Tasks and logged Events into one answer, so the account manager can see whether recent follow-up exists before the customer call.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Choose Apex for multi-object logic | The Rule evaluates completed Tasks and Events together. |
| Accept administrator-controlled parameters | JSON configures the recent-activity window without changing Apex. |
| Return a clear Framework result | The class supplies status, **Found**, **Expected**, and user guidance. |

## What the card shows

| Card value | Activity found | No activity found |
| --- | --- | --- |
| **Status** | `PASS` | `FAIL` |
| **Found** | Combined visible activity count | `0` |
| **Expected** | `1` | `1` |
| **Message** | No failure message | The Rule's configured Warning message |

Found reports the combined number of qualifying Tasks and Events. Expected reports the minimum
passing count. The failure guidance tells the user which activity types and configured window to
review.

## Why use Verify with Apex

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with Apex** | Best fit. One class can review completed Tasks and Events, apply the administrator's date window, and return one status. |
| **Verify with a formula** using Last Activity Date | Can read the Account's Last Activity Date but cannot apply separate Task and Event filters. |
| **Verify with a query** in two separate Rules | Would show separate Task and Event results instead of one recent-activity status. |
| **Compare two queries** | Can compare the Task and Event counts but cannot pass when either count is greater than zero. |

## What Record Health Check passes to Apex

Shared scope inputs (`scope.recordIds`, `scope.parameters`) are documented once in the
[Apex examples README](README.md#what-record-health-check-passes-to-apex). This Rule receives Account
Ids and a `daysBack` parameter.

```apex
List<Id> accountIds = scope.recordIds;
```

The complete class below seeds every requested Account, runs one grouped Task query and one grouped
Event query, and then returns one outcome for every map key.

## Step 1:
## Step 1: Understand the parameters

Use Rule parameters to change the activity window without editing the Apex class. This Rule uses:

```json
{
  "daysBack": 90
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON automatically and passes it to the class as
`scope.parameters`, a map of parameter names to values. The class uses 30 days only when `daysBack`
is absent. A supplied null, nonnumeric, or out-of-range value returns `INVALID_CONFIG`; the configured Rule explicitly uses 90 days. See
[Parameter parsing patterns](../../reference/evaluation/04-apex-rule-contract.md#scope)
for validation and type-conversion guidance.

## Step 2: Create the Apex class

Deploy this complete class after Record Health Check. It respects the running user's Salesforce
access when it counts Tasks and Events, combines those counts, and returns Status, Found, and
Expected.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example implementation of RecordHealthCheckRule: has the Account been touched
 * recently? At least one completed Task or logged Event inside a configurable
 * look-back window, tuned per Rule through ApexParametersJson__c, for example
 * {"daysBack": 90}.
 *
 * This is the reference implementation for the plugin contract, so it is
 * written the way every Rule should be: all data loading happens ABOVE the
 * loop, and the loop does computation only. Two queries serve the whole scope,
 * whether that scope holds one record or two hundred.
 *
 * Failure message, severity, and label all come from the Rule metadata. This
 * class decides PASS or FAIL and reports the values behind that decision; it
 * never stamps identity, severity, or anything the user sees.
 */
global with sharing class AccountHasRecentActivityCheck implements RecordHealthCheckRule {
  private static final Integer DEFAULT_DAYS_BACK = 30;
  private static final Integer MIN_DAYS_BACK = 1;
  private static final Integer MAX_DAYS_BACK = 3650;

  /** Evaluates recent activity once for the complete requested scope. */
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    List<Id> recordIds = scope.recordIds;
    if (recordIds == null || recordIds.isEmpty()) {
      return results;
    }
    Set<Id> queryRecordIds = new Set<Id>(recordIds);

    Integer daysBack = resolveDaysBack(scope.parameters);
    if (daysBack == null) {
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('INVALID_CONFIG')
        );
      }
      return results;
    }
    Date cutoff = Date.today().addDays(-daysBack);
    if (cutoff == null) {
      return results;
    }

    // Seed every Id with zero BEFORE overlaying the aggregates. An aggregate
    // returns no row at all for an Account with no activity, so a map built
    // only from query results would leave exactly those Accounts missing, and
    // "no recent activity" is precisely the population this check exists to
    // find. Zero is a real answer here, not an absent one.
    Map<Id, Integer> activityCounts = new Map<Id, Integer>();
    for (Id recordId : recordIds) {
      activityCounts.put(recordId, 0);
    }

    for (AggregateResult row : [
      SELECT WhatId whatId, COUNT(Id) total
      FROM Task
      WHERE
        WhatId IN :queryRecordIds
        AND IsClosed = TRUE
        AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      accumulate(
        activityCounts,
        (Id) row.get('whatId'),
        (Integer) row.get('total')
      );
    }

    for (AggregateResult row : [
      SELECT WhatId whatId, COUNT(Id) total
      FROM Event
      WHERE WhatId IN :queryRecordIds AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      accumulate(
        activityCounts,
        (Id) row.get('whatId'),
        (Integer) row.get('total')
      );
    }

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(1);
    for (Id recordId : recordIds) {
      Integer total = activityCounts.get(recordId);
      RecordHealthCheckOutcome outcome = total > 0
        ? RecordHealthCheckOutcome.pass('APEX_PASS')
        : RecordHealthCheckOutcome.fail('APEX_FAIL');
      results.put(
        recordId,
        outcome
          .withFound(RecordHealthCheckValue.ofCount(total))
          .withComparison('GREATER_THAN_OR_EQUAL', expected)
      );
    }

    return results;
  }

  /**
   * A WhatId can point at objects other than the ones in scope, so only seeded
   * keys are accumulated. Anything else would add a key the engine never asked
   * about, which fails the whole scope.
   */
  private static void accumulate(
    Map<Id, Integer> counts,
    Id whatId,
    Integer total
  ) {
    if (whatId != null && counts.containsKey(whatId)) {
      counts.put(whatId, counts.get(whatId) + total);
    }
  }

  /**
   * Bounded deliberately: an unbounded window is not a useful health check, and
   * a negative one would silently invert the question being asked.
   *
   * Null means the administrator supplied an invalid value; the caller returns
   * INVALID_CONFIG for every scoped record without running a query.
   */
  private Integer resolveDaysBack(Map<String, Object> parameters) {
    Object raw = parameters == null ? null : parameters.get('daysBack');
    if (raw == null) {
      return DEFAULT_DAYS_BACK;
    }
    Integer parsed;
    if (raw instanceof Integer) {
      parsed = (Integer) raw;
    } else if (raw instanceof Decimal) {
      parsed = ((Decimal) raw).intValue();
    } else if (raw instanceof String) {
      try {
        parsed = Integer.valueOf((String) raw);
      } catch (Exception ex) {
        return null;
      }
    } else {
      return null;
    }
    return (parsed < MIN_DAYS_BACK || parsed > MAX_DAYS_BACK) ? null : parsed;
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
| `recordIds` | `List<Id>` | Detached IDs to evaluate, with duplicates removed; use the collection in bulk SOQL |
| `objectApiName` | `String` | API name shared by every ID in the scope, such as `Account` |
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
| `comparisonOperator` | The operator behind the decision, such as `GREATER_THAN_OR_EQUAL` |
| `expected` | A typed `RecordHealthCheckValue` describing the passing requirement |

For applicability, configure **Applies To** on the Rule so Record Health Check skips before Apex
runs. The framework supplies identity, label, severity, messages, display values, and diagnostics.
Missing or extra map keys, a null outcome, an invalid status, forbidden writes, or an
unhandled exception produces `APEX_EVALUATOR_ERROR`, not a pass. See
[Returning an outcome](../../reference/evaluation/04-apex-rule-contract.md#outcome).


## Step 3: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/02-fields-check-rule.md#developer-name-developername) | `Has_Recent_Activity` |
| **Label** | [`MasterLabel`](../../metadata/02-fields-check-rule.md#label-masterlabel) | Has Recent Activity |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/02-fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/02-fields-check-rule.md#check-title-checktitle__c) | Has Recent Activity |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/02-fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/02-fields-check-rule.md#apex-class-apexclass__c) | `AccountHasRecentActivityCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/02-fields-check-rule.md#apex-parameters-json-apexparametersjson__c) | `{"daysBack": 90}` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/02-fields-check-rule.md#check-description-checkdescription__c) | Checks for a completed Task or Event related to the Account inside the selected number of days. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/02-fields-check-rule.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/02-fields-check-rule.md#message-when-failed-failuremessage__c) | Names the record, then asks for a completed Task or Event in the window: copy it from below the table |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/02-fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check recent activity. Confirm the running user can read Tasks and Events. |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/02-fields-check-rule.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/02-fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/02-fields-check-rule.md#fix-message-fixmessage__c) | Review the Account activity timeline. If no completed Task or Event falls inside the 90-day window, log the activity and rerun the check. |
| **Action Label** | [`ActionLabel__c`](../../metadata/02-fields-check-rule.md#action-label-actionlabel__c) | `Log account activity` |
| **Action URL** | [`ActionUrl__c`](../../metadata/02-fields-check-rule.md#action-url-actionurl__c) | `/lightning/o/Task/new?defaultFieldValues=WhatId={!record.Id}` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/02-fields-check-rule.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../metadata/02-fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/02-fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Copy this value into **Message When Failed**:

```text
{!record.Name fallback="this record"} has no completed tasks or logged events in the last 90 days. Log a completed Task or Event inside the look-back window.
```

Change `daysBack` to change the window without redeploying the class.

The pack metadata currently supplies severity, failure message, applicability, order, and Active.
The other rows above are recommended choices for a complete, useful card and may be added in Setup.

The action link opens a new Task with the Account already selected. It does not prove why an
existing Task or Event was excluded. For diagnosis, first use Found and the 90-day window shown on
this page, then check the Account activity timeline for these four requirements:

1. The activity is related to this Account.
2. A Task has a closed status; Events do not use the Task status check.
3. Activity Date is inside the selected window.
4. The person running the check can read the activity.

If your administrators maintain an activity report filtered by Account ID, a report action link is
better for diagnosis:

```text
/lightning/r/Report/00Oxxxxxxxxxxxxxxx/view?fv0={!record.Id}
```

Replace the report ID with one from the target org before sharing the URL. The prefilled Task link
is the safer portable default because it does not depend on an org-specific report or an assumed
Activity related-list API name.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Apex_Readiness` |
| **Object** | `Account` |
| **Card Title** | `Account Readiness` |
| **Card Subtitle** | Confirm recent Tasks or Events within the configured window. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

Formula, Query, and Compare two queries fields do not apply because this is the Verify with Apex Evaluation Type.

## What the user sees

The Apex class turns the activity counts and effective date window into these user-facing values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A completed Task or Event with `ActivityDate` on or after the cutoff passes. |
| **`FAIL`** | No matching activity shows Needs attention through a normal `FAIL`, not an evaluation error. |
| **`SKIPPED`** | This configuration applies to every Account and has no prerequisite, so it does not produce `SKIPPED`. |
| **Found** | Found shows the combined number of visible completed Tasks and Events inside the effective activity window. |
| **Expected** | Expected shows the minimum required activity count: `1`. |

Invalid `daysBack` values return `UNABLE_TO_EVALUATE` with `INVALID_CONFIG`. Test configuration changes before activation because the card intentionally shows the count comparison, not the parameter value. The Rule supplies the
label, severity, failure message, and display formatting.

## Security and access

The class uses sharing and user-mode queries so its result follows the running user's Salesforce access.

- Task and Event plus `WhatId`, `IsClosed`, and `ActivityDate`.

- Record sharing and restriction rules decide which activities contribute to the counts. Two users can legitimately see different results for the same Account.

- Insufficient object or field access must show **Unable to evaluate**. It is not proof that no activity exists.

- Keep `evaluate` free of DML and callouts because the card may run the Rule more than once.

- Run the Rule with the Permission Sets and activity visibility assigned to the intended users.

## Step 4: Test the Rule

1. Remove or push outside the window every completed Task and logged Event. Confirm Warning.
2. Add either back inside the window, rerun, and confirm a pass.
3. Edit `daysBack` in Apex Parameters (JSON) and confirm the window changes without a class redeploy.
4. Run as a user who cannot see a qualifying Task or Event. Confirm the result follows that user's
   visibility, then restore access and confirm the activity contributes again.

You can also test without the card from **Developer Console → Debug → Open Execute Anonymous
Window** (replace the placeholder with an Account ID):

```apex
Id accountId = '001XXXXXXXXXXXXXXX';
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forRule('Has_Recent_Activity', accountId)
    .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(response));
```

### Lightning record page

1. Add **Record Health Check** to the Account record page in Lightning App Builder.
2. Select `Account_Apex_Readiness`, save, and activate the page.
3. Open the same Account, click **Run** or **Rerun**, and compare Status, Found, and Expected with
   the Execute Anonymous result.

## Failures and remedies

| Symptom or reason | What to verify |
| --- | --- |
| `APEX_CLASS_NOT_FOUND` | Deploy `AccountHasRecentActivityCheck`, confirm the class name in **Apex Class**, and confirm it implements `RecordHealthCheckRule`. |
| `APEX_EVALUATOR_ERROR` | Confirm the running user can read Task/Event and the queried fields; inspect authorized diagnostics for the underlying exception. |
| A known Task does not count | Confirm it is closed, its `WhatId` is this Account, its `ActivityDate` is inside the effective window, and the running user can see it. |
| `INVALID_CONFIG` | Correct a null, nonnumeric, or out-of-range `daysBack`. Omit the key only when the deliberate 30-day default is appropriate. |

## Customize this Rule

Change `daysBack` in JSON to change the window without deploying code. Change the Task or Event
filters only when your definition of activity differs, and update the class tests and explanatory
copy at the same time. If `LastActivityDate` alone answers the business question, replace this Apex
Rule with a simpler Verify with a formula.

## Related

- [Next: Combine per-row conditions on a child object →](02-open-opportunity-health.md)
- [Browse Apex examples](README.md)
