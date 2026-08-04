# 02 · Open Pipeline Is Ready for Coaching

> [!NOTE]
> On this page, build an Apex Rule that flags only an open Opportunity carrying all three coaching risks, stale activity, no Next Step, and a Close Date outside the current quarter.
>
> **Setup reference**
>
> Use the [Apex reference](../../reference/evaluation/apex-rule-contract.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> The supporting Apex class for this example lives under `integration-tests/`. It does not install
> with the Framework package. Deploy or copy the class when you want this Rule in an org.

## Scenario

A sales manager opens an Account before pipeline coaching.

- The manager needs to find Opportunities that have several warning signs on the same deal.
- A stale deal with no Next Step and a Close Date outside the current quarter needs focused coaching.
- The same warnings spread across different Opportunities do not identify one deal with that combined risk.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check identifies deals where all three warning signs occur together, so the manager can coach the Opportunity that needs attention instead of reconciling separate warnings.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Apply several conditions to one related record | Apex evaluates multiple warning signs on each open Opportunity. |
| Keep complex logic readable | Named Apex conditions replace an opaque metadata expression. |
| Summarize a failure for users | The result identifies why pipeline needs attention. |

## What the card shows

| Card value | Healthy | Unhealthy | No open Opportunities |
| --- | --- | --- | --- |
| **Status** | `PASS` | `FAIL` | `SKIPPED` |
| **Found** | `0 unhealthy` | `<N> unhealthy` | Not applicable |
| **Expected** | `0 unhealthy` | `0 unhealthy` | Not applicable |
| **Message** | No failure message | Configured Critical message | Applicability explains the skip |

## Why use Verify with Apex

| Evaluation Type | Why it fits |
| --- | --- |
| **Verify with Apex** | Best fit. The class confirms that all three warning signs belong to the same open Opportunity. |
| **Verify with a query** in three separate Rules | Would show three separate results, and each warning could come from a different Opportunity. |
| **Verify with a query** in one Rule | Could place every condition in one query, but the current-quarter date logic and user guidance would be harder to maintain. |

## What Record Health Check passes to Apex

Shared scope inputs are documented once in the
[Apex examples README](README.md#what-record-health-check-passes-to-apex). This Rule receives Account
Ids and binds them in one Opportunity query.

```apex
List<Id> accountIds = scope.recordIds;
```

The complete class below returns one outcome for every requested Account.

## Step 1:
## Step 1: Understand the parameters

Use Rule parameters to change the stale-activity window without editing the Apex class:

```json
{
  "staleDays": 30
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON and supplies it as `scope.parameters`. The class accepts
`staleDays` from `1` through `3650`; a missing or invalid value uses 30. See
[Parameter parsing patterns](../../reference/evaluation/apex-rule-contract.md#scope)
for validation and type-conversion guidance.

## Step 2: Create the Apex class

The complete evaluator logic is below. It reads only open Opportunities visible to the running user,
calculates the current calendar-quarter boundaries, and counts a row only when all three conditions
are true.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Example RecordHealthCheckRule that flags open Opportunities that are simultaneously
 * stale, missing Next Step, and not closing this quarter. Tunable via
 * {"staleDays": 30}
 */
global with sharing class AccountOpenOpportunityHealthCheck implements RecordHealthCheckRule {
  private static final Integer DEFAULT_STALE_DAYS = 30;
  private static final Integer MIN_STALE_DAYS = 1;
  private static final Integer MAX_STALE_DAYS = 3650;

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
  ) {
    Integer staleDays = resolveStaleDays(scope.parameters);
    Date staleCutoff = Date.today().addDays(-staleDays);
    Date quarterStart = getQuarterStart(Date.today());
    Date quarterEnd = quarterStart.addMonths(3).addDays(-1);
    List<Id> recordIds = scope.recordIds;

    // Seed every Account first. An Account with no open Opportunities returns
    // no rows at all, and "nothing unhealthy" is a real pass rather than a
    // record the check forgot to answer for.
    Map<Id, Integer> unhealthyByAccount = new Map<Id, Integer>();
    Map<Id, Integer> scannedByAccount = new Map<Id, Integer>();
    for (Id recordId : recordIds) {
      unhealthyByAccount.put(recordId, 0);
      scannedByAccount.put(recordId, 0);
    }

    // One query for the whole scope. AccountId is selected so each row can be
    // attributed back to the record it belongs to.
    for (Opportunity opp : [
      SELECT AccountId, LastActivityDate, NextStep, CloseDate
      FROM Opportunity
      WHERE AccountId IN :recordIds AND IsClosed = FALSE
      WITH USER_MODE
    ]) {
      if (!scannedByAccount.containsKey(opp.AccountId)) {
        continue;
      }
      scannedByAccount.put(
        opp.AccountId,
        scannedByAccount.get(opp.AccountId) + 1
      );
      if (isUnhealthy(opp, staleCutoff, quarterStart, quarterEnd)) {
        unhealthyByAccount.put(
          opp.AccountId,
          unhealthyByAccount.get(opp.AccountId) + 1
        );
      }
    }

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(0);
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : recordIds) {
      Integer unhealthyCount = unhealthyByAccount.get(recordId);
      RecordHealthCheckOutcome outcome = unhealthyCount == 0
        ? RecordHealthCheckOutcome.pass('APEX_PASS')
        : RecordHealthCheckOutcome.fail('APEX_FAIL');
      results.put(
        recordId,
        outcome
          .withFound(RecordHealthCheckValue.ofCount(unhealthyCount))
          .withComparison('EQUALS', expected)
      );
    }
    return results;
  }

  @TestVisible
  private static Boolean isUnhealthy(
    Opportunity opp,
    Date staleCutoff,
    Date quarterStart,
    Date quarterEnd
  ) {
    Boolean stale =
      opp.LastActivityDate == null ||
      opp.LastActivityDate < staleCutoff;
    Boolean missingNextStep = String.isBlank(opp.NextStep);
    Boolean closeNotThisQuarter =
      opp.CloseDate == null ||
      opp.CloseDate < quarterStart ||
      opp.CloseDate > quarterEnd;
    return stale && missingNextStep && closeNotThisQuarter;
  }

  @TestVisible
  private static Date getQuarterStart(Date reference) {
    Integer month = reference.month();
    Integer quarterMonth = ((Integer) Math.floor((month - 1) / 3.0) * 3) + 1;
    return Date.newInstance(reference.year(), quarterMonth, 1);
  }

  @TestVisible
  private Integer resolveStaleDays(Map<String, Object> parameters) {
    if (parameters == null) {
      return DEFAULT_STALE_DAYS;
    }
    Object raw = parameters.get('staleDays');
    if (raw == null) {
      return DEFAULT_STALE_DAYS;
    }
    try {
      Integer parsed = Integer.valueOf(String.valueOf(raw));
      return parsed >= MIN_STALE_DAYS &&
        parsed <= MAX_STALE_DAYS
        ? parsed
        : DEFAULT_STALE_DAYS;
    } catch (Exception ex) {
      return DEFAULT_STALE_DAYS;
    }
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
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Open_Opportunities_Are_Healthy` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Open Opportunities Are Healthy |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Open Opportunities Are Healthy |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/fields-check-rule.md#apex-class-apexclass__c) | `AccountOpenOpportunityHealthCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/fields-check-rule.md#apex-parameters-json-apexparametersjson__c) | `{"staleDays": 30}` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | When a count query matches |
| **Applies When (Count Query)** | [`ApplicabilityCountQuery__c`](../../metadata/fields-check-rule.md#applies-when-count-query-applicabilitycountquery__c) | `SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false` |
| **Count Must Be** | [`ApplicabilityCountOperator__c`](../../metadata/fields-check-rule.md#count-must-be-applicabilitycountoperator__c) | Greater than |
| **Count Value** | [`ApplicabilityCountThreshold__c`](../../metadata/fields-check-rule.md#count-value-applicabilitycountthreshold__c) | `0` |

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Checks whether any open Opportunity is stale, missing Next Step, and outside the current quarter at the same time. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | `{!record.Name fallback="this record"}` has open opportunities that are simultaneously stale, missing a Next Step, and have a Close Date outside the current quarter. Update Next Step, activity, or Close Date on the unhealthy Opportunities. |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to check open Opportunity health. Confirm the running user can read the Opportunities and fields used by this Rule. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Review the open Opportunities. For each unhealthy Opportunity, update Next Step, log current activity, or correct Close Date. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | `Review open opportunities` |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | `/lightning/r/Account/{!record.Id}/related/Opportunities/view` |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `20` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

`staleDays` sets how old `LastActivityDate` must be before an Opportunity counts as stale.

The applicability fields in **Configure the Rule** are required for the documented skip behavior;
they are not repeated here. The pack metadata currently supplies the description, messages,
applicability, order, and Active. Add the recommended Fix Message and action link in Setup when the
standard Opportunities related list is available on the Account page.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Apex_Readiness` |
| **Object** | `Account` |
| **Card Title** | `Account Readiness` |
| **Card Subtitle** | Confirm open Opportunities are not stale on amount, close date, and next step. |
| **When Checks Run** | Run on request |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

## What the user sees

Count-query applicability and the Apex result become these Framework outcomes and card values:

| Framework result or card value | What the user sees |
| --- | --- |
| **`PASS`** | Zero unhealthy open Opportunities passes. |
| **`FAIL`** | One or more Opportunities has all three warning signs, so the card shows Needs attention with Critical severity. |
| **`SKIPPED`** | An Account with no open Opportunities is skipped by the applicability count query before the Apex class runs. |
| **Found** | Found shows the unhealthy Opportunity count, such as `0 unhealthy`. |
| **Expected** | Expected shows that the unhealthy Opportunity count must be `0`. |

`LastActivityDate = null` counts as stale, blank `NextStep` counts as missing, and null `CloseDate`
counts as outside the quarter. An Opportunity remains healthy when it has only one or two warning
signs because the class combines all three conditions with AND logic. Calling the class directly
with no open Opportunities returns `PASS`; only Framework applicability creates `SKIPPED`.

## Security and access

The class uses sharing and a user-mode Opportunity query so its result follows the running user's Salesforce access.

- Opportunity plus `AccountId`, `IsClosed`, `LastActivityDate`, `NextStep`, and `CloseDate`.

- A hidden unhealthy Opportunity does not contribute to the result and can change Needs attention to Pass or Skip.

- Missing object or field permission must show **Unable to evaluate**, not a false Pass.

- The evaluator performs no DML or callouts.

- Prove the access-limited case with the actual Permission Sets and Opportunity sharing assigned to card users.

## Step 4: Test the Rule

1. Add an open Opportunity with blank Next Step, `LastActivityDate` older than the stale window, and `CloseDate` outside the current quarter. Confirm Critical.
2. Fix or remove that Opportunity, rerun, and confirm a pass.
3. Remove all open Opportunities and confirm skip.
4. Repeat the failing case as a user who cannot see the unhealthy Opportunity. Confirm the result
   follows that user's visibility and does not expose hidden Opportunity data.

Execute Anonymous alternative:

```apex
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forRule(
    'Open_Opportunities_Are_Healthy',
    '001XXXXXXXXXXXXXXX'
  ).withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(response));
```

### Lightning record page

1. Add **Record Health Check** to the Account record page in Lightning App Builder.
2. Select `Account_Apex_Readiness`, save, and activate the page.
3. Open the same Account, click **Run** or **Rerun**, and compare Status, Found, and Expected with
   the Execute Anonymous result.

## Failures and remedies

| Symptom | What to verify |
| --- | --- |
| Rule skips unexpectedly | Confirm an open Opportunity is visible to the running user and the applicability query still uses the Account merge token. |
| Expected unhealthy row passes | Confirm all three conditions are true on the same Opportunity and that `staleDays` is valid. |
| `APEX_EVALUATOR_ERROR` | Verify Opportunity object/field access and inspect authorized diagnostics. |
| `APEX_CLASS_NOT_FOUND` | Deploy the class and match **Apex Class** exactly. |

## Customize this Rule

Change `staleDays` in JSON without redeploying. If you change the definition of unhealthy, update
the loop conditions, tests, failure message, and required field permissions together. Remove or
change the applicability configuration if an Account with no open Opportunities should pass rather
than skip.

## Related

- [← Prev: Recent activity](01-recent-activity.md) · [Next: Strategic readiness score →](03-strategic-readiness.md)
- [Browse Apex examples](README.md)
