# Record Health Check: Account Opportunity Readiness

## Plain-Language Summary

**Pass:** Every open Opportunity on the Account has a Next Step.

**Fail:** At least one open Opportunity has no Next Step, meaning the field is null or empty.

**Skip:** The Account has no open Opportunities to evaluate; the Check does not apply.

---

## Clarifying Questions

All required details are supplied by the requirement. No confirmation needed before proceeding to configuration.

---

## Check Set Table

| Setup Label                | API Field Name            | Proposed Value                                         | Why                                                                |
| -------------------------- | ------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------ |
| Label                      | MasterLabel               | Account Opportunity Readiness                          | Descriptive label for the card setup.                              |
| Developer Name             | DeveloperName             | Account_Opportunity_Readiness                          | Administrator-created name, no rhc\_\_ prefix per requirement.     |
| Object                     | ObjectApiName\_\_c        | Account                                                | The object whose record page shows this card.                      |
| Active                     | IsActive\_\_c             | true                                                   | Card is active by default.                                         |
| Card Title                 | CardTitle\_\_c            | Opportunity Readiness                                  | Title displayed at the top of the card on the Account record page. |
| Card Subtitle              | CardSubtitle\_\_c         | Checks that open Opportunities have Next Steps defined | Subtitle explains what this card covers for Account records.       |
| Run Mode                   | CardRunMode\_\_c          | RUN_ON_LOAD                                            | Requirement specifies "run when the page opens."                   |
| Reveal Mode                | CardRevealMode\_\_c       | ONE_BY_ONE                                             | Default; Checks are revealed one by one as they complete.          |
| Summary Display            | SummaryDisplay\_\_c       | TOP                                                    | Requirement specifies "summary above the Checks."                  |
| Passed Checks Display      | PassedChecksDisplay\_\_c  | SHOW_COUNT_ONLY                                        | Requirement specifies "show passed checks as a count only."        |
| Skipped Checks Display     | SkippedChecksDisplay\_\_c | SHOW_EACH_CHECK                                        | Default; skipped Checks are shown individually.                    |
| Found and Expected Display | FoundExpectedDisplay\_\_c | ON_DEMAND                                              | Default; Found and Expected values shown on demand.                |
| Run Button Display         | RunButtonDisplay\_\_c     | HIDE                                                   | Card runs on load, so no Run button is needed.                     |
| Run Button Label           | RunButtonLabel\_\_c       | (omit from metadata)                                   | Button is hidden; this field is not used.                          |
| Rerun Button Label         | RerunButtonLabel\_\_c     | (omit from metadata)                                   | Button is hidden; this field is not used.                          |
| Run Button Icon            | RunButtonIcon\_\_c        | (omit from metadata)                                   | Button is hidden; this field is not used.                          |
| Stop on System Error       | StopOnSystemError\_\_c    | false                                                  | Default; card continues running remaining Checks even after ERROR. |
| Show Diagnostics           | ShowDiagnostics\_\_c      | false                                                  | Diagnostics are off; sandbox troubleshooting only.                 |
| Publish User Run Event     | PublishUserRunEvent\_\_c  | false                                                  | Requirement specifies no Platform Events.                          |
| Publish Error Log Event    | PublishErrorLogEvent\_\_c | false                                                  | Requirement specifies no Platform Events.                          |

---

## Check Table

