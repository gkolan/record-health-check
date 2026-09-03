# Strategic Account Is Ready

> [!NOTE]
> On this page, build a weighted Apex readiness score that combines four Strategic Account signals, explains the gaps, and lets an administrator control the passing threshold through Custom Metadata.
>
> **Setup reference**
>
> Use the [Apex reference](../../developer-guides/write-an-apex-check.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> The supporting Apex class lives under `integration-tests/` and does not install with the package.
> Create and deploy the subscriber-owned class in Step 2 before configuring the Check. The code on
> this page uses the public `rhc.*` types provided by the installed package.

## Scenario

An account director preparing a Strategic Account for an executive review currently completes four
separate reviews:

- Customer relationships.
- Open pipeline.
- Recent follow-up.
- Billing address.

> [!TIP]
> **Why use Record Health Check**
>
> Record Health Check combines the four reviews into one score and points the director to the areas
> that still need attention.

## Before you start

- Install Record Health Check.
- Assign **Record Health Check Admin** to the administrator creating the Check Set and Check.
- Have a Salesforce developer review, test, and deploy the Apex class. Record Health Check does not
  install this example class.
- Confirm that `Strategic` is the exact Account Type picklist API value used in your org. If it is
  not, change the applicability formula in Step 4.

## What you will learn

| Skill | How this example teaches it |
| --- | --- |
| Build a weighted readiness score | Apex combines several Account signals into one score. |
| Keep thresholds configurable | Apex Parameters (JSON) lets an admin tune the decision. |
| Explain a calculated outcome | The result shows the score and passing target; the guidance names the four inputs to review. |

## Readiness criteria

### What contributes to readiness

| Criterion | Passes when |
| --- | --- |
| Contacts | At least one related Contact exists |
| Open pipeline | Sum of open Opportunity `Amount` is greater than zero |
| Recent activity | At least one completed Task or Event exists inside `activityDaysBack` |
| Billing complete | `BillingStreet`, `BillingCity`, and `BillingCountry` are all populated |

### How the result is decided

| Outcome | When it happens |
| --- | --- |
| **Pass** (`PASS`) | The score meets or exceeds `minScore` |
| **Fail** (`FAIL`) | The score is below `minScore` |
| **Skipped** (`SKIPPED`) | Account Type is not Strategic, so the scoring class does not run |

### Choose how your org measures readiness

The included configuration uses:

| Parameter | Default | Meaning |
| --- | --- | --- |
| Points per criterion | **25** | Each of the four criteria adds 25 points when it passes |
| Minimum passing score | **80** | Score must meet or exceed this value to Pass |
| Recent activity window | **60 days** | Look-back for completed Tasks and Events |
| Missing or invalid JSON | **80** points / **30 days** | Fallback `minScore` and `activityDaysBack` when parameters are missing or invalid |

The possible scores are 0, 25, 50, 75, and 100. A minimum of 80 therefore requires all four
criteria and is effectively the same as a minimum of 100.

Before activation, choose the policy that matches your process:

| Goal | Configuration |
| --- | --- |
| One missing area is acceptable | Change `minScore` to **75** |
| Every area is required, one combined result | Keep `minScore` at **80** |
| Every area is required, separate visible results | Create four Checks instead of using a score |

## What the card shows

| Card value | Meets minimum | Below minimum | Not Strategic |
| --- | --- | --- | --- |
| **Status** | `PASS` | `FAIL` | `SKIPPED` |
| **Found** | Numeric score from `0` through `100` | Numeric score from `0` through `100` | Not applicable |
| **Expected** | Configured minimum score | Configured minimum score | Not applicable |
| **Message** | None | Configured Critical message | Applicability explains skip |

## Why use Verify with Apex

| Approach | What the user gets |
| --- | --- |
| **One Verify with Apex** | One readiness result with a score out of 100 and a configurable passing score. The failure and fix guidance names the four source areas to review. |
| **Four separate Query or Checks that use Verify with a formula** | Four pass-or-fail results, one for Contacts, pipeline, activity, and billing. Use this approach when every area is required or should remain visible on its own. |
| **Checks with prerequisites** | Checks can run in a required order, but their results are not added into one score. Use prerequisites when a later check should wait for an earlier check to pass. |

## What Record Health Check passes to Apex

Shared scope inputs are documented once in the
[Apex examples README](./README.md#what-record-health-check-passes-to-apex). This Check receives Account
Ids plus scoring parameters (`minScore`, activity window, and related weights).

```apex
List<Id> accountIds = scope.recordIds;
```

The complete class below queries Accounts, Contacts, Opportunities, Tasks, and Events once per
scope and then assembles one score for every requested Account.

## Confirm the score and developer ownership

This class lives in integration-test source and is not installed in a subscriber org. A developer
must review, test, and deploy it before configuration. If no developer owns it, four focused Formula
or Query Checks are clearer and show which criterion failed.

`minScore: 80` is the passing threshold; it does not require a perfect score of 100. Build tests at
75, 80, and 100 so the boundary is visible. This example falls back to defaults for missing or
invalid JSON; approve that behavior rather than assuming it returns `INVALID_CONFIG` like every
plugin. The card shows the total score, not which individual criteria were missed.

`ISPICKVAL(Type, "Strategic")` uses the stored Account Type picklist API value, not Record Type.
Confirm it in Object Manager. Review user-mode access across Account, Contact, Opportunity, and
activity fields. Add the card to the Account Lightning page, activate the intended assignment, and
test as a user with **Record Health Check Card User**. Repository tests and Execute Anonymous are
developer steps.

## Step 1: Choose the score and activity window

Use Check parameters to change the passing score and activity window without editing the class:

```json
{
  "minScore": 80,
  "activityDaysBack": 60
}
```

Record Health Check parses the JSON and supplies both named values in `scope.parameters`.
`minScore` accepts `1`–`100`, and `activityDaysBack` accepts `1`–`3650`; missing or invalid values
silently use 80 and 30. Enter and test explicit valid whole numbers rather than relying on those
fallbacks. See
[Parameter parsing patterns](../../developer-guides/write-an-apex-check.md#scope)
for validation and type-conversion guidance.

## Implementation summary

The class queries the
three Account billing fields, counts visible Contacts, sums visible open Opportunity Amount, and
counts visible completed Tasks plus Events inside the window. Each true criterion adds 25 points.
It returns `PASS` when `score >= minScore`. Found shows the numeric score, and Expected shows the
configured minimum. The Check's guidance directs the user to Contacts, open pipeline, recent
activity, and billing address when the score is low.

Applicability evaluates `ISPICKVAL(Type, "Strategic")` before Apex runs. An open Opportunity with
blank Amount earns no pipeline points; any missing billing component loses all billing points; one
Contact or one qualifying activity is sufficient for its respective criterion.

## Step 2: Create and test the Apex class

Create an Apex class named `AccountStrategicReadinessCheck` from the code below. Comments explain
the inputs, administrator settings, user access, pass logic, and returned values.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Reference RecordHealthCheck for a weighted Strategic Account readiness score.
 * Example implementation retained here only as an integration-test sample.
 * {"minScore": 80, "activityDaysBack": 60}
 */
global with sharing class AccountStrategicReadinessCheck implements rhc.RecordHealthCheckPlugin {
  private static final Integer DEFAULT_MIN_SCORE = 80;
  private static final Integer DEFAULT_ACTIVITY_DAYS = 30;
  private static final Integer MIN_SCORE = 1;
  private static final Integer MAX_SCORE = 100;
  private static final Integer MIN_ACTIVITY_DAYS = 1;
  private static final Integer MAX_ACTIVITY_DAYS = 3650;
  private static final Integer POINTS_PER_CRITERION = 25;

  global Map<Id, rhc.RecordHealthCheckOutcome> evaluate(
    rhc.RecordHealthCheckScope scope
  ) {
    List<Id> recordIds = scope.recordIds;
    Integer minScore = resolveInt(
      scope.parameters,
      'minScore',
      DEFAULT_MIN_SCORE,
      MIN_SCORE,
      MAX_SCORE
    );
    Integer activityDays = resolveInt(
      scope.parameters,
      'activityDaysBack',
      DEFAULT_ACTIVITY_DAYS,
      MIN_ACTIVITY_DAYS,
      MAX_ACTIVITY_DAYS
    );

    // Five queries for the whole scope, where the single-record version needed
    // five per record. Each returns the SET of Accounts meeting one criterion,
    // so an Account absent from a set simply scores nothing for it.
    Map<Id, Account> accounts = loadAccounts(recordIds);
    Set<Id> withContacts = accountsWithContacts(recordIds);
    Set<Id> withPipeline = accountsWithOpenPipeline(recordIds);
    Set<Id> withActivity = accountsWithRecentActivity(recordIds, activityDays);

    rhc.RecordHealthCheckValue expected = rhc.RecordHealthCheckValue.ofCount(minScore);
    Map<Id, rhc.RecordHealthCheckOutcome> results = new Map<Id, rhc.RecordHealthCheckOutcome>();
    for (Id recordId : recordIds) {
      Account acct = accounts.get(recordId);
      if (acct == null) {
        // Deleted between selection and execution, or invisible to this user.
        // Never FAIL: failing a record the user cannot see would leak that it
        // exists.
        results.put(
          recordId,
          rhc.RecordHealthCheckOutcome.unableToEvaluate(
            'RECORD_NO_LONGER_AVAILABLE'
          )
        );
        continue;
      }

      Integer score = 0;
      if (withContacts.contains(recordId)) {
        score += POINTS_PER_CRITERION;
      }
      if (withPipeline.contains(recordId)) {
        score += POINTS_PER_CRITERION;
      }
      if (withActivity.contains(recordId)) {
        score += POINTS_PER_CRITERION;
      }
      if (billingComplete(acct)) {
        score += POINTS_PER_CRITERION;
      }

      results.put(
        recordId,
        (score >= minScore
            ? rhc.RecordHealthCheckOutcome.pass('APEX_PASS')
            : rhc.RecordHealthCheckOutcome.fail('APEX_FAIL'))
          .withFound(rhc.RecordHealthCheckValue.ofCount(score))
          .withComparison('GREATER_THAN_OR_EQUAL', expected)
      );
    }
    return results;
  }

  private static Map<Id, Account> loadAccounts(List<Id> recordIds) {
    return new Map<Id, Account>(
      [
        SELECT Id, BillingStreet, BillingCity, BillingCountry
        FROM Account
        WHERE Id IN :recordIds
        WITH USER_MODE
      ]
    );
  }

  private static Set<Id> accountsWithContacts(List<Id> recordIds) {
    Set<Id> found = new Set<Id>();
    for (AggregateResult row : [
      SELECT AccountId accountId
      FROM Contact
      WHERE AccountId IN :recordIds
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      found.add((Id) row.get('accountId'));
    }
    return found;
  }

  private static Set<Id> accountsWithOpenPipeline(List<Id> recordIds) {
    Set<Id> found = new Set<Id>();
    for (AggregateResult row : [
      SELECT AccountId accountId, SUM(Amount) total
      FROM Opportunity
      WHERE AccountId IN :recordIds AND IsClosed = FALSE
      WITH USER_MODE
      GROUP BY AccountId
    ]) {
      Decimal total = (Decimal) row.get('total');
      if (total != null && total > 0) {
        found.add((Id) row.get('accountId'));
      }
    }
    return found;
  }

  private static Set<Id> accountsWithRecentActivity(
    List<Id> recordIds,
    Integer daysBack
  ) {
    Date cutoff = Date.today().addDays(-daysBack);
    Set<Id> found = new Set<Id>();
    for (AggregateResult row : [
      SELECT WhatId whatId
      FROM Task
      WHERE WhatId IN :recordIds AND IsClosed = TRUE AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      found.add((Id) row.get('whatId'));
    }
    for (AggregateResult row : [
      SELECT WhatId whatId
      FROM Event
      WHERE WhatId IN :recordIds AND ActivityDate >= :cutoff
      WITH USER_MODE
      GROUP BY WhatId
    ]) {
      found.add((Id) row.get('whatId'));
    }
    return found;
  }

  private static Boolean billingComplete(Account acct) {
    return String.isNotBlank(acct.BillingStreet) &&
      String.isNotBlank(acct.BillingCity) &&
      String.isNotBlank(acct.BillingCountry);
  }

  @TestVisible
  private static Integer resolveInt(
    Map<String, Object> parameters,
    String key,
    Integer defaultValue,
    Integer min,
    Integer max
  ) {
    if (parameters == null) {
      return defaultValue;
    }
    Object raw = parameters.get(key);
    if (raw == null) {
      return defaultValue;
    }
    try {
      Integer parsed = Integer.valueOf(String.valueOf(raw));
      return parsed >= min && parsed <= max ? parsed : defaultValue;
    } catch (Exception ex) {
      return defaultValue;
    }
  }
}
```

<!-- END GENERATED APEX CLASS -->

Create an Apex test class before deployment. Test a score of 0, each individual 25-point
criterion, a score of 100, both parameter fallbacks, an unavailable Account, 200 Account IDs, and
constant SOQL query usage as the number of Accounts increases. The repository's
[`AccountStrategicReadinessCheckTest`](../../../packages/record-health-check/integration-tests/main/default/classes/AccountStrategicReadinessCheckTest.cls)
is a package implementation reference; a subscriber test must use the public `rhc.*` types.

## Context and result contract

Record Health Check calls the plugin once for a scope:

```apex
Map<Id, rhc.RecordHealthCheckOutcome> evaluate(rhc.RecordHealthCheckScope scope)
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

For applicability, configure **Applies To** on the Check so Record Health Check skips before Apex
runs. The framework supplies identity, label, severity, messages, display values, and diagnostics.
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
| **Card Title** | Account Readiness |
| **Card Subtitle** | Confirm the Account meets the strategic readiness score. |
| **When Checks Run** | When the user clicks Run |
| **Summary Display** | Below Checks |
| **Reveal Mode** | One by one |
| **Passed Checks** | Show each check |
| **Skipped Checks** | Show each check |
| **Found/Expected Display** | On demand |
| **Stop after a system error** | Unchecked |
| **Show Diagnostics** | Unchecked; enable temporarily only for authorized troubleshooting |
| **Publish User Run Event** | Unchecked |
| **Active** | Checked |

## Step 4: Configure the Check

In **Setup → Custom Metadata Types → Record Health Check → Manage Records**, create the Check:

| Setup field | API name | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../reference/custom-metadata/check-fields.md#developer-name-developername) | `Strategic_Account_Is_Ready` |
| **Label** | [`MasterLabel`](../../reference/custom-metadata/check-fields.md#label-masterlabel) | Strategic Account Is Ready |
| **Check Set** | [`Record_Health_Check_Set__c`](../../reference/custom-metadata/check-fields.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../reference/custom-metadata/check-fields.md#check-title-checktitle__c) | Strategic Account Is Ready |
| **Evaluation Type** | [`EvaluationType__c`](../../reference/custom-metadata/check-fields.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../reference/custom-metadata/check-fields.md#apex-class-apexclass__c) | `AccountStrategicReadinessCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../reference/custom-metadata/check-fields.md#apex-parameters-json-apexparametersjson__c) | `{"minScore": 80, "activityDaysBack": 60}` |
| **Applies To** | [`ApplicabilityMode__c`](../../reference/custom-metadata/check-fields.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../reference/custom-metadata/check-fields.md#applies-when-formula-applicabilityformula__c) | `ISPICKVAL(Type, "Strategic")` |

Confirm the `Strategic` Type picklist API value in your org. Skip comes from applicability: the class always returns PASS or FAIL when it runs.

## Optional configuration

| Setup field | API name | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../reference/custom-metadata/check-fields.md#check-description-checkdescription__c) | Scores Contact coverage, open pipeline, recent activity, and billing-address completeness for Strategic Accounts. |
| **Failure Severity** | [`FailureSeverity__c`](../../reference/custom-metadata/check-fields.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-failed-failuremessage__c) | This strategic account is not ready: readiness score is below the required minimum. Improve the readiness checks or lower `minScore` in Apex Parameters (JSON). |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../reference/custom-metadata/check-fields.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to calculate strategic readiness. Confirm the running user can read the Account and related records used by this Check. |
| **Prerequisite Check** | [`PrerequisiteCheck__c`](../../reference/custom-metadata/check-fields.md#prerequisite-check-prerequisitecheck__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../reference/custom-metadata/check-fields.md#fix-message-fixmessage__c) | Review Contact coverage, open pipeline, recent activity, and billing address to identify which criteria did not add points. |
| **Action Label** | [`ActionLabel__c`](../../reference/custom-metadata/check-fields.md#action-label-actionlabel__c) | Leave blank: one portable link cannot correct all four readiness areas. |
| **Action URL** | [`ActionUrl__c`](../../reference/custom-metadata/check-fields.md#action-url-actionurl__c) | Leave blank; use an org-specific readiness report or playbook only after verifying it. |
| **Evaluation Order** | [`EvaluationOrder__c`](../../reference/custom-metadata/check-fields.md#evaluation-order-evaluationorder__c) | `30` |
| **Active** | [`IsActive__c`](../../reference/custom-metadata/check-fields.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../reference/custom-metadata/check-fields.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

`minScore` and `activityDaysBack` change the passing score and activity window without changing the class.

The applicability fields in **Configure the Check** are required for the documented `SKIPPED`
result. Add an action link only when it helps the user identify the missing readiness area; an
Account view link alone does not explain which criterion lost points.

## What the user sees

The Apex class turns the weighted score and configured threshold into these user-facing values:

| Health result or card value | What the user sees |
| --- | --- |
| **`PASS`** | A Strategic Account at or above `minScore` passes. |
| **`FAIL`** | A score below `minScore` shows Needs attention with Critical severity. |
| **`SKIPPED`** | A non-Strategic Account is skipped by Formula applicability before the Apex class runs. |
| **Found** | Found shows the calculated score, such as `75`. |
| **Expected** | Expected shows the configured passing threshold, such as `80`. |

Scores move in 25-point increments, so a minimum of 80 effectively requires 100. Use 75 when
meeting three of the four criteria should pass.

## Security and access

The readiness score follows the running user's Salesforce access.

- Account billing fields plus visible Contacts, open Opportunities, Tasks, and Events.

- A user who cannot see a qualifying related record may receive a lower score than an administrator for the same Account.

- A lower user-mode score is not proof that the related record does not exist. Keep `WITH USER_MODE` so scores reflect the running user's access.

- If a query throws because the running user cannot access an object or queried field, Record
  Health Check returns `ERROR` with reason code `APEX_EVALUATOR_ERROR`. If the Account is deleted or
  is no longer visible after the run starts, the class returns `UNABLE_TO_EVALUATE` with
  `RECORD_NO_LONGER_AVAILABLE`.

- The class reads data only and performs no DML or callouts.

- Compare the score for the intended user and an administrator, then confirm the difference matches the approved sharing model.

## Step 5: Test the Check

1. Set Type to Strategic on an Account with no Contacts, no open pipeline Amount, no recent activity, and incomplete billing (score **0**). Confirm Critical (`0` vs `80+`).
2. Add only Contacts (score **25**). Confirm still Critical while `minScore` is 80.
3. Meet all four criteria (score **100**), or lower `minScore` in JSON until the current score passes, then confirm a pass.
4. Change Type away from Strategic and confirm skip (class does not run).
5. Repeat with restricted related-record access and confirm the score reflects only visible evidence.

### Execute Anonymous

Run this from **Developer Console → Debug → Open Execute Anonymous Window** after replacing the
placeholder with an Account ID you can access:

```apex
Id accountId = '001XXXXXXXXXXXXXXX';
rhc.RecordHealthCheckResponse response = rhc.RecordHealthCheck.evaluate(
  // This is the Check Qualified API Name created in Step 4.
  rhc.RecordHealthCheckRequest.forCheck('Strategic_Account_Is_Ready', accountId)
    .withResultMode(rhc.RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
);
System.debug(LoggingLevel.INFO, JSON.serializePretty(response));
```

Confirm `evaluation.status`, `display.foundDisplayValue`, and
`display.expectedDisplayValue` match the same Account on the card.

### Lightning record page

1. Add **Record Health Check** to the Account record page in Lightning App Builder.
2. Select `Account_Apex_Readiness`, save, and activate the page.
3. Open an Account, click **Run** or **Rerun**, and compare the result with Execute Anonymous.

## Failures, remedies, and customization

| Symptom | What to verify |
| --- | --- |
| Check always skips | Confirm the Type value is exactly `Strategic`, or adapt the applicability formula. |
| Score is unexpectedly low | Check all four criteria, blank Amount, activity window, and running-user visibility. |
| `APEX_EVALUATOR_ERROR` | Verify object/field access and inspect authorized diagnostics. |

Use JSON to change the minimum or window. Changing criteria or weights requires matching class,
test, threshold, and documentation updates.

## Related

- [← Prev: Open Opportunity health](./open-opportunity-health.md) · [Next: Inactive approvers →](./inactive-approver.md)
- [Browse Apex examples](./README.md)
