# Record Health Check: Account Recent Activity

## 1. Plain-language summary

This Check passes when the Account record has a Task or Event with `IsClosed = true` and `ActivityDate` within the last 90 days. It fails when the Account has no such recent activity. The Check applies to all Account records and never skips.

## 2. Clarifying questions

- **Check Set Developer Name**: Propose `Account_Activity_Checks` for the Check Set's `DeveloperName`. Confirm this value or provide the desired name.
- **Check Developer Name**: Propose `Has_Recent_Activity` for the Check's `DeveloperName`. Confirm this value or provide the desired name.
- **minimumActivities parameter**: `AccountHasRecentActivityCheck` supports an optional `minimumActivities` parameter (accepted range: 1–1,000, default: 1) to require multiple Tasks or Events. The requirement specifies only `daysBack: 90`. Confirm whether `minimumActivities` should be included and, if so, what value to set.

## 3. Check Set configuration

| Setup label             | API field name            | Proposed value                | Why                                                                        |
| ----------------------- | ------------------------- | ----------------------------- | -------------------------------------------------------------------------- |
| Label                   | MasterLabel               | Account Activity Checks       | Names the card on the Account record page.                                 |
| Developer Name          | DeveloperName             | Account_Activity_Checks       | Administrator-created name, no rhc\_\_ prefix. Confirm the desired value.  |
| Object API Name         | ObjectApiName\_\_c        | Account                       | Base object.                                                               |
| Active                  | IsActive\_\_c             | true                          | Default and required.                                                      |
| Card Title              | CardTitle\_\_c            | Account Activity              | Displays at the top of the card.                                           |
| Card Subtitle           | CardSubtitle\_\_c         | Recent Task and Event history | Describes what this card covers on Account records.                        |
| Card Run Mode           | CardRunMode\_\_c          | RUN_ON_REQUEST                | Runs when the user clicks the Run button.                                  |
| Card Reveal Mode        | CardRevealMode\_\_c       | ONE_BY_ONE                    | Default. Checks reveal one at a time.                                      |
| Summary Display         | SummaryDisplay\_\_c       | BOTTOM                        | Summary appears below the checks.                                          |
| Passed Checks Display   | PassedChecksDisplay\_\_c  | SHOW_EACH_CHECK               | Default. Shows each passing result.                                        |
| Skipped Checks Display  | SkippedChecksDisplay\_\_c | SHOW_EACH_CHECK               | Default. Applies to all records, but shows count if configuration changes. |
| Found/Expected Display  | FoundExpectedDisplay\_\_c | ON_DEMAND                     | Default. Apex Checks provide their own Found and Expected values.          |
| Run Button Display      | RunButtonDisplay\_\_c     | LABEL_AND_ICON                | Default. Show both the label and icon.                                     |
| Run Button Label        | RunButtonLabel\_\_c       | Run                           | Explicit label for editability.                                            |
| Rerun Button Label      | RerunButtonLabel\_\_c     | Rerun                         | Explicit label for editability.                                            |
| Run Button Icon         | RunButtonIcon\_\_c        | utility:refresh               | SLDS icon suggesting a refresh or check action.                            |
| Stop on System Error    | StopOnSystemError\_\_c    | false                         | Default. Continue evaluation even if an error occurs.                      |
| Show Diagnostics        | ShowDiagnostics\_\_c      | false                         | Sandbox troubleshooting only.                                              |
| Publish User Run Event  | PublishUserRunEvent\_\_c  | false                         | No platform events required.                                               |
| Publish Error Log Event | PublishErrorLogEvent\_\_c | false                         | No platform events required.                                               |

## 4. Check configuration