| Setup Label                   | API Field Name                   | Proposed Value                                                                                                                                                                | Why                                                                                                                                                                                                                      |
| ----------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Check Set                     | Record_Health_Check_Set\_\_c     | Account_Opportunity_Readiness                                                                                                                                                 | Links this Check to the Check Set above.                                                                                                                                                                                 |
| Label                         | MasterLabel                      | Open Opportunities Have Next Steps                                                                                                                                            | Descriptive name of the individual Check.                                                                                                                                                                                |
| Developer Name                | DeveloperName                    | Open_Opportunities_Have_Next_Steps                                                                                                                                            | Administrator-created name, no rhc\_\_ prefix per requirement.                                                                                                                                                           |
| Check Title                   | CheckTitle\_\_c                  | Open Opportunities have Next Steps                                                                                                                                            | Title states the claim being tested, so the row reads as a result.                                                                                                                                                       |
| Check Description             | CheckDescription\_\_c            | Passes when every open Opportunity on the Account has a Next Step defined.                                                                                                    | Explains what the Check compares and when it passes; does not restate the pass condition as a fact about the record.                                                                                                     |
| Evaluation Type               | EvaluationType\_\_c              | QUERY                                                                                                                                                                         | Requirement specifies QUERY Evaluation Type.                                                                                                                                                                             |
| Category                      | Category\_\_c                    | READINESS                                                                                                                                                                     | Requirement specifies Readiness category.                                                                                                                                                                                |
| Failure Severity              | FailureSeverity\_\_c             | CRITICAL                                                                                                                                                                      | Requirement specifies Critical severity.                                                                                                                                                                                 |
| Evaluation Order              | EvaluationOrder\_\_c             | 100                                                                                                                                                                           | Default; only one Check in this Set.                                                                                                                                                                                     |
| Active                        | IsActive\_\_c                    | true                                                                                                                                                                          | Check is active by default.                                                                                                                                                                                              |
| Failure Message               | FailureMessage\_\_c              | {!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} open Opportunit{!rhcResult.foundValuePluralSuffix} on {!record.Name fallback="this record"} lack a Next Step. | Concrete message stating what is wrong and how many are affected; includes record name token and plural handling.                                                                                                        |
| Unable to Evaluate Message    | UnableToEvaluateMessage\_\_c     | Check that you have Read access to the Opportunity object and its AccountId, IsClosed, and NextStep fields.                                                                   | Describes what could not be reached without blaming the user; ends with a full stop.                                                                                                                                     |
| Fix Message                   | FixMessage\_\_c                  | Add or update the Next Step field on each open Opportunity to document the planned next action.                                                                               | Tells the user what to do next in the order they would do it; ends with a full stop.                                                                                                                                     |
| Action Label                  | ActionLabel\_\_c                 | View Opportunities                                                                                                                                                            | Label for the action link on the card.                                                                                                                                                                                   |
| Action URL                    | ActionUrl\_\_c                   | /lightning/r/Account/{!record.Id}/related/Opportunities/view                                                                                                                  | Lightning URL to the Account's Opportunities related list so the user can add Next Steps.                                                                                                                                |
| Applicability Mode            | ApplicabilityMode\_\_c           | WHEN_COUNT_QUERY_MATCHES                                                                                                                                                      | Requirement specifies that the Check is skipped when the Account has no open Opportunities.                                                                                                                              |
| Applicability Count Query     | ApplicabilityCountQuery\_\_c     | SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false                                                                                           | Bare COUNT() query to count open Opportunities; returns > 0 when the Check applies.                                                                                                                                      |
| Applicability Count Operator  | ApplicabilityCountOperator\_\_c  | GREATER_THAN                                                                                                                                                                  | Opens Opportunities must be present.                                                                                                                                                                                     |
| Applicability Count Threshold | ApplicabilityCountThreshold\_\_c | 0                                                                                                                                                                             | Check applies when open Opportunity count is greater than 0.                                                                                                                                                             |
| Applicability Not Met Message | ApplicabilityNotMetMessage\_\_c  | No open Opportunities to check.                                                                                                                                               | Explains why the Check did not apply when ApplicabilityMode is not ALL_RECORDS; ends with a full stop.                                                                                                                   |
| Prerequisite Check            | PrerequisiteCheck\_\_c           | (blank)                                                                                                                                                                       | Requirement specifies no prerequisite Check.                                                                                                                                                                             |
| Comparison Display Mode       | ComparisonDisplayMode\_\_c       | AUTOMATIC                                                                                                                                                                     | Default; Found and Expected values are displayed based on the comparison operator.                                                                                                                                       |
| Display Value Format          | DisplayValueFormat\_\_c          | AUTO                                                                                                                                                                          | Default; format is determined automatically by the value type.                                                                                                                                                           |
| Display Found Text            | DisplayFoundText\_\_c            | {!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} open Opportunit{!rhcResult.foundValuePluralSuffix} lack Next Steps                                            | Replaces the Found line on the card with a meaningful result value; includes plural handling.                                                                                                                            |
| Display Expected Text         | DisplayExpectedText\_\_c         | All open Opportunities should have Next Steps                                                                                                                                 | Replaces the Expected line on the card with what the administrator expects to see.                                                                                                                                       |
| Publish User Result Event     | PublishUserResultEvent\_\_c      | false                                                                                                                                                                         | Requirement specifies no Platform Events.                                                                                                                                                                                |
| Source Query                  | SourceQuery\_\_c                 | SELECT COUNT() FROM Opportunity WHERE AccountId = {!record.Id} AND IsClosed = false AND NextStep = null                                                                       | Bare COUNT() query that counts open Opportunities without a Next Step. Passes when this count equals 0.                                                                                                                  |
| Source Query Field            | SourceQueryField\_\_c            | (blank)                                                                                                                                                                       | N/A: bare COUNT() aggregate does not need a field alias.                                                                                                                                                                 |
| How To Read Query Results     | QueryResultHandling\_\_c         | ONE_RESULT                                                                                                                                                                    | Bare COUNT() returns exactly one aggregate row.                                                                                                                                                                          |
| Comparison Operator           | ComparisonOperator\_\_c          | EQUALS                                                                                                                                                                        | The count of Opportunities without Next Steps must equal zero to pass.                                                                                                                                                   |
| Expected Value Source         | ExpectedValueSource\_\_c         | FIXED_VALUE                                                                                                                                                                   | The expected value is a fixed number, not a formula or another query.                                                                                                                                                    |
| Expected Fixed Value          | ExpectedFixedValue\_\_c          | 0                                                                                                                                                                             | Pass when zero open Opportunities lack a Next Step.                                                                                                                                                                      |
| If Query Finds No Records     | NoRowsResult\_\_c                | (omit from metadata)                                                                                                                                                          | A bare COUNT() query always returns exactly one aggregate row, even when the count is zero; this field never applies. Use ApplicabilityMode = WHEN_COUNT_QUERY_MATCHES instead to skip when no open Opportunities exist. |
| If Field Value Is Empty       | EmptyValueHandling\_\_c          | AS_NO_MATCH                                                                                                                                                                   | Default; an empty or null field value does not match the expected value.                                                                                                                                                 |
| Max Query Rows                | MaxQueryRows\_\_c                | 200                                                                                                                                                                           | Default; bare COUNT() returns one row regardless of this setting.                                                                                                                                                        |
| Pass Condition Formula        | PassConditionFormula\_\_c        | (omit from metadata)                                                                                                                                                          | QUERY Evaluation Type does not use Salesforce formulas for pass/fail logic.                                                                                                                                              |
| Formula Result Type           | FormulaResultType\_\_c           | AUTO                                                                                                                                                                          | Portable cross-cutting default; QUERY does not otherwise use formula result coercion.                                                                                                                                    |
| Display Found Formula         | DisplayFoundFormula\_\_c         | (omit from metadata)                                                                                                                                                          | QUERY Evaluation Type does not use formula display; use DisplayFoundText\_\_c instead.                                                                                                                                   |
| Display Expected Formula      | DisplayExpectedFormula\_\_c      | (omit from metadata)                                                                                                                                                          | QUERY Evaluation Type does not use formula display; use DisplayExpectedText\_\_c instead.                                                                                                                                |
| Apex Class                    | ApexClass\_\_c                   | (omit from metadata)                                                                                                                                                          | QUERY Evaluation Type does not use Apex.                                                                                                                                                                                 |
| Apex Parameters JSON          | ApexParametersJson\_\_c          | (omit from metadata)                                                                                                                                                          | QUERY Evaluation Type does not use Apex.                                                                                                                                                                                 |
| Comparison Query              | ComparisonQuery\_\_c             | (blank)                                                                                                                                                                       | Not needed; expected value comes from FIXED_VALUE.                                                                                                                                                                       |
| Comparison Query Field        | ComparisonQueryField\_\_c        | (blank)                                                                                                                                                                       | Not needed; expected value comes from FIXED_VALUE.                                                                                                                                                                       |
| Expected Record Formula       | ExpectedRecordFormula\_\_c       | (blank)                                                                                                                                                                       | Not needed; expected value comes from FIXED_VALUE.                                                                                                                                                                       |
| Expected Currency ISO Code    | ExpectedCurrencyIsoCode\_\_c     | (blank)                                                                                                                                                                       | Not multi-currency currency-conversion scenario; not required.                                                                                                                                                           |
| Find In List Formula          | FindInListFormula\_\_c           | (blank)                                                                                                                                                                       | Not a LIST_CONTAINS_ANY or LIST_CONTAINS_NONE comparison.                                                                                                                                                                |

