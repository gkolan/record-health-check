# 03 · Strategic Account Is Ready

> [!NOTE]
> On this page, build a weighted Apex readiness score that combines four Strategic Account signals, explains the gaps, and lets an administrator control the passing threshold through Custom Metadata.
>
> **Setup reference**
>
> Use the [Apex reference](../../reference/reference-apex.md) for the complete setup fields and behavior.

> [!IMPORTANT]
> The supporting Apex class for this example lives under `integration-tests/`. It does not install
> with the Framework package. Deploy or copy the class when you want this Rule in an org.

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

- **Pass:** The score meets or exceeds `minScore`.
- **Fail:** The score is below `minScore`.
- **Skip:** Account Type is not Strategic, so the scoring class does not run.

### Choose how your team measures readiness

The included configuration uses:

- **25 points** for each of the four criteria.
- **80 points** as the minimum passing score.
- **60 days** for recent activity.
- **80 points** and **30 days** when the parameter JSON is missing or invalid.

The possible scores are 0, 25, 50, 75, and 100. A minimum of 80 therefore requires all four
criteria and is effectively the same as a minimum of 100.

Before activation, choose the policy that matches your process:

- If one missing area is acceptable, change `minScore` to **75**.
- If every area is required and one combined result is preferred, keep `minScore` at **80**.
- If every area is required and users should see a separate result for each one, create four Rules
  instead of using a score.

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
| **Four separate Query or Rules that use Verify with a formula** | Four pass-or-fail results, one for Contacts, pipeline, activity, and billing. Use this approach when every area is required or should remain visible on its own. |
| **Rules with prerequisites** | Checks can run in a required order, but their results are not added into one score. Use prerequisites when a later check should wait for an earlier check to pass. |

## What Record Health Check passes to Apex

| Input in Apex | Where it comes from |
| --- | --- |
| `scope.recordIds` | The Accounts being evaluated in this run |
| `scope.parameters` | **Apex Parameters (JSON)** (`ApexParametersJson__c`) on the `Record_Health_Check_Rule__mdt` record |

Record Health Check supplies the Account ID automatically; leave it out of the parameter JSON:

- On a Lightning record page, the scope normally contains the open record.
- Bulk Apex requests can place as many as 200 record IDs in one scope.
- Flow supplies its **Record ID** input to the scope-building pipeline.

Use the supplied ID as a SOQL bind variable:

```apex
List<Id> accountIds = scope.recordIds;
```

The complete class below queries Accounts, Contacts, Opportunities, Tasks, and Events once per
scope and then assembles one score for every requested Account.

## Step 1: Understand the parameters

Use Rule parameters to change the passing score and activity window without editing the class:

```json
{
  "minScore": 80,
  "activityDaysBack": 60
}
```

After deploying the class:

1. Open **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**.
2. Create or edit the Rule record.
3. Paste the object into **Apex Parameters (JSON)** (`ApexParametersJson__c`) on `Record_Health_Check_Rule__mdt`.