| Setup label                   | API field name                  | Proposed value                                                                                                                              | Why                                                                                                                   |
| ----------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Record Health Check Set       | Record_Health_Check_Set\_\_c    | Account_Activity_Checks                                                                                                                     | Reference to the Check Set DeveloperName. Confirm the actual value.                                                   |
| Label                         | MasterLabel                     | Has Recent Activity                                                                                                                         | Names the Check record.                                                                                               |
| Developer Name                | DeveloperName                   | Has_Recent_Activity                                                                                                                         | Administrator-created name, no rhc\_\_ prefix. Confirm the desired value.                                             |
| Check Title                   | CheckTitle\_\_c                 | Recent Activity                                                                                                                             | Row heading on the card stating the claim being tested.                                                               |
| Check Description             | CheckDescription\_\_c           | Passes when this Account has a Task or Event within the last 90 days.                                                                       | Explains the pass condition without restating it as a fact about failing records.                                     |
| Evaluation Type               | EvaluationType\_\_c             | APEX                                                                                                                                        | Uses AccountHasRecentActivityCheck.                                                                                   |
| Category                      | Category\_\_c                   | TIMELINESS                                                                                                                                  | Groups the card summary. The rule assesses recency.                                                                   |
| Failure Severity              | FailureSeverity\_\_c            | WARNING                                                                                                                                     | Severity level for a failing result.                                                                                  |
| Evaluation Order              | EvaluationOrder\_\_c            | 100                                                                                                                                         | Default order.                                                                                                        |
| Active                        | IsActive\_\_c                   | true                                                                                                                                        | Default and required.                                                                                                 |
| Failure Message               | FailureMessage\_\_c             | {!record.Name fallback="this record"} has no recent activity. The last Task or Event was more than 90 days ago.                             | Tells the user what is wrong, includes the record name, and explains the 90-day threshold.                            |
| Unable to Evaluate Message    | UnableToEvaluateMessage\_\_c    | Unable to evaluate recent activity. Check that you have Read access to Account and its Task and Event records.                              | Names what could not be reached and what to check, without blaming the user.                                          |
| Fix Message                   | FixMessage\_\_c                 | Review the Account's Task and Event records to understand the activity history. Add a new Task or Event if the Account requires engagement. | Concrete next steps in order.                                                                                         |
| Action Label                  | ActionLabel\_\_c                | Review Account                                                                                                                              | Link text inviting the user to the Account record.                                                                    |
| Action URL                    | ActionUrl\_\_c                  | /lightning/r/Account/{!record.Id}/view                                                                                                      | Lightning record page for the Account. Allows the user to review activity.                                            |
| Applicability Mode            | ApplicabilityMode\_\_c          | ALL_RECORDS                                                                                                                                 | Applies to every Account. Never skips.                                                                                |
| Applicability Not Met Message | ApplicabilityNotMetMessage\_\_c | (blank)                                                                                                                                     | Not used; ApplicabilityMode is ALL_RECORDS.                                                                           |
| Prerequisite Check            | PrerequisiteCheck\_\_c          | (blank)                                                                                                                                     | No prerequisite required.                                                                                             |
| Comparison Display Mode       | ComparisonDisplayMode\_\_c      | AUTOMATIC                                                                                                                                   | Default. Apex Checks provide Found and Expected values.                                                               |
| Display Value Format          | DisplayValueFormat\_\_c         | AUTO                                                                                                                                        | Default. Format is supplied by the Apex class's own output.                                                           |
| Display Found Text            | DisplayFoundText\_\_c           | (omit from metadata)                                                                                                                        | Apex Checks provide their own Found text.                                                                             |
| Display Expected Text         | DisplayExpectedText\_\_c        | (omit from metadata)                                                                                                                        | Apex Checks provide their own Expected text.                                                                          |
| Display Found Formula         | DisplayFoundFormula\_\_c        | (omit from metadata)                                                                                                                        | Apex Checks do not use formulas.                                                                                      |
| Display Expected Formula      | DisplayExpectedFormula\_\_c     | (omit from metadata)                                                                                                                        | Apex Checks do not use formulas.                                                                                      |
| Publish User Result Event     | PublishUserResultEvent\_\_c     | false                                                                                                                                       | Default. No platform events required.                                                                                 |
| Apex Class                    | ApexClass\_\_c                  | AccountHasRecentActivityCheck                                                                                                               | Installed with the package. Implements rhc.RecordHealthCheckPlugin.                                                   |
| Apex Parameters JSON          | ApexParametersJson\_\_c         | {"daysBack": 90}                                                                                                                            | Configures the class to check for activity in the last 90 days. See clarifying questions regarding minimumActivities. |
| Pass Condition Formula        | PassConditionFormula\_\_c       | (omit from metadata)                                                                                                                        | Apex evaluation; formula not used.                                                                                    |
| Formula Result Type           | FormulaResultType\_\_c          | AUTO                                                                                                                                        | Apex evaluation; formula not used.                                                                                    |
| Source Query                  | SourceQuery\_\_c                | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |
| Source Query Field            | SourceQueryField\_\_c           | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |
| Comparison Query              | ComparisonQuery\_\_c            | (omit from metadata)                                                                                                                        | Apex evaluation; comparison not used.                                                                                 |
| Comparison Query Field        | ComparisonQueryField\_\_c       | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |
| Query Result Handling         | QueryResultHandling\_\_c        | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |
| Comparison Operator           | ComparisonOperator\_\_c         | (omit from metadata)                                                                                                                        | Apex evaluation; comparison not used.                                                                                 |
| Expected Value Source         | ExpectedValueSource\_\_c        | (omit from metadata)                                                                                                                        | Apex evaluation; expected value not used.                                                                             |
| Expected Fixed Value          | ExpectedFixedValue\_\_c         | (omit from metadata)                                                                                                                        | Apex evaluation; expected value not used.                                                                             |
| Expected Record Formula       | ExpectedRecordFormula\_\_c      | (omit from metadata)                                                                                                                        | Apex evaluation; formula not used.                                                                                    |
| Expected Currency ISO Code    | ExpectedCurrencyIsoCode\_\_c    | (omit from metadata)                                                                                                                        | Apex evaluation; currency not used.                                                                                   |
| Find in List Formula          | FindInListFormula\_\_c          | (omit from metadata)                                                                                                                        | Apex evaluation; formula not used.                                                                                    |
| No Rows Result                | NoRowsResult\_\_c               | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |
| Empty Value Handling          | EmptyValueHandling\_\_c         | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |
| Max Query Rows                | MaxQueryRows\_\_c               | (omit from metadata)                                                                                                                        | Apex evaluation; query not used.                                                                                      |