---

## What Users See

**When the Check passes:** "Open Opportunities have Next Steps" with a green checkmark or success indicator.

**When the Check fails:** "Open Opportunities have Next Steps" with a red X or failure indicator. The card displays:

- Failure Message: "{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} open Opportunit{!rhcResult.foundValuePluralSuffix} on {!record.Name fallback="this record"} lack a Next Step."
- Found: "{!rhcResult.failedRecordCount} of {!rhcResult.totalRecordCount} open Opportunit{!rhcResult.foundValuePluralSuffix} lack Next Steps"
- Expected: "All open Opportunities should have Next Steps"
- Fix Message: "Add or update the Next Step field on each open Opportunity to document the planned next action."
- Action: "View Opportunities" button linking to `/lightning/r/Account/{!record.Id}/related/Opportunities/view`

**When the Check is skipped:** "Open Opportunities have Next Steps" with a neutral or skip indicator (not counted because PassedChecksDisplay is SHOW_COUNT_ONLY, but displayed if ApplicabilityNotMetMessage is shown). The card displays:

- Applicability Not Met Message: "No open Opportunities to check."

**When the Check cannot be evaluated (UNABLE_TO_EVALUATE):** "Open Opportunities have Next Steps" with an error or unable indicator. The card displays:

- Unable to Evaluate Message: "Check that you have Read access to the Opportunity object and its AccountId, IsClosed, and NextStep fields."