Record Health Check parses the JSON and supplies both named values in `scope.parameters`.
`minScore` accepts `1`–`100`, and `activityDaysBack` accepts `1`–`3650`; missing or invalid values
use 80 and 30. See
[Parameter parsing patterns](../../reference/reference-apex.md#scope)
for validation and type-conversion guidance.

## Implementation summary

The class queries the
three Account billing fields, counts visible Contacts, sums visible open Opportunity Amount, and
counts visible completed Tasks plus Events inside the window. Each true criterion adds 25 points.
It returns `PASS` when `score >= minScore`. Found shows the numeric score, and Expected shows the
configured minimum. The Rule's guidance directs the user to Contacts, open pipeline, recent
activity, and billing address when the score is low.

Applicability evaluates `ISPICKVAL(Type, "Strategic")` before Apex runs. An open Opportunity with
blank Amount earns no pipeline points; any missing billing component loses all billing points; one
Contact or one qualifying activity is sufficient for its respective criterion.

## Step 2: Create the Apex class

This is the complete class deployed by the pack. Comments explain the Record Health Check inputs, administrator settings, user access, pass logic, and returned values.

<!-- BEGIN GENERATED APEX CLASS -->

```apex
/**
 * @author Gautam Kolan (https://github.com/gkolan)
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Reference RecordHealthCheckRule for a weighted Strategic Account readiness score.
 * Example implementation retained here only as an integration-test fixture.
 * {"minScore": 80, "activityDaysBack": 60}
 */
global with sharing class AccountStrategicReadinessCheck implements RecordHealthCheckRule {
  private static final Integer DEFAULT_MIN_SCORE = 80;
  private static final Integer DEFAULT_ACTIVITY_DAYS = 30;
  private static final Integer MIN_SCORE = 1;
  private static final Integer MAX_SCORE = 100;
  private static final Integer MIN_ACTIVITY_DAYS = 1;
  private static final Integer MAX_ACTIVITY_DAYS = 3650;
  private static final Integer POINTS_PER_CRITERION = 25;

  global Map<Id, RecordHealthCheckOutcome> evaluate(
    RecordHealthCheckScope scope
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

    RecordHealthCheckValue expected = RecordHealthCheckValue.ofCount(minScore);
    Map<Id, RecordHealthCheckOutcome> results = new Map<Id, RecordHealthCheckOutcome>();
    for (Id recordId : recordIds) {
      Account acct = accounts.get(recordId);
      if (acct == null) {
        // Deleted between selection and execution, or invisible to this user.
        // Never FAIL: failing a record the user cannot see would leak that it
        // exists.
        results.put(
          recordId,
          RecordHealthCheckOutcome.unableToEvaluate(
            RecordHealthCheckReasonCodes.RECORD_NO_LONGER_AVAILABLE
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
            ? RecordHealthCheckOutcome.pass('APEX_PASS')
            : RecordHealthCheckOutcome.fail('APEX_FAIL'))
          .withFound(RecordHealthCheckValue.ofCount(score))
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
| `comparisonOperator` | The operator behind the decision, such as `GREATER_THAN_OR_EQUAL` |
| `expected` | A typed `RecordHealthCheckValue` describing the passing requirement |

For applicability, configure **Applies To** on the Rule so Record Health Check skips before Apex
runs. The framework supplies identity, label, severity, messages, display values, and diagnostics.
Missing or extra map keys, a null outcome, an invalid status, forbidden side effects, or an
unhandled exception produces `APEX_EVALUATOR_ERROR`, not a pass. See
[Returning an outcome](../../reference/reference-apex.md#outcome).


## Step 3: Configure the Rule

In **Setup → Custom Metadata Types → Record Health Check Rule → Manage Records**, create the Rule:

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Developer Name** | [`DeveloperName`](../../metadata/fields-check-rule.md#developer-name-developername) | `Strategic_Account_Is_Ready` |
| **Label** | [`MasterLabel`](../../metadata/fields-check-rule.md#label-masterlabel) | Strategic Account Is Ready |
| **Check Set** | [`Record_Health_Check_Set__c`](../../metadata/fields-check-rule.md#check-set-record_health_check_set__c) | `Account_Apex_Readiness` |
| **Check Title** | [`CheckTitle__c`](../../metadata/fields-check-rule.md#check-title-checktitle__c) | Strategic Account Is Ready |
| **Evaluation Type** | [`EvaluationType__c`](../../metadata/fields-check-rule.md#evaluation-type-evaluationtype__c) | Verify with Apex |
| **Apex Class** | [`ApexClass__c`](../../metadata/fields-check-rule.md#apex-class-apexclass__c) | `AccountStrategicReadinessCheck` |
| **Apex Parameters (JSON)** | [`ApexParametersJson__c`](../../metadata/fields-check-rule.md#apex-parameters-json-apexparametersjson__c) | `{"minScore": 80, "activityDaysBack": 60}` |
| **Applies To** | [`ApplicabilityMode__c`](../../metadata/fields-check-rule.md#applies-to-applicabilitymode__c) | When a formula is true |
| **Applies When (Formula)** | [`ApplicabilityFormula__c`](../../metadata/fields-check-rule.md#applies-when-formula-applicabilityformula__c) | `ISPICKVAL(Type, "Strategic")` |

Confirm the `Strategic` Type picklist API value in your org. Skip comes from applicability: the class always returns PASS or FAIL when it runs.

## Optional configuration

| Setup field | API&nbsp;name&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Value |
| --- | --- | --- |
| **Check Description** | [`CheckDescription__c`](../../metadata/fields-check-rule.md#check-description-checkdescription__c) | Scores Contact coverage, open pipeline, recent activity, and billing-address completeness for Strategic Accounts. |
| **Failure Severity** | [`FailureSeverity__c`](../../metadata/fields-check-rule.md#failure-severity-failureseverity__c) | Critical |
| **Message When Failed** | [`FailureMessage__c`](../../metadata/fields-check-rule.md#message-when-failed-failuremessage__c) | This strategic account is not ready: readiness score is below the required minimum. Improve the readiness checks or lower `minScore` in Apex Parameters (JSON). |
| **Message When Unable To Evaluate** | [`UnableToEvaluateMessage__c`](../../metadata/fields-check-rule.md#message-when-unable-to-evaluate-unabletoevaluatemessage__c) | Unable to calculate strategic readiness. Confirm the running user can read the Account and related records used by this Rule. |
| **Prerequisite Rule** | [`PrerequisiteRule__c`](../../metadata/fields-check-rule.md#prerequisite-rule-prerequisiterule__c) | Leave blank |
| **Fix Message** | [`FixMessage__c`](../../metadata/fields-check-rule.md#fix-message-fixmessage__c) | Review Contact coverage, open pipeline, recent activity, and billing address to identify which criteria did not add points. |
| **Action Label** | [`ActionLabel__c`](../../metadata/fields-check-rule.md#action-label-actionlabel__c) | Leave blank: one portable link cannot correct all four readiness areas. |
| **Action URL** | [`ActionUrl__c`](../../metadata/fields-check-rule.md#action-url-actionurl__c) | Leave blank; use an org-specific readiness report or playbook only after verifying it. |
| **Evaluation Order** | [`EvaluationOrder__c`](../../metadata/fields-check-rule.md#evaluation-order-evaluationorder__c) | `30` |
| **Active** | [`IsActive__c`](../../metadata/fields-check-rule.md#active-isactive__c) | Checked |
| **Publish User Result Event** | [`PublishUserResultEvent__c`](../../metadata/fields-check-rule.md#publish-user-result-event-publishuserresultevent__c) | Unchecked |

`minScore` and `activityDaysBack` change the passing score and activity window without changing the class.

The applicability fields in **Configure the Rule** are required for the documented skip behavior.
The pack supplies description, failure settings, applicability, order, and Active. The remaining
rows document recommended choices. Add an action link only when it helps the user fix the issue;
an Account view link alone does not show which readiness item is missing.

## Check Set configuration

Use these Check Set values:

| Check Set setting | Value |
| --- | --- |
| **Check Set** | `Account_Apex_Readiness` |
| **Object** | `Account` |
| **Card Title** | `Account Readiness` |
| **Card Subtitle** | Add one short sentence explaining what the card reviews. |
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

The Apex class turns the weighted score and configured threshold into these user-facing values:

| Framework result or card value | What the user sees |
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

- The class reads data only and performs no DML or callouts.

- Compare the score for the intended user and an administrator, then confirm the difference matches the approved sharing model.

## Step 4: Test the Rule

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
RecordHealthCheckResponse response = RecordHealthCheck.evaluate(
  RecordHealthCheckRequest.forRule('Strategic_Account_Is_Ready', accountId)
    .withResultMode(RecordHealthCheckResultMode.EVALUATION_WITH_DISPLAY)
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
| Rule always skips | Confirm the Type value is exactly `Strategic`, or adapt the applicability formula. |
| Score is unexpectedly low | Check all four criteria, blank Amount, activity window, and running-user visibility. |
| `APEX_EVALUATOR_ERROR` | Verify object/field access and inspect authorized diagnostics. |

Use JSON to change the minimum or window. Changing criteria or weights requires matching class,
test, threshold, and documentation updates.

## Related

- [← Prev: Open Opportunity health](02-open-opportunity-health.md) · [Next: Inactive approvers →](04-inactive-approver.md)
- [Browse Apex examples](README.md)