## 5. AccountHasRecentActivityCheck class contract

**Objects and fields queried:**

- `Task`: `Id`, `WhatId`, `ActivityDate`, `IsClosed`
- `Event`: `Id`, `WhatId`, `ActivityDate`

**Bulk query shape:**
The class receives one or more Account IDs and queries Tasks and Events in bulk, once per object, with no SOQL inside a loop.

**Outcome per requested record ID:**
One result per Account ID:

- **PASS**: The Account has at least one closed Task or one Event with `ActivityDate` on or after the cutoff date (today minus `daysBack` days), and the count of such records meets or exceeds `minimumActivities` (if supplied).
- **FAIL**: The Account has no Task or Event meeting the criteria, or the count is below `minimumActivities`.
- **UNABLE_TO_EVALUATE**: The running user lacks Read access to Account, Task, or Event, or `ApexParametersJson__c` is invalid or contains out-of-range values.
- **ERROR**: An unexpected exception occurred.

**Parameters (ApexParametersJson\_\_c):**

- `daysBack` (number, required): The number of days to look back from today. Accepted range: 1–3,650. Default: 30 (when not supplied, but this Check specifies 90).
- `minimumActivities` (number, optional): The minimum number of qualifying Tasks or Events required to pass. Accepted range: 1–1,000. Default: 1.

**Reason codes:**

- `INVALID_APEX_PARAMETERS`: `ApexParametersJson__c` is malformed JSON.
- `INVALID_CONFIG`: A parameter value is outside its accepted range (e.g., `daysBack: 4000`).
- `PERMISSION_DENIED`: The running user lacks Read access to a required object or field.

**Tests:**

1. **Bulk evaluation**: Supply 25 Account IDs, half with qualifying Tasks/Events, half without. Verify the class returns one outcome per Account ID and queries all records in bulk.
2. **Recent Task pass**: Account with a closed Task dated 30 days ago. Expect PASS.
3. **Recent Event pass**: Account with an Event dated 60 days ago. Expect PASS.
4. **Stale Task fail**: Account with a closed Task dated 100 days ago. Expect FAIL.
5. **No activity fail**: Account with no Tasks or Events. Expect FAIL.
6. **Permission denied**: User with Read access to Account and Task, but not Event. Query results include Events. Expect UNABLE_TO_EVALUATE with `PERMISSION_DENIED`.
7. **Invalid daysBack**: Set `ApexParametersJson__c` to `{"daysBack": 4000}`. Expect UNABLE_TO_EVALUATE with `INVALID_CONFIG`.
8. **Malformed JSON**: Set `ApexParametersJson__c` to `{"daysBack": "not a number"}`. Expect UNABLE_TO_EVALUATE with `INVALID_APEX_PARAMETERS`.
9. **minimumActivities threshold**: Account with two qualifying Tasks; `minimumActivities: 2`. Expect PASS. Same Account; `minimumActivities: 3`. Expect FAIL.

## 6. What users see

### PASS

**Card row title:** Recent Activity
**Outcome:** Apex class returns Found and Expected values (e.g., Found: "Task on 2026-08-15"; Expected: "Activity within 90 days").

### FAIL

**Card row title:** Recent Activity
**Severity:** Warning
**Failure message:** "{!record.Name fallback="this record"} has no recent activity. The last Task or Event was more than 90 days ago."
**Fix message:** "Review the Account's Task and Event records to understand the activity history. Add a new Task or Event if the Account requires engagement."
**Action link:** "Review Account" → `/lightning/r/Account/{record.Id}/view`

### SKIPPED

Not applicable; the Check applies to all Accounts.

### UNABLE_TO_EVALUATE

**Message:** "Unable to evaluate recent activity. Check that you have Read access to Account and its Task and Event records."
**Reason codes:** `INVALID_APEX_PARAMETERS`, `INVALID_CONFIG`, `PERMISSION_DENIED`.