**When the Check encounters an error (ERROR):** A system error message is displayed, typically "An error occurred while evaluating this Check." The exact message depends on the error type.

---

## Permissions and Sharing Assumptions

The running user must have:

- **Object access:** Read access to the Opportunity object.
- **Field access:** Read access to the following fields on Opportunity:
  - `AccountId` (standard field, lookup)
  - `IsClosed` (standard field, checkbox)
  - `NextStep` (standard field, text area)

**Behavior under access restrictions:**

- If the user lacks Read access to the Opportunity object, the Check returns UNABLE_TO_EVALUATE and displays: "Check that you have Read access to the Opportunity object and its AccountId, IsClosed, and NextStep fields."
- If the user lacks Read access to any of the three required fields, the Check returns UNABLE_TO_EVALUATE with the same message.
- Related Opportunity records the user cannot see due to sharing rules, role hierarchies, or field-level security are not counted by the queries. This reflects the user's actual view of the data and is not the same as clean data. For example, if an Account has five open Opportunities but the user can see only three, the query runs against the three visible records only.
- Users without the ability to edit Opportunity records can still view the Check results and the "View Opportunities" action link; they cannot make changes from the related list.

**For account managers (the specified user group):**

- Ensure account managers have Read access to the Opportunity object and all required fields.
- If account managers have record access restrictions (e.g., cannot see Opportunities outside their territory), the Check results reflect only the records they can see. This is expected behavior.

---

## Sandbox Test Cases

### Test Case 1: All Open Opportunities Have Next Steps (PASS)

**Setup:**

- Create an Account, for example "Test Account 1".
- Create three open Opportunities related to this Account:
  - Opportunity 1: IsClosed = false, NextStep = "Send proposal"
  - Opportunity 2: IsClosed = false, NextStep = "Schedule demo"
  - Opportunity 3: IsClosed = false, NextStep = "Follow up after demo"

**Action:**

- Open the Account record in Salesforce. The card loads automatically (RUN_ON_LOAD).

**Expected Result:**

