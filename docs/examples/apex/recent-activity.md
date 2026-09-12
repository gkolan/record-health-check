# Account Is Ready for Customer Follow-up

> [!NOTE]
> On this page, create an Account Check that passes when the running user can see a completed Task
> or Event inside a configurable number of days. The Apex class is included with the installed
> package; you create the Check Set and Check for your org.
>
> **Setup reference**
>
> Use the [Apex reference](../../developer-guides/write-an-apex-check.md) for the complete setup fields and behavior.

## Scenario

An account manager opens an Account before a customer call and wants to know whether anyone has completed follow-up recently.

- The answer should include completed Tasks and logged Events without making the manager interpret two separate card rows.
- Customer follow-up may be recorded as either type of activity.
- Opening and comparing both activity lists takes attention away from preparing for the conversation.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check combines completed Tasks and logged Events into one answer, so the account manager can see whether recent follow-up exists before the customer call.

## Before you start

- Install Record Health Check and assign **Record Health Check Admin** to the administrator creating
  the Check Set and Check.
- Confirm that the intended users have **Record Health Check Card User** and can read Account, Task,
  Event, and the fields listed under [Security and access](#security-and-access).
- Build and test this example in a sandbox before adding it to a production Lightning record page.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Choose Apex for multi-object logic | The Check evaluates completed Tasks and Events together. |
| Accept administrator-controlled parameters | A typed definition validates JSON, applies defaults and bounds, and reports labels and help without changing Apex. |
| Explain the decision | The class supplies status, **Found**, **Expected**, and typed evidence for the observed count, requirement, window, and Account. |
| Add safe presentation | An optional display hook adds guidance, a record link, formats, and an action without changing the verdict. |

## What the card shows

| Card value | Activity found | No activity found |
| --- | --- | --- |
| **Status** | `PASS` | `FAIL` |
| **Found** | Combined visible activity count | `0` |
| **Expected** | Configured minimum | Configured minimum |
| **Message** | Cadence met, with an Account link | Below requirement, with remediation and an Account action |

Found reports the combined number of qualifying Tasks and Events. Expected reports the minimum
passing count. The failure guidance tells the user which activity types and configured window to
review.

## Why use Verify with Apex

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with Apex** | Best fit. One class can review completed Tasks and Events, apply the administrator's date window, and return one status. |
| **Verify with a formula** using Last Activity Date | Can read the Account's Last Activity Date but cannot apply separate Task and Event filters. |
| **Verify with a query** in two separate Checks | Would show separate Task and Event results instead of one recent-activity status. |
| **Compare two queries** | Can compare the Task and Event counts but cannot pass when either count is greater than zero. |

## What Record Health Check passes to Apex

Shared scope inputs (`scope.recordIds`, `scope.parameters`) are documented once in the
[Apex examples README](./README.md#what-record-health-check-passes-to-apex). This Check receives Account
Ids plus declared `daysBack` and `minimumActivities` parameters.

```apex
List<Id> accountIds = scope.recordIds;
```

The complete class below seeds every requested Account, runs one grouped Task query and one grouped
Event query, and then returns one outcome for every map key.

## Administrator setup notes

This class is included with the package. On a **Verify with Apex** Check, select the packaged
`AccountHasRecentActivityCheck` entry shown by Salesforce and paste the documented JSON exactly
into **Apex Parameters (JSON)**. In a subscriber org the underlying Apex type is namespaced, but do
not invent or remove `rhc__` from a Custom Metadata Qualified API Name.

`{"daysBack":30}` means 30 days and uses the default minimum of one. The shipped Check uses
`{"daysBack":60,"minimumActivities":2}`. Invalid JSON, unknown or duplicate keys, wrong types,
and values outside the declared bounds produce `INVALID_APEX_PARAMETERS` before `evaluate` runs.
The class considers Tasks
and Events whose **Related To** (`WhatId`) is the Account; a Contact-only **Name** (`WhoId`)
relationship is not enough. For a test Task, set Related To to the Account, mark it Completed, and
use a current due date.

The create-Task action URL uses `defaultFieldValues=WhatId=...` to prefill Related To; the user must
still review required fields and save. If the standard `LastActivityDate` behavior fully answers the
business question, prefer a Formula Check.

Add the card to the Account Lightning page, activate the intended assignment, and test as a user
with **Record Health Check Card User**. Developer Console and Execute Anonymous sections are optional
developer verification, not administrator setup.

## Step 1: Choose the activity window

Use Check parameters to change the activity window and passing threshold without editing the Apex
class. This Check uses:

```json
{
  "daysBack": 90,
  "minimumActivities": 2
}
```

Record Health Check parses the JSON automatically and passes it to the class as
`scope.parameters`, a map of parameter names to values. The class declares a 30-day default and a
minimum of one activity. `daysBack` accepts 1–3,650 and `minimumActivities` accepts 1–1,000. A
wrong type or out-of-range value returns `UNABLE_TO_EVALUATE` with reason code
`INVALID_APEX_PARAMETERS` before the class runs.
This copyable example uses 90 days and two activities. See
[Parameter parsing patterns](../../developer-guides/write-an-apex-check.md#scope)
for validation and type-conversion guidance.

## Step 2: Review the packaged Apex class

The package already includes this class. The source below is shown for review and therefore uses
the unprefixed type names used inside the package. A subscriber-owned plugin uses the public
`rhc.RecordHealthCheckPlugin` contract instead.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example implementation of RecordHealthCheckPlugin: has the Account been touched
 * recently and often enough? A configurable minimum number of completed Tasks
 * or logged Events must fall inside a configurable look-back window, tuned per
 * Check through ApexParametersJson__c, for example
 * {"daysBack": 60, "minimumActivities": 2}.
 *
 * This is the reference implementation for the plugin contract, so it is
 * written the way every Check should be: all data loading happens ABOVE the
 * loop, and the loop does computation only. Two queries serve the whole scope,
 * whether that scope holds one record or two hundred.
 *
 * The class declares its JSON parameters, returns typed decision evidence, and
 * can add display-only context after evaluation. Check metadata still owns
 * identity, applicability, severity, publication, and safe fallback copy.
 */
global with sharing class AccountHasRecentActivityCheck implements RecordHealthCheckPlugin, RecordHealthCheckPluginDefinitionSource, RecordHealthCheckDisplayPlugin {
  private static final Integer DEFAULT_DAYS_BACK = 30;
  private static final Integer MIN_DAYS_BACK = 1;
  private static final Integer MAX_DAYS_BACK = 3650;
  private static final Integer DEFAULT_MINIMUM_ACTIVITIES = 1;
  private static final Integer MINIMUM_ACTIVITIES = 1;
  private static final Integer MAXIMUM_ACTIVITIES = 1000;
  private Map<Id, Integer> evaluatedActivityCounts = new Map<Id, Integer>();
  private Integer evaluatedDaysBack;
  private Integer evaluatedMinimumActivities;

  /** Declares the accepted parameters and bulk scheduling characteristics. */
  global RecordHealthCheckPluginDefinition getDefinition() {
    return new RecordHealthCheckPluginDefinition()
      .integerParameter(
        'daysBack',
        DEFAULT_DAYS_BACK,
        MIN_DAYS_BACK,
        MAX_DAYS_BACK
      )
      .describe(
        'daysBack',
        'Look-back days',
        'Count completed Tasks and Events on or after this many days ago.'
      )
      .integerParameter(
        'minimumActivities',
        DEFAULT_MINIMUM_ACTIVITIES,
        MINIMUM_ACTIVITIES,
        MAXIMUM_ACTIVITIES
      )
      .describe(
        'minimumActivities',
        'Required activities',
        'Minimum completed Tasks and Events required inside the look-back window.'
      )
      .capacity(200, true, 'LOW');
  }

  /** Evaluates recent activity once for the complete requested scope. */
  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    evaluatedActivityCounts.clear();
    evaluatedDaysBack = null;
    evaluatedMinimumActivities = null;
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    List<Id> recordIds = scope.recordIds;
    if (recordIds == null || recordIds.isEmpty()) {
      return results;
    }
    Set<Id> queryRecordIds = new Set<Id>(recordIds);

    Integer daysBack = resolveDaysBack(scope.parameters);
    Integer minimumActivities = resolveMinimumActivities(scope.parameters);
    if (daysBack == null || minimumActivities == null) {
      for (Id recordId : recordIds) {
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate('INVALID_CONFIG')
        );
      }
      return results;
    }
    evaluatedDaysBack = daysBack;
    evaluatedMinimumActivities = minimumActivities;
    Date cutoff = Date.today().addDays(-daysBack);

    // Seed every Id with zero BEFORE overlaying the aggregates. An aggregate
    // returns no row at all for an Account with no activity, so a map built
    // only from query results would leave exactly those Accounts missing, and
    // "no recent activity" is precisely the Accounts this check exists to
    // find. Zero is a real answer here, not an absent one.
    Map<Id, Integer> activityCounts = new Map<Id, Integer>();
    for (Id recordId : recordIds) {
      activityCounts.put(recordId, 0);
    }

    Map<String, Object> queryBinds = new Map<String, Object>{
      'queryRecordIds' => queryRecordIds,
      'cutoff' => cutoff
    };
    accumulateRows(
      activityCounts,
      RecordHealthCheckQueryEvaluatorSupport.runAggregateQuery(
        'SELECT WhatId whatId, COUNT(Id) total FROM Task WHERE WhatId IN :queryRecordIds AND IsClosed = TRUE AND ActivityDate >= :cutoff GROUP BY WhatId',
        queryBinds
      )
    );
    accumulateRows(
      activityCounts,
      RecordHealthCheckQueryEvaluatorSupport.runAggregateQuery(
        'SELECT WhatId whatId, COUNT(Id) total FROM Event WHERE WhatId IN :queryRecordIds AND ActivityDate >= :cutoff GROUP BY WhatId',
        queryBinds
      )
    );

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(
      minimumActivities
    );
    ActivityOutcomeEvaluator recordEvaluator = new ActivityOutcomeEvaluator(
      activityCounts,
      minimumActivities,
      daysBack,
      expected
    );
    for (Id recordId : recordIds) {
      Integer total = activityCounts.get(recordId);
      evaluatedActivityCounts.put(recordId, total);
      results.put(
        recordId,
        RecordHealthCheckOutcome.tryEvaluate(recordId, recordEvaluator)
      );
    }

    return results;
  }

  public static RecordHealthCheckOutcome outcomeFor(
    Integer total,
    Integer minimumActivities
  ) {
    RecordHealthCheckOutcome outcome = total >= minimumActivities
      ? RecordHealthCheckOutcome.pass('APEX_PASS')
      : RecordHealthCheckOutcome.fail('APEX_FAIL');
    return outcome.withFound(RecordHealthCheckValue.ofCount(total));
  }

  /** Builds one outcome with the typed evidence displayed by diagnostics 2.0. */
  public static RecordHealthCheckOutcome outcomeFor(
    Integer total,
    Integer minimumActivities,
    Integer daysBack,
    Id recordId
  ) {
    RecordHealthCheckEvidence evidence = new RecordHealthCheckEvidence(
        'Recent completed activity used for this decision.'
      )
      .column('accountId', 'Account', 'ID')
      .column('activityCount', 'Completed activities', 'NUMBER')
      .column('requiredCount', 'Required activities', 'NUMBER')
      .column('windowDays', 'Look-back days', 'NUMBER')
      .row(
        new List<RecordHealthCheckEvidenceCell>{
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofId(recordId)
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofCount(total)
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofCount(minimumActivities)
          ),
          RecordHealthCheckEvidenceCell.value(
            RecordHealthCheckValue.ofNumber(
              Decimal.valueOf(String.valueOf(daysBack))
            )
          )
        }
      )
      .groupBy('windowDays', 'accountId');
    return outcomeFor(total, minimumActivities).withEvidence(evidence);
  }

  /**
   * Adds presentation after evaluation without querying or changing outcomes.
   * Missing state produces no override, allowing metadata fallback copy.
   */
  global Map<Id, RecordHealthCheckDisplayOverride> getDisplay(
    RecordHealthCheckScope scope
  ) {
    Map<Id, RecordHealthCheckDisplayOverride> displayByRecordId = new Map<Id, RecordHealthCheckDisplayOverride>();
    if (
      scope == null ||
      evaluatedDaysBack == null ||
      evaluatedMinimumActivities == null
    ) {
      return displayByRecordId;
    }
    for (Id recordId : scope.recordIds) {
      if (!evaluatedActivityCounts.containsKey(recordId)) {
        continue;
      }
      Integer total = evaluatedActivityCounts.get(recordId);
      Boolean passing = total >= evaluatedMinimumActivities;
      RecordHealthCheckDisplayOverride displayValue = new RecordHealthCheckDisplayOverride()
        .withMessage(
          new RecordHealthCheckDisplayText()
            .text(
              passing
                ? 'Recent follow-up meets the configured activity requirement.'
                : 'Recent follow-up is below the configured activity requirement.'
            )
            .lineBreak()
            .link('Open account', '/lightning/r/Account/' + recordId + '/view')
        )
        .withExpectedLabel('Required recent activity')
        .withFoundFormat('NUMBER', null)
        .withExpectedFormat('NUMBER', null)
        .withAction(
          new RecordHealthCheckDisplayAction(
            'Open account',
            '/lightning/r/Account/' + recordId + '/view'
          )
        );
      if (!passing) {
        displayValue.withFix(
          new RecordHealthCheckDisplayText()
            .text(
              'Log a completed Task or Event for this Account, then run the Check again.'
            )
        );
      }
      displayByRecordId.put(recordId, displayValue);
    }
    return displayByRecordId;
  }

  /** Evaluates one record from the already loaded count map. */
  private class ActivityOutcomeEvaluator implements RecordHealthCheckRecordEvaluator {
    private Map<Id, Integer> activityCounts;
    private Integer minimumActivities;
    private Integer daysBack;
    private RecordHealthCheckValue expected;

    private ActivityOutcomeEvaluator(
      Map<Id, Integer> activityCounts,
      Integer minimumActivities,
      Integer daysBack,
      RecordHealthCheckValue expected
    ) {
      this.activityCounts = activityCounts;
      this.minimumActivities = minimumActivities;
      this.daysBack = daysBack;
      this.expected = expected;
    }

    public RecordHealthCheckOutcome evaluateRecord(Id recordId) {
      return outcomeFor(
          activityCounts.get(recordId),
          minimumActivities,
          daysBack,
          recordId
        )
        .withComparison('GREATER_THAN_OR_EQUAL', expected);
    }
  }

  /**
   * A WhatId can point at objects other than the ones in scope, so only seeded
   * keys are accumulated. Anything else would add a key the engine never asked
   * about, which fails the whole scope.
   */
  public static void accumulateRows(
    Map<Id, Integer> counts,
    List<AggregateResult> rows
  ) {
    for (AggregateResult row : rows) {
      accumulate(counts, (Id) row.get('whatId'), (Integer) row.get('total'));
    }
  }

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
    return resolveBoundedInteger(raw, MIN_DAYS_BACK, MAX_DAYS_BACK);
  }

  /**
   * Resolves the minimum completed engagements required inside the window.
   * Existing Check metadata remains backward-compatible because an omitted
   * value defaults to one.
   */
  private Integer resolveMinimumActivities(Map<String, Object> parameters) {
    Object raw;
    if (parameters != null) {
      raw = parameters.get('minimumActivities');
    }
    if (raw == null) {
      return DEFAULT_MINIMUM_ACTIVITIES;
    }
    return resolveBoundedInteger(raw, MINIMUM_ACTIVITIES, MAXIMUM_ACTIVITIES);
  }

  /** Converts supported parameter types and enforces an inclusive range. */
  private Integer resolveBoundedInteger(
    Object raw,
    Integer minimum,
    Integer maximum
  ) {
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
    return (parsed < minimum || parsed > maximum) ? null : parsed;
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
| `checkQualifiedApiName` | `String` | Qualified Check identity |
| `checkSetQualifiedApiName` | `String` | Qualified Check Set identity |
| `checkDeveloperName` | `String` | Unqualified Check `DeveloperName` |
| `checkSetDeveloperName` | `String` | Unqualified parent Check Set `DeveloperName` |
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
| `evidence` | Optional bounded rows explaining the decision; field provenance is filtered by access |

For applicability, configure **Applies To** on the Check so Record Health Check skips before Apex
runs. Record Health Check supplies identity, label, severity, applicability, publication, and
diagnostics. This example optionally supplies display-only message, fix, action, labels, and formats
after evaluation; metadata remains the field-by-field fallback.
Missing or extra map keys, a null outcome, an invalid status, forbidden writes, or an
unhandled exception produces `APEX_EVALUATOR_ERROR`, not a pass. See
[Returning an outcome](../../developer-guides/write-an-apex-check.md#outcome).


## Step 3: Create the Check Set

In **Setup → Custom Metadata Types → Record Health Check Set → Manage Records**, select **New** and
create this Check Set:

| Setup field | Value |
| --- | --- |
| **Label** | Account Apex Readiness |
| **Record Health Check Set Name** | `Account_Apex_Readiness` |
| **Object** | `Account` |
| **Card Title** | `Account Readiness` |
| **Card Subtitle** | Confirm recent Tasks or Events within the configured window. |
| **When Checks Run** | When the user clicks Run |
| **Summary Display** | Show below checks |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each passed check |
| **Skipped Checks** | Show each skipped check |
| **Found/Expected Display** | Show on demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

Save the record. Because an administrator created it in your org, its **Qualified API Name** is
normally `Account_Apex_Readiness` without `rhc__`.

## Step 4: Configure the Check

In **Setup → Custom Metadata Types → Record Health Check → Manage Records**, create the Check:

| Setup field | API name | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../reference/custom-metadata/check-fields.md#developer-name-developername) | `Account_Has_Recent_Activity` |
| **Label** | [`MasterLabel`](../../reference/custom-metadata/check-fields.md#label-masterlabel) | Has Recent Activity |
| **Check Set** | [`Record_Health_Check_Set__c`](../../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../reference/custom-metadata/check-fields.md#check-title-checktitle__c) | Has Recent Activity |
| **Evaluation Type** | [`EvaluationType__c`](../../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../reference/custom-metadata/check-fields.md#apex-class-apexclass__c) | `AccountHasRecentActivityCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../reference/custom-metadata/check-fields.md#apex-parameters-json-apexparametersjson__c) | `{"daysBack": 90, "minimumActivities": 2}` |

## Optional configuration

| Setup field | API name | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../reference/custom-metadata/check-fields.md#check-description-checkdescription__c) | Checks for a completed Task or Event related to the Account inside the selected number of days. |
| **Failure Severity** | [`FailureSeverity__c`](../../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c) | Warning |
| **Message When Failed** | [`FailureMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | Names the record, then asks for a completed Task or Event in the window: copy it from below the table |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check recent activity. Enter `daysBack` as a whole number from 1 through 3650. |
| **Applies To** | [`ApplicabilityMode__c`](../../reference/custom-metadata/check-fields.md#applies-to-applicabilitymode__c) | All records |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../reference/custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c) | Review the activity timeline and include an explicit safe Account link as shown below. This remains the optional display hook's fallback. |
| **Action Label** | [`ActionLabel__c`](../../reference/custom-metadata/check-fields.md#action-label-actionlabel__c) | `Log account activity` |
| **Action URL** | [`ActionUrl__c`](../../reference/custom-metadata/check-fields.md#action-url-actionurl__c) | `/lightning/o/Task/new?defaultFieldValues=WhatId={!record.Id}` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c) | `10` |
| **Active** | [`IsActive__c`](../../reference/custom-metadata/check-fields.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../reference/custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

Copy this value into **Message When Failed**:

```text
{!record.Name fallback="this record"} has no completed tasks or logged events in the last 90 days. Review the timeline and record any completed activity that has not yet been logged.
```

Copy this value into **Fix Message** to exercise 2.0.10 inline-link syntax:

```text
Review completed Tasks and Events. {!link label="Open this Account" href="/lightning/r/Account/{!record.Id}/view"} to record genuine completed activity or plan the next follow-up.
```

Change `daysBack` to change the window without redeploying the class.

This example is deliberately `WhatId`-only. A Task related only through a Contact `WhoId`, Shared
Activities relations, or an Opportunity/Case `WhatId` is not counted for the Account. See
[Platform limitations and safe patterns](../../reference/platform/limitations.md#activities-what-who-and-shared-relations)
for the exact matrix and a bulk-safe WhoId recipe.

These values create a new Check owned by your org. They do not change the example Check included
with the installed package.

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

Formula, Query, and Compare two queries fields do not apply because this is the Verify with Apex Evaluation Type.

## What the user sees

The Apex class turns the activity counts and effective date window into these user-facing values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A completed Task or Event with `ActivityDate` on or after the cutoff passes. |
| **`FAIL`** | No matching activity shows Needs attention through a normal `FAIL`, not an evaluation error. |
| **`SKIPPED`** | This configuration applies to every Account and has no prerequisite, so it does not produce `SKIPPED`. |
| **Found** | Found shows the combined number of visible completed Tasks and Events inside the effective activity window. |
| **Expected** | Expected shows the configured minimum under **Required recent activity**. |
| **Evidence** | One typed row contains Account ID, completed-activity count, required count, and look-back days. |
| **Presentation** | The Apex display hook adds a status-specific message, safe Account link, numeric formats, and failure remediation. Metadata remains the fallback. |

Invalid declared parameter input returns `UNABLE_TO_EVALUATE` with `INVALID_APEX_PARAMETERS`.
The class's own `INVALID_CONFIG` branch is defensive behavior for a direct call that bypasses the
normal definition service; it is not the expected reason from Record Health Check evaluation. Test
configuration changes before activation. Check metadata always owns label, severity,
applicability, publication, and fallback copy. Presentation cannot change PASS or FAIL.

## Security and access

The class uses sharing and user-mode queries, so it can count only activities the running user can
access. The running user needs Read access to:

- Account;
- Task and its `WhatId`, `IsClosed`, and `ActivityDate` fields; and
- Event and its `WhatId` and `ActivityDate` fields.

- Salesforce sharing and Restriction Rules decide which activities contribute to the counts. Two users can legitimately see different results for the same Account.

- If a user-mode query throws because the user cannot access an object or field, Record Health Check
  returns `ERROR` with `APEX_EVALUATOR_ERROR`. A zero count and `FAIL` mean the queries ran but found
  no visible matching activity; they do not prove that no hidden activity exists.

- Keep `evaluate` free of DML and callouts because the card may run the Check more than once.

- Run the Check with the Permission Sets and activity visibility assigned to the intended users.

## Step 5: Test the Check

1. Use an Account with at least two visible completed WhatId Tasks or Events inside 60 days. Confirm
   PASS, Found `2` or more, Expected `2`, and complete evidence.
2. Use an Account with exactly one qualifying activity. Confirm Warning/FAIL and remediation.
3. Use an Account with no activity. Confirm Found is exactly `0`; it must not be absent.
4. Add a Contact-only WhoId Task and an activity older than the window. Confirm neither changes the
   count.
5. Edit either declared parameter and confirm behavior changes without a class deployment.
6. Enter `{"daysBack":"90","minimumActivities":2}`, an unknown key, zero, and a value above its
   maximum. Confirm each returns `UNABLE_TO_EVALUATE` with `INVALID_APEX_PARAMETERS` before the
   plugin runs. Restore valid JSON.
7. Confirm the message link and **Open account** action use a same-org safe path. In a
   subscriber-owned copy, try an unsafe scheme and confirm the readable label remains without a
   clickable unsafe destination.
8. Run as a user who cannot see a qualifying Task or Event. Confirm the result follows that user's
   visibility, then restore access and confirm the activity contributes again.

You can also test without the card from **Developer Console → Debug → Open Execute Anonymous
Window** (replace the placeholder with an Account ID):

```apex
Id accountId = '001XXXXXXXXXXXXXXX';
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  // This is the Qualified API Name of the Check created in Step 4.
  rhc.RecordHealthCheckRequest.forCheck('Account_Has_Recent_Activity', accountId)
    .withResultMode(rhc.RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
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
| `APEX_CLASS_NOT_FOUND` | Confirm the installed package contains `AccountHasRecentActivityCheck`, match the class name in **Apex Class**, and confirm any replacement class implements `rhc.RecordHealthCheckPlugin`. |
| `APEX_EVALUATOR_ERROR` | Confirm the running user can read Task, Event, and the queried fields. Then use **Show Diagnostics** only with an authorized administrator to inspect the underlying exception. |
| A known Task does not count | Confirm it is closed, its `WhatId` is this Account, its `ActivityDate` is inside the effective window, and the running user can see it. |
| `INVALID_APEX_PARAMETERS` | Remove unknown or duplicate keys; use JSON integers; keep `daysBack` in 1–3,650 and `minimumActivities` in 1–1,000. Omit a key only when its deliberate default is appropriate. |

## Customize this Check

Change `daysBack` or `minimumActivities` in JSON without deploying code. Change the Task or Event
filters only when your definition of activity differs, and update the class tests and explanatory
copy at the same time. If `LastActivityDate` alone answers the business question, replace this Apex
Check with a simpler Verify with a formula.

## Related

- [Next: Combine per-row conditions on a child object →](./open-opportunity-health.md)
- [Browse Apex examples](./README.md)
- [Complete 2.0.10 contract](../../reference/release-2.0.10.md)