### ERROR

An unexpected error occurred during evaluation. Inspect debug logs and enable `ShowDiagnostics__c` for additional details.

## 7. Permissions and sharing assumptions

- The running user must have Read access to the Account object.
- The running user must have Read access to the Task object and its `WhatId`, `ActivityDate`, and `IsClosed` fields.
- The running user must have Read access to the Event object and its `WhatId` and `ActivityDate` fields.
- `AccountHasRecentActivityCheck` respects the running user's access and does not escalate permissions. A Task or Event the user cannot see is not counted.
- Verify that account managers (the specified user audience) have at least Read access to Account, Task, and Event.
- Test the Check with account manager users to confirm expected PASS, FAIL, and UNABLE_TO_EVALUATE outcomes under their permission sets.

## 8. Sandbox test cases

### Test 1: Account with a Task in the last 90 days

**Setup:** Create an Account named "Active Customer". Create a closed Task with `WhatId = Account.Id`, `ActivityDate = today - 30 days`.
**Action:** Run the Check on the Account.
**Expected result:** PASS. Apex class detects the recent Task.

### Test 2: Account with an Event in the last 90 days

**Setup:** Create an Account named "Event Account". Create an Event with `WhatId = Account.Id`, `ActivityDate = today - 60 days`.
**Action:** Run the Check on the Account.
**Expected result:** PASS. Apex class detects the recent Event.

### Test 3: Account with Task outside the 90-day window

**Setup:** Create an Account named "Dormant Account". Create a closed Task with `WhatId = Account.Id`, `ActivityDate = today - 100 days`.
**Action:** Run the Check on the Account.
**Expected result:** FAIL. Message: "Dormant Account has no recent activity. The last Task or Event was more than 90 days ago."

### Test 4: Account with no Tasks or Events

**Setup:** Create an Account named "New Account" with no associated Tasks or Events.
**Action:** Run the Check on the Account.
**Expected result:** FAIL. Message: "New Account has no recent activity. The last Task or Event was more than 90 days ago."

### Test 5: Account manager with full access

**Setup:** Create an Account. Create a Task dated 30 days ago. Assign a user to a permission set that grants Read access to Account, Task, and Event. Log in as that user.
**Action:** Run the Check on the Account.
**Expected result:** PASS.

### Test 6: User without Read access to Event

**Setup:** Create an Account. Create a Task dated 30 days ago. Assign a user a permission set that grants Read access to Account and Task, but explicitly denies Read access to Event. Log in as that user.
**Action:** Run the Check on the Account.
**Expected result:** UNABLE_TO_EVALUATE. Message: "Unable to evaluate recent activity. Check that you have Read access to Account and its Task and Event records."

### Test 7: Bulk evaluation with mixed results

**Setup:** Create 25 Accounts. Add a Task dated 30 days ago to 15 of them. Leave 10 without any Tasks or Events.
**Action:** Run the Check Set on all 25 Accounts.
**Expected result:** 15 Accounts return PASS, 10 return FAIL. Verify that the Apex class queries all records in bulk without SOQL inside a loop.

### Test 8: Invalid daysBack parameter

**Setup:** Set `ApexParametersJson__c` to `{"daysBack": 4000}`.
**Action:** Run the Check on any Account.
**Expected result:** UNABLE_TO_EVALUATE with reason code `INVALID_CONFIG`.

### Test 9: Malformed JSON in ApexParametersJson

**Setup:** Set `ApexParametersJson__c` to invalid JSON, such as `{"daysBack": "ninety"}`.
**Action:** Run the Check on any Account.
**Expected result:** UNABLE_TO_EVALUATE with reason code `INVALID_APEX_PARAMETERS`.

### Test 10: minimumActivities parameter (if included)

**Setup:** Set `ApexParametersJson__c` to `{"daysBack": 90, "minimumActivities": 2}`. Create an Account with one Task dated 30 days ago.
**Action:** Run the Check.
**Expected result:** FAIL (only one Task; minimum is two). Add a second Task and rerun. Expected result: PASS.

## 9. Fields and values that still require confirmation in Salesforce Setup

- **Check Set DeveloperName**: Confirm the value for `Record_Health_Check_Set__mdt.DeveloperName`. Proposed: `Account_Activity_Checks`.
- **Check DeveloperName**: Confirm the value for `Record_Health_Check__mdt.DeveloperName`. Proposed: `Has_Recent_Activity`.
- **ApexParametersJson\_\_c**: Confirm whether the optional `minimumActivities` parameter should be included and, if so, what value it should have. Current proposal: `{"daysBack": 90}`.
- **AccountHasRecentActivityCheck availability**: Verify that the `AccountHasRecentActivityCheck` class is deployed in the target org and is accessible to the package or the running user.