- Status: PASS
- Title: "Open Opportunities have Next Steps" with a success indicator.
- Message: "(No failure message; Check passed.)"
- Found: "0 of 3 open Opportunities lack Next Steps" (or similar wording indicating all are complete).
- Action: "View Opportunities" link is available.

### Test Case 2: Some Open Opportunities Have No Next Step (FAIL)

**Setup:**

- Create an Account, for example "Test Account 2".
- Create three open Opportunities related to this Account:
  - Opportunity 1: IsClosed = false, NextStep = "Send proposal"
  - Opportunity 2: IsClosed = false, NextStep = null (empty)
  - Opportunity 3: IsClosed = false, NextStep = null (empty)

**Action:**

- Open the Account record in Salesforce. The card loads automatically (RUN_ON_LOAD).

**Expected Result:**

- Status: FAIL
- Title: "Open Opportunities have Next Steps" with a failure indicator.
- Failure Message: "2 of 3 open Opportunities on Test Account 2 lack a Next Step."
- Found: "2 of 3 open Opportunities lack Next Steps"
- Expected: "All open Opportunities should have Next Steps"
- Fix Message: "Add or update the Next Step field on each open Opportunity to document the planned next action."
- Action: "View Opportunities" link is available for the user to make corrections.

### Test Case 3: Account Has No Open Opportunities (SKIPPED)

**Setup:**

- Create an Account, for example "Test Account 3".
- Create two closed Opportunities related to this Account:
  - Opportunity 1: IsClosed = true, NextStep = "Deal closed"
  - Opportunity 2: IsClosed = true, NextStep = "Deal closed"
- Do not create any open Opportunities.

**Action:**

- Open the Account record in Salesforce. The card loads automatically (RUN_ON_LOAD).

**Expected Result:**

- Status: SKIPPED
- Title: "Open Opportunities have Next Steps" with a skip indicator (not counted in the summary due to SHOW_COUNT_ONLY).
- Applicability Not Met Message: "No open Opportunities to check."
- No Found, Expected, or Fix Message is shown.

### Test Case 4: User Lacks Read Access to Opportunity (UNABLE_TO_EVALUATE)

**Setup:**

- Create an Account, for example "Test Account 4".
- Create an open Opportunity related to this Account with NextStep = null.
- Create a user without Read access to the Opportunity object (e.g., a restricted permission set that does not include Opportunity read).

**Action:**

- Log in as the restricted user and open the Account record.

**Expected Result:**

- Status: UNABLE_TO_EVALUATE
- Title: "Open Opportunities have Next Steps" with an unable indicator.
- Unable to Evaluate Message: "Check that you have Read access to the Opportunity object and its AccountId, IsClosed, and NextStep fields."
- No Found, Expected, or Fix Message is shown.

### Test Case 5: Mixed Open and Closed Opportunities (FAIL)

**Setup:**

- Create an Account, for example "Test Account 5".
- Create five Opportunities related to this Account:
  - Opportunity 1: IsClosed = true, NextStep = "Deal closed" (closed, ignored)
  - Opportunity 2: IsClosed = false, NextStep = "Send proposal" (open, has next step)
  - Opportunity 3: IsClosed = false, NextStep = null (open, no next step)
  - Opportunity 4: IsClosed = false, NextStep = "Schedule meeting" (open, has next step)
  - Opportunity 5: IsClosed = true, NextStep = null (closed, ignored)

**Action:**

- Open the Account record in Salesforce. The card loads automatically (RUN_ON_LOAD).

**Expected Result:**

- Status: FAIL
- Title: "Open Opportunities have Next Steps" with a failure indicator.
- Failure Message: "1 of 3 open Opportunities on Test Account 5 lack a Next Step." (Only open opportunities are counted; closed ones are ignored.)
- Found: "1 of 3 open Opportunities lack Next Steps"
- Expected: "All open Opportunities should have Next Steps"
- Fix Message: "Add or update the Next Step field on each open Opportunity to document the planned next action."

---

## Fields and Values That Require Confirmation in Salesforce Setup

No fields or values require confirmation. All details—object names, field names, relationships, and business logic—are supplied by the requirement and match the Salesforce standard object structure.

The Check is ready for import into the Salesforce org after the Check Set and Check metadata are created.
